import { before, after, test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";

import {
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";

import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  setDoc,
  updateDoc,
  where,
} from "firebase/firestore";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const RULES_PATH = process.env.CANDIDATE_RULES ?? path.resolve(__dirname, "../qa_candidates/firestore_candidate_v2.rules");

const COLONY_A = "rules76_colony_a";
const COLONY_B = "rules76_colony_b";
const COLONY_INACTIVE = "rules76_colony_inactive";

const USER_A = "rules76_user_a";
const USER_B = "rules76_user_b";
const USER_INACTIVE = "rules76_user_inactive";

const HOUSE_A = "rules76_household_a";
const HOUSE_B = "rules76_household_b";

let testEnv;

function authenticatedDb(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

async function assertPermissionDenied(operation) {
  try {
    await operation;
  } catch (error) {
    assert.equal(
      error.code,
      "permission-denied",
      `Expected permission-denied, received ${error.code}: ${error.message}`
    );
    return;
  }

  assert.fail("Expected Firestore to reject this operation.");
}

async function seedFixtures() {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();

    const fixtures = [
      // User profiles
      ["users/" + USER_A, { uid: USER_A, name: "Resident A" }],
      ["users/" + USER_B, { uid: USER_B, name: "Resident B" }],

      // Colony documents
      ["colonies/" + COLONY_A, { colonyId: COLONY_A, name: "Colony A" }],
      ["colonies/" + COLONY_B, { colonyId: COLONY_B, name: "Colony B" }],
      [
        "colonies/" + COLONY_INACTIVE,
        { colonyId: COLONY_INACTIVE, name: "Inactive Colony" },
      ],

      // Active memberships in Colony A
      [
        `colonies/${COLONY_A}/members/${USER_A}`,
        {
          uid: USER_A,
          userId: USER_A,
          residentId: "rules76_resident_a",
          colonyId: COLONY_A,
          role: "resident",
          status: "active",
        },
      ],
      [
        `colonies/${COLONY_A}/members/${USER_B}`,
        {
          uid: USER_B,
          userId: USER_B,
          residentId: "rules76_resident_b",
          colonyId: COLONY_A,
          role: "resident",
          status: "active",
        },
      ],

      // User B also belongs to Colony B
      [
        `colonies/${COLONY_B}/members/${USER_B}`,
        {
          uid: USER_B,
          userId: USER_B,
          residentId: "rules76_resident_b",
          colonyId: COLONY_B,
          role: "resident",
          status: "active",
        },
      ],

      // Inactive membership
      [
        `colonies/${COLONY_INACTIVE}/members/${USER_INACTIVE}`,
        {
          uid: USER_INACTIVE,
          userId: USER_INACTIVE,
          residentId: "rules76_resident_inactive",
          colonyId: COLONY_INACTIVE,
          role: "resident",
          status: "inactive",
        },
      ],

      // Resident records
      [
        `colonies/${COLONY_A}/residents/rules76_resident_a`,
        {
          uid: USER_A,
          userId: USER_A,
          residentId: "rules76_resident_a",
          colonyId: COLONY_A,
          householdId: HOUSE_A,
          residentStatus: "active",
        },
      ],
      [
        `colonies/${COLONY_A}/residents/rules76_resident_b`,
        {
          uid: USER_B,
          userId: USER_B,
          residentId: "rules76_resident_b",
          colonyId: COLONY_A,
          householdId: HOUSE_B,
          residentStatus: "active",
        },
      ],

      // Households
      [
        `colonies/${COLONY_A}/households/${HOUSE_A}`,
        {
          householdId: HOUSE_A,
          colonyId: COLONY_A,
          residentIds: ["rules76_resident_a"],
          status: "active",
        },
      ],
      [
        `colonies/${COLONY_A}/households/${HOUSE_B}`,
        {
          householdId: HOUSE_B,
          colonyId: COLONY_A,
          residentIds: ["rules76_resident_b"],
          status: "active",
        },
      ],

      // Announcements
      [
        `colonies/${COLONY_A}/announcements/rules76_announcement_published`,
        {
          announcementId: "rules76_announcement_published",
          colonyId: COLONY_A,
          status: "published",
          title: "Published announcement",
        },
      ],
      [
        `colonies/${COLONY_A}/announcements/rules76_announcement_draft`,
        {
          announcementId: "rules76_announcement_draft",
          colonyId: COLONY_A,
          status: "draft",
          title: "Draft announcement",
        },
      ],

      // Complaints: one per resident
      [
        `colonies/${COLONY_A}/complaints/rules76_complaint_a`,
        {
          complaintId: "rules76_complaint_a",
          colonyId: COLONY_A,
          submittedBy: USER_A,
          residentId: USER_A,
          status: "open",
        },
      ],
      [
        `colonies/${COLONY_A}/complaints/rules76_complaint_b`,
        {
          complaintId: "rules76_complaint_b",
          colonyId: COLONY_A,
          submittedBy: USER_B,
          residentId: USER_B,
          status: "open",
        },
      ],

      // Visitors: one hosted by each resident
      [
        `colonies/${COLONY_A}/visitors/rules76_visitor_a`,
        {
          visitorId: "rules76_visitor_a",
          colonyId: COLONY_A,
          hostUid: USER_A,
          hostId: USER_A,
          hostResidentId: "rules76_resident_a",
          householdId: HOUSE_A,
          status: "pre_registered",
        },
      ],
      [
        `colonies/${COLONY_A}/visitors/rules76_visitor_b`,
        {
          visitorId: "rules76_visitor_b",
          colonyId: COLONY_A,
          hostUid: USER_B,
          hostId: USER_B,
          hostResidentId: "rules76_resident_b",
          householdId: HOUSE_B,
          status: "pre_registered",
        },
      ],

      // Maintenance bills: one per household
      [
        `colonies/${COLONY_A}/maintenanceBills/rules76_bill_a`,
        {
          billId: "rules76_bill_a",
          colonyId: COLONY_A,
          householdId: HOUSE_A,
          amount: 1000,
          status: "issued",
        },
      ],
      [
        `colonies/${COLONY_A}/maintenanceBills/rules76_bill_b`,
        {
          billId: "rules76_bill_b",
          colonyId: COLONY_A,
          householdId: HOUSE_B,
          amount: 1500,
          status: "issued",
        },
      ],

      // Payments: one per resident
      [
        `colonies/${COLONY_A}/maintenancePayments/rules76_payment_a`,
        {
          paymentId: "rules76_payment_a",
          colonyId: COLONY_A,
          submittedBy: USER_A,
          userId: USER_A,
          householdId: HOUSE_A,
          amount: 1000,
          status: "pending",
        },
      ],
      [
        `colonies/${COLONY_A}/maintenancePayments/rules76_payment_b`,
        {
          paymentId: "rules76_payment_b",
          colonyId: COLONY_A,
          submittedBy: USER_B,
          userId: USER_B,
          householdId: HOUSE_B,
          amount: 1500,
          status: "pending",
        },
      ],

      // Housekeeping requests: one per resident
      [
        `colonies/${COLONY_A}/housekeepingRequests/rules76_housekeeping_a`,
        {
          requestId: "rules76_housekeeping_a",
          colonyId: COLONY_A,
          requestedBy: USER_A,
          userId: USER_A,
          residentId: USER_A,
          householdId: HOUSE_A,
          status: "open",
        },
      ],
      [
        `colonies/${COLONY_A}/housekeepingRequests/rules76_housekeeping_b`,
        {
          requestId: "rules76_housekeeping_b",
          colonyId: COLONY_A,
          requestedBy: USER_B,
          userId: USER_B,
          residentId: USER_B,
          householdId: HOUSE_B,
          status: "open",
        },
      ],
    ];

    await Promise.all(
      fixtures.map(([documentPath, data]) =>
        setDoc(doc(db, documentPath), data)
      )
    );
  });
}

