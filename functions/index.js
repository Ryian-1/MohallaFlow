const crypto = require('node:crypto');
const { getApps, initializeApp } = require('firebase-admin/app');
const { FieldValue, Timestamp, getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { approvePayrollRun, PayrollApprovalError } = require('./lib/payroll');
const {
  toIndianE164,
  groupMatchesByColony,
  isClaimableRegistration,
  isActiveResident,
} = require('./lib/phone');

if (getApps().length === 0) {
  initializeApp();
}

const db = getFirestore();
const messaging = getMessaging();

// Enforce App Check for deployed callable Functions. The Firebase Functions
// Emulator bypasses attestation so local integration tests remain usable.
const enforceCallableAppCheck = process.env.FUNCTIONS_EMULATOR !== 'true';

const INVALID_FID_CODES = new Set([
  'messaging/installation-id-not-registered',
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
]);

function matchesAudience(memberId, member, recipientKeys) {
  const uid = member.uid || memberId;
  if (uid !== memberId || !member.role) return false;

  if (recipientKeys.has(`user:${uid}`)) return true;
  if (recipientKeys.has(`role:${member.role}`)) return true;

  const workerId = typeof member.workerId === 'string' ? member.workerId : '';
  return member.role === 'worker' &&
    workerId.length > 0 &&
    recipientKeys.has(`worker:${workerId}`);
}

async function sendOneInstallation({
  colonyId,
  notificationId,
  memberId,
  installationRef,
  installationId,
  title,
  body,
  data,
}) {
  const hash = crypto.createHash('sha256').update(installationId).digest('hex');
  const receiptRef = db
    .collection('colonies').doc(colonyId)
    .collection('pushNotificationDeliveries').doc(notificationId)
    .collection('devices').doc(hash);

  const claimed = await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(receiptRef);
    if (snapshot.exists) {
      const previous = snapshot.data() || {};
      if (previous.status === 'sent' || previous.status === 'invalid') return false;
      const leaseUntil = previous.leaseUntil;
      if (previous.status === 'sending' &&
          leaseUntil &&
          typeof leaseUntil.toMillis === 'function' &&
          leaseUntil.toMillis() > Date.now()) {
        return false;
      }
    }

    transaction.set(receiptRef, {
      status: 'sending',
      leaseUntil: Timestamp.fromMillis(Date.now() + 120000),
      fidHash: hash,
      memberId,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    return true;
  });

  if (!claimed) return 'skipped';

  try {
    const messageId = await messaging.send({
      fid: installationId,
      notification: { title, body },
      data,
      android: { priority: 'high' },
      apns: {
        headers: { 'apns-priority': '10' },
        payload: { aps: { sound: 'default' } },
      },
    });

    await receiptRef.set({
      status: 'sent',
      messageId,
      sentAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      leaseUntil: FieldValue.delete(),
    }, { merge: true });
    return 'sent';
  } catch (error) {
    const code = error && error.code ? String(error.code) : 'unknown';

    if (INVALID_FID_CODES.has(code)) {
      await installationRef.delete().catch(() => undefined);
      await receiptRef.set({
        status: 'invalid',
        errorCode: code,
        updatedAt: FieldValue.serverTimestamp(),
        leaseUntil: FieldValue.delete(),
      }, { merge: true });
      return 'invalid';
    }

    await receiptRef.set({
      status: 'failed',
      errorCode: code,
      updatedAt: FieldValue.serverTimestamp(),
      leaseUntil: FieldValue.delete(),
    }, { merge: true });
    throw error;
  }
}

exports.dispatchMohallaFlowPush = onDocumentCreated(
  {
    document: 'colonies/{colonyId}/notifications/{notificationId}',
    retry: true,
    timeoutSeconds: 120,
    memory: '256MiB',
  },
  async (event) => {
    const { colonyId, notificationId } = event.params;
    const notificationSnapshot = event.data;
    if (!notificationSnapshot) return;

    const notification = notificationSnapshot.data() || {};

    // Historical notification copies created by the scalar-recipient
    // migration must remain visible in-app without replaying old pushes.
    if (notification.pushSuppressed === true) {
      console.log('Historical notification push suppressed.', {
        colonyId,
        notificationId,
      });
      return;
    }

    // New notifications are one document per audience key. Prefer the scalar
    // key to avoid dispatching to every audience member for each fan-out copy.
    // Legacy documents without recipientKey retain the original array path.
    const hasScalarRecipient = Object.prototype.hasOwnProperty.call(
      notification,
      'recipientKey',
    );

    let rawRecipients;
    if (hasScalarRecipient) {
      const scalarRecipient = typeof notification.recipientKey === 'string'
        ? notification.recipientKey.trim()
        : '';

      if (!scalarRecipient) {
        console.warn('Invalid recipientKey; push dispatch skipped.', {
          colonyId,
          notificationId,
        });
        return;
      }

      rawRecipients = [scalarRecipient];
    } else {
      rawRecipients = Array.isArray(notification.recipientKeys)
        ? notification.recipientKeys
        : [];
    }

    const recipientKeys = new Set(
      rawRecipients
        .filter((value) =>
          typeof value === 'string' && value.trim().length > 0)
        .map((value) => value.trim()),
    );

    if (recipientKeys.size === 0) {
      console.log(
        'No valid recipientKey or legacy recipientKeys; push dispatch skipped.',
        { colonyId, notificationId },
      );
      return;
    }

    const membersSnapshot = await db
      .collection('colonies').doc(colonyId)
      .collection('members')
      .where('status', '==', 'active')
      .get();

    const targets = [];
    for (const memberDocument of membersSnapshot.docs) {
      const member = memberDocument.data() || {};
      if (member.colonyId !== colonyId ||
          !matchesAudience(memberDocument.id, member, recipientKeys)) {
        continue;
      }

      const accountSnapshot = await db.collection('users').doc(memberDocument.id).get();
      const account = accountSnapshot.data() || {};
      if (!accountSnapshot.exists || String(account.status || '').toLowerCase() !== 'active') {
        continue;
      }

      const installations = await memberDocument.ref
        .collection('pushInstallations')
        .get();

      for (const installationDocument of installations.docs) {
        const installation = installationDocument.data() || {};
        const fid = typeof installation.fid === 'string'
          ? installation.fid
          : installationDocument.id;
        if (!fid || fid !== installationDocument.id || fid.includes('/')) continue;

        targets.push({
          memberId: memberDocument.id,
          installationRef: installationDocument.ref,
          installationId: fid,
        });
      }
    }

    const title = String(notification.title || 'MohallaFlow update').slice(0, 120);
    const body = String(notification.message || 'You have a new colony update.').slice(0, 500);
    const messageData = {
      colonyId: String(colonyId),
      notificationId: String(notificationId),
      eventType: String(notification.eventType || 'colony_update'),
      sourceCollection: String(notification.sourceCollection || ''),
      sourceId: String(notification.sourceId || ''),
    };

    const dispatchRef = db
      .collection('colonies').doc(colonyId)
      .collection('pushNotificationDeliveries').doc(notificationId);

    if (targets.length === 0) {
      await dispatchRef.set({
        status: 'no_devices',
        targetCount: 0,
        completedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
      return;
    }

    let sentCount = 0;
    let invalidCount = 0;
    let skippedCount = 0;
    const retryableErrors = [];

    // Bound concurrency so large colonies do not create a burst of unbounded
    // simultaneous FCM requests. Receipts make repeated trigger attempts safe.
    for (let offset = 0; offset < targets.length; offset += 25) {
      const chunk = targets.slice(offset, offset + 25);
      const results = await Promise.allSettled(chunk.map((target) =>
        sendOneInstallation({
          colonyId,
          notificationId,
          ...target,
          title,
          body,
          data: messageData,
        }),
      ));

      for (const result of results) {
        if (result.status === 'rejected') {
          retryableErrors.push(result.reason);
          continue;
        }
        if (result.value === 'sent') sentCount += 1;
        else if (result.value === 'invalid') invalidCount += 1;
        else skippedCount += 1;
      }
    }

    await dispatchRef.set({
      status: retryableErrors.length > 0 ? 'retrying' : 'sent',
      targetCount: targets.length,
      sentCount,
      invalidCount,
      skippedCount,
      completedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    if (retryableErrors.length > 0) {
      throw new Error(
        `MohallaFlow push dispatch had ${retryableErrors.length} retryable device failures.`,
      );
    }
  },
);



// -----------------------------------------------------------------------------
// MOHALLAFLOW — EMERGENCY SOS PUSH AND SERVER-SIDE ESCALATION
// Uses the existing notifications collection and existing FID dispatcher.
// All notification documents are created by Firebase Admin SDK.
// -----------------------------------------------------------------------------

async function createEmergencyPushNotification({
  colonyId,
  alertId,
  eventKey,
  alert,
  title,
  body,
  eventType,
  recipientKeys,
}) {
  const safeEventKey = String(eventKey)
    .replace(/[^A-Za-z0-9_-]/g, '_')
    .slice(0, 120);

  const baseNotificationId = `sos_${alertId}_${safeEventKey}`;

  const recipients = [...new Set(
    (Array.isArray(recipientKeys) ? recipientKeys : [])
      .filter(
        (value) =>
          typeof value === 'string' && value.trim().length > 0,
      )
      .map((value) => value.trim()),
  )];

  if (recipients.length === 0) return false;

  let createdAny = false;

  for (const recipientKey of recipients) {
    const recipientSuffix = recipients.length === 1
      ? ''
      : `_r_${crypto.createHash('sha256')
        .update(recipientKey)
        .digest('hex')
        .slice(0, 12)}`;

    const notificationId = `${baseNotificationId}${recipientSuffix}`;
    const notificationRef = db
      .collection('colonies').doc(colonyId)
      .collection('notifications').doc(notificationId);

    const record = {
      title: String(title || 'Emergency SOS').slice(0, 120),
      message: String(body || 'An emergency alert requires attention.').slice(0, 500),
      eventType,
      recipientKeys: recipients,
      recipientKey,
      sourceCollection: 'emergencyAlerts',
      sourceId: String(alertId),
      createdBy: String(alert.createdByUid || 'system'),
      createdAt: FieldValue.serverTimestamp(),
    };

    try {
      await notificationRef.create(record);
      createdAny = true;
    } catch (error) {
      const code = error && error.code;
      if (
        code === 6 ||
        code === 'already-exists' ||
        String(code).endsWith('/already-exists')
      ) {
        continue;
      }
      throw error;
    }
  }

  return createdAny;
}

// A new SOS immediately alerts the colony Admin role.
exports.notifyEmergencySOSCreated = onDocumentCreated(
  {
    document: 'colonies/{colonyId}/emergencyAlerts/{alertId}',
    retry: true,
    timeoutSeconds: 60,
    memory: '256MiB',
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const { colonyId, alertId } = event.params;
    const alert = snapshot.data() || {};

    // Server-owned scheduling field. Clients cannot set or alter it in Rules.
    const createdAt = alert.createdAt;
    if (
      createdAt && typeof createdAt.toMillis === 'function' &&
      Number(alert.escalationLevel || 0) === 0 &&
      alert.acknowledgedAt == null && alert.resolvedAt == null && alert.cancelledAt == null
    ) {
      await snapshot.ref.update({
        nextEscalationAt: Timestamp.fromMillis(createdAt.toMillis() + 2 * 60 * 1000),
      });
    }

    await createEmergencyPushNotification({
      colonyId,
      alertId,
      eventKey: 'created',
      alert,
      title: `Emergency SOS — ${alert.category || 'Emergency'}`,
      body: `${alert.createdByName || 'A resident'} raised a ${alert.severity || 'urgent'} SOS at ${alert.location || 'an unspecified location'}.`,
      eventType: 'emergency_sos_created',
      recipientKeys: ['role:admin'],
    });
  },
);

// Assignment, acknowledgement, response progress, resolution and escalation.
exports.notifyEmergencySOSUpdated = onDocumentUpdated(
  {
    document: 'colonies/{colonyId}/emergencyAlerts/{alertId}',
    retry: true,
    timeoutSeconds: 60,
    memory: '256MiB',
  },
  async (event) => {
    if (!event.data) return;

    const before = event.data.before.data() || {};
    const after = event.data.after.data() || {};
    const { colonyId, alertId } = event.params;
    const eventKey = String(event.id || Date.now());

    const isEscalationActive =
      ['open', 'escalated'].includes(String(after.status || '')) &&
      after.acknowledgedAt == null && after.resolvedAt == null && after.cancelledAt == null;
    const escalationLevelForTimer = Number(after.escalationLevel || 0);
    const createdAtForTimer = after.createdAt;
    const afterRef = event.data.after.ref;

    if (!isEscalationActive && Object.prototype.hasOwnProperty.call(after, 'nextEscalationAt')) {
      await afterRef.update({ nextEscalationAt: FieldValue.delete() });
    } else if (
      isEscalationActive &&
      !Object.prototype.hasOwnProperty.call(after, 'nextEscalationAt') &&
      Number.isInteger(escalationLevelForTimer) && escalationLevelForTimer >= 0 && escalationLevelForTimer < 3 &&
      createdAtForTimer && typeof createdAtForTimer.toMillis === 'function'
    ) {
      const dueMinutes = [2, 5, 10][escalationLevelForTimer];
      await afterRef.update({
        nextEscalationAt: Timestamp.fromMillis(createdAtForTimer.toMillis() + dueMinutes * 60 * 1000),
      });
    }

    const beforeAssigned = String(before.assignedResponderUid || '');
    const afterAssigned = String(after.assignedResponderUid || '');

    const acknowledgementJustOccurred =
      String(before.status || '') !== 'acknowledged' &&
      String(after.status || '') === 'acknowledged';

    if (
      afterAssigned &&
      afterAssigned !== beforeAssigned &&
      !acknowledgementJustOccurred
    ) {
      await createEmergencyPushNotification({
        colonyId,
        alertId,
        eventKey: `assigned_${eventKey}`,
        alert: after,
        title: 'Emergency SOS — You are assigned',
        body: `You have been assigned to an emergency at ${after.location || 'the colony'}. Open MohallaFlow and acknowledge the alert immediately.`,
        eventType: 'emergency_sos_assigned',
        recipientKeys: [`user:${afterAssigned}`],
      });
    }

    const beforeLevel = Number(before.escalationLevel || 0);
    const afterLevel = Number(after.escalationLevel || 0);

    if (afterLevel > beforeLevel) {
      const recipients = ['role:admin'];
      if (afterAssigned) recipients.push(`user:${afterAssigned}`);

      await createEmergencyPushNotification({
        colonyId,
        alertId,
        eventKey: `escalated_${eventKey}`,
        alert: after,
        title: `UNACKNOWLEDGED EMERGENCY — Level ${afterLevel}`,
        body: `SOS at ${after.location || 'the colony'} remains unacknowledged. Admin intervention is required.`,
        eventType: 'emergency_sos_escalated',
        recipientKeys: recipients,
      });
    }

    const statusChanged = before.status !== after.status;
    const residentUpdateStatuses = [
      'acknowledged',
      'responding',
      'on_scene',
      'resolved',
    ];

    if (
      statusChanged &&
      residentUpdateStatuses.includes(String(after.status || '')) &&
      typeof after.createdByUid === 'string' &&
      after.createdByUid.length > 0
    ) {
      const statusText = String(after.status).replaceAll('_', ' ');

      await createEmergencyPushNotification({
        colonyId,
        alertId,
        eventKey: `status_${eventKey}`,
        alert: after,
        title: 'Emergency SOS status update',
        body: `Your emergency alert is now: ${statusText}.`,
        eventType: 'emergency_sos_status',
        recipientKeys: [`user:${after.createdByUid}`],
      });
    }
  },
);

// Escalation policy:
// Level 1: 2 minutes without acknowledgement.
// Level 2: 5 minutes without acknowledgement.
// Level 3: 10 minutes without acknowledgement.
// An acknowledgement, resolution or cancellation stops escalation.
// Only due alerts are queried through a collection-group composite index.
exports.escalateUnacknowledgedEmergencyAlerts = onSchedule(
  {
    schedule: 'every 1 minutes',
    timeZone: 'Asia/Kolkata',
    region: 'asia-south1',
    timeoutSeconds: 120,
    memory: '256MiB',
    maxInstances: 1,
  },
  async () => {
    const escalationThresholdsMs = [
      2 * 60 * 1000,
      5 * 60 * 1000,
      10 * 60 * 1000,
    ];
    const now = Timestamp.now();

    // Only due alerts are read. This avoids scanning every open alert in every
    // colony once per minute. nextEscalationAt is written only by Admin SDK.
    const dueAlerts = await db.collectionGroup('emergencyAlerts')
      .where('status', 'in', ['open', 'escalated'])
      .where('nextEscalationAt', '<=', now)
      .orderBy('nextEscalationAt', 'asc')
      .limit(250)
      .get();

    for (const alertDocument of dueAlerts.docs) {
      try {
      const alert = alertDocument.data() || {};
      const currentLevel = Number(alert.escalationLevel || 0);
      if (
        !Number.isInteger(currentLevel) ||
        currentLevel < 0 ||
        currentLevel >= escalationThresholdsMs.length ||
        alert.acknowledgedAt != null ||
        alert.resolvedAt != null ||
        alert.cancelledAt != null
      ) continue;

      await db.runTransaction(async (transaction) => {
        const freshSnapshot = await transaction.get(alertDocument.ref);
        if (!freshSnapshot.exists) return;

        const fresh = freshSnapshot.data() || {};
        const freshLevel = Number(fresh.escalationLevel || 0);
        const dueAt = fresh.nextEscalationAt;
        if (
          !['open', 'escalated'].includes(String(fresh.status || '')) ||
          fresh.acknowledgedAt != null ||
          fresh.resolvedAt != null ||
          fresh.cancelledAt != null ||
          !Number.isInteger(freshLevel) ||
          freshLevel !== currentLevel ||
          freshLevel >= escalationThresholdsMs.length ||
          !dueAt || typeof dueAt.toMillis !== 'function' ||
          dueAt.toMillis() > now.toMillis()
        ) return;

        const nextLevel = freshLevel + 1;
        const update = {
          status: 'escalated',
          escalationLevel: nextLevel,
          updatedAt: FieldValue.serverTimestamp(),
          updatedBy: 'system',
        };

        if (nextLevel < escalationThresholdsMs.length) {
          const createdAt = fresh.createdAt;
          if (!createdAt || typeof createdAt.toMillis !== 'function') return;
          update.nextEscalationAt = Timestamp.fromMillis(
            createdAt.toMillis() + escalationThresholdsMs[nextLevel],
          );
        } else {
          update.nextEscalationAt = FieldValue.delete();
        }

        const nextEventReference = alertDocument.ref
          .collection('events')
          .doc(`system_escalation_${nextLevel}`);
        transaction.update(alertDocument.ref, update);
        transaction.set(nextEventReference, {
          action: 'escalated',
          actorUid: 'system',
          actorName: 'MohallaFlow Emergency Automation',
          note: `Automatic escalation level ${nextLevel}: alert remained unacknowledged.`,
          createdAt: FieldValue.serverTimestamp(),
        });
      });
      } catch (error) {
        console.error('Emergency escalation failed for one alert; it will remain eligible for retry.', {
          alertPath: alertDocument.ref.path,
          errorCode: error && error.code ? String(error.code) : 'unknown',
        });
      }
    }
  },
);

const residentPhoneLinkRegion = 'asia-south1';
const residentPhoneLinkMaxMatches = 50;
const residentPhoneLinkMaxColonies = 10;

function residentPhoneLinkFail(code, message) {
  throw new HttpsError(code, message);
}

function residentPhoneLinkString(value) {
  return typeof value === 'string' ? value.trim() : '';
}

exports.claimResidentRegistration = onCall(
  {
    enforceAppCheck: enforceCallableAppCheck,
    region: residentPhoneLinkRegion,
    timeoutSeconds: 30,
    memory: '256MiB',
    maxInstances: 10,
  },
  async (request) => {
    if (!request.auth) {
      residentPhoneLinkFail('unauthenticated', 'Sign in with your own mobile number before linking a resident account.');
    }

    const uid = request.auth.uid;
    // Identity comes only from Firebase Auth's signed phone_number claim.
    // No phone, resident, household, role or colony identifier is accepted from client data.
    const tokenPhone = residentPhoneLinkString(request.auth.token.phone_number);
    const verifiedPhoneE164 = toIndianE164(tokenPhone);
    if (!verifiedPhoneE164 || verifiedPhoneE164 !== tokenPhone) {
      residentPhoneLinkFail('failed-precondition', 'A verified Indian mobile number is required for resident account linking.');
    }

    const registrationsQuery = db.collectionGroup('residentLoginRegistrations')
      .where('phoneNumberE164', '==', verifiedPhoneE164)
      .limit(residentPhoneLinkMaxMatches + 1);

    const result = await db.runTransaction(async (transaction) => {
      const querySnapshot = await transaction.get(registrationsQuery);
      if (querySnapshot.size > residentPhoneLinkMaxMatches) {
        residentPhoneLinkFail('resource-exhausted', 'Too many resident registrations use this personal login number. Contact your Colony Admin.');
      }
      if (querySnapshot.empty) {
        residentPhoneLinkFail('failed-precondition', 'This verified number is not registered for individual resident login. Ask your Colony Admin to add your personal login number.');
      }

      const matches = querySnapshot.docs.map((document) => {
        const colonyDocument = document.ref.parent.parent;
        const colonyId = colonyDocument ? colonyDocument.id : '';
        return {
          registrationRef: document.ref,
          residentRef: colonyDocument
            ? colonyDocument.collection('residents').doc(document.id)
            : null,
          colonyRef: colonyDocument,
          colonyId,
          initial: document.data(),
        };
      });
      if (matches.some((item) => !item.colonyId || !item.residentRef || !item.colonyRef)) {
        residentPhoneLinkFail('internal', 'The resident registration could not be resolved. Contact your Colony Admin.');
      }

      if (matches.some((item) => {
        const linkedUid = residentPhoneLinkString(item.initial.linkedUid);
        return linkedUid.length > 0 && linkedUid !== uid;
      })) {
        residentPhoneLinkFail('already-exists', 'This mobile number is already linked to another MohallaFlow account. Contact your Colony Admin.');
      }

      const grouped = groupMatchesByColony(matches);
      if ([...grouped.values()].some((items) => items.length > 1)) {
        residentPhoneLinkFail('failed-precondition', 'This personal login number is assigned to multiple resident records in the same colony. Ask your Colony Admin to resolve the duplicate.');
      }

      const eligible = matches.filter((item) => isClaimableRegistration(item.initial));
      if (eligible.length === 0) {
        residentPhoneLinkFail('failed-precondition', 'No active resident registration is enabled for this verified mobile number. Contact your Colony Admin.');
      }
      if (eligible.length > residentPhoneLinkMaxColonies) {
        residentPhoneLinkFail('resource-exhausted', 'This account is registered in too many colonies for automatic linking. Contact your Colony Admin.');
      }

      const userRef = db.collection('users').doc(uid);
      const profileSnapshot = await transaction.get(userRef);
      if (profileSnapshot.exists) {
        residentPhoneLinkFail('already-exists', 'A MohallaFlow profile already exists for this account. Contact your Colony Admin to resolve the existing account link.');
      }

      const prepared = [];
      for (const item of eligible) {
        const registrationSnapshot = await transaction.get(item.registrationRef);
        const residentSnapshot = await transaction.get(item.residentRef);
        if (!registrationSnapshot.exists || !residentSnapshot.exists) {
          residentPhoneLinkFail('not-found', 'The resident registration changed. Ask your Colony Admin to refresh it.');
        }
        const registration = registrationSnapshot.data();
        const resident = residentSnapshot.data();
        if (
          residentPhoneLinkString(registration.phoneNumberE164) !== verifiedPhoneE164 ||
          !isClaimableRegistration(registration) ||
          !isActiveResident(resident)
        ) {
          residentPhoneLinkFail('failed-precondition', 'The resident registration is no longer eligible for account linking.');
        }
        const linkedUid = residentPhoneLinkString(registration.linkedUid);
        if (linkedUid && linkedUid !== uid) {
          residentPhoneLinkFail('already-exists', 'This resident registration is already linked to another account.');
        }

        const householdId = residentPhoneLinkString(resident.householdId);
        if (!householdId) {
          residentPhoneLinkFail('failed-precondition', 'The resident registration is missing its household link.');
        }
        const householdRef = item.colonyRef.collection('households').doc(householdId);
        const memberRef = item.colonyRef.collection('members').doc(uid);
        const colonySnapshot = await transaction.get(item.colonyRef);
        const householdSnapshot = await transaction.get(householdRef);
        const memberSnapshot = await transaction.get(memberRef);
        if (!colonySnapshot.exists || !householdSnapshot.exists) {
          residentPhoneLinkFail('failed-precondition', 'The linked colony or household no longer exists.');
        }

        const household = householdSnapshot.data();
        const sharedHouseholdPhone = toIndianE164(residentPhoneLinkString(household.primaryPhone));
        if (sharedHouseholdPhone && sharedHouseholdPhone === verifiedPhoneE164) {
          residentPhoneLinkFail('failed-precondition', "Use the resident's own personal mobile number, not the shared household contact number.");
        }

        const colonyData = colonySnapshot.data();
        const colonyName = residentPhoneLinkString(colonyData.name) ||
          residentPhoneLinkString(colonyData.colonyName) ||
          residentPhoneLinkString(colonyData.displayName) || item.colonyId;
        if (memberSnapshot.exists) {
          const member = memberSnapshot.data();
          if (
            residentPhoneLinkString(member.uid) !== uid ||
            residentPhoneLinkString(member.colonyId) !== item.colonyId ||
            residentPhoneLinkString(member.role) !== 'resident' ||
            residentPhoneLinkString(member.residentId) !== item.residentRef.id
          ) {
            residentPhoneLinkFail('already-exists', 'This account already has a different role or resident link in this colony. Contact your Colony Admin.');
          }
          if (residentPhoneLinkString(member.status).toLowerCase() !== 'active') {
            residentPhoneLinkFail('permission-denied', 'Your existing colony membership is inactive. Contact your Colony Admin.');
          }
        }

        prepared.push({
          item,
          resident,
          memberRef,
          memberExists: memberSnapshot.exists,
          colonyId: item.colonyId,
          colonyName,
          householdId,
          blockId: residentPhoneLinkString(resident.blockId) || residentPhoneLinkString(household.blockId),
        });
      }

      const firstResident = prepared[0].resident;
      const displayName = residentPhoneLinkString(firstResident.fullName) || 'Resident';
      const colonyIds = prepared.map((item) => item.colonyId);
      transaction.create(userRef, {
        uid,
        fullName: displayName,
        displayName,
        phoneNumber: verifiedPhoneE164,
        phoneNumberE164: verifiedPhoneE164,
        phoneNumberVerified: true,
        accountType: 'resident',
        status: 'active',
        colonyIds,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });

      for (const item of prepared) {
        if (!item.memberExists) {
          transaction.create(item.memberRef, {
            uid,
            colonyId: item.colonyId,
            colonyName: item.colonyName,
            role: 'resident',
            status: 'active',
            residentId: item.item.residentRef.id,
            householdId: item.householdId,
            blockId: item.blockId,
            createdAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
            linkedBy: 'verified_phone_registration',
            linkedAt: FieldValue.serverTimestamp(),
          });
        }
        transaction.update(item.item.registrationRef, {
          status: 'linked',
          linkedUid: uid,
          linkedAt: FieldValue.serverTimestamp(),
          verifiedPhoneNumberE164: verifiedPhoneE164,
          updatedAt: FieldValue.serverTimestamp(),
        });
      }

      return {
        linkedCount: prepared.length,
        colonies: prepared.map((item) => ({ id: item.colonyId, name: item.colonyName })),
      };
    });

    console.info('MohallaFlow resident phone registration linked.', {
      uid,
      linkedCount: result.linkedCount,
      colonyIds: result.colonies.map((item) => item.id),
    });
    return { success: true, status: 'linked', ...result };
  },
);


/**
 * Creates a user-initiated account-deletion request. This intentionally does
 * not delete the Firebase Auth account or colony records automatically:
 * colony financial, payroll, safety and statutory records may have retention
 * obligations and require a reviewed deletion/retention workflow.
 */
exports.requestAccountDeletion = onCall(
  {
    enforceAppCheck: enforceCallableAppCheck,
    region: 'asia-south1',
    timeoutSeconds: 60,
    memory: '256MiB',
    maxInstances: 5,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Sign in before requesting account deletion.');
    }

    const uid = request.auth.uid;
    const reason = typeof request.data?.reason === 'string'
      ? request.data.reason.trim().slice(0, 500)
      : '';
    const parentRef = db.collection('accountDeletionRequests').doc(uid);

    try {
      const result = await db.runTransaction(async (transaction) => {
        const parentSnapshot = await transaction.get(parentRef);
        const previous = parentSnapshot.exists ? parentSnapshot.data() || {} : {};
        const previousStatus = String(previous.status || '');
        if (['submitted', 'reviewing'].includes(previousStatus) &&
            typeof previous.latestRequestId === 'string' &&
            previous.latestRequestId.length > 0) {
          return {
            requestId: previous.latestRequestId,
            status: previousStatus,
            alreadySubmitted: true,
          };
        }

        const requestRef = parentRef.collection('requests').doc();
        const record = {
          requestId: requestRef.id,
          uid,
          status: 'submitted',
          requestType: 'account_deletion',
          reason,
          requestedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        };
        transaction.create(requestRef, record);
        transaction.set(parentRef, {
          uid,
          latestRequestId: requestRef.id,
          status: 'submitted',
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
        return { requestId: requestRef.id, status: 'submitted', alreadySubmitted: false };
      });

      return { success: true, ...result };
    } catch (error) {
      console.error('Account deletion request could not be recorded.', {
        uid,
        errorCode: error && error.code ? String(error.code) : 'unknown',
      });
      throw new HttpsError(
        'internal',
        'Your deletion request could not be recorded. Please retry.',
      );
    }
  },
);


/**
 * Authoritative Admin-only approval of a complete colony payroll run.
 * Firestore client Rules intentionally do not permit direct approval writes.
 */
exports.approveColonyPayrollRun = onCall(
  {
    enforceAppCheck: enforceCallableAppCheck,
    region: 'asia-south1',
    timeoutSeconds: 120,
    memory: '512MiB',
    maxInstances: 10,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        'unauthenticated',
        'Sign in before approving payroll.',
      );
    }

    const data = request.data || {};

    try {
      return await approvePayrollRun({
        db,
        colonyId: data.colonyId,
        runId: data.runId,
        uid: request.auth.uid,
      });
    } catch (error) {
      if (error instanceof PayrollApprovalError) {
        throw new HttpsError(error.code, error.message);
      }

      console.error('Payroll approval transaction failed.', {
        colonyId: data.colonyId,
        runId: data.runId,
        uid: request.auth.uid,
        errorCode: error && error.code ? String(error.code) : 'unknown',
      });

      throw new HttpsError(
        'internal',
        'Payroll approval could not be completed. Refresh and try again.',
      );
    }
  },
);
