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
  serverTimestamp,
  Timestamp
} from "firebase/firestore";

// --------------------------------------------------
// PROJECT AND TEST IDENTITIES
// --------------------------------------------------

const PROJECT_ID = "mohallaflow";

const COLONY_A = "rules_write_test_colony_a";
const COLONY_B = "rules_write_test_colony_b";

const ADMIN_ID = "rules_write_test_admin";
const MANAGER_ID = "rules_write_test_manager";
const RESIDENT_ID = "rules_write_test_resident";
const WORKER_A_ID = "rules_write_test_worker_a";
const WORKER_B_ID = "rules_write_test_worker_b";

const RESIDENT_RECORD_ID = "rules_write_test_resident_record";
const HOUSEHOLD_ID = "rules_write_test_household";

const WORKER_A_PROFILE_ID = "rules_write_test_worker_profile_a";
const WORKER_B_PROFILE_ID = "rules_write_test_worker_profile_b";

const WORKER_A_NAME = "Rules Test Worker A";
const WORKER_B_NAME = "Rules Test Worker B";

const WORKER_A_PHONE = "9876543210";
const WORKER_B_PHONE = "9876543211";

const RESIDENT_NAME = "Rules Test Resident";

const FIXED_TIME = Timestamp.fromDate(
  new Date("2026-11-01T10:00:00.000Z")
);

let testEnv;

const rules = readFileSync(
  process.env.CANDIDATE_RULES ?? new URL("../qa_candidates/firestore_candidate_v2.rules", import.meta.url),
  "utf8"
);

// --------------------------------------------------
// PATH HELPERS
// --------------------------------------------------

function memberPath(colonyId, uid) {
  return `colonies/${colonyId}/members/${uid}`;
}

function residentPath(colonyId, residentId) {
  return `colonies/${colonyId}/residents/${residentId}`;
}

function workerPath(colonyId, workerId) {
  return `colonies/${colonyId}/cleanlinessWorkers/${workerId}`;
}

function workerPrivatePath(colonyId, workerId) {
  return `colonies/${colonyId}/workerPrivateProfiles/${workerId}`;
}

function complaintPath(colonyId, id) {
  return `colonies/${colonyId}/complaints/${id}`;
}

function taskPath(colonyId, id) {
  return `colonies/${colonyId}/cleanlinessTasks/${id}`;
}

function requestPath(colonyId, id) {
  return `colonies/${colonyId}/housekeepingRequests/${id}`;
}