before(async () => {
  const rules = fs.readFileSync(RULES_PATH, "utf8");

  testEnv = await initializeTestEnvironment({
    projectId: "mohallaflow",
    firestore: {
      host: "127.0.0.1",
      port: 8080,
      rules,
    },
  });

  await testEnv.clearFirestore();
  await seedFixtures();
});

after(async () => {
  if (testEnv) {
    await testEnv.cleanup();
  }
});

// ============================================================
// TESTS 76–81: USER PROFILE ISOLATION
// ============================================================

test("76 - User can read their own profile", async () => {
  const db = authenticatedDb(USER_A);

  const snapshot = await getDoc(doc(db, `users/${USER_A}`));

  assert.equal(snapshot.exists(), true);
});

test("77 - User cannot read another user's profile", async () => {
  const db = authenticatedDb(USER_A);

  await assertPermissionDenied(
    getDoc(doc(db, `users/${USER_B}`))
  );
});

test("78 - User cannot list all user profiles", async () => {
  const db = authenticatedDb(USER_A);

  await assertPermissionDenied(
    getDocs(collection(db, "users"))
  );
});

test("79 - User cannot create a profile directly", async () => {
  const db = authenticatedDb(USER_A);

  await assertPermissionDenied(
    setDoc(doc(db, "users/rules76_new_user"), {
      uid: "rules76_new_user",
      name: "Unauthorized Profile",
    })
  );
});

