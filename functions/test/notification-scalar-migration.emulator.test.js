'use strict';

const { test, after } = require('node:test');
const assert = require('node:assert/strict');

const PROJECT_ID = 'demo-mohallaflow';

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  throw new Error('Notification migration tests require Firestore Emulator.');
}
if (process.env.GCLOUD_PROJECT !== PROJECT_ID) {
  throw new Error('Notification migration tests are restricted to demo-mohallaflow.');
}

process.env.FUNCTIONS_EMULATOR = 'true';

const handlers = require('../index');
const { getFirestore } = require('firebase-admin/firestore');
const { getApps, deleteApp } = require('firebase-admin/app');
const { Timestamp } = require('firebase-admin/firestore');

const {
  recipientCopyId,
  migrateColonyNotifications,
} = require('../lib/notification_scalar_migration');

const db = getFirestore();
const colonyId = `notification_scalar_migration_${process.pid}_${Date.now()}`;
const colonyRef = db.collection('colonies').doc(colonyId);
const notificationsRef = colonyRef.collection('notifications');

async function cleanup() {
  const refs = [];

  const notifications = await notificationsRef.get();
  for (const document of notifications.docs) refs.push(document.ref);

  const members = await colonyRef.collection('members').get();
  for (const member of members.docs) {
    refs.push(member.ref);

    const receipts = await member.ref.collection('notificationReads').get();
    for (const receipt of receipts.docs) refs.push(receipt.ref);

    const installations = await member.ref.collection('pushInstallations').get();
    for (const installation of installations.docs) refs.push(installation.ref);
  }

  const deliveries = await colonyRef.collection('pushNotificationDeliveries').get();
  for (const delivery of deliveries.docs) {
    refs.push(delivery.ref);
    const devices = await delivery.ref.collection('devices').get();
    for (const device of devices.docs) refs.push(device.ref);
  }

  for (let offset = 0; offset < refs.length; offset += 400) {
    const batch = db.batch();
    for (const ref of refs.slice(offset, offset + 400)) batch.delete(ref);
    await batch.commit();
  }

  await colonyRef.delete().catch(() => undefined);
}

after(async () => {
  await cleanup();
  for (const app of getApps()) await deleteApp(app);
});

