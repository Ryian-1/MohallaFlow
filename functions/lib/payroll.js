
'use strict';

const {
  FieldValue,
  Timestamp,
} = require('firebase-admin/firestore');

const MAX_AMOUNT = 1000000000;

class PayrollApprovalError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'PayrollApprovalError';
    this.code = code;
  }
}

function fail(message, code = 'failed-precondition') {
  throw new PayrollApprovalError(code, message);
}

function finiteNonNegative(data, key, maximum = MAX_AMOUNT) {
  const value = data[key];

  if (
    typeof value !== 'number' ||
    !Number.isFinite(value) ||
    value < 0 ||
    value > maximum
  ) {
    fail(`Payroll entry contains an invalid ${key} value.`);
  }

  return value;
}

/**
 * Reproduces the existing Dart payroll calculation.
 * Stored derived values are deliberately ignored.
 */
function calculatePayrollEntry(entry, staffId, divisor) {
  if (!entry || typeof entry !== 'object' || Array.isArray(entry)) {
    fail('A payroll staff entry is invalid.');
  }

  if (entry.staffId !== staffId) {
    fail(`Payroll staff identity mismatch for ${staffId}.`);
  }

  if (
    typeof entry.staffCode !== 'string' ||
    entry.staffCode.trim().length === 0 ||
    entry.staffCode.length > 40 ||
    typeof entry.staffName !== 'string' ||
    entry.staffName.trim().length === 0 ||
    entry.staffName.length > 120
  ) {
    fail(`Payroll staff identity is incomplete for ${staffId}.`);
  }

  if (entry.status !== 'draft' || entry.amountPaid !== 0) {
    fail(`Staff entry ${staffId} is not an unpaid draft.`);
  }

  if (!(entry.createdAt instanceof Timestamp)) {
    fail(`Staff entry ${staffId} has an invalid creation timestamp.`);
  }

  if (!['monthly', 'daily', 'hourly'].includes(entry.payBasis)) {
    fail(`Staff entry ${staffId} has an unsupported pay basis.`);
  }

  const fields = [
    'baseRate',
    'hra',
    'transportAllowance',
    'otherAllowance',
    'defaultDeduction',
    'attendanceDays',
    'paidDays',
    'paidLeaveDays',
    'unpaidLeaveDays',
    'approvedPaidLeaveDays',
    'approvedUnpaidLeaveDays',
    'hoursWorked',
    'overtimeHours',
    'overtimeRate',
    'bonus',
    'reimbursements',
    'advanceRecovery',
    'otherDeductions',
    'amountPaid',
  ];

  const values = {};
  for (const field of fields) {
    values[field] = finiteNonNegative(entry, field);
  }

  if (values.baseRate <= 0) {
    fail(`Staff entry ${staffId} must have a positive base rate.`);
  }

  const rate = values.baseRate;

  // Same order of operations as StaffPayrollScreen._calculate().
  const allowance =
    values.hra +
    values.transportAllowance +
    values.otherAllowance;

  const bonus = values.bonus;
  const reimbursement = values.reimbursements;
  const overtime = values.overtimeHours * values.overtimeRate;
  const unpaid = values.unpaidLeaveDays;
  const paidDays = values.paidDays + values.paidLeaveDays;
  const hours = values.hoursWorked;

  let base;

  if (entry.payBasis === 'daily') {
    base = rate * paidDays;
  } else if (entry.payBasis === 'hourly') {
    base = rate * hours;
  } else {
    const standard = divisor <= 0 ? 30 : divisor;
    base = Math.min(
      rate,
      Math.max(0, rate - ((rate / standard) * unpaid)),
    );
  }

  const gross = base + allowance + bonus + reimbursement + overtime;

  const deductions =
    values.defaultDeduction +
    values.advanceRecovery +
    values.otherDeductions;

  const net = Math.max(0, gross - deductions);

  const result = {
    basePay: base,
    overtimePay: overtime,
    grossPay: gross,
    totalDeductions: deductions,
    netPay: net,
  };

  for (const [key, value] of Object.entries(result)) {
    if (!Number.isFinite(value) || value < 0 || value > MAX_AMOUNT) {
      fail(`Calculated ${key} is outside the permitted payroll range.`);
    }
  }

  return result;
}

/**
 * Approves an entire run using an Admin SDK transaction.
 *
 * The membership, payroll run and complete entry query are read inside
 * the transaction. No writes occur until every entry has been validated
 * and independently recalculated.
 */
