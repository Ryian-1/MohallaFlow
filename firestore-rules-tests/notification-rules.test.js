import { after, before, test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import {
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  where,
  writeBatch,
} from 'firebase/firestore';

const suffix = `${process.pid}_${Date.now()}`;
const projectId = `mohallaflow-notifications-${process.pid}`;
const colonyId = `notification_test_${suffix}`;
const ADMIN = `admin_${suffix}`;
const RESIDENT = `resident_${suffix}`;
const OTHER_RESIDENT = `other_resident_${suffix}`;
const CLEANLINESS_MANAGER = `manager_${suffix}`;
const SOURCE_COMPLAINT = `existing_complaint_${suffix}`;
const SUBMISSION_NOTIFICATION = `submission_notification_${suffix}`;
const MANAGER_SUBMISSION_NOTIFICATION = `manager_submission_notification_${suffix}`;
const STATUS_NOTIFICATION = `status_notification_${suffix}`;

let testEnv;

function path(...parts) {
  return parts.join('/');
}

function dbFor(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

async function assertPermissionDeniedWithoutEvaluationLimit(operation) {
  let failure;

  try {
    await operation;
  } catch (error) {
    failure = error;
  }

  assert.ok(failure, 'Expected Firestore permission denial.');

  const detail = `${failure.code || ''}: ${failure.message || failure}`;

  assert.equal(
    failure.code,
    'permission-denied',
    `Unexpected failure type: ${detail}`,
  );

  assert.doesNotMatch(
    detail,
    /maximum of 1000 expressions|expression evaluation limit/i,
    'Expression-limit failures must not count as authorization denials.',
  );
}

function memberData(uid, role, extra = {}) {
  return {
    uid,
    colonyId,
    role,
    status: 'active',
    ...(role === 'resident' ? {residentId: `resident_record_${uid}`} : {}),
    ...extra,
  };
}

function complaintData(submittedBy, overrides = {}) {
  return {
    title: 'Lift is not working',
    description: 'The passenger lift is not responding on the second floor.',
    category: 'Lift',
    complaintType: 'maintenance',
    location: 'Block A, second floor',
    reportedByName: 'Test Resident',
    reportedByPhone: '9876543210',
    submittedBy,
    submittedByName: 'Test Resident',
    priority: 'normal',
    status: 'submitted',
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    ...overrides,
  };
}

function notificationData({
  sourceId,
  createdBy,
  recipientKeys,
  recipientKey = recipientKeys[0],
  eventType,
}) {
  return {
    title: eventType === 'complaint_submitted'
      ? 'New complaint submitted'
      : 'Complaint status updated',
    message: 'A test complaint notification.',
    eventType,
    recipientKeys,
    recipientKey,
    sourceCollection: 'complaints',
    sourceId,
    createdBy,
    createdAt: serverTimestamp(),
  };
}

before(async () => {
  const rulesPath = process.env.CANDIDATE_RULES
    ?? new URL('../qa_candidates/firestore_candidate_v2.rules', import.meta.url);
  const rules = readFileSync(rulesPath, 'utf8');
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: {
      host: '127.0.0.1',
      port: 8080,
      rules,
    },
  });

  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await Promise.all([
      setDoc(doc(db, path('colonies', colonyId, 'members', ADMIN)), memberData(ADMIN, 'admin')),
      setDoc(doc(db, path('colonies', colonyId, 'members', RESIDENT)), memberData(RESIDENT, 'resident')),
      setDoc(doc(db, path('colonies', colonyId, 'members', OTHER_RESIDENT)), memberData(OTHER_RESIDENT, 'resident')),
      setDoc(doc(db, path('colonies', colonyId, 'members', CLEANLINESS_MANAGER)), memberData(CLEANLINESS_MANAGER, 'cleanliness_manager')),
      setDoc(
        doc(db, path('colonies', colonyId, 'complaints', SOURCE_COMPLAINT)),
        {
          title: 'Lift is not working',
          description: 'The passenger lift is not responding on the second floor.',
          category: 'Lift',
          complaintType: 'maintenance',
          location: 'Block A, second floor',
          reportedByName: 'Test Resident',
          reportedByPhone: '9876543210',
          submittedBy: RESIDENT,
          submittedByName: 'Test Resident',
          priority: 'normal',
          status: 'submitted',
          createdAt: new Date(),
          updatedAt: new Date(),
        },
      ),
    ]);
  });
});