function authenticatedDb(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

function ref(db, path) {
  return doc(db, path);
}

// --------------------------------------------------
// STRICT DENIAL ASSERTION
// --------------------------------------------------

async function assertPermissionDenied(operation) {
  let caught = null;

  try {
    await operation;
  } catch (error) {
    caught = error;
  }

  assert.ok(
    caught,
    "Expected Firestore to deny this operation, but it succeeded."
  );

  assert.equal(
    caught.code,
    "permission-denied",
    `Expected permission-denied, received ${caught.code ?? caught.name}: ${caught.message}`
  );
}

// --------------------------------------------------
// VALID COMPLAINT PAYLOAD
// --------------------------------------------------

function validComplaint(submittedBy) {
  return {
    title: "Garbage collection missed",
    description: "Garbage was not collected from our block today.",
    category: "Garbage collection",
    complaintType: "cleanliness",
    location: "Block A",
    reportedByName: RESIDENT_NAME,
    reportedByPhone: WORKER_A_PHONE,
    submittedBy,
    submittedByName: RESIDENT_NAME,
    priority: "normal",
    status: "submitted",
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp()
  };
}

// --------------------------------------------------
// VALID CLEANLINESS WORKER PAYLOAD
// --------------------------------------------------

function validNewWorker(createdBy, id = "new_worker_profile") {
  return {
    fullName: "New Rules Test Worker",
    phoneNumber: "9876543212",
    assignedArea: "South Block",
    status: "active",
    createdBy,
    createdByName: "Rules Test Creator",
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp()
  };
}

// --------------------------------------------------
// VALID CLEANLINESS TASK PAYLOAD
// --------------------------------------------------

function validNewTask() {
  return {
    title: "Clean North Block",
    location: "North Block common area",
    description: "Clean the common area near the north block entrance.",
    priority: "normal",
    status: "assigned",
    assignedWorkerId: WORKER_A_PROFILE_ID,
    assignedWorkerName: WORKER_A_NAME,
    assignedWorkerPhone: WORKER_A_PHONE,
    createdBy: ADMIN_ID,
    createdByName: "Rules Test Admin",
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    completedAt: null
  };
}

// --------------------------------------------------
// TASK FIXTURE
// --------------------------------------------------

function taskFixture(workerId, status) {
  const isWorkerA = workerId === WORKER_A_PROFILE_ID;

  return {
    title: "Test cleaning task",
    location: "Block A",
    description: "Complete the assigned cleaning work.",
    priority: "normal",
    status,
    assignedWorkerId: workerId,
    assignedWorkerName: isWorkerA ? WORKER_A_NAME : WORKER_B_NAME,
    assignedWorkerPhone: isWorkerA ? WORKER_A_PHONE : WORKER_B_PHONE,
    createdBy: ADMIN_ID,
    createdByName: "Rules Test Admin",
    createdAt: FIXED_TIME,
    updatedAt: FIXED_TIME,
    completedAt: null
  };
}

// --------------------------------------------------
// HOUSEKEEPING REQUEST FIXTURE
// --------------------------------------------------

function housekeepingFixture(status = "submitted", workerId = null) {
  const isWorkerA = workerId === WORKER_A_PROFILE_ID;
  const isWorkerB = workerId === WORKER_B_PROFILE_ID;

  return {
    title: "Home cleaning",
    serviceType: "Home cleaning",
    description: "Please clean the kitchen and living room.",
    preferredDate: Timestamp.fromDate(
      new Date("2026-12-01T10:00:00.000Z")
    ),
    preferredTime: "Morning (8 AM – 12 PM)",
    status,

    requestedBy: RESIDENT_ID,
    requestedByName: RESIDENT_NAME,

    residentId: RESIDENT_RECORD_ID,
    residentName: RESIDENT_NAME,

    householdId: HOUSEHOLD_ID,
    blockId: "Block A",
    houseNumber: "A-101",
    location: "Block A, A-101",

    assignedWorkerId: workerId,
    assignedWorkerName: isWorkerA
      ? WORKER_A_NAME
      : isWorkerB
        ? WORKER_B_NAME
        : null,

    assignedWorkerPhone: isWorkerA
      ? WORKER_A_PHONE
      : isWorkerB
        ? WORKER_B_PHONE
        : null,

    assignedBy: workerId ? ADMIN_ID : null,
    assignedAt: workerId ? FIXED_TIME : null,
    completedAt: null,

    createdAt: FIXED_TIME,
    updatedAt: FIXED_TIME
  };
}

// --------------------------------------------------
// INITIALIZE AND SEED EMULATOR-ONLY DATA
// --------------------------------------------------

before(async () => {
  console.log("\nConnecting to Firestore Emulator for write tests...");

  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      host: "127.0.0.1",
      port: 8080,
      rules
    }
  });

  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();

    // Membership documents.
    const members = [
      {
        path: memberPath(COLONY_A, ADMIN_ID),
        data: {
          uid: ADMIN_ID,
          colonyId: COLONY_A,
          role: "admin",
          status: "active"
        }
      },
      {
        path: memberPath(COLONY_A, MANAGER_ID),
        data: {
          uid: MANAGER_ID,
          colonyId: COLONY_A,
          role: "cleanliness_manager",
          status: "active"
        }
      },
      {
        path: memberPath(COLONY_A, RESIDENT_ID),
        data: {
          uid: RESIDENT_ID,
          colonyId: COLONY_A,
          role: "resident",
          status: "active",
          residentId: RESIDENT_RECORD_ID
        }
      },
      {
        path: memberPath(COLONY_A, WORKER_A_ID),
        data: {
          uid: WORKER_A_ID,
          colonyId: COLONY_A,
          role: "worker",
          status: "active",
          workerId: WORKER_A_PROFILE_ID
        }
      },
      {
        path: memberPath(COLONY_A, WORKER_B_ID),
        data: {
          uid: WORKER_B_ID,
          colonyId: COLONY_A,
          role: "worker",
          status: "active",
          workerId: WORKER_B_PROFILE_ID
        }
      }
    ];

    for (const item of members) {
      await setDoc(ref(db, item.path), item.data);
    }

    // Resident document used by housekeeping request validation.
    await setDoc(
      ref(db, residentPath(COLONY_A, RESIDENT_RECORD_ID)),
      {
        residentStatus: "active",
        householdId: HOUSEHOLD_ID,
        fullName: RESIDENT_NAME,
        blockId: "Block A",
        houseNumber: "A-101"
      }
    );

    // Active worker profiles.
    await setDoc(
      ref(db, workerPath(COLONY_A, WORKER_A_PROFILE_ID)),
      {
        fullName: WORKER_A_NAME,
        phoneNumber: WORKER_A_PHONE,
        assignedArea: "North Block",
        status: "active",
        createdBy: ADMIN_ID,
        createdByName: "Rules Test Admin",
        createdAt: FIXED_TIME,
        updatedAt: FIXED_TIME
      }
    );

    await setDoc(
      ref(db, workerPath(COLONY_A, WORKER_B_PROFILE_ID)),
      {
        fullName: WORKER_B_NAME,
        phoneNumber: WORKER_B_PHONE,
        assignedArea: "South Block",
        status: "active",
        createdBy: ADMIN_ID,
        createdByName: "Rules Test Admin",
        createdAt: FIXED_TIME,
        updatedAt: FIXED_TIME
      }
    );

    await setDoc(
      ref(db, workerPrivatePath(COLONY_A, WORKER_A_PROFILE_ID)),
      {
        bloodGroup: "O+",
        familyMemberName: "Worker A Emergency Contact",
        familyMemberPhone: "9876500001",
        consentStatus: "granted",
        consentAt: FIXED_TIME,
        privacyNoticeVersion: "worker-private-v1",
        updatedAt: FIXED_TIME
      }
    );
    await setDoc(
      ref(db, workerPrivatePath(COLONY_A, WORKER_B_PROFILE_ID)),
      {
        bloodGroup: "A+",
        familyMemberName: "Worker B Emergency Contact",
        familyMemberPhone: "9876500002",
        consentStatus: "pending",
        consentAt: null,
        privacyNoticeVersion: "worker-private-v1",
        updatedAt: FIXED_TIME
      }
    );
    await setDoc(
      ref(db, workerPrivatePath(COLONY_B, WORKER_A_PROFILE_ID)),
      {
        bloodGroup: "AB+",
        familyMemberName: "Colony B Emergency Contact",
        familyMemberPhone: "9876500004",
        consentStatus: "granted",
        consentAt: FIXED_TIME,
        privacyNoticeVersion: "worker-private-v1",
        updatedAt: FIXED_TIME
      }
    );

    // Complaint records for update authorization tests.
    await setDoc(
      ref(db, complaintPath(COLONY_A, "write_test_cleanliness_complaint")),
      {
        complaintType: "cleanliness",
        status: "submitted",
        updatedAt: FIXED_TIME
      }
    );

    await setDoc(
      ref(db, complaintPath(COLONY_A, "write_test_maintenance_complaint")),
      {
        complaintType: "maintenance",
        status: "submitted",
        updatedAt: FIXED_TIME
      }
    );

    // Assigned tasks for worker transition tests.
    await setDoc(
      ref(db, taskPath(COLONY_A, "write_test_task_start")),
      taskFixture(WORKER_A_PROFILE_ID, "assigned")
    );

    await setDoc(
      ref(db, taskPath(COLONY_A, "write_test_task_complete")),
      taskFixture(WORKER_A_PROFILE_ID, "in_progress")
    );

    await setDoc(
      ref(db, taskPath(COLONY_A, "write_test_task_other_worker")),
      taskFixture(WORKER_B_PROFILE_ID, "assigned")
    );

    // Housekeeping request fixtures.
    const requests = [
      ["write_test_request_cancel", housekeepingFixture("submitted")],
      ["write_test_request_cancel_assigned", housekeepingFixture("assigned", WORKER_A_PROFILE_ID)],
      ["write_test_request_admin_assign", housekeepingFixture("submitted")],
      ["write_test_request_worker_start", housekeepingFixture("assigned", WORKER_A_PROFILE_ID)],
      ["write_test_request_worker_complete", housekeepingFixture("in_progress", WORKER_A_PROFILE_ID)],
      ["write_test_request_other_worker", housekeepingFixture("assigned", WORKER_B_PROFILE_ID)]
    ];

    for (const [id, data] of requests) {
      await setDoc(
        ref(db, requestPath(COLONY_A, id)),
        data
      );
    }
  });

  console.log("Write-test fixtures prepared in the local emulator.");
});