test('legacy notification migration is dry-run safe, idempotent and preserves read receipts', async () => {
  const members = [
    { uid: 'admin-user', role: 'admin' },
    { uid: 'manager-user', role: 'cleanliness_manager' },
    {
      uid: 'resident-user',
      role: 'resident',
      residentId: 'resident-record-1',
    },
    {
      uid: 'worker-user',
      role: 'worker',
      workerId: 'worker-migration-1',
    },
  ];

  for (const member of members) {
    await colonyRef.collection('members').doc(member.uid).set({
      ...member,
      colonyId,
      status: 'active',
    });
  }

  const originalId = 'legacy-multi-audience-notification';
  const originalRef = notificationsRef.doc(originalId);
  const originalReadAt = Timestamp.fromMillis(1760000000000);

  const recipients = [
    'role:admin',
    'role:cleanliness_manager',
    'user:resident-user',
    'worker:worker-migration-1',
  ];

  await originalRef.set({
    title: 'Legacy colony announcement',
    message: 'Historical notification to migrate.',
    eventType: 'legacy_test',
    recipientKeys: recipients,
    sourceCollection: 'legacy',
    sourceId: 'legacy-source-1',
    createdBy: 'legacy-system',
    createdAt: Timestamp.fromMillis(1759990000000),
  });

  await colonyRef.collection('members').doc('admin-user')
    .collection('notificationReads').doc(originalId)
    .set({ readAt: originalReadAt });

  await colonyRef.collection('members').doc('resident-user')
    .collection('notificationReads').doc(originalId)
    .set({ readAt: originalReadAt });

  await colonyRef.collection('members').doc('worker-user')
    .collection('notificationReads').doc(originalId)
    .set({ readAt: originalReadAt });

  console.log('DRY RUN: no documents may be modified.');
  const dry = await migrateColonyNotifications(db, colonyId, {
    dryRun: true,
  });

  assert.equal(dry.legacyDocumentsFound, 1);
  assert.equal(dry.originalDocumentsUpdated, 0);
  assert.equal(dry.recipientCopiesPlanned, 3);
  assert.equal(dry.recipientCopiesCreated, 0);
  assert.equal(dry.readReceiptsPlanned, 2);
  assert.equal((await originalRef.get()).data().recipientKey, undefined);

  for (const recipientKey of recipients.slice(1)) {
    const copyId = recipientCopyId(originalId, recipientKey);
    assert.equal((await notificationsRef.doc(copyId).get()).exists, false);
  }

  console.log('PASS: Dry-run performs no writes.');

  console.log('APPLY: migrate recipients and copy read receipts.');
  const applied = await migrateColonyNotifications(db, colonyId, {
    dryRun: false,
  });

  assert.equal(applied.legacyDocumentsFound, 1);
  assert.equal(applied.originalDocumentsUpdated, 1);
  assert.equal(applied.recipientCopiesCreated, 3);
  assert.equal(applied.readReceiptsCopied, 2);

  const original = await originalRef.get();
  assert.equal(original.data().recipientKey, 'role:admin');
  assert.equal(original.data().scalarRecipientMigrationVersion, 1);
  assert.equal(original.data().pushSuppressed, undefined);

  for (const recipientKey of recipients.slice(1)) {
    const copyId = recipientCopyId(originalId, recipientKey);
    const copy = await notificationsRef.doc(copyId).get();

    assert.equal(copy.exists, true);
    assert.equal(copy.data().recipientKey, recipientKey);
    assert.deepEqual(copy.data().recipientKeys, recipients);
    assert.equal(copy.data().migrationClone, true);
    assert.equal(copy.data().migrationSourceId, originalId);
    assert.equal(copy.data().scalarRecipientMigrationVersion, 1);
    assert.equal(copy.data().pushSuppressed, true);
  }

  const adminReceipt = await colonyRef.collection('members').doc('admin-user')
    .collection('notificationReads').doc(originalId).get();
  assert.equal(adminReceipt.exists, true);

  const managerCopyId = recipientCopyId(originalId, 'role:cleanliness_manager');
  const managerReceipt = await colonyRef.collection('members').doc('manager-user')
    .collection('notificationReads').doc(managerCopyId).get();
  assert.equal(managerReceipt.exists, false);

  const residentCopyId = recipientCopyId(originalId, 'user:resident-user');
  const residentReceipt = await colonyRef.collection('members').doc('resident-user')
    .collection('notificationReads').doc(residentCopyId).get();
  assert.equal(residentReceipt.exists, true);
  assert.equal(residentReceipt.data().readAt.isEqual(originalReadAt), true);

  const workerCopyId = recipientCopyId(originalId, 'worker:worker-migration-1');
  const workerReceipt = await colonyRef.collection('members').doc('worker-user')
    .collection('notificationReads').doc(workerCopyId).get();
  assert.equal(workerReceipt.exists, true);
  assert.equal(workerReceipt.data().readAt.isEqual(originalReadAt), true);

  console.log('PASS: Original notification ID and primary receipt preserved.');
  console.log('PASS: Matching recipient receipts copied to deterministic IDs.');
  console.log('PASS: Unread manager receipt remains absent.');

  console.log('PUSH: migrated copies must never replay historical pushes.');
  const migratedCopyRef = notificationsRef.doc(residentCopyId);
  await handlers.dispatchMohallaFlowPush.run({
    params: {
      colonyId,
      notificationId: residentCopyId,
    },
    data: await migratedCopyRef.get(),
  });

  const suppressedDelivery = await colonyRef
    .collection('pushNotificationDeliveries')
    .doc(residentCopyId)
    .get();
  assert.equal(suppressedDelivery.exists, false);

  console.log('PASS: Migrated copy suppresses push dispatch.');

  console.log('RERUN: applying migration a second time must be safe.');
  const rerun = await migrateColonyNotifications(db, colonyId, {
    dryRun: false,
  });

  assert.equal(rerun.originalDocumentsUpdated, 0);
  assert.equal(rerun.recipientCopiesCreated, 0);
  assert.equal(rerun.readReceiptsCopied, 0);
  assert.equal(rerun.alreadyMigratedDocuments, 1);

  const afterRerun = await notificationsRef.get();
  assert.equal(afterRerun.size, 4);

  console.log('PASS: Second migration run creates no duplicates or receipt changes.');
});