test("80 - User cannot update their own profile directly", async () => {
  const db = authenticatedDb(USER_A);

  await assertPermissionDenied(
    updateDoc(doc(db, `users/${USER_A}`), {
      name: "Modified Name",
    })
  );
});

test("81 - User cannot delete their own profile", async () => {
  const db = authenticatedDb(USER_A);

  await assertPermissionDenied(
    deleteDoc(doc(db, `users/${USER_A}`))
  );
});

// ============================================================
// TESTS 82–87: COLONY DOCUMENT ISOLATION
// ============================================================

test("82 - Active colony member can read their colony document", async () => {
  const db = authenticatedDb(USER_A);

  const snapshot = await getDoc(
    doc(db, `colonies/${COLONY_A}`)
  );

  assert.equal(snapshot.exists(), true);
});

test("83 - Member of one colony cannot read another colony document", async () => {
  const db = authenticatedDb(USER_A);

  await assertPermissionDenied(
    getDoc(doc(db, `colonies/${COLONY_B}`))
  );
});

test("84 - Inactive member cannot read their colony document", async () => {
  const db = authenticatedDb(USER_INACTIVE);

  await assertPermissionDenied(
    getDoc(doc(db, `colonies/${COLONY_INACTIVE}`))
  );
});

test("85 - User cannot list all colonies", async () => {
  const db = authenticatedDb(USER_A);

  await assertPermissionDenied(
    getDocs(collection(db, "colonies"))
  );
});

test("86 - User cannot create a colony directly", async () => {
  const db = authenticatedDb(USER_A);

  await assertPermissionDenied(
    setDoc(doc(db, "colonies/rules76_unauthorized_colony"), {
      colonyId: "rules76_unauthorized_colony",
      name: "Unauthorized Colony",
    })
  );
});

test("87 - User cannot update or delete a colony directly", async () => {
  const db = authenticatedDb(USER_A);

  await assertPermissionDenied(
    updateDoc(doc(db, `colonies/${COLONY_A}`), {
      name: "Unauthorized Colony Update",
    })
  );

  await assertPermissionDenied(
    deleteDoc(doc(db, `colonies/${COLONY_A}`))
  );
});

// ============================================================
// TESTS 88–89: ANNOUNCEMENT QUERY ISOLATION
// ============================================================

test("88 - Resident can query published announcements", async () => {
  const db = authenticatedDb(USER_A);

  const result = await getDocs(
    query(
      collection(db, `colonies/${COLONY_A}/announcements`),
      where("status", "==", "published")
    )
  );

  assert.equal(result.size, 1);
  assert.equal(result.docs[0].data().status, "published");
});

test("89 - Resident cannot query all announcements without a status filter", async () => {
  const db = authenticatedDb(USER_A);

  await assertPermissionDenied(
    getDocs(
      collection(db, `colonies/${COLONY_A}/announcements`)
    )
  );
});

