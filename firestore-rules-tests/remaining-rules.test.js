import { before, after, test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

import {
  initializeTestEnvironment,
  assertSucceeds
} from "@firebase/rules-unit-testing";

import {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  writeBatch,
  serverTimestamp,
  Timestamp
} from "firebase/firestore";

// ==================================================
// CONFIGURATION
// ==================================================

const PROJECT_ID = "mohallaflow";
const COLONY_A = "rules_remaining_colony_a";

const ADMIN = "rules_remaining_admin";
const RESIDENT_A = "rules_remaining_resident_a";
const RESIDENT_B = "rules_remaining_resident_b";

const RESIDENT_RECORD_A = "rules_remaining_resident_record_a";
const RESIDENT_RECORD_B = "rules_remaining_resident_record_b";

const HOUSEHOLD_A = "rules_remaining_household_a";
const HOUSEHOLD_B = "rules_remaining_household_b";

const VENDOR_ID = "rules_remaining_vendor";
const SUPPLIER_ID = "rules_remaining_supplier";

const WORKER_PHONE = "9876543210";

const RESIDENT_NAME_A = "Rules Resident A";
const RESIDENT_NAME_B = "Rules Resident B";

const FIXED_TIME = Timestamp.fromDate(
  new Date("2026-11-01T10:00:00.000Z")
);

const FUTURE_TIME = Timestamp.fromDate(
  new Date("2026-12-01T10:00:00.000Z")
);

const PAST_TIME = Timestamp.fromDate(
  new Date("2026-10-01T10:00:00.000Z")
);

let testEnv;

const rules = readFileSync(
  process.env.CANDIDATE_RULES ?? new URL("../qa_candidates/firestore_candidate_v2.rules", import.meta.url),
  "utf8"
);

// ==================================================
// PATH HELPERS
// ==================================================

const path = {
  member: id => `colonies/${COLONY_A}/members/${id}`,
  resident: id => `colonies/${COLONY_A}/residents/${id}`,
  household: id => `colonies/${COLONY_A}/households/${id}`,
  visitor: id => `colonies/${COLONY_A}/visitors/${id}`,
  job: id => `colonies/${COLONY_A}/maintenanceJobs/${id}`,
  vendor: id => `colonies/${COLONY_A}/maintenanceVendors/${id}`,
  bill: id => `colonies/${COLONY_A}/maintenanceBills/${id}`,
  payment: id => `colonies/${COLONY_A}/maintenancePayments/${id}`,
  supplier: id => `colonies/${COLONY_A}/waterSuppliers/${id}`,
  delivery: id => `colonies/${COLONY_A}/waterDeliveries/${id}`,
  announcement: id => `colonies/${COLONY_A}/announcements/${id}`
};

function authenticatedDb(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

function document(db, documentPath) {
  return doc(db, documentPath);
}

async function assertPermissionDenied(operation) {
  let caught = null;

  try {
    await operation;
  } catch (error) {
    caught = error;
  }

  assert.ok(caught, "Expected operation to be denied.");

  assert.equal(
    caught.code,
    "permission-denied",
    `Expected permission-denied, received ${caught.code ?? caught.name}: ${caught.message}`
  );

  assert.ok(
    !/maximum of 1000 expressions/i.test(caught.message ?? ""),
    `Rules expression-limit failure is not an acceptable denial: ${caught.message}`
  );
}

// ==================================================
// DATA FIXTURES
// ==================================================

function residentRecord(name, householdId) {
  return {
    fullName: name,
    phoneNumber: WORKER_PHONE,
    email: "test@example.com",
    householdId,
    blockId: "Block A",
    houseNumber: householdId === HOUSEHOLD_A ? "A-101" : "B-201",
    relationshipToHead: "Owner",
    residentStatus: "active",
    createdAt: FIXED_TIME,
    updatedAt: FIXED_TIME,
    createdBy: ADMIN
  };
}

function validNewResident() {
  return {
    fullName: "New Test Resident",
    phoneNumber: "9876543212",
    email: "newresident@example.com",
    householdId: HOUSEHOLD_A,
    blockId: "Block A",
    houseNumber: "A-101",
    relationshipToHead: "Spouse",
    residentStatus: "active",
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    createdBy: ADMIN
  };
}

function visitorFixture({
  hostUid = RESIDENT_A,
  hostResidentId = RESIDENT_RECORD_A,
  status = "expected",
  visitType = "pre_registered"
} = {}) {
  const isAdmin = hostUid === null;

  return {
    visitorName: "Rules Test Visitor",
    visitorPhone: "9876543210",
    purpose: "Family visit",
    hostName: isAdmin ? "Guest" : RESIDENT_NAME_A,
    hostUnit: "A-101",
    hostResidentId,
    hostUid,
    visitType,
    status,
    expectedAt: FUTURE_TIME,
    checkedInAt: status === "checked_in" ? FIXED_TIME : null,
    checkedOutAt: null,
    cancelledAt: null,
    createdBy: isAdmin ? ADMIN : hostUid,
    createdByRole: isAdmin ? "admin" : "resident",
    createdByName: isAdmin ? "Rules Test Admin" : RESIDENT_NAME_A,
    createdAt: FIXED_TIME,
    updatedAt: FIXED_TIME,
    updatedBy: isAdmin ? ADMIN : hostUid
  };
}

function maintenanceJobFixture() {
  return {
    title: "Lift maintenance",
    category: "Lift",
    location: "Tower A",
    description: "Inspect and repair the common lift system.",
    priority: "high",
    status: "open",
    vendorId: null,
    vendorName: null,
    vendorPhone: null,
    resolutionNotes: "",
    actualCost: null,
    createdBy: ADMIN,
    createdByName: "Rules Test Admin",
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    completedAt: null
  };
}

function vendorFixture() {
  return {
    vendorName: "Rules Test Maintenance Vendor",
    contactPerson: "Vendor Contact",
    phoneNumber: "9876543213",
    email: "vendor@example.com",
    serviceCategory: "Plumbing",
    status: "active",
    createdBy: ADMIN,
    createdByName: "Rules Test Admin",
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp()
  };
}

function billFixture(householdId, number = "A-101") {
  return {
    householdId,
    blockId: "Block A",
    houseNumber: number,
    householdHeadName: "Rules Test Household Head",
    billingPeriod: "November 2026",
    title: "Monthly maintenance",
    description: "Monthly colony maintenance charges.",
    totalAmount: 1000,
    amountPaid: 0,
    status: "unpaid",
    dueDate: FUTURE_TIME,
    upiId: "test@upi",
    paymentInstructions: "Pay using the colony UPI ID.",
    createdBy: ADMIN,
    createdByName: "Rules Test Admin",
    createdAt: FIXED_TIME,
    updatedAt: FIXED_TIME
  };
}

function residentPaymentFixture() {
  return {
    billId: "remaining_test_bill_a",
    householdId: HOUSEHOLD_A,
    residentId: RESIDENT_RECORD_A,
    residentName: RESIDENT_NAME_A,
    submittedBy: RESIDENT_A,
    submittedByName: RESIDENT_NAME_A,
    submittedByRole: "resident",
    paymentMethod: "upi",
    amount: 250,
    transactionReference: "TEST-UPI-REFERENCE-001",
    notes: "November maintenance payment.",
    status: "pending",
    createdBy: RESIDENT_A,
    createdByRole: "resident",
    createdByName: RESIDENT_NAME_A,
    verifiedBy: null,
    verifiedByName: null,
    verifiedAt: null,
    rejectionReason: null,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp()
  };
}

function adminPaymentFixture(billId, householdId, amount) {
  return {
    billId,
    householdId,
    residentId: null,
    residentName: "Rules Test Household Head",
    submittedBy: ADMIN,
    submittedByName: "Rules Test Admin",
    submittedByRole: "admin",
    paymentMethod: "cash",
    amount,
    transactionReference: "CASH-RECEIPT-TEST",
    notes: "",
    status: "verified",
    createdBy: ADMIN,
    createdByRole: "admin",
    createdByName: "Rules Test Admin",
    verifiedBy: ADMIN,
    verifiedByName: "Rules Test Admin",
    verifiedAt: serverTimestamp(),
    rejectionReason: null,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp()
  };
}

function supplierFixture() {
  return {
    supplierName: "Rules Test Water Supplier",
    contactPerson: "Supplier Contact",
    phoneNumber: "9876543214",
    email: "water@example.com",
    serviceType: "Water Tanker",
    status: "active",
    createdBy: ADMIN,
    createdByName: "Rules Test Admin",
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp()
  };
}

function waterDeliveryFixture() {
  return {
    supplierId: SUPPLIER_ID,
    supplierName: "Rules Test Water Supplier",
    supplierPhone: "9876543214",
    vehicleNumber: "DL01AB1234",
    quantityLitres: 10000,
    cost: 2500,
    paymentStatus: "pending",
    status: "scheduled",
    deliveryDate: FUTURE_TIME,
    deliveryLocation: "Main water tank",
    distributionNotes: "Test delivery.",
    createdBy: ADMIN,
    createdByName: "Rules Test Admin",
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    completedAt: null
  };
}

function announcementFixture() {
  return {
    title: "Test Colony Announcement",
    message: "This is a test announcement for the colony.",
    category: "General",
    priority: "normal",
    status: "draft",
    createdBy: ADMIN,
    createdByName: "Rules Test Admin",
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    publishedAt: null,
    archivedAt: null
  };
}

// ==================================================
// INITIALIZE EMULATOR AND SEED TEST DATA
// ==================================================

before(async () => {
  console.log("\nConnecting to Firestore Emulator...");

  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      host: "127.0.0.1",
      port: 8080,
      rules
    }
  });

  await testEnv.withSecurityRulesDisabled(async context => {
    const db = context.firestore();

    const seed = async (p, data) => {
      await setDoc(document(db, p), data);
    };

    // Membership records.
    await seed(path.member(ADMIN), {
      uid: ADMIN,
      colonyId: COLONY_A,
      role: "admin",
      status: "active"
    });

    await seed(path.member(RESIDENT_A), {
      uid: RESIDENT_A,
      colonyId: COLONY_A,
      role: "resident",
      status: "active",
      residentId: RESIDENT_RECORD_A
    });

    await seed(path.member(RESIDENT_B), {
      uid: RESIDENT_B,
      colonyId: COLONY_A,
      role: "resident",
      status: "active",
      residentId: RESIDENT_RECORD_B
    });

    // Households.
    await seed(path.household(HOUSEHOLD_A), {
      blockId: "Block A",
      houseNumber: "A-101",
      householdHeadName: RESIDENT_NAME_A,
      primaryPhone: WORKER_PHONE,
      occupancyStatus: "occupied",
      createdAt: FIXED_TIME,
      updatedAt: FIXED_TIME,
      createdBy: ADMIN
    });

    await seed(path.household(HOUSEHOLD_B), {
      blockId: "Block B",
      houseNumber: "B-201",
      householdHeadName: RESIDENT_NAME_B,
      primaryPhone: "9876543215",
      occupancyStatus: "occupied",
      createdAt: FIXED_TIME,
      updatedAt: FIXED_TIME,
      createdBy: ADMIN
    });

    // Residents.
    await seed(path.resident(RESIDENT_RECORD_A),
      residentRecord(RESIDENT_NAME_A, HOUSEHOLD_A));

    await seed(path.resident(RESIDENT_RECORD_B),
      residentRecord(RESIDENT_NAME_B, HOUSEHOLD_B));

    // Visitors.
    await seed(path.visitor("remaining_cancel_own"),
      visitorFixture());

    await seed(path.visitor("remaining_cancel_other"),
      visitorFixture({
        hostUid: RESIDENT_B,
        hostResidentId: RESIDENT_RECORD_B
      }));

    await seed(path.visitor("remaining_admin_checkin"),
      visitorFixture());

    await seed(path.visitor("remaining_admin_checkout"),
      {
        ...visitorFixture({ status: "checked_in" }),
        checkedInAt: FIXED_TIME
      });

    // Existing maintenance bills used for payment tests.
    await seed(path.bill("remaining_test_bill_a"),
      billFixture(HOUSEHOLD_A));

    await seed(path.bill("remaining_test_bill_b"),
      billFixture(HOUSEHOLD_B, "B-201"));

    // Existing published announcement for archive test.
    await seed(path.announcement("remaining_published_announcement"), {
      ...announcementFixture(),
      status: "published",
      publishedAt: FIXED_TIME
    });
  });

  console.log("Remaining-collection fixtures prepared.");
});