// --------------------------------------------------
// CLEANUP
// --------------------------------------------------

after(async () => {
  if (testEnv) {
    try {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();

        const paths = [
          memberPath(COLONY_A, ADMIN_ID),
          memberPath(COLONY_A, MANAGER_ID),
          memberPath(COLONY_A, RESIDENT_ID),
          memberPath(COLONY_A, WORKER_A_ID),
          memberPath(COLONY_A, WORKER_B_ID),
          residentPath(COLONY_A, RESIDENT_RECORD_ID),
          workerPath(COLONY_A, WORKER_A_PROFILE_ID),
          workerPath(COLONY_A, WORKER_B_PROFILE_ID),
          workerPrivatePath(COLONY_A, WORKER_A_PROFILE_ID),
          workerPrivatePath(COLONY_A, WORKER_B_PROFILE_ID),
          workerPrivatePath(COLONY_B, WORKER_A_PROFILE_ID),

          complaintPath(COLONY_A, "write_test_cleanliness_complaint"),
          complaintPath(COLONY_A, "write_test_maintenance_complaint"),
          complaintPath(COLONY_A, "write_test_complaint_create"),
          complaintPath(COLONY_A, "write_test_complaint_spoof"),
          complaintPath(COLONY_B, "write_test_complaint_cross_colony"),

          workerPath(COLONY_A, "write_test_new_worker"),
          workerPath(COLONY_A, "write_test_resident_worker"),
          workerPath(COLONY_A, "write_test_worker_update"),

          taskPath(COLONY_A, "write_test_task_start"),
          taskPath(COLONY_A, "write_test_task_complete"),
          taskPath(COLONY_A, "write_test_task_other_worker"),
          taskPath(COLONY_A, "write_test_task_create"),
          taskPath(COLONY_A, "write_test_task_resident_create"),

          requestPath(COLONY_A, "write_test_request_cancel"),
          requestPath(COLONY_A, "write_test_request_cancel_assigned"),
          requestPath(COLONY_A, "write_test_request_admin_assign"),
          requestPath(COLONY_A, "write_test_request_worker_start"),
          requestPath(COLONY_A, "write_test_request_worker_complete"),
          requestPath(COLONY_A, "write_test_request_other_worker"),
          requestPath(COLONY_A, "write_test_request_create"),
          requestPath(COLONY_A, "write_test_request_forged_resident"),
          requestPath(COLONY_A, "write_test_request_delete"),
          requestPath(COLONY_B, "write_test_request_cross_colony")
        ];

        for (const path of paths) {
          await deleteDoc(ref(db, path));
        }
      });
    } finally {
      await testEnv.cleanup();
    }
  }

  console.log("Write-test fixtures cleaned up.");
});

