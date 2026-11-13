'use strict';

const crypto = require('node:crypto');
const { FieldPath } = require('firebase-admin/firestore');

const MIGRATION_VERSION = 1;

function normalizedRecipientKeys(data) {
  if (!Array.isArray(data.recipientKeys)) return [];

  return [...new Set(
    data.recipientKeys
      .filter((value) => typeof value === 'string')
      .map((value) => value.trim())
      .filter(Boolean),
  )].sort();
}

function recipientCopyId(sourceNotificationId, recipientKey) {
  const digest = crypto.createHash('sha256')
    .update(`${sourceNotificationId}\0${recipientKey}`)
    .digest('hex')
    .slice(0, 32);

  return `migrated_${digest}`;
}

function memberMatchesRecipient(memberId, member, colonyId, recipientKey) {
  if (
    !member ||
    member.uid !== memberId ||
    member.colonyId !== colonyId
  ) {
    return false;
  }

  if (recipientKey.startsWith('user:')) {
    return memberId === recipientKey.slice('user:'.length);
  }

  if (recipientKey.startsWith('role:')) {
    return member.role === recipientKey.slice('role:'.length);
  }

  if (recipientKey.startsWith('worker:')) {
    return member.role === 'worker' &&
      member.workerId === recipientKey.slice('worker:'.length);
  }

  return false;
}

function alreadyMigratedCopy(data, sourceId, recipientKey) {
  return data.migrationClone === true &&
    data.scalarRecipientMigrationVersion === MIGRATION_VERSION &&
    data.migrationSourceId === sourceId &&
    data.recipientKey === recipientKey &&
    data.pushSuppressed === true;
}

/**
 * Converts one colony's legacy array-recipient notifications to scalar
 * recipient documents.
 *
 * Dry-run is the default. This function never sends push notifications.
 * Original document IDs and their read receipts are retained for the
 * first deterministic recipient. Other recipients receive deterministic
 * copies and matching existing read receipts.
 */
async function migrateColonyNotifications(
  db,
  colonyId,
  {
    dryRun = true,
    pageSize = 100,
  } = {},
) {
  if (!db) throw new Error('A Firestore Admin instance is required.');
  if (typeof colonyId !== 'string' || !colonyId.trim()) {
    throw new Error('A non-empty colonyId is required.');
  }
  if (!Number.isInteger(pageSize) || pageSize < 1 || pageSize > 400) {
    throw new Error('pageSize must be between 1 and 400.');
  }

  const colonyRef = db.collection('colonies').doc(colonyId);
  const notificationsRef = colonyRef.collection('notifications');
  const membersSnapshot = await colonyRef.collection('members').get();
  const members = membersSnapshot.docs.map((document) => ({
    id: document.id,
    ref: document.ref,
    data: document.data() || {},
  }));

  // Capture the source document set before creating copies. This prevents
  // newly-created copies from being reprocessed during the same run.
  const sourceDocuments = [];
  let cursor = null;

  while (true) {
    let query = notificationsRef
      .orderBy(FieldPath.documentId())
      .limit(pageSize);

    if (cursor) query = query.startAfter(cursor);

    const page = await query.get();
    if (page.empty) break;

    sourceDocuments.push(...page.docs);
    cursor = page.docs[page.docs.length - 1];

    if (page.size < pageSize) break;
  }

  const summary = {
    colonyId,
    dryRun,
    documentsScanned: sourceDocuments.length,
    legacyDocumentsFound: 0,
    originalDocumentsUpdated: 0,
    recipientCopiesPlanned: 0,
    recipientCopiesCreated: 0,
    recipientCopiesReused: 0,
    readReceiptsPlanned: 0,
    readReceiptsCopied: 0,
    alreadyScalarDocuments: 0,
    alreadyMigratedDocuments: 0,
    migrationCopiesSkipped: 0,
    notificationsWithoutRecipients: 0,
  };

  for (const sourceDocument of sourceDocuments) {
    const sourceId = sourceDocument.id;
    const data = sourceDocument.data() || {};

    if (data.migrationClone === true) {
      summary.migrationCopiesSkipped += 1;
      continue;
    }

    if (data.scalarRecipientMigrationVersion === MIGRATION_VERSION) {
      if (
        typeof data.recipientKey !== 'string' ||
        !data.recipientKey.trim()
      ) {
        throw new Error(
          `Migration marker exists without a valid recipientKey: ${sourceId}`,
        );
      }
      summary.alreadyMigratedDocuments += 1;
      continue;
    }

    // New app-created notifications already have a scalar key. Do not
    // re-fan-out those documents.
    if (data.recipientKey !== undefined && data.recipientKey !== null) {
      if (
        typeof data.recipientKey !== 'string' ||
        !data.recipientKey.trim()
      ) {
        throw new Error(`Invalid existing recipientKey: ${sourceId}`);
      }
      summary.alreadyScalarDocuments += 1;
      continue;
    }

    const recipients = normalizedRecipientKeys(data);

    if (recipients.length === 0) {
      summary.notificationsWithoutRecipients += 1;
      continue;
    }

    summary.legacyDocumentsFound += 1;

    // The original ID remains assigned to the first stable recipient.
    const primaryRecipient = recipients[0];

    for (const recipientKey of recipients.slice(1)) {
      summary.recipientCopiesPlanned += 1;

      const copyId = recipientCopyId(sourceId, recipientKey);
      const copyRef = notificationsRef.doc(copyId);

      const copyData = {
        ...data,
        recipientKeys: recipients,
        recipientKey,
        scalarRecipientMigrationVersion: MIGRATION_VERSION,
        migrationClone: true,
        migrationSourceId: sourceId,
        pushSuppressed: true,
      };

      const existingCopy = await copyRef.get();

      if (existingCopy.exists) {
        if (!alreadyMigratedCopy(existingCopy.data(), sourceId, recipientKey)) {
          throw new Error(
            `Deterministic recipient-copy ID collision: ${copyId}`,
          );
        }
        summary.recipientCopiesReused += 1;
      } else if (dryRun) {
        // No writes in dry-run mode.
      } else {
        await copyRef.create(copyData);
        summary.recipientCopiesCreated += 1;
      }

      // Copy a read receipt only for members who match this recipient key.
      // Inactive memberships are included so their read state is not lost.
      for (const member of members) {
        if (!memberMatchesRecipient(
          member.id,
          member.data,
          colonyId,
          recipientKey,
        )) {
          continue;
        }

        const sourceReceiptRef = member.ref
          .collection('notificationReads')
          .doc(sourceId);
        const destinationReceiptRef = member.ref
          .collection('notificationReads')
          .doc(copyId);

        const sourceReceipt = await sourceReceiptRef.get();
        if (!sourceReceipt.exists) continue;

        const destinationReceipt = await destinationReceiptRef.get();
        if (destinationReceipt.exists) continue;

        if (dryRun) {
          summary.readReceiptsPlanned += 1;
        } else {
          await destinationReceiptRef.create(sourceReceipt.data());
          summary.readReceiptsCopied += 1;
        }
      }
    }

    if (!dryRun) {
      // Update the original only after all copies and receipt transfers
      // succeeded. A failed run can be safely resumed.
      await sourceDocument.ref.update({
        recipientKey: primaryRecipient,
        scalarRecipientMigrationVersion: MIGRATION_VERSION,
      });
      summary.originalDocumentsUpdated += 1;
    }
  }

  return summary;
}

module.exports = {
  MIGRATION_VERSION,
  normalizedRecipientKeys,
  recipientCopyId,
  memberMatchesRecipient,
  migrateColonyNotifications,
};
