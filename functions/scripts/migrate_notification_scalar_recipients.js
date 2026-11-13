'use strict';

const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { migrateColonyNotifications } = require('../lib/notification_scalar_migration');

async function main() {
  const args = process.argv.slice(2);
  const apply = args.includes('--apply');
  const colonyId = args.find((value) => !value.startsWith('--'));

  if (!process.env.FIRESTORE_EMULATOR_HOST) {
    throw new Error(
      'This migration tool is emulator-only. FIRESTORE_EMULATOR_HOST is required.',
    );
  }

  const projectId = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT;
  if (!projectId || !projectId.startsWith('demo-')) {
    throw new Error(
      'Refusing to run without a demo-* Firebase project ID.',
    );
  }

  if (!colonyId) {
    throw new Error(
      'Usage: node scripts/migrate_notification_scalar_recipients.js [--apply] <colonyId>',
    );
  }

  const app = initializeApp({ projectId });
  try {
    const summary = await migrateColonyNotifications(
      getFirestore(app),
      colonyId,
      { dryRun: !apply },
    );

    console.log(
      apply ? 'NOTIFICATION MIGRATION APPLIED' : 'NOTIFICATION MIGRATION DRY RUN',
    );
    console.log(JSON.stringify(summary, null, 2));
  } finally {
    await app.delete();
  }
}

main().catch((error) => {
  console.error('[NOTIFICATION MIGRATION FAILED]', error);
  process.exitCode = 1;
});