// ==================================================
// COMPLAINT TESTS
// ==================================================

// 13 — Resident creates a valid complaint in own colony.

test("13 — Resident can create a valid complaint", async () => {
  const db = authenticatedDb(RESIDENT_ID);

  await assertSucceeds(
    setDoc(
      ref(db, complaintPath(COLONY_A, "write_test_complaint_create")),
      validComplaint(RESIDENT_ID)
    )
  );
});

// 14 — Resident cannot submit a complaint as another user.

test("14 — Resident cannot forge complaint submitter identity", async () => {
  const db = authenticatedDb(RESIDENT_ID);

  await assertPermissionDenied(
    setDoc(
      ref(db, complaintPath(COLONY_A, "write_test_complaint_spoof")),
      validComplaint(ADMIN_ID)
    )
  );
});

// 15 — Resident cannot create a complaint in another colony.

test("15 — Resident cannot create complaint in another colony", async () => {
  const db = authenticatedDb(RESIDENT_ID);

  await assertPermissionDenied(
    setDoc(
      ref(db, complaintPath(COLONY_B, "write_test_complaint_cross_colony")),
      validComplaint(RESIDENT_ID)
    )
  );
});

// 16 — Resident cannot update complaint status.

test("16 — Resident cannot change complaint status", async () => {
  const db = authenticatedDb(RESIDENT_ID);

  await assertPermissionDenied(
    updateDoc(
      ref(db, complaintPath(COLONY_A, "write_test_cleanliness_complaint")),
      {
        status: "acknowledged",
        updatedAt: serverTimestamp()
      }
    )
  );
});

