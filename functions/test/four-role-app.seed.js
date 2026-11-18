'use strict';

const { initializeApp, deleteApp } = require('firebase-admin/app');
const { Timestamp, getFirestore } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');

const PROJECT_ID = 'demo-mohallaflow';
const COLONY_ID = 'four_role_application_integration';
const COLONY_NAME = 'Greenview Residency';
const PASSWORD = 'MohallaFlow-Integration-2026!';

const ACCOUNTS = [
  {
    key: 'admin',
    email: 'mf-four-role-admin@example.test',
    name: 'Colony Admin',
    role: 'admin',
  },
  {
    key: 'resident',
    email: 'mf-four-role-resident@example.test',
    name: 'Aarav Mehta',
    role: 'resident',
    residentId: 'resident-four-role',
    householdId: 'household-four-role',
  },
  {
    key: 'manager',
    email: 'mf-four-role-manager@example.test',
    name: 'Priya Sharma',
    role: 'cleanliness_manager',
  },
  {
    key: 'worker',
    email: 'mf-four-role-worker@example.test',
    name: 'Ravi Kumar',
    role: 'worker',
    workerId: 'worker-four-role',
  },
];

if (!process.env.FIRESTORE_EMULATOR_HOST ||
    !process.env.FIREBASE_AUTH_EMULATOR_HOST) {
  throw new Error(
    'Firestore and Auth Emulator environment variables are required.',
  );
}

const app = initializeApp(
  { projectId: PROJECT_ID },
  `four-role-app-seed-${process.pid}`,
);

const db = getFirestore(app);
const auth = getAuth(app);
const colonyRef = db.collection('colonies').doc(COLONY_ID);

async function findUser(email) {
  try {
    return await auth.getUserByEmail(email);
  } catch (error) {
    if (error.code === 'auth/user-not-found') return null;
    throw error;
  }
}


async function withFirestoreRetry(label, operation) {
  const retryableCodes = new Set([1, 4, 8, 10, 13, 14]);

  for (let attempt = 1; attempt <= 3; attempt++) {
    try {
      return await operation();
    } catch (error) {
      const rawCode = error && error.code;
      const code = Number.isInteger(rawCode)
        ? rawCode
        : Number.parseInt(
            String(rawCode ?? '').match(/^\d+/)?.[0] || '',
            10,
          );

      if (!retryableCodes.has(code) || attempt === 3) {
        throw error;
      }

      console.warn(
        `[RETRY] ${label}: attempt ${attempt}/3 failed; retrying.`,
      );

      await new Promise((resolve) =>
        setTimeout(resolve, attempt * 200),
      );
    }
  }
}

async function deleteDocumentTree(documentRef) {
  const subcollections = await withFirestoreRetry(
    `List subcollections: ${documentRef.path}`,
    () => documentRef.listCollections(),
  );

  for (const subcollection of subcollections) {
    const childDocuments = await withFirestoreRetry(
      `List documents: ${subcollection.path}`,
      () => subcollection.listDocuments(),
    );

    // Sequential traversal avoids concurrent BulkWriter deletion.
    for (const childDocument of childDocuments) {
      await deleteDocumentTree(childDocument);
    }
  }

  await withFirestoreRetry(
    `Delete document: ${documentRef.path}`,
    () => documentRef.delete(),
  );
}

async function deleteAccountFixture(account, failures) {
  let user;

  try {
    user = await findUser(account.email);
  } catch (error) {
    failures.push(
      `Auth lookup ${account.email}: ${error.stack || error}`,
    );
    return;
  }

  if (!user) return;

  try {
    await deleteDocumentTree(
      db.collection('users').doc(user.uid),
    );
  } catch (error) {
    failures.push(
      `User Firestore document ${account.email}: ${error.stack || error}`,
    );
  }

  // Attempt Auth deletion even if Firestore cleanup failed.
  try {
    await auth.deleteUser(user.uid);
  } catch (error) {
    if (error.code !== 'auth/user-not-found') {
      failures.push(
        `Auth deletion ${account.email}: ${error.stack || error}`,
      );
    }
  }
}