// ==================================================
// CLEANUP
// ==================================================

after(async () => {
  if (!testEnv) return;

  const paths = [
    path.member(ADMIN),
    path.member(RESIDENT_A),
    path.member(RESIDENT_B),

    path.household(HOUSEHOLD_A),
    path.household(HOUSEHOLD_B),

    path.resident(RESIDENT_RECORD_A),
    path.resident(RESIDENT_RECORD_B),
    path.resident("remaining_new_resident"),

    path.visitor("remaining_new_resident_visit"),
    path.visitor("remaining_spoofed_visit"),
    path.visitor("remaining_admin_walkin"),
    path.visitor("remaining_cancel_own"),
    path.visitor("remaining_cancel_other"),
    path.visitor("remaining_admin_checkin"),
    path.visitor("remaining_admin_checkout"),

    path.job("remaining_new_job"),

    path.vendor(VENDOR_ID),

    path.bill("remaining_test_bill_a"),
    path.bill("remaining_test_bill_b"),
    path.bill("remaining_new_bill"),

    path.payment("remaining_resident_payment"),
    path.payment("remaining_admin_payment_without_bill"),
    path.payment("remaining_admin_payment_atomic"),

    path.supplier(SUPPLIER_ID),

    path.delivery("remaining_new_delivery"),

    path.announcement("remaining_new_announcement"),
    path.announcement("remaining_published_announcement")
  ];

  try {
    await testEnv.withSecurityRulesDisabled(async context => {
      const db = context.firestore();

      for (const p of paths) {
        await deleteDoc(document(db, p));
      }
    });
  } finally {
    await testEnv.cleanup();
  }

  console.log("Remaining-collection fixtures cleaned up.");
});

