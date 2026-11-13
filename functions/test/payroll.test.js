
'use strict';

const { test, after } = require('node:test');
const assert = require('node:assert/strict');

const { initializeApp, deleteApp } = require('firebase-admin/app');
const {
  FieldValue,
  Timestamp,
  getFirestore,
} = require('firebase-admin/firestore');

const {
  approvePayrollRun,
  PayrollApprovalError,
} = require('../lib/payroll');

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  throw new Error('Payroll backend tests must run against the Firestore Emulator.');
}

const app = initializeApp(
  { projectId: 'mohallaflow' },
  `payroll-backend-tests-${process.pid}`,
);
const db = getFirestore(app);
const createdColonies = [];

function runFixture(staffCount) {
  const now = Timestamp.now();

  return {
    periodKey: '2026-11',
    periodStart: '2026-11-01',
    periodEnd: '2026-11-30',
    payDate: '2026-11-30',
    monthlyProrationDivisor: 30,
    status: 'draft',
    staffCount,
    grossTotal: 0,
    deductionTotal: 0,
    netTotal: 0,
    paidTotal: 0,
    balanceTotal: 0,
    createdBy: 'payroll-test-admin',
    createdByName: 'Rules Admin',
    createdAt: now,
    updatedAt: now,
  };
}

function entryFixture(staffId, overrides = {}) {
  return {
    staffId,
    staffCode: `ST-${staffId}`,
    staffName: `Test ${staffId}`,
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
    // Deliberately forged derived values: the backend must overwrite them.
    basePay: 1,
    overtimePay: 1,
    grossPay: 1,
    totalDeductions: 1,
    netPay: 1,
    balance: 1,
    createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
    ...overrides,
  };
}

async function prepareColony(
  colonyId,
  {
    role = 'admin',
    staffCount,
    entries,
  },
) {
  createdColonies.push(colonyId);

  const colonyRef = db.collection('colonies').doc(colonyId);

  await colonyRef.collection('members').doc('payroll-test-admin').set({
    uid: 'payroll-test-admin',
    colonyId,
    role,
    status: 'active',
    fullName: 'Payroll Backend Admin',
  });

  const runRef = colonyRef
    .collection('colonyPayrollRuns')
    .doc('2026-11');

  await runRef.set(runFixture(staffCount));

  for (const entry of entries) {
    await runRef.collection('entries').doc(entry.staffId).set(entry);
  }

  return { runRef, colonyRef };
}

function approve(colonyId) {
  return approvePayrollRun({
    db,
    colonyId,
    runId: '2026-11',
    uid: 'payroll-test-admin',
  });
}

function isPayrollError(code) {
  return (error) =>
    error instanceof PayrollApprovalError && error.code === code;
}

