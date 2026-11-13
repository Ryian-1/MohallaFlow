import { before, after, test } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
  serverTimestamp,
  Timestamp,
} from 'firebase/firestore';

const COLONY = 'staff_rules_test_colony';
const OTHER = 'staff_rules_other_colony';
const ADMIN = 'staff_rules_admin';
const RESIDENT = 'staff_rules_resident';
const MANAGER = 'staff_rules_manager';
const WORKER = 'staff_rules_worker';

if (!process.env.CANDIDATE_RULES) {
  throw new Error('CANDIDATE_RULES must point to the tested rules file.');
}
const rules = readFileSync(process.env.CANDIDATE_RULES, 'utf8');

const staffPath = `colonies/${COLONY}/colonyStaff/staff-001`;
const historyPath = `${staffPath}/salaryHistory/history-001`;
let env;

function db(uid) {
  return env.authenticatedContext(uid).firestore();
}

const adminDb = () => db(ADMIN);

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-mohallaflow',
    firestore: { host: '127.0.0.1', port: 8080, rules },
  });

  await env.withSecurityRulesDisabled(async context => {
    const firestore = context.firestore();

    for (const [uid, colonyId, role, workerId] of [
      [ADMIN, COLONY, 'admin', null],
      [RESIDENT, COLONY, 'resident', null],
      [MANAGER, COLONY, 'cleanliness_manager', null],
      [WORKER, COLONY, 'worker', 'worker-001'],
      ['staff_rules_other_admin', OTHER, 'admin', null],
    ]) {
      await setDoc(doc(firestore, `colonies/${colonyId}/members/${uid}`), {
        uid,
        colonyId,
        role,
        status: 'active',
        ...(workerId ? { workerId } : {}),
      });
    }

    await setDoc(doc(firestore, staffPath), {
      staffCode: 'ST-001',
      staffName: 'Test Staff',
      status: 'active',
    });

    await setDoc(doc(firestore, historyPath), {
      amount: 1000,
      recordedAt: Timestamp.fromMillis(1000),
    });

    await setDoc(
      doc(firestore, `colonies/${OTHER}/colonyStaff/other-staff`),
      { staffCode: 'ST-002', status: 'active' },
    );
  });
});

after(async () => {
  if (env) await env.cleanup();
});

test('Admin can read and list colony staff', async () => {
  await assertSucceeds(getDoc(doc(adminDb(), staffPath)));
  await assertSucceeds(
    getDocs(collection(adminDb(), `colonies/${COLONY}/colonyStaff`)),
  );
});

test('Resident, Manager and Worker cannot read or list colony staff', async () => {
  for (const uid of [RESIDENT, MANAGER, WORKER]) {
    await assertFails(getDoc(doc(db(uid), staffPath)));
    await assertFails(
      getDocs(collection(db(uid), `colonies/${COLONY}/colonyStaff`)),
    );
  }
});

test('Admin can create and update staff, but cannot delete', async () => {
  const ref = doc(adminDb(), `colonies/${COLONY}/colonyStaff/new-staff`);
  await assertSucceeds(setDoc(ref, { staffCode: 'ST-NEW', status: 'active' }));
  await assertSucceeds(updateDoc(ref, { status: 'inactive' }));
  await assertFails(deleteDoc(doc(adminDb(), staffPath)));
});

test('Non-Admin roles cannot create or update staff', async () => {
  for (const uid of [RESIDENT, MANAGER, WORKER]) {
    await assertFails(
      setDoc(doc(db(uid), `colonies/${COLONY}/colonyStaff/blocked-${uid}`), {
        staffCode: 'FORGED',
        status: 'active',
      }),
    );
    await assertFails(
      updateDoc(doc(db(uid), staffPath), { status: 'inactive' }),
    );
  }
});

test('Admin can read and list salary history', async () => {
  await assertSucceeds(getDoc(doc(adminDb(), historyPath)));
  await assertSucceeds(
    getDocs(collection(adminDb(), `${staffPath}/salaryHistory`)),
  );
});

test('Non-Admin roles cannot read salary history', async () => {
  for (const uid of [RESIDENT, MANAGER, WORKER]) {
    await assertFails(getDoc(doc(db(uid), historyPath)));
    await assertFails(
      getDocs(collection(db(uid), `${staffPath}/salaryHistory`)),
    );
  }
});

test('Admin can create salary history with server timestamp', async () => {
  await assertSucceeds(
    setDoc(doc(adminDb(), `${staffPath}/salaryHistory/history-new`), {
      amount: 2000,
      recordedAt: serverTimestamp(),
    }),
  );
});

test('Forged salary-history timestamp is rejected', async () => {
  await assertFails(
    setDoc(doc(adminDb(), `${staffPath}/salaryHistory/history-forged`), {
      amount: 2000,
      recordedAt: Timestamp.fromMillis(1000),
    }),
  );
});

test('Salary history cannot be updated or deleted', async () => {
  await assertFails(
    updateDoc(doc(adminDb(), historyPath), { amount: 9999 }),
  );
  await assertFails(deleteDoc(doc(adminDb(), historyPath)));
});

test('Admin cannot access or create staff in another colony', async () => {
  const foreignPath = `colonies/${OTHER}/colonyStaff/other-staff`;
  await assertFails(getDoc(doc(adminDb(), foreignPath)));
  await assertFails(
    setDoc(doc(adminDb(), `colonies/${OTHER}/colonyStaff/forged`), {
      staffCode: 'FORGED',
      status: 'active',
    }),
  );
});

test('Non-Admin roles cannot create salary-history records', async () => {
  for (const uid of [RESIDENT, MANAGER, WORKER]) {
    await assertFails(
      setDoc(doc(db(uid), `${staffPath}/salaryHistory/blocked-${uid}`), {
        amount: 500,
        recordedAt: serverTimestamp(),
      }),
    );
  }
});