// ==================================================
// MEMBERSHIP AND RESIDENT TESTS — 41 TO 46
// ==================================================

test("41 — User can directly read own membership document", async () => {
  const db = authenticatedDb(RESIDENT_A);

  const result = await assertSucceeds(
    getDoc(document(db, path.member(RESIDENT_A)))
  );

  assert.equal(result.exists(), true);
});

test("42 — User cannot read another member's document", async () => {
  const db = authenticatedDb(RESIDENT_A);

  await assertPermissionDenied(
    getDoc(document(db, path.member(RESIDENT_B)))
  );
});

test("43 — Admin can create valid resident record", async () => {
  const db = authenticatedDb(ADMIN);

  await assertSucceeds(
    setDoc(
      document(db, path.resident("remaining_new_resident")),
      validNewResident()
    )
  );
});

test("44 — Resident cannot create another resident record", async () => {
  const db = authenticatedDb(RESIDENT_A);

  await assertPermissionDenied(
    setDoc(
      document(db, path.resident("remaining_new_resident")),
      validNewResident()
    )
  );
});

test("45 — Resident can read own resident record", async () => {
  const db = authenticatedDb(RESIDENT_A);

  const result = await assertSucceeds(
    getDoc(document(db, path.resident(RESIDENT_RECORD_A)))
  );

  assert.equal(result.exists(), true);
});

