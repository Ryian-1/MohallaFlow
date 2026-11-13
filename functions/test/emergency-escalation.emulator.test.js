'use strict';

const { test, afterEach, after } = require('node:test');
const assert = require('node:assert/strict');

const {
  getApps,
  deleteApp,
} = require('firebase-admin/app');

const {
  Timestamp,
  getFirestore,
} = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

const PROJECT_ID = 'demo-mohallaflow';

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  throw new Error('Emergency tests require the Firestore Emulator.');
}

if (process.env.GCLOUD_PROJECT !== PROJECT_ID) {
  throw new Error('Emergency tests are restricted to demo-mohallaflow.');
}

process.env.FUNCTIONS_EMULATOR = 'true';

const handlers = require('../index');
const db = getFirestore();
const adminMessaging = getMessaging();

const scheduled = handlers.escalateUnacknowledgedEmergencyAlerts;
const updatedHandler = handlers.notifyEmergencySOSUpdated;
const dispatchHandler = handlers.dispatchMohallaFlowPush;

const colonyId = `emergency_escalation_${process.pid}_${Date.now()}`;
const colonyRef = db.collection('colonies').doc(colonyId);
const alertsRef = colonyRef.collection('emergencyAlerts');

for (const [name, handler] of [
  ['scheduled escalation', scheduled],
  ['SOS update handler', updatedHandler],
  ['push dispatcher', dispatchHandler],
]) {
  if (typeof handler?.run !== 'function') {
    throw new Error(`${name} does not expose a callable run method.`);
  }
}

function fixture({
  level = 0,
  ageMinutes = 3,
  status,
  acknowledgedAt = null,
  resolvedAt = null,
  cancelledAt = null,
} = {}) {
  const createdAt = Timestamp.fromMillis(
    Date.now() - ageMinutes * 60 * 1000,
  );

  return {
    status: status || (level === 0 ? 'open' : 'escalated'),
    escalationLevel: level,
    createdAt,
    nextEscalationAt: Timestamp.fromMillis(Date.now() - 5000),
    acknowledgedAt,
    resolvedAt,
    cancelledAt,
    createdByUid: 'resident-test',
    createdByName: 'Emergency Test Resident',
    assignedResponderUid: null,
    location: 'Block A',
    category: 'medical',
    severity: 'critical',
  };
}

async function seedAlert(id, options = {}) {
  const ref = alertsRef.doc(id);
  const data = fixture(options);

  await ref.set(data);

  return { ref, data };
}

// Remove test documents in batches, including known event subdocuments.
async function cleanupColony() {
  const refs = [colonyRef];

  const alerts = await alertsRef.get();

  for (const alert of alerts.docs) {
    refs.push(alert.ref);

    for (const level of [1, 2, 3]) {
      refs.push(
        alert.ref.collection('events')
          .doc(`system_escalation_${level}`),
      );
    }
  }

  const members = await colonyRef.collection('members').get();

  for (const member of members.docs) {
    refs.push(member.ref);
    refs.push(db.collection('users').doc(member.id));

    const installations = await member.ref
      .collection('pushInstallations')
      .get();

    for (const installation of installations.docs) {
      refs.push(installation.ref);
    }
  }

  for (const collectionName of [
    'notifications',
    'pushNotificationDeliveries',
  ]) {
    const snapshot = await colonyRef.collection(collectionName).get();

    for (const document of snapshot.docs) {
      refs.push(document.ref);

      if (collectionName === 'pushNotificationDeliveries') {
        const devices = await document.ref.collection('devices').get();
        for (const device of devices.docs) refs.push(device.ref);
      }
    }
  }

  for (let offset = 0; offset < refs.length; offset += 400) {
    const batch = db.batch();

    for (const ref of refs.slice(offset, offset + 400)) {
      batch.delete(ref);
    }

    await batch.commit();
  }
}

afterEach(async () => {
  await cleanupColony();
});

after(async () => {
  for (const app of getApps()) {
    await deleteApp(app);
  }
});

