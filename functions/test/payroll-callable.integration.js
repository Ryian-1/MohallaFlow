'use strict';

const assert = require('node:assert/strict');
const {
  initializeApp,
  deleteApp,
} = require('firebase-admin/app');
const {
  Timestamp,
  getFirestore,
} = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');

const PROJECT_ID = process.env.GCLOUD_PROJECT || 'mohallaflow';
const AUTH_HOST = process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099';
const FUNCTION_URL =
  `http://127.0.0.1:5001/${PROJECT_ID}/asia-south1/approveColonyPayrollRun`;

const unique = `${process.pid}_${Date.now()}`;
const colonyId = `payroll_callable_${unique}`;

const app = initializeApp(
  { projectId: PROJECT_ID },
  `payroll-callable-integration-${process.pid}`,
);

const db = getFirestore(app);
const auth = getAuth(app);
const createdUsers = [];

async function createEmulatorUser(label) {
  const email = `payroll-${label}-${unique}@example.test`;

  const response = await fetch(
    `http://${AUTH_HOST}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email,
        password: 'MohallaFlow-Test-2026!',
        returnSecureToken: true,
      }),
    },
  );

  const body = await response.json();

  assert.equal(
    response.ok,
    true,
    `Auth Emulator signup failed: ${JSON.stringify(body)}`,
  );

  assert.ok(body.localId, 'Auth Emulator did not return a UID.');
  assert.ok(body.idToken, 'Auth Emulator did not return an ID token.');

  createdUsers.push(body.localId);

  return {
    uid: body.localId,
    idToken: body.idToken,
  };
}

function memberFixture(uid, role, fullName) {
  return {
    uid,
    colonyId,
    role,
    status: 'active',
    fullName,
  };
}

function runFixture(periodKey, creatorUid) {
  const isNovember = periodKey === '2026-11';

  const now = Timestamp.now();

  return {
    periodKey,
    periodStart: `${periodKey}-01`,
    periodEnd: isNovember ? '2026-11-30' : '2026-12-31',
    payDate: isNovember ? '2026-11-30' : '2026-12-31',
    monthlyProrationDivisor: 30,
    status: 'draft',
    staffCount: 1,
    grossTotal: 0,
    deductionTotal: 0,
    netTotal: 0,
    paidTotal: 0,
    balanceTotal: 0,
    createdBy: creatorUid,
    createdByName: 'Callable Integration Admin',
    createdAt: now,
    updatedAt: now,
  };
}

function entryFixture(staffId) {
  const now = Timestamp.now();

  return {
    staffId,
    staffCode: `ST-${staffId}`,
    staffName: 'Callable Integration Staff',
    payBasis: 'monthly',
    baseRate: 30000,
    hra: 3000,
    transportAllowance: 500,
    otherAllowance: 0,
    defaultDeduction: 1000,
    attendanceDays: 20,
    paidDays: 30,
    paidLeaveDays: 0,
    unpaidLeaveDays: 2,
    approvedPaidLeaveDays: 0,
    approvedUnpaidLeaveDays: 0,
    hoursWorked: 0,
    overtimeHours: 2,
    overtimeRate: 200,
    bonus: 1000,
    reimbursements: 500,
    advanceRecovery: 200,
    otherDeductions: 300,
    amountPaid: 0,
    status: 'draft',
    basePay: 1,
    overtimePay: 1,
    grossPay: 1,
    totalDeductions: 1,
    netPay: 1,
    balance: 1,
    createdAt: now,
    updatedAt: now,
  };
}

async function createPayrollRun(colonyRef, periodKey, creatorUid) {
  const runRef = colonyRef
    .collection('colonyPayrollRuns')
    .doc(periodKey);

  const entry = entryFixture(`staff-${periodKey}`);

  await runRef.set(runFixture(periodKey, creatorUid));
  await runRef.collection('entries').doc(entry.staffId).set(entry);

  return { runRef, staffId: entry.staffId };
}

async function invokeCallable(token, data) {
  const headers = {
    'Content-Type': 'application/json',
  };

  if (token) {
    headers.Authorization = `Bearer ${token}`;
  }

  const response = await fetch(FUNCTION_URL, {
    method: 'POST',
    headers,
    body: JSON.stringify({ data }),
  });

  const body = await response.json();

  return { httpStatus: response.status, body };
}

async function expectCallableError(response, expectedStatus, label) {
  assert.ok(
    response.body.error,
    `${label}: expected callable error, received ${JSON.stringify(response.body)}`,
  );

  assert.equal(
    response.body.error.status,
    expectedStatus,
    `${label}: unexpected error response ${JSON.stringify(response.body)}`,
  );

  console.log(`PASS: ${label} (${expectedStatus})`);
}

async function main() {
  const colonyRef = db.collection('colonies').doc(colonyId);

  try {
    console.log('Creating Auth Emulator users...');

    const admin = await createEmulatorUser('admin');
    const worker = await createEmulatorUser('worker');

    await colonyRef.collection('members').doc(admin.uid).set(
      memberFixture(admin.uid, 'admin', 'Callable Integration Admin'),
    );

    await colonyRef.collection('members').doc(worker.uid).set(
      memberFixture(worker.uid, 'worker', 'Callable Integration Worker'),
    );

    const adminRun = await createPayrollRun(
      colonyRef,
      '2026-11',
      admin.uid,
    );

    const workerRun = await createPayrollRun(
      colonyRef,
      '2026-12',
      admin.uid,
    );

    const adminRequest = {
      colonyId,
      runId: '2026-11',
    };

    const workerRequest = {
      colonyId,
      runId: '2026-12',
    };

    console.log('\n========== CALLABLE AUTHORIZATION TESTS ==========');

    const unauthenticated = await invokeCallable(null, adminRequest);

    await expectCallableError(
      unauthenticated,
      'UNAUTHENTICATED',
      'Unauthenticated caller cannot approve payroll',
    );

    const workerResponse = await invokeCallable(
      worker.idToken,
      workerRequest,
    );

    await expectCallableError(
      workerResponse,
      'PERMISSION_DENIED',
      'Worker cannot approve payroll',
    );

    const workerRunAfter = (await workerRun.runRef.get()).data();

    assert.equal(
      workerRunAfter.status,
      'draft',
      'Worker rejection must not modify the payroll run.',
    );

    console.log('PASS: Worker rejection leaves payroll unchanged.');

    console.log('\n========== ADMIN APPROVAL THROUGH CALLABLE ==========');

    const approval = await invokeCallable(
      admin.idToken,
      adminRequest,
    );

    assert.equal(
      approval.httpStatus,
      200,
      `Admin callable failed: ${JSON.stringify(approval.body)}`,
    );

    assert.ok(
      approval.body.result,
      `Callable result is missing: ${JSON.stringify(approval.body)}`,
    );

    const result = approval.body.result;

    assert.equal(result.status, 'approved');
    assert.equal(result.staffCount, 1);
    assert.equal(result.grossTotal, 33400);
    assert.equal(result.deductionTotal, 1500);
    assert.equal(result.netTotal, 31900);

    const approvedRun = (await adminRun.runRef.get()).data();

    assert.equal(approvedRun.status, 'approved');
    assert.equal(approvedRun.approvedBy, admin.uid);
    assert.equal(
      approvedRun.approvedByName,
      'Callable Integration Admin',
    );
    assert.equal(approvedRun.grossTotal, 33400);
    assert.equal(approvedRun.deductionTotal, 1500);
    assert.equal(approvedRun.netTotal, 31900);
    assert.equal(approvedRun.balanceTotal, 31900);

    const approvedEntry = (
      await adminRun.runRef
        .collection('entries')
        .doc(adminRun.staffId)
        .get()
    ).data();

    assert.equal(approvedEntry.status, 'approved');
    assert.equal(approvedEntry.basePay, 28000);
    assert.equal(approvedEntry.overtimePay, 400);
    assert.equal(approvedEntry.grossPay, 33400);
    assert.equal(approvedEntry.totalDeductions, 1500);
    assert.equal(approvedEntry.netPay, 31900);
    assert.equal(approvedEntry.balance, 31900);

    console.log('PASS: Admin callable approved the payroll run.');
    console.log('PASS: Backend recalculated and persisted all payroll totals.');
    console.log('PASS: Forged client-derived payroll values were overwritten.');

    console.log('\n========== DUPLICATE APPROVAL PROTECTION ==========');

    const duplicate = await invokeCallable(
      admin.idToken,
      adminRequest,
    );

    await expectCallableError(
      duplicate,
      'FAILED_PRECONDITION',
      'Already-approved payroll run cannot be approved again',
    );

    const finalRun = (await adminRun.runRef.get()).data();

    assert.equal(finalRun.status, 'approved');
    assert.equal(finalRun.netTotal, 31900);

    console.log('PASS: Duplicate approval did not change payroll totals.');
    console.log('\nALL PAYROLL CALLABLE INTEGRATION CHECKS PASSED.');
  } finally {
    console.log('\nCleaning up isolated emulator test data...');

    const cleanupFailures = [];

    async function deleteDocumentTree(documentRef) {
      const collections = await documentRef.listCollections();

      for (const collection of collections) {
        const documents = await collection.listDocuments();

        for (const document of documents) {
          await deleteDocumentTree(document);
        }
      }

      await documentRef.delete();
    }

    try {
      await deleteDocumentTree(colonyRef);
      console.log('PASS: Payroll Firestore fixtures deleted.');
    } catch (error) {
      cleanupFailures.push(`Firestore cleanup: ${error.stack || error}`);
    }

    for (const uid of createdUsers) {
      try {
        await auth.deleteUser(uid);
      } catch (error) {
        if (error.code !== 'auth/user-not-found') {
          cleanupFailures.push(
            `Auth cleanup ${uid}: ${error.stack || error}`,
          );
        }
      }
    }

    try {
      await deleteApp(app);
    } catch (error) {
      cleanupFailures.push(`Firebase Admin shutdown: ${error.stack || error}`);
    }

    if (cleanupFailures.length > 0) {
      throw new Error(
        'Callable integration cleanup failed:\\n' +
        cleanupFailures.join('\\n\\n'),
      );
    }

    console.log('PASS: All Auth Emulator users deleted.');
  }
}

main().catch((error) => {
  console.error('\nPAYROLL CALLABLE INTEGRATION FAILED.');
  console.error(error.stack || error);
  process.exitCode = 1;
});