// 17 — Cleanliness Manager can update cleanliness complaint.

test("17 — Cleanliness Manager can update cleanliness complaint status", async () => {
  const db = authenticatedDb(MANAGER_ID);

  await assertSucceeds(
    updateDoc(
      ref(db, complaintPath(COLONY_A, "write_test_cleanliness_complaint")),
      {
        status: "acknowledged",
        updatedAt: serverTimestamp()
      }
    )
  );
});

// 18 — Cleanliness Manager cannot update maintenance complaint.

test("18 — Cleanliness Manager cannot update maintenance complaint", async () => {
  const db = authenticatedDb(MANAGER_ID);

  await assertPermissionDenied(
    updateDoc(
      ref(db, complaintPath(COLONY_A, "write_test_maintenance_complaint")),
      {
        status: "acknowledged",
        updatedAt: serverTimestamp()
      }
    )
  );
});

// 19 — Complaint deletion is denied, including for Admin.

test("19 — Admin cannot delete complaint", async () => {
  const db = authenticatedDb(ADMIN_ID);

  await assertPermissionDenied(
    deleteDoc(
      ref(db, complaintPath(COLONY_A, "write_test_cleanliness_complaint"))
    )
  );
});

// ==================================================
// CLEANLINESS WORKER TESTS
// ==================================================

// Worker medical and family emergency information is not visible to managers.

test("20A — Cleanliness Manager cannot read worker private profile", async () => {
  const db = authenticatedDb(MANAGER_ID);
  await assertPermissionDenied(
    getDoc(ref(db, workerPrivatePath(COLONY_A, WORKER_A_PROFILE_ID)))
  );
});

test("20A2 — Manager operational worker record contains no private fields", async () => {
  const db = authenticatedDb(MANAGER_ID);
  const snapshot = await getDoc(ref(db, workerPath(COLONY_A, WORKER_A_PROFILE_ID)));
  assert.equal(snapshot.exists(), true);
  assert.equal(Object.hasOwn(snapshot.data(), "bloodGroup"), false);
  assert.equal(Object.hasOwn(snapshot.data(), "familyMemberName"), false);
  assert.equal(Object.hasOwn(snapshot.data(), "familyMemberPhone"), false);
});

