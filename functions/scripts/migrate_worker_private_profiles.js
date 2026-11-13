'use strict';

// Emulator-only migration. Production execution is intentionally blocked.
// Run without --apply first to inspect; --apply writes only to the local emulator.

const { initializeApp, getApps } = require('firebase-admin/app');
const { FieldValue, getFirestore } = require('firebase-admin/firestore');
const {
  buildWorkerPrivateProfile,
  legacyPrivateFieldDeleteMap,
} = require('../lib/worker_private_profile_migration');

const DEMO_PROJECT_ID = 'demo-mohallaflow';
const host = process.env.FIRESTORE_EMULATOR_HOST || '';
const apply = process.argv.includes('--apply');

if (!/^(127\.0\.0\.1|localhost):8080$/.test(host)) {
  throw new Error(
    'Blocked: this migration only runs against Firestore Emulator at 127.0.0.1:8080.',
  );
}

const configuredProject = process.env.GCLOUD_PROJECT || DEMO_PROJECT_ID;
if (configuredProject !== DEMO_PROJECT_ID) {
  throw new Error(
    `Blocked: expected demo project ${DEMO_PROJECT_ID}; received ${configuredProject}.`,
  );
}

if (getApps().length === 0) initializeApp({ projectId: DEMO_PROJECT_ID });
const db = getFirestore();

async function main() {
  console.log(`Worker private-profile migration (${apply ? 'APPLY' : 'DRY RUN'})`);
  console.log(`Project: ${DEMO_PROJECT_ID}`);
  console.log(`Emulator: ${host}`);

  const colonies = await db.collection('colonies').get();
  let scanned = 0;
  let changed = 0;
  let batch = db.batch();
  let batchWrites = 0;

  async function commitBatch() {
    if (batchWrites === 0) return;
    await batch.commit();
    batch = db.batch();
    batchWrites = 0;
  }

  for (const colony of colonies.docs) {
    const workers = await colony.ref.collection('cleanlinessWorkers').get();

    for (const worker of workers.docs) {
      scanned += 1;
      const legacyData = worker.data();
      const privateRef = colony.ref.collection('workerPrivateProfiles').doc(worker.id);
      const privateSnapshot = await privateRef.get();
      const existingPrivate = privateSnapshot.exists ? privateSnapshot.data() : {};
      const privateProfile = buildWorkerPrivateProfile(legacyData, existingPrivate);
      const removals = legacyPrivateFieldDeleteMap(
        legacyData,
        FieldValue.delete(),
      );
      const hasLegacyFields = Object.keys(removals).length > 0;
      const shouldCreatePrivate = !privateSnapshot.exists;

      if (!hasLegacyFields && !shouldCreatePrivate) continue;
      changed += 1;

      console.log(
        `${apply ? '[PLAN]' : '[DRY RUN]'} ${colony.id}/${worker.id}: ` +
        `${hasLegacyFields ? 'move legacy private fields' : 'create private profile'}; ` +
        `consent=${privateProfile.consentStatus}`,
      );

      if (apply) {
        batch.set(
          privateRef,
          {
            ...privateProfile,
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
        batchWrites += 1;

        if (hasLegacyFields) {
          batch.update(worker.ref, removals);
          batchWrites += 1;
        }

        if (batchWrites >= 400) await commitBatch();
      }
    }
  }

  if (apply) await commitBatch();

  console.log(`Scanned worker records: ${scanned}`);
  console.log(`Records requiring migration: ${changed}`);
  console.log(
    apply
      ? 'Migration committed to the Firestore Emulator.'
      : 'No writes performed. Re-run with --apply to modify the emulator.',
  );
}

main().catch((error) => {
  console.error('Worker private-profile migration failed:', error);
  process.exitCode = 1;
});