after(async () => {
  await testEnv?.cleanup();
});

test('Resident can atomically create recipient-specific complaint notifications', async () => {
  const db = dbFor(RESIDENT);
  const complaintId = `new_complaint_${suffix}`;
  const recipients = ['role:admin', 'role:cleanliness_manager'];
  const batch = writeBatch(db);

  batch.set(
    doc(db, path('colonies', colonyId, 'complaints', complaintId)),
    complaintData(RESIDENT, {
      title: 'Missed garbage collection',
      category: 'Garbage collection',
      complaintType: 'cleanliness',
      location: 'Block C, service lane',
    }),
  );

  batch.set(
    doc(db, path('colonies', colonyId, 'notifications', SUBMISSION_NOTIFICATION)),
    notificationData({
      sourceId: complaintId,
      createdBy: RESIDENT,
      recipientKeys: recipients,
      recipientKey: 'role:admin',
      eventType: 'complaint_submitted',
    }),
  );

  batch.set(
    doc(db, path('colonies', colonyId, 'notifications', MANAGER_SUBMISSION_NOTIFICATION)),
    notificationData({
      sourceId: complaintId,
      createdBy: RESIDENT,
      recipientKeys: recipients,
      recipientKey: 'role:cleanliness_manager',
      eventType: 'complaint_submitted',
    }),
  );

  await assertSucceeds(batch.commit());

  await assertSucceeds(getDoc(doc(
    dbFor(ADMIN),
    path('colonies', colonyId, 'notifications', SUBMISSION_NOTIFICATION),
  )));
  await assertSucceeds(getDoc(doc(
    dbFor(CLEANLINESS_MANAGER),
    path('colonies', colonyId, 'notifications', MANAGER_SUBMISSION_NOTIFICATION),
  )));

  await assertPermissionDeniedWithoutEvaluationLimit(getDoc(doc(
    dbFor(ADMIN),
    path('colonies', colonyId, 'notifications', MANAGER_SUBMISSION_NOTIFICATION),
  )));
  await assertPermissionDeniedWithoutEvaluationLimit(getDoc(doc(
    dbFor(CLEANLINESS_MANAGER),
    path('colonies', colonyId, 'notifications', SUBMISSION_NOTIFICATION),
  )));
  await assertPermissionDeniedWithoutEvaluationLimit(getDoc(doc(
    dbFor(RESIDENT),
    path('colonies', colonyId, 'notifications', SUBMISSION_NOTIFICATION),
  )));

  const adminList = await assertSucceeds(getDocs(query(
    collection(dbFor(ADMIN), path('colonies', colonyId, 'notifications')),
    where('recipientKey', 'in', ['role:admin', `user:${ADMIN}`]),
  )));
  assert.deepEqual(
    adminList.docs.map((item) => item.id),
    [SUBMISSION_NOTIFICATION],
  );

  const managerList = await assertSucceeds(getDocs(query(
    collection(dbFor(CLEANLINESS_MANAGER), path('colonies', colonyId, 'notifications')),
    where('recipientKey', 'in', [
      'role:cleanliness_manager',
      `user:${CLEANLINESS_MANAGER}`,
    ]),
  )));
  assert.deepEqual(
    managerList.docs.map((item) => item.id),
    [MANAGER_SUBMISSION_NOTIFICATION],
  );

  await assertPermissionDeniedWithoutEvaluationLimit(getDocs(query(
    collection(dbFor(RESIDENT), path('colonies', colonyId, 'notifications')),
    where('recipientKey', 'in', ['role:admin', `user:${ADMIN}`]),
  )));
});