test("20B — Worker can read only their own private profile", async () => {
  const db = authenticatedDb(WORKER_A_ID);
  const own = await getDoc(ref(db, workerPrivatePath(COLONY_A, WORKER_A_PROFILE_ID)));
  assert.equal(own.data().bloodGroup, "O+");
  await assertPermissionDenied(
    getDoc(ref(db, workerPrivatePath(COLONY_A, WORKER_B_PROFILE_ID)))
  );
});

test("20C — Admin can read worker private profile", async () => {
  const db = authenticatedDb(ADMIN_ID);
  const privateProfile = await getDoc(ref(db, workerPrivatePath(COLONY_A, WORKER_A_PROFILE_ID)));
  assert.equal(privateProfile.data().familyMemberName, "Worker A Emergency Contact");
});

test("20C2 — Admin cannot read private details before worker consent", async () => {
  const db = authenticatedDb(ADMIN_ID);
  await assertPermissionDenied(
    getDoc(ref(db, workerPrivatePath(COLONY_A, WORKER_B_PROFILE_ID)))
  );
});

test("20B2 — Worker cannot read private details from another colony", async () => {
  const db = authenticatedDb(WORKER_A_ID);
  await assertPermissionDenied(
    getDoc(ref(db, workerPrivatePath(COLONY_B, WORKER_A_PROFILE_ID)))
  );
});

test("20D — Worker can update only their own private profile", async () => {
  const db = authenticatedDb(WORKER_A_ID);
  await assertSucceeds(
    updateDoc(ref(db, workerPrivatePath(COLONY_A, WORKER_A_PROFILE_ID)), {
      bloodGroup: "B+",
      updatedAt: serverTimestamp()
    })
  );
  await assertPermissionDenied(
    updateDoc(ref(db, workerPrivatePath(COLONY_A, WORKER_B_PROFILE_ID)), {
      bloodGroup: "B+",
      updatedAt: serverTimestamp()
    })
  );
});

test("20E — Cleanliness Manager cannot create private worker details", async () => {
  const db = authenticatedDb(MANAGER_ID);
  await assertPermissionDenied(
    setDoc(ref(db, workerPrivatePath(COLONY_A, "manager_forged_private")), {
      bloodGroup: "O+",
      familyMemberName: "Forged Contact",
      familyMemberPhone: "9876500003",
      updatedAt: serverTimestamp()
    })
  );
});

// 20 — Cleanliness Manager can create a worker without private medical data.

test("20 — Cleanliness Manager can create cleanliness worker", async () => {
  const db = authenticatedDb(MANAGER_ID);

  const data = validNewWorker(MANAGER_ID);

  await assertSucceeds(
    setDoc(
      ref(db, workerPath(COLONY_A, "write_test_new_worker")),
      data
    )
  );
});

// 21 — Resident cannot create a worker.

test("21 — Resident cannot create cleanliness worker", async () => {
  const db = authenticatedDb(RESIDENT_ID);

  await assertPermissionDenied(
    setDoc(
      ref(db, workerPath(COLONY_A, "write_test_resident_worker")),
      validNewWorker(RESIDENT_ID)
    )
  );
});

// 22 — Worker cannot modify worker records.

test("22 — Worker cannot update cleanliness worker profile", async () => {
  const db = authenticatedDb(WORKER_A_ID);

  await assertPermissionDenied(
    updateDoc(
      ref(db, workerPath(COLONY_A, WORKER_A_PROFILE_ID)),
      {
        assignedArea: "Unauthorized Area"
      }
    )
  );
});

// ==================================================
// CLEANLINESS TASK TESTS
// ==================================================

// 23 — Admin creates a valid task assigned to active worker.

test("23 — Admin can create valid cleanliness task", async () => {
  const db = authenticatedDb(ADMIN_ID);

  await assertSucceeds(
    setDoc(
      ref(db, taskPath(COLONY_A, "write_test_task_create")),
      validNewTask()
    )
  );
});

// 24 — Resident cannot create a task.

