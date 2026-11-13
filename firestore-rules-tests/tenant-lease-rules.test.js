import { before, after, test } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  initializeTestEnvironment, assertSucceeds, assertFails,
} from '@firebase/rules-unit-testing';
import {
  doc, setDoc, getDoc, updateDoc, deleteDoc, writeBatch, serverTimestamp, Timestamp, deleteField, collection, getDocs, query, where,
} from 'firebase/firestore';

const C = 'lease_test_colony';
const OTHER = 'lease_test_other';
const ADMIN = 'lease_admin';
const RESIDENT = 'lease_resident';
const RESIDENT_B = 'lease_resident_b';
const LEASE_END = Timestamp.fromDate(new Date('2027-01-01T00:00:00Z'));
const NEW_END = Timestamp.fromDate(new Date('2028-01-01T00:00:00Z'));
const OLD_START = Timestamp.fromDate(new Date('2026-01-01T00:00:00Z'));

if (!process.env.CANDIDATE_RULES) throw new Error('CANDIDATE_RULES missing');
const rules = readFileSync(process.env.CANDIDATE_RULES, 'utf8');
let env;
const db = uid => env.authenticatedContext(uid).firestore();
const p = (colony, group, id) => `colonies/${colony}/${group}/${id}`;
const leasePath = id => p(C, 'tenantLeases', id);
const requestPath = id => p(C, 'tenantLeaseRenewalRequests', id);

function lease(uid = ADMIN, household = 'household-a', resident = 'tenant-a') {
  return {
    householdId: household, blockId: 'A', houseNumber: '101',
    householdHeadName: 'Household A', tenantResidentId: resident,
    tenantName: 'Tenant A', tenantPhone: '9876543210',
    leaseStart: OLD_START, leaseEnd: LEASE_END,
    monthlyRent: 25000, securityDeposit: 50000,
    agreementReference: 'LEASE-TEST-001', status: 'active',
    createdBy: uid, createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  };
}

function renewal(id, uid = RESIDENT) {
  return {
    leaseId: 'lease-a', tenantResidentId: 'tenant-a',
    requesterUid: uid, householdId: 'household-a',
    tenantName: 'Tenant A', blockId: 'A', houseNumber: '101',
    currentLeaseEnd: LEASE_END, requestedEndDate: NEW_END,
    note: 'Requesting lease extension', status: 'pending',
    requestedAt: serverTimestamp(), createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  };
}

async function seedRequest(id, status = 'pending') {
  await env.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(), requestPath(id)), {
      ...renewal(id),
      requestedAt: Timestamp.now(),
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
      ...(status === 'rejected' ? {
        status: 'rejected', reviewNote: 'Previously declined',
        reviewedBy: ADMIN, reviewedAt: Timestamp.now(),
      } : {}),
    });
  });
}

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-mohallaflow',
    firestore: {
      host: '127.0.0.1',
      port: Number(process.env.FIRESTORE_EMULATOR_PORT || 8080),
      rules,
    },
  });

  await env.withSecurityRulesDisabled(async context => {
    const f = context.firestore();
    const b = writeBatch(f);
    for (const [uid, colony, role, residentId] of [
      [ADMIN, C, 'admin', null],
      [RESIDENT, C, 'resident', 'tenant-a'],
      [RESIDENT_B, C, 'resident', 'tenant-b'],
    ]) {
      b.set(doc(f, p(colony, 'members', uid)), {
        uid, colonyId: colony, role, status: 'active',
        ...(residentId ? { residentId } : {}),
      });
    }
    for (const [colony, household, residentId] of [
      [C, 'household-a', 'tenant-a'],
      [C, 'household-b', 'tenant-b'],
      [OTHER, 'household-a', 'tenant-a'],
    ]) {
      b.set(doc(f, p(colony, 'households', household)), { name: household });
      b.set(doc(f, p(colony, 'residents', residentId)), {
        householdId: household, relationshipToHead: 'Tenant',
        residentStatus: 'active',
      });
    }
    b.set(doc(f, leasePath('lease-a')), {
      ...lease(), createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
    });
    b.set(doc(f, leasePath('lease-b')), {
      ...lease(ADMIN, 'household-b', 'tenant-b'),
      createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
    });
    b.set(doc(f, p(OTHER, 'tenantLeases', 'lease-other')), {
      ...lease(ADMIN), createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
    });
    await b.commit();
  });
});

after(async () => { if (env) await env.cleanup(); });

test('Admin can create a valid tenant lease', async () => {
  await assertSucceeds(setDoc(
    doc(db(ADMIN), leasePath('lease-created')), lease(),
  ));
});

test('invalid household linkage and resident lease creation are denied', async () => {
  await assertFails(setDoc(
    doc(db(ADMIN), leasePath('lease-invalid')),
    lease(ADMIN, 'household-a', 'tenant-b'),
  ));
  await assertFails(setDoc(
    doc(db(RESIDENT), leasePath('lease-resident-created')),
    lease(RESIDENT),
  ));
});

test('residents can read only their own lease', async () => {
  await assertSucceeds(getDoc(doc(db(RESIDENT), leasePath('lease-a'))));
  await assertFails(getDoc(doc(db(RESIDENT), leasePath('lease-b'))));
  await assertFails(getDoc(doc(db(RESIDENT_B), leasePath('lease-a'))));
});

test('resident can submit a renewal for their own lease', async () => {
  await assertSucceeds(setDoc(
    doc(db(RESIDENT), requestPath('request-own')), renewal('request-own'),
  ));
});

test('another resident and a forged requester cannot submit a renewal', async () => {
  await assertFails(setDoc(
    doc(db(RESIDENT_B), requestPath('request-other')),
    renewal('request-other'),
  ));
  await assertFails(setDoc(
    doc(db(RESIDENT), requestPath('request-forged')),
    renewal('request-forged', ADMIN),
  ));
});