async function approvePayrollRun({
  db,
  colonyId,
  runId,
  uid,
}) {
  if (
    typeof colonyId !== 'string' ||
    colonyId.trim().length === 0 ||
    colonyId.length > 128 ||
    colonyId.includes('/')
  ) {
    fail('A valid colony identifier is required.', 'invalid-argument');
  }

  if (
    typeof runId !== 'string' ||
    !/^[0-9]{4}-(0[1-9]|1[0-2])$/.test(runId)
  ) {
    fail('A valid YYYY-MM payroll period is required.', 'invalid-argument');
  }

  if (typeof uid !== 'string' || uid.length === 0) {
    fail('Authentication is required.', 'unauthenticated');
  }

  const colonyRef = db.collection('colonies').doc(colonyId);
  const memberRef = colonyRef.collection('members').doc(uid);
  const runRef = colonyRef.collection('colonyPayrollRuns').doc(runId);
  const entriesQuery = runRef.collection('entries').limit(401);

  return db.runTransaction(async (transaction) => {
    const [memberSnapshot, runSnapshot, entriesSnapshot] =
      await Promise.all([
        transaction.get(memberRef),
        transaction.get(runRef),
        transaction.get(entriesQuery),
      ]);

    if (!memberSnapshot.exists) {
      fail('Active Colony Admin membership is required.', 'permission-denied');
    }

    const member = memberSnapshot.data() || {};

    if (
      member.uid !== uid ||
      member.colonyId !== colonyId ||
      member.role !== 'admin' ||
      member.status !== 'active'
    ) {
      fail('Only an active Colony Admin can approve payroll.', 'permission-denied');
    }

    const nameCandidates = [
      member.fullName,
      member.displayName,
      member.name,
      member.memberName,
    ];

    const verifiedAdminName = nameCandidates.find(
      (value) => typeof value === 'string' &&
        value.trim().length > 0 &&
        value.trim().length <= 120,
    )?.trim() || 'Colony Admin';

    if (!runSnapshot.exists) {
      fail('The payroll run no longer exists.', 'not-found');
    }

    const run = runSnapshot.data() || {};

    if (run.periodKey !== runId) {
      fail('Payroll period and document identity do not match.');
    }

    if (run.status !== 'draft') {
      fail('Only a draft payroll run can be approved.');
    }

    if (
      !Number.isInteger(run.staffCount) ||
      run.staffCount < 1 ||
      run.staffCount > 400
    ) {
      fail('Payroll must contain between 1 and 400 staff entries.');
    }

    if (entriesSnapshot.size > 400) {
      fail('This payroll run exceeds the 400-entry transaction limit.');
    }

    if (entriesSnapshot.size !== run.staffCount) {
      fail(
        'Payroll entry count does not match the run. Refresh and review the draft.',
      );
    }

    const divisor = run.monthlyProrationDivisor;

    if (
      typeof divisor !== 'number' ||
      !Number.isFinite(divisor) ||
      divisor <= 0 ||
      divisor > 31
    ) {
      fail('The payroll proration divisor is invalid.');
    }

    let grossTotal = 0;
    let deductionTotal = 0;
    let netTotal = 0;

    const approvals = [];

    for (const document of entriesSnapshot.docs) {
      const calculation = calculatePayrollEntry(
        document.data(),
        document.id,
        divisor,
      );

      grossTotal += calculation.grossPay;
      deductionTotal += calculation.totalDeductions;
      netTotal += calculation.netPay;

      approvals.push({
        ref: document.ref,
        calculation,
      });
    }

    for (const [label, value] of Object.entries({
      grossTotal,
      deductionTotal,
      netTotal,
    })) {
      if (!Number.isFinite(value) || value < 0 || value > MAX_AMOUNT) {
        fail(`Payroll ${label} exceeds the permitted total.`);
      }
    }

    // All reads and calculations have completed. Writes begin here.
    const serverTimestamp = FieldValue.serverTimestamp();

    transaction.update(runRef, {
      status: 'approved',
      grossTotal,
      deductionTotal,
      netTotal,
      paidTotal: 0,
      balanceTotal: netTotal,
      approvedBy: uid,
      approvedByName: verifiedAdminName,
      approvedAt: serverTimestamp,
      updatedAt: serverTimestamp,
    });

    for (const approval of approvals) {
      transaction.update(approval.ref, {
        ...approval.calculation,
        balance: approval.calculation.netPay,
        status: 'approved',
        approvedAt: serverTimestamp,
        updatedAt: serverTimestamp,
      });
    }

    return {
      runId,
      status: 'approved',
      staffCount: approvals.length,
      grossTotal,
      deductionTotal,
      netTotal,
    };
  });
}

module.exports = {
  PayrollApprovalError,
  calculatePayrollEntry,
  approvePayrollRun,
};