test("46 — Resident cannot read another resident record", async () => {
  const db = authenticatedDb(RESIDENT_A);

  await assertPermissionDenied(
    getDoc(document(db, path.resident(RESIDENT_RECORD_B)))
  );
});

// ==================================================
// VISITOR TESTS — 47 TO 53
// ==================================================

test("47 — Resident can pre-register own visitor", async () => {
  const db = authenticatedDb(RESIDENT_A);

  const data = {
    visitorName: "New Test Visitor",
    visitorPhone: "9876543216",
    purpose: "Family visit",
    hostName: RESIDENT_NAME_A,
    hostUnit: "A-101",
    hostResidentId: RESIDENT_RECORD_A,
    hostUid: RESIDENT_A,
    visitType: "pre_registered",
    status: "expected",
    expectedAt: FUTURE_TIME,
    checkedInAt: null,
    checkedOutAt: null,
    cancelledAt: null,
    createdBy: RESIDENT_A,
    createdByRole: "resident",
    createdByName: RESIDENT_NAME_A,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    updatedBy: RESIDENT_A
  };

  await assertSucceeds(
    setDoc(
      document(db, path.visitor("remaining_new_resident_visit")),
      data
    )
  );
});

test("48 — Resident cannot pre-register visitor for another resident", async () => {
  const db = authenticatedDb(RESIDENT_A);

  const data = {
    visitorName: "Spoofed Visitor",
    visitorPhone: "9876543217",
    purpose: "Family visit",
    hostName: RESIDENT_NAME_B,
    hostUnit: "B-201",
    hostResidentId: RESIDENT_RECORD_B,
    hostUid: RESIDENT_B,
    visitType: "pre_registered",
    status: "expected",
    expectedAt: FUTURE_TIME,
    checkedInAt: null,
    checkedOutAt: null,
    cancelledAt: null,
    createdBy: RESIDENT_A,
    createdByRole: "resident",
    createdByName: RESIDENT_NAME_A,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    updatedBy: RESIDENT_A
  };

  await assertPermissionDenied(
    setDoc(
      document(db, path.visitor("remaining_spoofed_visit")),
      data
    )
  );
});

