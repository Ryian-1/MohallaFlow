'use strict';

const {
  initializeApp,
  deleteApp,
} = require('firebase-admin/app');

const {
  Timestamp,
  getFirestore,
} = require('firebase-admin/firestore');

const { getAuth } = require('firebase-admin/auth');

const PROJECT_ID = 'demo-mohallaflow';
const COLONY_ID = 'payroll_flutter_sdk_integration';

const ADMIN_EMAIL = 'payroll-flutter-admin@example.test';
const WORKER_EMAIL = 'payroll-flutter-worker@example.test';
const PASSWORD = 'MohallaFlow-Emulator-2026!';

if (!process.env.FIRESTORE_EMULATOR_HOST ||
    !process.env.FIREBASE_AUTH_EMULATOR_HOST) {
  throw new Error('Both Firestore and Auth Emulator hosts must be configured.');
}

const app = initializeApp(
  { projectId: PROJECT_ID },
  `payroll-flutter-sdk-seed-${process.pid}`,
);

const db = getFirestore(app);
const auth = getAuth(app);
const colonyRef = db.collection('colonies').doc(COLONY_ID);

async function deleteExistingUser(email) {
  try {
    const existing = await auth.getUserByEmail(email);
    await auth.deleteUser(existing.uid);
  } catch (error) {
    if (error.code !== 'auth/user-not-found') {
      throw error;
    }
  }
}

async function findUser(email) {
  try {
    return await auth.getUserByEmail(email);
  } catch (error) {
    if (error.code === 'auth/user-not-found') return null;
    throw error;
  }
}

function runFixture(periodKey, adminUid) {
  const december = periodKey === '2026-12';
  const now = Timestamp.now();

  return {
    periodKey,
    periodStart: `${periodKey}-01`,
    periodEnd: december ? '2026-12-31' : '2026-11-30',
    payDate: december ? '2026-12-31' : '2026-11-30',
    monthlyProrationDivisor: 30,
    status: 'draft',
    staffCount: 1,
    grossTotal: 0,
    deductionTotal: 0,
    netTotal: 0,
    paidTotal: 0,
    balanceTotal: 0,
    createdBy: adminUid,
    createdByName: 'Flutter SDK Integration Admin',
    createdAt: now,
    updatedAt: now,
  };
}

function entryFixture(staffId) {
  const now = Timestamp.now();

  return {
    staffId,
    staffCode: `ST-${staffId}`,
    staffName: 'Flutter SDK Test Staff',
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

async function seed() {
  await db.recursiveDelete(colonyRef);

  await deleteExistingUser(ADMIN_EMAIL);
  await deleteExistingUser(WORKER_EMAIL);

  const admin = await auth.createUser({
    email: ADMIN_EMAIL,
    password: PASSWORD,
    displayName: 'Flutter SDK Integration Admin',
  });

  const worker = await auth.createUser({
    email: WORKER_EMAIL,
    password: PASSWORD,
    displayName: 'Flutter SDK Integration Worker',
  });

  await colonyRef.collection('members').doc(admin.uid).set({
    uid: admin.uid,
    colonyId: COLONY_ID,
    role: 'admin',
    status: 'active',
    fullName: 'Flutter SDK Integration Admin',
  });

  await colonyRef.collection('members').doc(worker.uid).set({
    uid: worker.uid,
    colonyId: COLONY_ID,
    role: 'worker',
    status: 'active',
    fullName: 'Flutter SDK Integration Worker',
  });

  for (const periodKey of ['2026-11', '2026-12']) {
    const runRef = colonyRef
      .collection('colonyPayrollRuns')
      .doc(periodKey);

    const staffId = `staff-${periodKey}`;

    await runRef.set(runFixture(periodKey, admin.uid));
    await runRef.collection('entries').doc(staffId).set(entryFixture(staffId));
  }

  console.log('Seeded isolated Admin, Worker and two draft payroll runs.');
}

async function cleanup() {
  await db.recursiveDelete(colonyRef);
  await deleteExistingUser(ADMIN_EMAIL);
  await deleteExistingUser(WORKER_EMAIL);
  console.log('Removed isolated test payroll data and Auth accounts.');
}

async function main() {
  try {
    const mode = process.argv[2];

    if (mode === 'seed') {
      await seed();
    } else if (mode === 'cleanup') {
      await cleanup();
    } else {
      throw new Error('Usage: node payroll-flutter-sdk.seed.js seed|cleanup');
    }
  } finally {
    await deleteApp(app);
  }
}

main().catch((error) => {
  console.error(error.stack || error);
  process.exitCode = 1;
});