async function resetFixture() {
  const failures = [];

  try {
    await deleteDocumentTree(colonyRef);
  } catch (error) {
    failures.push(
      `Colony fixture ${colonyRef.path}: ${error.stack || error}`,
    );
  }

  // Continue through all four accounts, even if one cleanup fails.
  for (const account of ACCOUNTS) {
    await deleteAccountFixture(account, failures);
  }

  if (failures.length > 0) {
    throw new Error(
      `Fixture cleanup failed (${failures.length} issue(s)):\n` +
      failures.join('\n\n'),
    );
  }
}

async function seed() {
  await resetFixture();

  const now = Timestamp.now();
  const users = {};

  await colonyRef.set({
    colonyId: COLONY_ID,
    colonyName: COLONY_NAME,
    name: COLONY_NAME,
    status: 'active',
    createdAt: now,
    updatedAt: now,
  });

  for (const account of ACCOUNTS) {
    const user = await auth.createUser({
      email: account.email,
      password: PASSWORD,
      displayName: account.name,
      emailVerified: true,
      disabled: false,
    });

    users[account.key] = user;

    await db.collection('users').doc(user.uid).set({
      displayName: account.name,
      email: account.email,
      phoneNumber: '',
      status: 'active',
      colonyIds: [COLONY_ID],
      createdAt: now,
      updatedAt: now,
    });

    const membership = {
      uid: user.uid,
      colonyId: COLONY_ID,
      colonyName: COLONY_NAME,
      role: account.role,
      status: 'active',
      fullName: account.name,
      createdAt: now,
      updatedAt: now,
    };

    if (account.residentId) {
      membership.residentId = account.residentId;
      membership.householdId = account.householdId;
      membership.blockId = 'A';
    }

    if (account.workerId) {
      membership.workerId = account.workerId;
    }

    await colonyRef.collection('members').doc(user.uid).set(membership);
  }

  const resident = users.resident;
  const admin = users.admin;
  const manager = users.manager;
  const worker = users.worker;

  await colonyRef.collection('households')
    .doc('household-four-role')
    .set({
      blockId: 'A',
      houseNumber: 'A-101',
      householdHeadName: ACCOUNTS[1].name,
      primaryPhone: '0000000000',
      occupancyStatus: 'occupied',
      createdAt: now,
      updatedAt: now,
      createdBy: admin.uid,
    });

  await colonyRef.collection('residents')
    .doc('resident-four-role')
    .set({
      residentId: 'resident-four-role',
      uid: resident.uid,
      userId: resident.uid,
      fullName: ACCOUNTS[1].name,
      name: ACCOUNTS[1].name,
      residentStatus: 'active',
      status: 'active',
      householdId: 'household-four-role',
      blockId: 'A',
      houseNumber: 'A-101',
      phoneNumber: '0000000000',
      email: ACCOUNTS[1].email,
      createdAt: now,
      updatedAt: now,
    });

  await colonyRef.collection('cleanlinessWorkers')
    .doc('worker-four-role')
    .set({
      fullName: ACCOUNTS[3].name,
      phoneNumber: '9000000000',
      assignedArea: 'Block A',
      status: 'active',
      createdBy: admin.uid,
      createdByName: ACCOUNTS[0].name,
      createdAt: now,
      updatedAt: now,
    });

  await colonyRef.collection('workerPrivateProfiles')
    .doc('worker-four-role')
    .set({
      bloodGroup: 'O+',
      familyMemberName: 'Emergency Contact',
      familyMemberPhone: '9000000000',
      consentStatus: 'granted',
      consentAt: now,
      privacyNoticeVersion: 'worker-private-v1',
      updatedAt: now,
    });

  await colonyRef.collection('announcements')
    .doc('four-role-notice')
    .set({
      title: 'Four-role integration notice',
      message: 'Emulator notice for resident dashboard verification.',
      body: 'Emulator notice for resident dashboard verification.',
      status: 'published',
      publishedAt: now,
      createdAt: now,
      createdBy: admin.uid,
      createdByName: ACCOUNTS[0].name,
    });

  await colonyRef.collection('complaints')
    .doc('four-role-complaint')
    .set({
      complaintId: 'four-role-complaint',
      title: 'Litter near Block A corridor',
      description: 'Litter needs to be cleared from the shared corridor.',
      category: 'cleanliness',
      complaintType: 'cleanliness',
      status: 'submitted',
      priority: 'normal',
      submittedBy: resident.uid,
      submittedByName: ACCOUNTS[1].name,
      createdAt: now,
      updatedAt: now,
    });

  await colonyRef.collection('cleanlinessTasks')
    .doc('four-role-task')
    .set({
      taskId: 'four-role-task',
      title: 'Block A corridor cleaning',
      taskName: 'Block A corridor cleaning',
      description: 'Routine cleaning assigned for the Block A corridor.',
      area: 'Block A',
      status: 'assigned',
      assignedWorkerId: 'worker-four-role',
      workerId: 'worker-four-role',
      assignedBy: manager.uid,
      assignedByName: ACCOUNTS[2].name,
      createdAt: now,
      updatedAt: now,
      assignedAt: now,
    });

  await colonyRef.collection('housekeepingRequests')
    .doc('four-role-housekeeping')
    .set({
      requestId: 'four-role-housekeeping',
      title: 'Routine housekeeping request',
      description: 'Routine housekeeping for the shared areas.',
      status: 'assigned',
      requestedBy: resident.uid,
      requestedByName: ACCOUNTS[1].name,
      assignedWorkerId: 'worker-four-role',
      workerId: 'worker-four-role',
      createdAt: now,
      updatedAt: now,
    });

  await colonyRef.collection('maintenanceBills')
    .doc('four-role-bill')
    .set({
      householdId: 'household-four-role',
      blockId: 'A',
      houseNumber: 'A-101',
      householdHeadName: ACCOUNTS[1].name,
      billingPeriod: 'November 2026',
      title: 'November maintenance bill',
      description: 'Monthly maintenance contribution for the demo community.',
      totalAmount: 2500,
      amountPaid: 500,
      status: 'partially_paid',
      dueDate: Timestamp.fromDate(
        new Date('2026-12-01T00:00:00.000Z'),
      ),
      upiId: 'mohallaflow@bank',
      paymentInstructions: 'Use the demo payment flow for verification testing.',
      createdBy: admin.uid,
      createdByName: ACCOUNTS[0].name,
      createdAt: now,
      updatedAt: now,
    });

  await colonyRef.collection('maintenanceJobs')
    .doc('four-role-maintenance')
    .set({
      jobId: 'four-role-maintenance',
      title: 'Common-area maintenance request',
      description: 'Routine maintenance request for the demo community.',
      status: 'submitted',
      createdAt: now,
      updatedAt: now,
    });

  await colonyRef.collection('gateOperators')
    .doc(worker.uid)
    .set({
      uid: worker.uid,
      fullName: ACCOUNTS[3].name,
      status: 'active',
      createdAt: now,
      updatedAt: now,
    });

  // Notification fan-out regression fixture: one logical worker event,
  // represented by three scalar-recipient documents.
  const notificationRecipients = [
    'role:worker',
    `user:${worker.uid}`,
    'worker:worker-four-role',
  ];

  const notificationBase = {
    title: 'Worker assignment fan-out regression',
    message: 'One task event was delivered through three audience keys.',
    eventType: 'task_assigned',
    recipientKeys: notificationRecipients,
    sourceCollection: 'cleanlinessTasks',
    sourceId: 'four-role-task',
    createdBy: manager.uid,
    createdAt: now,
  };

  const notificationCopies = [
    {id: 'notification-dedupe-role', recipientKey: 'role:worker'},
    {id: 'notification-dedupe-user', recipientKey: `user:${worker.uid}`},
    {id: 'notification-dedupe-worker', recipientKey: 'worker:worker-four-role'},
  ];

  for (const copy of notificationCopies) {
    await colonyRef.collection('notifications').doc(copy.id).set({
      ...notificationBase,
      recipientKey: copy.recipientKey,
    });
  }

  console.log(
    'Seeded three scalar-recipient copies for the worker notification deduplication test.',
  );

}

async function cleanup() {
  await resetFixture();

  console.log(
    'Removed all four-role emulator fixtures and Auth accounts.',
  );
}

async function main() {
  try {
    const mode = process.argv[2];

    if (mode === 'seed') {
      await seed();
    } else if (mode === 'cleanup') {
      await cleanup();
    } else {
      throw new Error('Usage: four-role-app.seed.js seed|cleanup');
    }
  } finally {
    await deleteApp(app);
  }
}

main().catch((error) => {
  console.error(error.stack || error);
  process.exitCode = 1;
});