// 1. Verify the exact escalation timeline and persistent event records.
test('escalates at 2, 5 and 10 minutes with correct event records', async () => {
  const cases = [
    { id: 'level-one', level: 0, ageMinutes: 3, nextMinutes: 5 },
    { id: 'level-two', level: 1, ageMinutes: 6, nextMinutes: 10 },
    { id: 'level-three', level: 2, ageMinutes: 11, nextMinutes: null },
  ];

  const seeded = [];

  for (const item of cases) {
    seeded.push({
      ...item,
      ...(await seedAlert(item.id, {
        level: item.level,
        ageMinutes: item.ageMinutes,
      })),
    });
  }

  await scheduled.run();

  for (const item of seeded) {
    const snapshot = await item.ref.get();
    const data = snapshot.data();

    assert.equal(data.escalationLevel, item.level + 1);
    assert.equal(data.status, 'escalated');

    const eventRef = item.ref.collection('events')
      .doc(`system_escalation_${item.level + 1}`);

    const event = await eventRef.get();

    assert.equal(event.exists, true);
    assert.equal(event.data().action, 'escalated');
    assert.equal(
      event.data().actorUid,
      'system',
    );

    if (item.nextMinutes === null) {
      assert.equal(
        Object.hasOwn(data, 'nextEscalationAt'),
        false,
        'Final escalation must remove its next timer.',
      );
    } else {
      assert.equal(
        data.nextEscalationAt.toMillis(),
        item.data.createdAt.toMillis() +
          item.nextMinutes * 60 * 1000,
      );
    }
  }

  console.log('PASS: Level 1, Level 2 and Level 3.');
  console.log('PASS: Escalation timestamps and event records.');
});

// 2. Verify stop conditions and server-side timer removal.
test('acknowledgement, resolution and cancellation stop escalation', async () => {
  const cases = [
    {
      id: 'stop-acknowledged',
      marker: 'acknowledgedAt',
      status: 'acknowledged',
    },
    {
      id: 'stop-resolved',
      marker: 'resolvedAt',
      status: 'resolved',
    },
    {
      id: 'stop-cancelled',
      marker: 'cancelledAt',
      status: 'cancelled',
    },
  ];

  const seeded = [];

  for (const item of cases) {
    seeded.push({
      ...item,
      ...(await seedAlert(item.id, {
        level: 0,
        ageMinutes: 3,
        [item.marker]: Timestamp.now(),
      })),
    });
  }

  await scheduled.run();

  for (const item of seeded) {
    const unchanged = await item.ref.get();

    assert.equal(unchanged.data().escalationLevel, 0);
    assert.equal(
      (await item.ref.collection('events').get()).size,
      0,
    );

    const before = await item.ref.get();

    await item.ref.update({
      status: item.status,
      [item.marker]: Timestamp.now(),
    });

    const afterSnapshot = await item.ref.get();

    await updatedHandler.run({
      id: `stop-event-${item.id}`,
      params: {
        colonyId,
        alertId: item.id,
      },
      data: {
        before,
        after: afterSnapshot,
      },
    });

    const finalSnapshot = await item.ref.get();
    const finalData = finalSnapshot.data();

    assert.equal(finalData.status, item.status);
    assert.equal(finalData.escalationLevel, 0);
    assert.equal(
      Object.hasOwn(finalData, 'nextEscalationAt'),
      false,
      `${item.status} must remove the escalation timer.`,
    );
  }

  console.log('PASS: Acknowledged alerts stop.');
  console.log('PASS: Resolved alerts stop.');
  console.log('PASS: Cancelled alerts stop.');
});

// 3. Concurrent execution, notification idempotency and no-device dispatch.
test('concurrent runs create one event and notification without external FCM', async () => {
  const { ref } = await seedAlert('concurrent-alert', {
    level: 0,
    ageMinutes: 3,
  });

  const before = await ref.get();

  await Promise.all([
    scheduled.run(),
    scheduled.run(),
  ]);

  const afterSnapshot = await ref.get();
  const data = afterSnapshot.data();

  assert.equal(data.escalationLevel, 1);

  const events = await ref.collection('events').get();
  assert.equal(events.size, 1);

  const eventId = 'stable-escalation-test-event';

  const updateEvent = {
    id: eventId,
    params: {
      colonyId,
      alertId: 'concurrent-alert',
    },
    data: {
      before,
      after: afterSnapshot,
    },
  };

  await updatedHandler.run(updateEvent);
  await updatedHandler.run(updateEvent);

  const notificationId =
    `sos_concurrent-alert_escalated_${eventId}`;

  const notificationRef = colonyRef
    .collection('notifications')
    .doc(notificationId);

  const notification = await notificationRef.get();

  assert.equal(notification.exists, true);
  assert.equal(
    notification.data().eventType,
    'emergency_sos_escalated',
  );
  assert.equal(notification.data().recipientKey, 'role:admin');
  assert.deepEqual(notification.data().recipientKeys, ['role:admin']);

  // No members or push installations are seeded in this test colony.
  // The real dispatcher must therefore record no_devices without calling FCM.
  await dispatchHandler.run({
    params: {
      colonyId,
      notificationId,
    },
    data: notification,
  });

  const delivery = await colonyRef
    .collection('pushNotificationDeliveries')
    .doc(notificationId)
    .get();

  assert.equal(delivery.exists, true);
  assert.equal(delivery.data().status, 'no_devices');
  assert.equal(delivery.data().targetCount, 0);

  await scheduled.run();

  assert.equal(
    (await ref.collection('events').get()).size,
    1,
  );

  console.log('PASS: Concurrent escalation protected.');
  console.log('PASS: Duplicate notification creation prevented.');
  console.log('PASS: Dispatcher recorded no_devices.');
  console.log('PASS: No external FCM delivery required.');
});