test("48B — Resident cannot use own UID with another resident ID", async () => {
  const db = authenticatedDb(RESIDENT_A);
  const data = {
    ...visitorFixture({
      hostUid: RESIDENT_A,
      hostResidentId: RESIDENT_RECORD_B
    }),
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp()
  };

  await assertPermissionDenied(
    setDoc(
      document(db, path.visitor("remaining_spoofed_resident_id")),
      data
    )
  );
});

test("49 — Admin can register walk-in visitor", async () => {
  const db = authenticatedDb(ADMIN);

  const data = {
    visitorName: "Walk-in Test Visitor",
    visitorPhone: "9876543218",
    purpose: "Delivery",
    hostName: "Guest",
    hostUnit: "",
    hostResidentId: null,
    hostUid: null,
    visitType: "walk_in",
    status: "checked_in",
    expectedAt: PAST_TIME,
    checkedInAt: serverTimestamp(),
    checkedOutAt: null,
    cancelledAt: null,
    createdBy: ADMIN,
    createdByRole: "admin",
    createdByName: "Rules Test Admin",
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    updatedBy: ADMIN
  };

  await assertSucceeds(
    setDoc(
      document(db, path.visitor("remaining_admin_walkin")),
      data
    )
  );
});

test("50 — Resident can cancel own expected visitor registration", async () => {
  const db = authenticatedDb(RESIDENT_A);

  await assertSucceeds(
    updateDoc(
      document(db, path.visitor("remaining_cancel_own")),
      {
        status: "cancelled",
        cancelledAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
        updatedBy: RESIDENT_A
      }
    )
  );
});

test("51 — Resident cannot cancel another resident's visitor registration", async () => {
  const db = authenticatedDb(RESIDENT_A);

  await assertPermissionDenied(
    updateDoc(
      document(db, path.visitor("remaining_cancel_other")),
      {
        status: "cancelled",
        cancelledAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
        updatedBy: RESIDENT_A
      }
    )
  );
});

test("52 — Admin can check in an expected visitor", async () => {
  const db = authenticatedDb(ADMIN);

  await assertSucceeds(
    updateDoc(
      document(db, path.visitor("remaining_admin_checkin")),
      {
        status: "checked_in",
        checkedInAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
        updatedBy: ADMIN
      }
    )
  );
});

test("53 — Admin can check out an already checked-in visitor", async () => {
  const db = authenticatedDb(ADMIN);

  await assertSucceeds(
    updateDoc(
      document(db, path.visitor("remaining_admin_checkout")),
      {
        status: "checked_out",
        checkedOutAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
        updatedBy: ADMIN
      }
    )
  );
});

// ==================================================
// MAINTENANCE JOB AND VENDOR TESTS — 54 TO 59
// ==================================================

test("54 — Admin can create valid maintenance job", async () => {
  const db = authenticatedDb(ADMIN);

  await assertSucceeds(
    setDoc(
      document(db, path.job("remaining_new_job")),
      maintenanceJobFixture()
    )
  );
});

test("55 — Resident cannot read admin-only maintenance job", async () => {
  const db = authenticatedDb(RESIDENT_A);

  await assertPermissionDenied(
    getDoc(document(db, path.job("remaining_new_job")))
  );
});