test('renewal request must extend the current lease end', async () => {
  const bad = renewal('request-bad-date');
  bad.requestedEndDate = LEASE_END;
  await assertFails(setDoc(
    doc(db(RESIDENT), requestPath('request-bad-date')), bad,
  ));
});

test('Admin can reject a pending request without changing the lease', async () => {
  await seedRequest('request-reject');
  await assertSucceeds(updateDoc(
    doc(db(ADMIN), requestPath('request-reject')),
    {
      status: 'rejected', reviewNote: 'Declined by Admin',
      reviewedBy: ADMIN, reviewedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    },
  ));
});

test('resident cannot forge an Admin approval', async () => {
  await seedRequest('request-forged-approval');
  await assertFails(updateDoc(
    doc(db(RESIDENT), requestPath('request-forged-approval')),
    {
      status: 'approved', reviewNote: 'Forged',
      reviewedBy: RESIDENT, reviewedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    },
  ));
});

test('Admin approval without the matching lease update is denied', async () => {
  await seedRequest('request-split');
  await assertFails(updateDoc(
    doc(db(ADMIN), requestPath('request-split')),
    {
      status: 'approved', reviewNote: 'Approved',
      reviewedBy: ADMIN, reviewedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    },
  ));
  await assertFails(updateDoc(
    doc(db(ADMIN), leasePath('lease-a')),
    {
      leaseEnd: NEW_END, updatedAt: serverTimestamp(),
      lastRenewalRequestId: 'request-split',
      renewedAt: serverTimestamp(), renewedBy: ADMIN,
    },
  ));
});

test('Admin can approve atomically with the lease extension', async () => {
  await seedRequest('request-atomic');
  const f = db(ADMIN);
  const batch = writeBatch(f);
  batch.update(doc(f, leasePath('lease-a')), {
    leaseEnd: NEW_END, updatedAt: serverTimestamp(),
    lastRenewalRequestId: 'request-atomic',
    renewedAt: serverTimestamp(), renewedBy: ADMIN,
  });
  batch.update(doc(f, requestPath('request-atomic')), {
    status: 'approved', reviewNote: 'Renewal approved',
    reviewedBy: ADMIN, reviewedAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });
  await assertSucceeds(batch.commit());
  const updated = await getDoc(doc(f, leasePath('lease-a')));
  if (updated.data().leaseEnd.toMillis() !== NEW_END.toMillis()) {
    throw new Error('Lease end date was not extended');
  }
});

test('lease and renewal request deletion are denied', async () => {
  await assertFails(deleteDoc(doc(db(ADMIN), leasePath('lease-a'))));
  await seedRequest('request-no-delete');
  await assertFails(deleteDoc(
    doc(db(ADMIN), requestPath('request-no-delete')),
  ));
});

test('lease access does not cross colony boundaries', async () => {
  await assertFails(getDoc(
    doc(db(RESIDENT), p(OTHER, 'tenantLeases', 'lease-other')),
  ));
});

test('Resident lease and renewal queries are owner-scoped', async () => {
  await seedRequest('request-query');
  const leases = await assertSucceeds(getDocs(query(
    collection(db(RESIDENT), `colonies/${C}/tenantLeases`),
    where('tenantResidentId', '==', 'tenant-a'),
  )));
  if (!['lease-a', 'lease-created'].every(id =>
      leases.docs.some(d => d.id === id)) ||
      leases.docs.some(d => d.data().tenantResidentId !== 'tenant-a'))
    throw new Error('Resident lease query mismatch');

  const requests = await assertSucceeds(getDocs(query(
    collection(db(RESIDENT), `colonies/${C}/tenantLeaseRenewalRequests`),
    where('tenantResidentId', '==', 'tenant-a'),
  )));
  if (!requests.docs.some(d => d.id === 'request-query') ||
      requests.docs.some(d => d.data().tenantResidentId !== 'tenant-a'))
    throw new Error('Resident renewal query mismatch');

  await assertFails(getDocs(query(
    collection(db(RESIDENT), `colonies/${C}/tenantLeaseRenewalRequests`),
    where('tenantResidentId', '==', 'tenant-b'),
  )));

  const pending = await assertSucceeds(getDocs(query(
    collection(db(ADMIN), `colonies/${C}/tenantLeaseRenewalRequests`),
    where('status', '==', 'pending'),
  )));
  if (pending.docs.some(d => d.data().status !== 'pending'))
    throw new Error('Admin pending query mismatch');
});

test('Resident can resubmit a rejected renewal request', async () => {
  await assertSucceeds(setDoc(
    doc(db(ADMIN), leasePath('lease-resubmit')), lease(),
  ));
  await seedRequest('request-resubmit', 'rejected');
  await env.withSecurityRulesDisabled(async context => {
    await updateDoc(
      doc(context.firestore(), requestPath('request-resubmit')),
      { leaseId: 'lease-resubmit' },
    );
  });
  await assertSucceeds(updateDoc(
    doc(db(RESIDENT), requestPath('request-resubmit')),
    {
      requestedEndDate: NEW_END,
      currentLeaseEnd: LEASE_END,
      note: 'Updated renewal request',
      status: 'pending',
      requestedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
      reviewNote: deleteField(),
      reviewedBy: deleteField(),
      reviewedAt: deleteField(),
    },
  ));
  const updated = await getDoc(doc(db(ADMIN), requestPath('request-resubmit')));
  if (updated.data().status !== 'pending' ||
      ['reviewNote', 'reviewedBy', 'reviewedAt'].some(k => k in updated.data()))
    throw new Error('Rejected request was not cleanly reopened');
});
