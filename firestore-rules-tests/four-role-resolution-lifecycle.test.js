import { after, before, test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  doc,
  getDoc,
  serverTimestamp,
  Timestamp,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

const PROJECT_ID = 'demo-mohallaflow';
const COLONY_ID = 'stage6_linked_resolution_colony';
const RESIDENT_UID = 'stage6_resolution_resident';
const WORKER_UID = 'stage6_resolution_worker';
const OTHER_WORKER_UID = 'stage6_resolution_other_worker';
const WORKER_RECORD_ID = 'stage6_worker_record';
const OTHER_WORKER_RECORD_ID = 'stage6_other_worker_record';
const rules = readFileSync(process.env.CANDIDATE_RULES ?? new URL('../firestore.rules', import.meta.url), 'utf8');
let testEnv;
let sequence = 0;

const complaintPath = (id) => `colonies/${COLONY_ID}/complaints/${id}`;
const taskPath = (id) => `colonies/${COLONY_ID}/cleanlinessTasks/${id}`;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { host: '127.0.0.1', port: 8080, rules },
  });
});

after(async () => {
  if (testEnv) await testEnv.cleanup();
});

async function seedLinkedPair(tag) {
  sequence += 1;
  const complaintId = `linked_complaint_${tag}_${sequence}`;
  const taskId = `linked_task_${tag}_${sequence}`;
  const now = Timestamp.now();

  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    const colony = db.collection('colonies').doc(COLONY_ID);
    await colony.set({ colonyId: COLONY_ID, colonyName: 'Stage 6 Resolution QA' });
    await colony.collection('members').doc(RESIDENT_UID).set({
      uid: RESIDENT_UID, colonyId: COLONY_ID, role: 'resident', status: 'active', residentId: 'stage6_resident_record',
    });
    await colony.collection('members').doc(WORKER_UID).set({
      uid: WORKER_UID, colonyId: COLONY_ID, role: 'worker', status: 'active', workerId: WORKER_RECORD_ID,
    });
    await colony.collection('members').doc(OTHER_WORKER_UID).set({
      uid: OTHER_WORKER_UID, colonyId: COLONY_ID, role: 'worker', status: 'active', workerId: OTHER_WORKER_RECORD_ID,
    });
    await colony.collection('complaints').doc(complaintId).set({
      title: 'Garbage collection missed',
      description: 'Garbage was not collected from the common area today.',
      category: 'Garbage collection',
      complaintType: 'cleanliness',
      location: 'Block A',
      reportedByName: 'Stage 6 Resident',
      reportedByPhone: '9876543210',
      submittedBy: RESIDENT_UID,
      submittedByName: 'Stage 6 Resident',
      priority: 'normal',
      status: 'acknowledged',
      createdAt: now,
      updatedAt: now,
    });
    await colony.collection('cleanlinessTasks').doc(taskId).set({
      title: 'Clear Block A garbage point',
      location: 'Block A',
      description: 'Collect and clear the missed garbage.',
      priority: 'normal',
      status: 'in_progress',
      assignedWorkerId: WORKER_RECORD_ID,
      assignedWorkerName: 'Stage 6 Worker',
      assignedWorkerPhone: '9876543211',
      createdBy: 'stage6_test_admin',
      createdByName: 'Stage 6 Admin',
      createdAt: now,
      updatedAt: now,
      completedAt: null,
      sourceComplaintId: complaintId,
    });
  });

  return { complaintId, taskId };
}

function workerDb(uid = WORKER_UID) {
  return testEnv.authenticatedContext(uid).firestore();
}

function residentDb() {
  return testEnv.authenticatedContext(RESIDENT_UID).firestore();
}

async function completeAndResolve(db, ids, complaintId = ids.complaintId) {
  const batch = writeBatch(db);
  batch.update(doc(db, taskPath(ids.taskId)), {
    status: 'completed',
    updatedAt: serverTimestamp(),
    completedAt: serverTimestamp(),
  });
  batch.update(doc(db, complaintPath(complaintId)), {
    status: 'resolved',
    updatedAt: serverTimestamp(),
    resolvedAt: serverTimestamp(),
    resolutionTaskId: ids.taskId,
  });
  return batch.commit();
}

test('linked cleanliness task and complaint resolution must be atomic and worker-scoped', async (t) => {
  await t.test('resident cannot resolve a complaint directly, even when a task is linked', async () => {
    const ids = await seedLinkedPair('resident_direct');
    await assertFails(updateDoc(doc(residentDb(), complaintPath(ids.complaintId)), {
      status: 'resolved',
      updatedAt: serverTimestamp(),
      resolvedAt: serverTimestamp(),
      resolutionTaskId: ids.taskId,
    }));
  });

  await t.test('worker cannot resolve a complaint while its linked task is still in progress', async () => {
    const ids = await seedLinkedPair('complaint_only');
    const db = workerDb();
    await assertFails(updateDoc(doc(db, complaintPath(ids.complaintId)), {
      status: 'resolved',
      updatedAt: serverTimestamp(),
      resolvedAt: serverTimestamp(),
      resolutionTaskId: ids.taskId,
    }));
  });

  await t.test('worker cannot complete a linked task without resolving its complaint in the same batch', async () => {
    const ids = await seedLinkedPair('task_only');
    const db = workerDb();
    await assertFails(updateDoc(doc(db, taskPath(ids.taskId)), {
      status: 'completed',
      updatedAt: serverTimestamp(),
      completedAt: serverTimestamp(),
    }));
  });

  await t.test('assigned worker can atomically complete the task and resolve the exact complaint', async () => {
    const ids = await seedLinkedPair('success');
    const db = workerDb();
    await assertSucceeds(completeAndResolve(db, ids));

    const residentComplaint = await assertSucceeds(
      getDoc(doc(residentDb(), complaintPath(ids.complaintId))),
    );
    const workerTask = await assertSucceeds(
      getDoc(doc(db, taskPath(ids.taskId))),
    );
    assert.equal(residentComplaint.data().status, 'resolved');
    assert.equal(residentComplaint.data().resolutionTaskId, ids.taskId);
    assert.ok(residentComplaint.data().resolvedAt);
    assert.equal(workerTask.data().status, 'completed');
    assert.ok(workerTask.data().completedAt);
  });

  await t.test('worker cannot attach completion to a different cleanliness complaint', async () => {
    const ids = await seedLinkedPair('wrong_link');
    const wrongComplaintId = `unrelated_complaint_${sequence}`;
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.doc(complaintPath(wrongComplaintId)).set({
        title: 'Separate complaint', description: 'Another unrelated cleanliness issue.',
        category: 'Garbage collection', complaintType: 'cleanliness', location: 'Block B',
        reportedByName: 'Stage 6 Resident', reportedByPhone: '9876543210',
        submittedBy: RESIDENT_UID, submittedByName: 'Stage 6 Resident', priority: 'normal',
        status: 'acknowledged', createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
      });
    });
    await assertFails(completeAndResolve(workerDb(), ids, wrongComplaintId));
  });

  await t.test('a different worker cannot complete or resolve another worker assignment', async () => {
    const ids = await seedLinkedPair('wrong_worker');
    await assertFails(completeAndResolve(workerDb(OTHER_WORKER_UID), ids));
  });
});