test('Resident cannot create a second notification for an existing complaint', async () => {
  const db = dbFor(RESIDENT);
  const ref = doc(db, path('colonies', colonyId, 'notifications', `spam_${suffix}`));
  await assertPermissionDeniedWithoutEvaluationLimit(setDoc(ref, notificationData({
    sourceId: SOURCE_COMPLAINT,
    createdBy: RESIDENT,
    recipientKeys: ['role:admin'],
    eventType: 'complaint_submitted',
  })));
});

test('Resident cannot redirect a complaint notification to an unrelated user', async () => {
  const db = dbFor(RESIDENT);
  const complaintId = `redirect_complaint_${suffix}`;
  const batch = writeBatch(db);
  batch.set(doc(db, path('colonies', colonyId, 'complaints', complaintId)), complaintData(RESIDENT));
  batch.set(
    doc(db, path('colonies', colonyId, 'notifications', `redirect_notification_${suffix}`)),
    notificationData({
      sourceId: complaintId,
      createdBy: RESIDENT,
      recipientKeys: [`user:${OTHER_RESIDENT}`],
      eventType: 'complaint_submitted',
    }),
  );
  await assertPermissionDeniedWithoutEvaluationLimit(batch.commit());
});

test('Admin can atomically update a complaint and notify its submitting resident', async () => {
  const db = dbFor(ADMIN);
  const batch = writeBatch(db);
  batch.update(doc(db, path('colonies', colonyId, 'complaints', SOURCE_COMPLAINT)), {
    status: 'acknowledged',
    updatedAt: serverTimestamp(),
  });
  batch.set(
    doc(db, path('colonies', colonyId, 'notifications', STATUS_NOTIFICATION)),
    notificationData({
      sourceId: SOURCE_COMPLAINT,
      createdBy: ADMIN,
      recipientKeys: [`user:${RESIDENT}`],
      eventType: 'complaint_status_changed',
    }),
  );

  await assertSucceeds(batch.commit());
  await assertSucceeds(getDoc(doc(dbFor(RESIDENT), path('colonies', colonyId, 'notifications', STATUS_NOTIFICATION))));
  await assertPermissionDeniedWithoutEvaluationLimit(getDoc(doc(dbFor(OTHER_RESIDENT), path('colonies', colonyId, 'notifications', STATUS_NOTIFICATION))));
});

test('Admin cannot create a status notification without changing the complaint', async () => {
  const db = dbFor(ADMIN);
  await assertPermissionDeniedWithoutEvaluationLimit(setDoc(
    doc(db, path('colonies', colonyId, 'notifications', `no_transition_${suffix}`)),
    notificationData({
      sourceId: SOURCE_COMPLAINT,
      createdBy: ADMIN,
      recipientKeys: [`user:${RESIDENT}`],
      eventType: 'complaint_status_changed',
    }),
  ));
});

test('A recipient can create their own read receipt, but another member cannot', async () => {
  const notificationRef = doc(
    dbFor(RESIDENT),
    path('colonies', colonyId, 'notifications', STATUS_NOTIFICATION),
  );
  await assertSucceeds(getDoc(notificationRef));

  const ownReceipt = doc(
    dbFor(RESIDENT),
    path('colonies', colonyId, 'members', RESIDENT, 'notificationReads', STATUS_NOTIFICATION),
  );
  await assertSucceeds(setDoc(ownReceipt, {readAt: serverTimestamp()}));

  const otherUsersReceipt = doc(
    dbFor(OTHER_RESIDENT),
    path('colonies', colonyId, 'members', RESIDENT, 'notificationReads', STATUS_NOTIFICATION),
  );
  await assertPermissionDeniedWithoutEvaluationLimit(getDoc(otherUsersReceipt));
  await assertPermissionDeniedWithoutEvaluationLimit(setDoc(ownReceipt, {readAt: serverTimestamp()}));
});