test("56 — Admin can complete maintenance job with permitted fields", async () => {
  const db = authenticatedDb(ADMIN);

  await assertSucceeds(
    updateDoc(
      document(db, path.job("remaining_new_job")),
      {
        status: "completed",
        resolutionNotes: "Maintenance completed successfully.",
        actualCost: 1500,
        updatedAt: serverTimestamp(),
        completedAt: serverTimestamp()
      }
    )
  );
});

test("57 — Admin can create valid maintenance vendor", async () => {
  const db = authenticatedDb(ADMIN);

  await assertSucceeds(
    setDoc(
      document(db, path.vendor(VENDOR_ID)),
      vendorFixture()
    )
  );
});

test("58 — Admin can deactivate maintenance vendor", async () => {
  const db = authenticatedDb(ADMIN);

  await assertSucceeds(
    updateDoc(
      document(db, path.vendor(VENDOR_ID)),
      {
        status: "inactive",
        updatedAt: serverTimestamp()
      }
    )
  );
});

test("59 — Resident cannot create maintenance vendor", async () => {
  const db = authenticatedDb(RESIDENT_A);

  await assertPermissionDenied(
    setDoc(
      document(db, path.vendor(VENDOR_ID)),
      vendorFixture()
    )
  );
});

// ==================================================
// MAINTENANCE BILL AND PAYMENT TESTS — 60 TO 65
// ==================================================

test("60 — Admin can issue valid maintenance bill", async () => {
  const db = authenticatedDb(ADMIN);

  const data = {
    ...billFixture(HOUSEHOLD_A),
    amountPaid: 0,
    status: "unpaid",
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp()
  };

  await assertSucceeds(
    setDoc(
      document(db, path.bill("remaining_new_bill")),
      data
    )
  );
});

test("61 — Resident can read bill for own household", async () => {
  const db = authenticatedDb(RESIDENT_A);

  const result = await assertSucceeds(
    getDoc(document(db, path.bill("remaining_test_bill_a")))
  );

  assert.equal(result.exists(), true);
});

test("62 — Resident cannot read another household's bill", async () => {
  const db = authenticatedDb(RESIDENT_A);

  await assertPermissionDenied(
    getDoc(document(db, path.bill("remaining_test_bill_b")))
  );
});

test("63 — Resident can submit valid payment for own household bill", async () => {
  const db = authenticatedDb(RESIDENT_A);

  await assertSucceeds(
    setDoc(
      document(db, path.payment("remaining_resident_payment")),
      residentPaymentFixture()
    )
  );
});

test("64 — Resident cannot verify or alter own payment submission", async () => {
  const db = authenticatedDb(RESIDENT_A);

  await assertPermissionDenied(
    updateDoc(
      document(db, path.payment("remaining_resident_payment")),
      {
        status: "verified",
        verifiedBy: RESIDENT_A,
        verifiedByName: RESIDENT_NAME_A,
        verifiedAt: serverTimestamp(),
        updatedAt: serverTimestamp()
      }
    )
  );
});

test("65 — Admin cannot verify payment without matching bill increment", async () => {
  const db = authenticatedDb(ADMIN);

  await assertPermissionDenied(
    updateDoc(
      document(db, path.payment("remaining_resident_payment")),
      {
        status: "verified",
        verifiedBy: ADMIN,
        verifiedByName: "Rules Test Admin",
        verifiedAt: serverTimestamp(),
        rejectionReason: null,
        updatedAt: serverTimestamp()
      }
    )
  );
});

test("65B — Admin can verify resident payment with atomic bill increment", async () => {
  const db = authenticatedDb(ADMIN);
  const batch = writeBatch(db);

  batch.update(document(db, path.bill("remaining_test_bill_a")), {
    amountPaid: 250,
    status: "partially_paid",
    updatedAt: serverTimestamp()
  });

  batch.update(document(db, path.payment("remaining_resident_payment")), {
    status: "verified",
    verifiedBy: ADMIN,
    verifiedByName: "Rules Test Admin",
    verifiedAt: serverTimestamp(),
    rejectionReason: null,
    updatedAt: serverTimestamp()
  });

  await assertSucceeds(batch.commit());

  const bill = await assertSucceeds(
    getDoc(document(db, path.bill("remaining_test_bill_a")))
  );
  assert.equal(bill.data().amountPaid, 250);
});


