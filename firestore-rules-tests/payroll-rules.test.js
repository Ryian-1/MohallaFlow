import { before, after, test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails
} from "@firebase/rules-unit-testing";

import {
  doc,
  setDoc,
  updateDoc,
  getDoc,
  writeBatch,
  serverTimestamp,
  Timestamp
} from "firebase/firestore";

const PROJECT_ID = "mohallaflow";
const COLONY = "payroll_rules_test_colony";
const ADMIN = "payroll_rules_test_admin";
const RUN_ID = "2026-11";
const STAFF_ID = "staff-001";
const PAYMENT_ID = "pay-001";
const EXPENSE_ID = `payroll_${RUN_ID}_${STAFF_ID}_${PAYMENT_ID}`;

const rules = readFileSync(
  process.env.CANDIDATE_RULES ?? new URL("../qa_candidates/firestore_candidate_v2.rules", import.meta.url),
  "utf8"
);

let testEnv;

const paths = {
  member: `colonies/${COLONY}/members/${ADMIN}`,
  run: `colonies/${COLONY}/colonyPayrollRuns/${RUN_ID}`,
  entry: `colonies/${COLONY}/colonyPayrollRuns/${RUN_ID}/entries/${STAFF_ID}`,
  payment: `colonies/${COLONY}/colonyPayrollRuns/${RUN_ID}/entries/${STAFF_ID}/payments/${PAYMENT_ID}`,
  expense: `colonies/${COLONY}/colonyExpenses/${EXPENSE_ID}`
};

function adminDb() {
  return testEnv.authenticatedContext(ADMIN).firestore();
}

function runFixture() {
  return {
    periodKey: RUN_ID,
    periodStart: "2026-11-01",
    periodEnd: "2026-11-30",
    payDate: "2026-11-30",
    monthlyProrationDivisor: 30,
    status: "draft",
    staffCount: 1,
    grossTotal: 0,
    deductionTotal: 0,
    netTotal: 0,
    paidTotal: 0,
    balanceTotal: 0,
    createdBy: ADMIN,
    createdByName: "Rules Admin",
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp()
  };
}

function entryFixture() {
  return {
    staffId: STAFF_ID,
    staffCode: "ST-001",
    staffName: "Test Staff",
    phoneSnapshot: "9876543210",
    department: "Housekeeping",
    designation: "Worker",
    employmentType: "full_time",
    payBasis: "monthly",
    baseRate: 30000,
    hra: 3000,
    transportAllowance: 500,
    otherAllowance: 0,
    defaultDeduction: 1000,
    linkedWorkerId: "",
    linkedWorkerName: "",
    attendanceDays: 0,
    paidDays: 30,
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
    amountPaid: 0,
    status: "draft",
    basePay: 30000,
    overtimePay: 0,
    grossPay: 33500,
    totalDeductions: 1000,
    netPay: 32500,
    balance: 32500,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp()
  };
}

function expenseFixture() {
  return {
    title: "Salary payout - Test Staff - 2026-11",
    category: "staff",
    amount: 10000,
    amountPaid: 10000,
    paymentStatus: "paid",
    paymentMethod: "upi",
    expenseDate: Timestamp.fromDate(
      new Date("2026-11-08T12:00:00.000Z")
    ),
    monthKey: "2026-11",
    payeeName: "Test Staff",
    vendorName: "",
    assetName: "",
    reference: "PAY-001",
    notes: "Payroll 2026-11; staff ST-001; Test payout",
    createdBy: ADMIN,
    createdByName: "Rules Admin",
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    payrollRunId: RUN_ID,
    payrollStaffEntryId: STAFF_ID,
    payrollPaymentId: PAYMENT_ID
  };
}

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      host: "127.0.0.1",
      port: 8080,
      rules
    }
  });

  await testEnv.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(), paths.member), {
      uid: ADMIN,
      colonyId: COLONY,
      role: "admin",
      status: "active"
    });
  });
});

after(async () => {
  if (testEnv) {
    await testEnv.cleanup();
  }
});