test('legacy notifications without recipientKey retain array-based dispatch', async () => {
  const notificationId = 'legacy-notification-no-scalar-key';
  const notificationRef = colonyRef
    .collection('notifications')
    .doc(notificationId);

  await notificationRef.create({
    title: 'Legacy notification',
    message: 'Compatibility test for a pre-scalar notification.',
    eventType: 'legacy_test',
    recipientKeys: ['role:admin'],
    sourceCollection: 'legacy',
    sourceId: 'legacy-source',
    createdBy: 'legacy-system',
    createdAt: Timestamp.now(),
  });

  const notification = await notificationRef.get();

  await dispatchHandler.run({
    params: { colonyId, notificationId },
    data: notification,
  });

  const delivery = await colonyRef
    .collection('pushNotificationDeliveries')
    .doc(notificationId)
    .get();

  assert.equal(delivery.exists, true);
  assert.equal(delivery.data().status, 'no_devices');
  assert.equal(delivery.data().targetCount, 0);

  console.log('PASS: Legacy recipientKeys fallback remains available.');
});

test('multi-recipient SOS events create deterministic recipient-specific notifications', async () => {
  const { ref } = await seedAlert('multi-recipient-alert', {
    level: 0,
    ageMinutes: 3,
  });

  const before = await ref.get();

  await ref.update({
    status: 'escalated',
    escalationLevel: 1,
    assignedResponderUid: 'responder-test',
  });

  const afterSnapshot = await ref.get();

  const updateEvent = {
    id: 'stable-multi-recipient-test-event',
    params: {
      colonyId,
      alertId: 'multi-recipient-alert',
    },
    data: { before, after: afterSnapshot },
  };

  await updatedHandler.run(updateEvent);
  await updatedHandler.run(updateEvent);

  const notifications = await colonyRef
    .collection('notifications')
    .where('sourceId', '==', 'multi-recipient-alert')
    .get();

  assert.equal(notifications.size, 3);

  const assignmentDocs = notifications.docs.filter(
    (document) => document.data().eventType === 'emergency_sos_assigned',
  );
  assert.equal(assignmentDocs.length, 1);
  assert.equal(assignmentDocs[0].data().recipientKey, 'user:responder-test');
  assert.deepEqual(
    assignmentDocs[0].data().recipientKeys,
    ['user:responder-test'],
  );

  const escalationDocs = notifications.docs.filter(
    (document) => document.data().eventType === 'emergency_sos_escalated',
  );
  assert.equal(escalationDocs.length, 2);

  const scalarRecipients = escalationDocs
    .map((document) => document.data().recipientKey)
    .sort();

  assert.deepEqual(
    scalarRecipients,
    ['role:admin', 'user:responder-test'],
  );

  for (const document of escalationDocs) {
    assert.deepEqual(
      document.data().recipientKeys,
      ['role:admin', 'user:responder-test'],
    );
  }

  assert.equal(
    new Set(notifications.docs.map((document) => document.id)).size,
    3,
  );

  console.log('PASS: SOS assignment uses one scalar recipient.');
  console.log('PASS: Multi-recipient escalation creates separate documents.');
  console.log('PASS: Recipient-specific IDs are deterministic.');
  console.log('PASS: Retried events do not create duplicate notifications.');
});