test("65D — Admin can create verified payment with atomic bill increment", async () => {
  const db = authenticatedDb(ADMIN);
  const batch = writeBatch(db);

  batch.update(document(db, path.bill("remaining_test_bill_b")), {
    amountPaid: 100,
    status: "partially_paid",
    updatedAt: serverTimestamp()
  });

  batch.set(
    document(db, path.payment("remaining_admin_payment_atomic")),
    adminPaymentFixture("remaining_test_bill_b", HOUSEHOLD_B, 100)
  );

  await assertSucceeds(batch.commit());

  const bill = await assertSucceeds(
    getDoc(document(db, path.bill("remaining_test_bill_b")))
  );
  assert.equal(bill.data().amountPaid, 100);
});

// ==================================================
// WATER SUPPLIER AND DELIVERY TESTS — 66 TO 71
// ==================================================

test("66 — Admin can create valid water supplier", async () => {
  const db = authenticatedDb(ADMIN);

  await assertSucceeds(
    setDoc(
      document(db, path.supplier(SUPPLIER_ID)),
      supplierFixture()
    )
  );
});

test("67 — Resident cannot read admin-only water supplier", async () => {
  const db = authenticatedDb(RESIDENT_A);

  await assertPermissionDenied(
    getDoc(document(db, path.supplier(SUPPLIER_ID)))
  );
});

test("68 — Admin can deactivate water supplier", async () => {
  const db = authenticatedDb(ADMIN);

  await assertSucceeds(
    updateDoc(
      document(db, path.supplier(SUPPLIER_ID)),
      {
        status: "inactive",
        updatedAt: serverTimestamp()
      }
    )
  );
});

test("69 — Admin can create valid water delivery using active supplier", async () => {
  const db = authenticatedDb(ADMIN);

  // Reactivate supplier for the delivery fixture.
  await assertSucceeds(
    updateDoc(
      document(db, path.supplier(SUPPLIER_ID)),
      {
        status: "active",
        updatedAt: serverTimestamp()
      }
    )
  );

  await assertSucceeds(
    setDoc(
      document(db, path.delivery("remaining_new_delivery")),
      waterDeliveryFixture()
    )
  );
});

test("70 — Resident cannot read water delivery records", async () => {
  const db = authenticatedDb(RESIDENT_A);

  await assertPermissionDenied(
    getDoc(document(db, path.delivery("remaining_new_delivery")))
  );
});

test("71 — Admin can mark water delivery completed and paid", async () => {
  const db = authenticatedDb(ADMIN);

  await assertSucceeds(
    updateDoc(
      document(db, path.delivery("remaining_new_delivery")),
      {
        status: "delivered",
        paymentStatus: "paid",
        completedAt: serverTimestamp(),
        updatedAt: serverTimestamp()
      }
    )
  );
});

// ==================================================
// ANNOUNCEMENT TESTS — 72 TO 75
// ==================================================

test("72 — Admin can create a valid draft announcement", async () => {
  const db = authenticatedDb(ADMIN);

  await assertSucceeds(
    setDoc(
      document(db, path.announcement("remaining_new_announcement")),
      announcementFixture()
    )
  );
});

test("73 — Resident cannot create announcement", async () => {
  const db = authenticatedDb(RESIDENT_A);

  await assertPermissionDenied(
    setDoc(
      document(db, path.announcement("remaining_new_announcement")),
      announcementFixture()
    )
  );
});

test("74 — Admin can archive a published announcement", async () => {
  const db = authenticatedDb(ADMIN);

  await assertSucceeds(
    updateDoc(
      document(db, path.announcement("remaining_published_announcement")),
      {
        status: "archived",
        archivedAt: serverTimestamp(),
        updatedAt: serverTimestamp()
      }
    )
  );
});

test("75 — Admin cannot delete announcement", async () => {
  const db = authenticatedDb(ADMIN);

  await assertPermissionDenied(
    deleteDoc(
      document(db, path.announcement("remaining_published_announcement"))
    )
  );
});