test("Payroll lifecycle: server-only approval, atomic payout and forged-write protection", async () => {
  const db = adminDb();

  const runRef = doc(db, paths.run);
  const entryRef = doc(db, paths.entry);
  const paymentRef = doc(db, paths.payment);
  const expenseRef = doc(db, paths.expense);
  // 1. Create the run and its initial entry together.
  const creation = writeBatch(db);
  creation.set(runRef, runFixture());
  creation.set(entryRef, entryFixture());

  await assertSucceeds(creation.commit());
  // 2. Additional entries cannot be added after run creation.
  const lateEntry = {
    ...entryFixture(),
    staffId: "staff-002"
  };

  const lateCreation = writeBatch(db);
  lateCreation.set(
    doc(db, `colonies/${COLONY}/colonyPayrollRuns/${RUN_ID}/entries/staff-002`),
    lateEntry
  );

  await assertFails(lateCreation.commit());
  // 3. Draft adjustments are allowed.
  await assertSucceeds(
    updateDoc(entryRef, {
      bonus: 1000,
      grossPay: 34500,
      netPay: 33500,
      balance: 33500,
      updatedAt: serverTimestamp()
    })
  );
  // Direct client approval must be rejected for both documents.
  const forgedRunApproval = {
    status: "approved",
    grossTotal: 34500,
    deductionTotal: 1000,
    netTotal: 33500,
    paidTotal: 0,
    balanceTotal: 33500,
    approvedBy: ADMIN,
    approvedByName: "Forged Client Name",
    approvedAt: serverTimestamp(),
    updatedAt: serverTimestamp()
  };

  const forgedEntryApproval = {
    status: "approved",
    approvedAt: serverTimestamp(),
    updatedAt: serverTimestamp()
  };

  await assertFails(updateDoc(runRef, forgedRunApproval));
  await assertFails(updateDoc(entryRef, forgedEntryApproval));

  const forgedApprovalBatch = writeBatch(db);
  forgedApprovalBatch.update(runRef, forgedRunApproval);
  forgedApprovalBatch.update(entryRef, forgedEntryApproval);
  await assertFails(forgedApprovalBatch.commit());

  const [stillDraftRun, stillDraftEntry] = await Promise.all([
    getDoc(runRef),
    getDoc(entryRef)
  ]);
  assert.equal(stillDraftRun.data().status, "draft");
  assert.equal(stillDraftEntry.data().status, "draft");

  // Simulate the trusted Admin SDK result to test the separate payout rules.
  await testEnv.withSecurityRulesDisabled(async context => {
    const privilegedDb = context.firestore();

    await updateDoc(doc(privilegedDb, paths.run), {
      status: "approved",
      grossTotal: 34500,
      deductionTotal: 1000,
      netTotal: 33500,
      paidTotal: 0,
      balanceTotal: 33500,
      approvedBy: ADMIN,
      approvedByName: "Rules Admin",
      approvedAt: serverTimestamp(),
      updatedAt: serverTimestamp()
    });

    await updateDoc(doc(privilegedDb, paths.entry), {
      basePay: 30000,
      overtimePay: 0,
      grossPay: 34500,
      totalDeductions: 1000,
      netPay: 33500,
      balance: 33500,
      status: "approved",
      approvedAt: serverTimestamp(),
      updatedAt: serverTimestamp()
    });
  });

  // 5. An approved payroll entry cannot be edited independently.
  await assertFails(
    updateDoc(entryRef, {
      bonus: 2000,
      updatedAt: serverTimestamp()
    })
  );
  // 6. Four linked payout records must be created atomically.
  const payout = writeBatch(db);

  payout.update(entryRef, {
    amountPaid: 10000,
    balance: 23500,
    status: "partially_paid",
    lastPaidAt: serverTimestamp(),
    lastPaymentId: PAYMENT_ID,
    updatedAt: serverTimestamp()
  });

  payout.update(runRef, {
    paidTotal: 10000,
    balanceTotal: 23500,
    status: "partially_paid",
    lastPaymentId: PAYMENT_ID,
    lastPaymentStaffEntryId: STAFF_ID,
    updatedAt: serverTimestamp()
  });

  payout.set(paymentRef, {
    runId: RUN_ID,
    staffEntryId: STAFF_ID,
    expenseId: EXPENSE_ID,
    amount: 10000,
    paymentMethod: "upi",
    reference: "PAY-001",
    notes: "Test payout",
    recordedBy: ADMIN,
    recordedByName: "Rules Admin",
    recordedAt: serverTimestamp()
  });

  payout.set(expenseRef, expenseFixture());

  await assertSucceeds(payout.commit());
  // 7. Confirm all four records persisted.
  const [run, entry, payment, expense] = await Promise.all([
    getDoc(runRef),
    getDoc(entryRef),
    getDoc(paymentRef),
    getDoc(expenseRef)
  ]);

  assert.equal(run.data().paidTotal, 10000);
  assert.equal(entry.data().amountPaid, 10000);
  assert.equal(payment.data().expenseId, EXPENSE_ID);
  assert.equal(expense.data().payrollPaymentId, PAYMENT_ID);
  // Replaying an existing immutable payment must not credit payroll twice.
    const replay = writeBatch(db);

    replay.update(entryRef, {
      amountPaid: 20000,
      balance: 13500,
      status: "partially_paid",
      lastPaidAt: serverTimestamp(),
      lastPaymentId: PAYMENT_ID,
      updatedAt: serverTimestamp()
    });

    replay.update(runRef, {
      paidTotal: 20000,
      balanceTotal: 13500,
      status: "partially_paid",
      lastPaymentId: PAYMENT_ID,
      lastPaymentStaffEntryId: STAFF_ID,
      updatedAt: serverTimestamp()
    });

    await assertFails(replay.commit());

    const [afterReplayRun, afterReplayEntry] = await Promise.all([
      getDoc(runRef),
      getDoc(entryRef)
    ]);

    assert.equal(afterReplayRun.data().paidTotal, 10000);
    assert.equal(afterReplayRun.data().balanceTotal, 23500);
    assert.equal(afterReplayEntry.data().amountPaid, 10000);
    assert.equal(afterReplayEntry.data().balance, 23500);

    // 8. A forged payment without its matching expense must fail.
  const orphanId = "orphan-payment";

  const orphanRef = doc(
    db,
    `colonies/${COLONY}/colonyPayrollRuns/${RUN_ID}/entries/${STAFF_ID}/payments/${orphanId}`
  );

  await assertFails(
    setDoc(orphanRef, {
      runId: RUN_ID,
      staffEntryId: STAFF_ID,
      expenseId: `payroll_${RUN_ID}_${STAFF_ID}_${orphanId}`,
      amount: 1,
      paymentMethod: "upi",
      reference: "",
      notes: "",
      recordedBy: ADMIN,
      recordedByName: "Rules Admin",
      recordedAt: serverTimestamp()
    })
  );
  // 9. A forged payroll expense without a matching payment must fail.
  await assertFails(
    setDoc(
      doc(db, `colonies/${COLONY}/colonyExpenses/payroll_${RUN_ID}_${STAFF_ID}_fake`),
      {
        ...expenseFixture(),
        payrollPaymentId: "fake"
      }
    )
  );
});

test("Ordinary colony expenses remain compatible", async () => {
  const db = adminDb();

  const expenseRef = doc(
    db,
    `colonies/${COLONY}/colonyExpenses/ordinary-expense-test`
  );

  await assertSucceeds(
    setDoc(expenseRef, {
      title: "Common area repair",
      category: "repairs",
      amount: 500,
      amountPaid: 0,
      paymentStatus: "unpaid",
      paymentMethod: "upi",
      expenseDate: Timestamp.fromDate(
        new Date("2026-11-08T12:00:00.000Z")
      ),
      monthKey: "2026-11",
      payeeName: "Repair Vendor",
      vendorName: "",
      assetName: "",
      reference: "",
      notes: "",
      createdBy: ADMIN,
      createdByName: "Rules Admin",
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp()
    })
  );

  await assertSucceeds(
    updateDoc(expenseRef, {
      amountPaid: 250,
      paymentStatus: "partially_paid",
      updatedAt: serverTimestamp()
    })
  );
});