test('scalar dispatch targets only one audience; legacy dispatch preserves array audiences', async () => {
  const adminUid = `push_admin_${process.pid}`;
  const managerUid = `push_manager_${process.pid}`;
  const adminFid = `fake_admin_fid_${process.pid}`;
  const managerFid = `fake_manager_fid_${process.pid}`;

  const members = [
    {
      uid: adminUid,
      role: 'admin',
      fid: adminFid,
    },
    {
      uid: managerUid,
      role: 'cleanliness_manager',
      fid: managerFid,
    },
  ];

  for (const member of members) {
    const memberRef = colonyRef.collection('members').doc(member.uid);

    await memberRef.set({
      uid: member.uid,
      colonyId,
      role: member.role,
      status: 'active',
    });

    await db.collection('users').doc(member.uid).set({
      status: 'active',
    });

    await memberRef.collection('pushInstallations').doc(member.fid).set({
      fid: member.fid,
      platform: 'ios',
    });
  }

  const scalarId = 'scalar-admin-only-dispatch';
  const legacyId = 'legacy-array-dispatch';

  const notificationData = {
    title: 'Recipient routing test',
    message: 'This is an emulator-only FCM routing test.',
    eventType: 'routing_test',
    recipientKeys: ['role:admin', 'role:cleanliness_manager'],
    sourceCollection: 'routingTests',
    sourceId: 'routing-test-source',
    createdBy: 'routing-test',
    createdAt: Timestamp.now(),
  };

  const scalarRef = colonyRef.collection('notifications').doc(scalarId);
  const legacyRef = colonyRef.collection('notifications').doc(legacyId);

  await scalarRef.create({
    ...notificationData,
    recipientKey: 'role:admin',
  });

  await legacyRef.create(notificationData);

  const sentFids = [];
  const originalSend = adminMessaging.send;

  adminMessaging.send = async (message) => {
    sentFids.push(message.fid);
    return `mock-message-${message.fid}`;
  };

  try {
    for (const notificationRef of [scalarRef, legacyRef]) {
      const snapshot = await notificationRef.get();

      await dispatchHandler.run({
        params: {
          colonyId,
          notificationId: notificationRef.id,
        },
        data: snapshot,
      });
    }
  } finally {
    adminMessaging.send = originalSend;
  }

  const scalarDelivery = await colonyRef
    .collection('pushNotificationDeliveries')
    .doc(scalarId)
    .get();

  const legacyDelivery = await colonyRef
    .collection('pushNotificationDeliveries')
    .doc(legacyId)
    .get();

  assert.equal(scalarDelivery.data().targetCount, 1);
  assert.equal(scalarDelivery.data().sentCount, 1);

  assert.equal(legacyDelivery.data().targetCount, 2);
  assert.equal(legacyDelivery.data().sentCount, 2);

  assert.equal(
    sentFids.filter((fid) => fid === adminFid).length,
    2,
    'Admin should receive the scalar and legacy notifications.',
  );

  assert.equal(
    sentFids.filter((fid) => fid === managerFid).length,
    1,
    'Manager should receive only the legacy array notification.',
  );

  console.log('PASS: Scalar notification dispatched only to Admin.');
  console.log('PASS: Manager did not receive the scalar Admin notification.');
  console.log('PASS: Legacy notification reached both configured audiences.');
  console.log('PASS: FCM was stubbed; no external notification was sent.');
});

// 4. Verify the scheduler's 250-document query limit and subsequent run.
test(
  'processes 250 due alerts and remaining alerts on the next run',
  { timeout: 120000 },
  async () => {
    const createdAt = Timestamp.fromMillis(
      Date.now() - 3 * 60 * 1000,
    );

    const dueAt = Timestamp.fromMillis(Date.now() - 5000);
    const batch = db.batch();
    const total = 251;

    for (let i = 0; i < total; i++) {
      const ref = alertsRef.doc(`batch-${String(i).padStart(3, '0')}`);

      batch.set(ref, {
        status: 'open',
        escalationLevel: 0,
        createdAt,
        nextEscalationAt: dueAt,
        acknowledgedAt: null,
        resolvedAt: null,
        cancelledAt: null,
        createdByUid: 'resident-test',
        createdByName: 'Batch Test Resident',
        location: 'Block B',
        category: 'medical',
        severity: 'critical',
      });
    }

    await batch.commit();

    await scheduled.run();

    let snapshot = await alertsRef.get();

    let processed = snapshot.docs.filter(
      (document) => document.data().escalationLevel === 1,
    ).length;

    assert.equal(processed, 250);

    await scheduled.run();

    snapshot = await alertsRef.get();

    processed = snapshot.docs.filter(
      (document) => document.data().escalationLevel === 1,
    ).length;

    assert.equal(processed, 251);

    console.log('PASS: First run processed exactly 250 alerts.');
    console.log('PASS: Second run processed the remaining alert.');
  },
);