test("24 — Resident cannot create cleanliness task", async () => {
  const db = authenticatedDb(RESIDENT_ID);

  await assertPermissionDenied(
    setDoc(
      ref(db, taskPath(COLONY_A, "write_test_task_resident_create")),
      validNewTask()
    )
  );
});

// 25 — Assigned worker can read own task.

test("25 — Assigned worker can read own cleanliness task", async () => {
  const db = authenticatedDb(WORKER_A_ID);

  const result = await assertSucceeds(
    getDoc(
      ref(db, taskPath(COLONY_A, "write_test_task_start"))
    )
  );

  assert.equal(result.exists(), true);
});

// 26 — Assigned worker can start task.

test("26 — Assigned worker can move task to in_progress", async () => {
  const db = authenticatedDb(WORKER_A_ID);

  await assertSucceeds(
    updateDoc(
      ref(db, taskPath(COLONY_A, "write_test_task_start")),
      {
        status: "in_progress",
        updatedAt: serverTimestamp(),
        completedAt: null
      }
    )
  );
});

// 27 — Assigned worker can complete task.

test("27 — Assigned worker can complete own task", async () => {
  const db = authenticatedDb(WORKER_A_ID);

  await assertSucceeds(
    updateDoc(
      ref(db, taskPath(COLONY_A, "write_test_task_complete")),
      {
        status: "completed",
        updatedAt: serverTimestamp(),
        completedAt: serverTimestamp()
      }
    )
  );
});

// 28 — Worker cannot access or update another worker's task.

test("28 — Worker cannot access another worker's task", async () => {
  const db = authenticatedDb(WORKER_A_ID);

  await assertPermissionDenied(
    getDoc(
      ref(db, taskPath(COLONY_A, "write_test_task_other_worker"))
    )
  );

  await assertPermissionDenied(
    updateDoc(
      ref(db, taskPath(COLONY_A, "write_test_task_other_worker")),
      {
        status: "in_progress",
        updatedAt: serverTimestamp(),
        completedAt: null
      }
    )
  );
});

// ==================================================
// HOUSEKEEPING REQUEST TESTS
// ==================================================

function validHousekeepingRequest() {
  return {
    title: "Home cleaning",
    serviceType: "Home cleaning",
    description: "Please clean the kitchen and living room.",

    preferredDate: Timestamp.fromDate(
      new Date("2026-12-01T10:00:00.000Z")
    ),

    preferredTime: "Morning (8 AM – 12 PM)",
    status: "submitted",

    requestedBy: RESIDENT_ID,
    requestedByName: RESIDENT_NAME,

    residentId: RESIDENT_RECORD_ID,
    residentName: RESIDENT_NAME,

    householdId: HOUSEHOLD_ID,
    blockId: "Block A",
    houseNumber: "A-101",
    location: "Block A, A-101",

    assignedWorkerId: null,
    assignedWorkerName: null,
    assignedWorkerPhone: null,
    assignedBy: null,
    assignedAt: null,
    completedAt: null,

    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp()
  };
}

// 29 — Resident can create own housekeeping request.

test("29 — Resident can create own housekeeping request", async () => {
  const db = authenticatedDb(RESIDENT_ID);

  await assertSucceeds(
    setDoc(
      ref(db, requestPath(COLONY_A, "write_test_request_create")),
      validHousekeepingRequest()
    )
  );
});

// 30 — Resident cannot forge another resident record.

test("30 — Resident cannot create request using another resident ID", async () => {
  const db = authenticatedDb(RESIDENT_ID);

  const payload = validHousekeepingRequest();
  payload.residentId = "another_resident_record";

  await assertPermissionDenied(
    setDoc(
      ref(db, requestPath(COLONY_A, "write_test_request_forged_resident")),
      payload
    )
  );
});

// 31 — Resident cannot create request in another colony.

test("31 — Resident cannot create housekeeping request in another colony", async () => {
  const db = authenticatedDb(RESIDENT_ID);

  await assertPermissionDenied(
    setDoc(
      ref(db, requestPath(COLONY_B, "write_test_request_cross_colony")),
      validHousekeepingRequest()
    )
  );
});