// ============================================================
// TESTS 90–91: COMPLAINT QUERY ISOLATION
// ============================================================

test("90 - Resident can query their own complaints", async () => {
  const db = authenticatedDb(USER_A);

  const result = await getDocs(
    query(
      collection(db, `colonies/${COLONY_A}/complaints`),
      where("submittedBy", "==", USER_A)
    )
  );

  assert.equal(result.size, 1);
  assert.equal(result.docs[0].data().submittedBy, USER_A);
});

test("91 - Resident cannot query another resident's complaints", async () => {
  const db = authenticatedDb(USER_A);

  await assertPermissionDenied(
    getDocs(
      query(
        collection(db, `colonies/${COLONY_A}/complaints`),
        where("submittedBy", "==", USER_B)
      )
    )
  );
});

// ============================================================
// TESTS 92–93: VISITOR QUERY ISOLATION
// ============================================================

test("92 - Resident can query visitors hosted by them", async () => {
  const db = authenticatedDb(USER_A);

  const result = await getDocs(
    query(
      collection(db, `colonies/${COLONY_A}/visitors`),
      where("hostUid", "==", USER_A)
    )
  );

  assert.equal(result.size, 1);
  assert.equal(result.docs[0].data().hostUid, USER_A);
});

test("93 - Resident cannot query all visitors without a host filter", async () => {
  const db = authenticatedDb(USER_A);

  await assertPermissionDenied(
    getDocs(
      collection(db, `colonies/${COLONY_A}/visitors`)
    )
  );
});

// ============================================================
// TESTS 94–95: MAINTENANCE BILL HOUSEHOLD ISOLATION
// ============================================================

test("94 - Resident can query maintenance bills for their household", async () => {
  const db = authenticatedDb(USER_A);

  const result = await getDocs(
    query(
      collection(db, `colonies/${COLONY_A}/maintenanceBills`),
      where("householdId", "==", HOUSE_A)
    )
  );

  assert.equal(result.size, 1);
  assert.equal(result.docs[0].data().householdId, HOUSE_A);
});

test("95 - Resident cannot query another household's maintenance bills", async () => {
  const db = authenticatedDb(USER_A);

  await assertPermissionDenied(
    getDocs(
      query(
        collection(db, `colonies/${COLONY_A}/maintenanceBills`),
        where("householdId", "==", HOUSE_B)
      )
    )
  );
});

// ============================================================
// TESTS 96–97: PAYMENT QUERY ISOLATION
// ============================================================

test("96 - Resident can query their own payments", async () => {
  const db = authenticatedDb(USER_A);

  const result = await getDocs(
    query(
      collection(db, `colonies/${COLONY_A}/maintenancePayments`),
      where("submittedBy", "==", USER_A)
    )
  );

  assert.equal(result.size, 1);
  assert.equal(result.docs[0].data().submittedBy, USER_A);
});

test("97 - Resident cannot query another resident's payments", async () => {
  const db = authenticatedDb(USER_A);

  await assertPermissionDenied(
    getDocs(
      query(
        collection(db, `colonies/${COLONY_A}/maintenancePayments`),
        where("submittedBy", "==", USER_B)
      )
    )
  );
});

// ============================================================
// TESTS 98–99: HOUSEKEEPING REQUEST ISOLATION
// ============================================================

test("98 - Resident can query their own housekeeping requests", async () => {
  const db = authenticatedDb(USER_A);

  const result = await getDocs(
    query(
      collection(db, `colonies/${COLONY_A}/housekeepingRequests`),
      where("requestedBy", "==", USER_A)
    )
  );

  assert.equal(result.size, 1);
  assert.equal(result.docs[0].data().requestedBy, USER_A);
});

test("99 - Resident cannot query another resident's housekeeping requests", async () => {
  const db = authenticatedDb(USER_A);

  await assertPermissionDenied(
    getDocs(
      query(
        collection(db, `colonies/${COLONY_A}/housekeepingRequests`),
        where("requestedBy", "==", USER_B)
      )
    )
  );
});