test('Backend recalculates monthly and daily entries and approves atomically', async () => {
  const colonyId = 'payroll_backend_valid';

  const monthly = entryFixture('staff-monthly');

  const daily = entryFixture('staff-daily', {
    payBasis: 'daily',
    baseRate: 1000,
    hra: 0,
    transportAllowance: 0,
    otherAllowance: 0,
    defaultDeduction: 25000,
    attendanceDays: 20,
    paidDays: 20,
    paidLeaveDays: 0,
    unpaidLeaveDays: 0,
    approvedPaidLeaveDays: 0,
    approvedUnpaidLeaveDays: 0,
    hoursWorked: 0,
    overtimeHours: 0,
    overtimeRate: 0,
    bonus: 0,
    reimbursements: 0,
    advanceRecovery: 0,
    otherDeductions: 0,
  });

  const hourly = entryFixture('staff-hourly', {
    payBasis: 'hourly',
    baseRate: 500,
    hra: 0,
    transportAllowance: 0,
    otherAllowance: 0,
    defaultDeduction: 0,
    attendanceDays: 0,
    paidDays: 0,
    paidLeaveDays: 0,
    unpaidLeaveDays: 0,
    approvedPaidLeaveDays: 0,
    approvedUnpaidLeaveDays: 0,
    hoursWorked: 40,
    overtimeHours: 0,
    overtimeRate: 0,
    bonus: 0,
    reimbursements: 0,
    advanceRecovery: 0,
    otherDeductions: 0,
  });

  const { runRef } = await prepareColony(colonyId, {
    staffCount: 3,
    entries: [monthly, daily, hourly],
  });

  const result = await approve(colonyId);

  assert.equal(result.status, 'approved');
  assert.equal(result.staffCount, 3);
  assert.equal(result.grossTotal, 73400);
  assert.equal(result.deductionTotal, 26500);
  assert.equal(result.netTotal, 51900);

  const run = (await runRef.get()).data();

  assert.equal(run.status, 'approved');
  assert.equal(run.approvedBy, 'payroll-test-admin');
  assert.equal(run.approvedByName, 'Payroll Backend Admin');
  assert.equal(run.grossTotal, 73400);
  assert.equal(run.deductionTotal, 26500);
  assert.equal(run.netTotal, 51900);
  assert.equal(run.balanceTotal, 51900);

  const monthlyResult = (
    await runRef.collection('entries').doc('staff-monthly').get()
  ).data();

  assert.equal(monthlyResult.basePay, 28000);
  assert.equal(monthlyResult.overtimePay, 400);
  assert.equal(monthlyResult.grossPay, 33400);
  assert.equal(monthlyResult.totalDeductions, 1500);
  assert.equal(monthlyResult.netPay, 31900);
  assert.equal(monthlyResult.status, 'approved');

  const dailyResult = (
    await runRef.collection('entries').doc('staff-daily').get()
  ).data();

  assert.equal(dailyResult.basePay, 20000);
  assert.equal(dailyResult.grossPay, 20000);
  assert.equal(dailyResult.netPay, 0);
  assert.equal(dailyResult.status, 'approved');

  const hourlyResult = (
    await runRef.collection('entries').doc('staff-hourly').get()
  ).data();

  assert.equal(hourlyResult.basePay, 20000);
  assert.equal(hourlyResult.grossPay, 20000);
  assert.equal(hourlyResult.netPay, 20000);
  assert.equal(hourlyResult.status, 'approved');

  // Sum of individual net pay is 51,900. Aggregate gross less
  // aggregate deductions would incorrectly produce 46,900.
});

test('Backend refuses incomplete payroll entry collections without writing approval', async () => {
  const colonyId = 'payroll_backend_incomplete';

  const { runRef } = await prepareColony(colonyId, {
    staffCount: 2,
    entries: [entryFixture('staff-001')],
  });

  await assert.rejects(
    approve(colonyId),
    isPayrollError('failed-precondition'),
  );

  assert.equal((await runRef.get()).data().status, 'draft');
  assert.equal(
    (await runRef.collection('entries').doc('staff-001').get()).data().status,
    'draft',
  );
});

test('Backend refuses approval by a non-Admin colony member', async () => {
  const colonyId = 'payroll_backend_non_admin';

  const { runRef } = await prepareColony(colonyId, {
    role: 'worker',
    staffCount: 1,
    entries: [entryFixture('staff-001')],
  });

  await assert.rejects(
    approve(colonyId),
    isPayrollError('permission-denied'),
  );

  assert.equal((await runRef.get()).data().status, 'draft');
});

test('Backend rejects malformed payroll inputs without partial approval', async () => {
  const colonyId = 'payroll_backend_invalid_input';

  const invalidEntry = entryFixture('staff-001', {
    bonus: '1000',
  });

  const { runRef } = await prepareColony(colonyId, {
    staffCount: 1,
    entries: [invalidEntry],
  });

  await assert.rejects(
    approve(colonyId),
    isPayrollError('failed-precondition'),
  );

  assert.equal((await runRef.get()).data().status, 'draft');
  assert.equal(
    (await runRef.collection('entries').doc('staff-001').get()).data().status,
    'draft',
  );
});

after(async () => {
  for (const colonyId of createdColonies) {
    await db.recursiveDelete(db.collection('colonies').doc(colonyId));
  }

  await deleteApp(app);
});