// 32 — Resident can cancel own unassigned request.

test("32 — Resident can cancel own submitted request", async () => {
  const db = authenticatedDb(RESIDENT_ID);

  await assertSucceeds(
    updateDoc(
      ref(db, requestPath(COLONY_A, "write_test_request_cancel")),
      {
        status: "cancelled",
        updatedAt: serverTimestamp()
      }
    )
  );
});

// 33 — Resident cannot cancel after assignment.

test("33 — Resident cannot cancel already assigned request", async () => {
  const db = authenticatedDb(RESIDENT_ID);

  await assertPermissionDenied(
    updateDoc(
      ref(db, requestPath(COLONY_A, "write_test_request_cancel_assigned")),
      {
        status: "cancelled",
        updatedAt: serverTimestamp()
      }
    )
  );
});

// 34 — Admin can assign an active worker.

test("34 — Admin can assign active worker to housekeeping request", async () => {
  const db = authenticatedDb(ADMIN_ID);

  await assertSucceeds(
    updateDoc(
      ref(db, requestPath(COLONY_A, "write_test_request_admin_assign")),
      {
        assignedWorkerId: WORKER_A_PROFILE_ID,
        assignedWorkerName: WORKER_A_NAME,
        assignedWorkerPhone: WORKER_A_PHONE,
        assignedBy: ADMIN_ID,
        assignedAt: serverTimestamp(),
        status: "assigned",
        updatedAt: serverTimestamp()
      }
    )
  );
});

// 35 — Assigned worker can read the request.

test("35 — Assigned worker can read assigned housekeeping request", async () => {
  const db = authenticatedDb(WORKER_A_ID);

  const result = await assertSucceeds(
    getDoc(
      ref(db, requestPath(COLONY_A, "write_test_request_worker_start"))
    )
  );

  assert.equal(result.exists(), true);
});

// 36 — Assigned worker can start the request.

test("36 — Assigned worker can start housekeeping request", async () => {
  const db = authenticatedDb(WORKER_A_ID);

  await assertSucceeds(
    updateDoc(
      ref(db, requestPath(COLONY_A, "write_test_request_worker_start")),
      {
        status: "in_progress",
        updatedAt: serverTimestamp(),
        completedAt: null
      }
    )
  );
});

// 37 — Assigned worker can complete the request.

test("37 — Assigned worker can complete housekeeping request", async () => {
  const db = authenticatedDb(WORKER_A_ID);

  await assertSucceeds(
    updateDoc(
      ref(db, requestPath(COLONY_A, "write_test_request_worker_complete")),
      {
        status: "completed",
        updatedAt: serverTimestamp(),
        completedAt: serverTimestamp()
      }
    )
  );
});

// 38 — Worker cannot read or update another worker's request.

test("38 — Worker cannot access another worker's housekeeping request", async () => {
  const db = authenticatedDb(WORKER_A_ID);

  await assertPermissionDenied(
    getDoc(
      ref(db, requestPath(COLONY_A, "write_test_request_other_worker"))
    )
  );

  await assertPermissionDenied(
    updateDoc(
      ref(db, requestPath(COLONY_A, "write_test_request_other_worker")),
      {
        status: "in_progress",
        updatedAt: serverTimestamp(),
        completedAt: null
      }
    )
  );
});

// 39 — Admin cannot delete a housekeeping request.

test("39 — Admin cannot delete housekeeping request", async () => {
  const db = authenticatedDb(ADMIN_ID);

  await assertPermissionDenied(
    deleteDoc(
      ref(db, requestPath(COLONY_A, "write_test_request_delete"))
    )
  );
});

// 40 — Admin cannot delete a cleanliness task.

test("40 — Admin cannot delete cleanliness task", async () => {
  const db = authenticatedDb(ADMIN_ID);

  await assertPermissionDenied(
    deleteDoc(
      ref(db, taskPath(COLONY_A, "write_test_task_start"))
    )
  );
});
