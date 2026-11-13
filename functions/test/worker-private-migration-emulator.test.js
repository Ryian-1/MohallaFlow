'use strict';

const { test } = require('node:test');
const assert = require('node:assert/strict');
const { execFileSync } = require('node:child_process');
const path = require('node:path');
const { initializeApp } = require('firebase-admin/app');
const { Timestamp, getFirestore } = require('firebase-admin/firestore');

const PROJECT_ID = 'demo-mohallaflow';
const HOST = process.env.FIRESTORE_EMULATOR_HOST || '';
const COLONY_ID = 'stage6_worker_private_migration_test';

if (!/^(127\.0\.0\.1|localhost):8080$/.test(HOST)) {
  throw new Error(
    'This integration test requires the Firestore Emulator at 127.0.0.1:8080.',
  );
}
if ((process.env.GCLOUD_PROJECT || PROJECT_ID) !== PROJECT_ID) {
  throw new Error('This test is restricted to demo-mohallaflow.');
}

const app = initializeApp({ projectId: PROJECT_ID }, 'worker-private-migration-test');
const db = getFirestore(app);

test('legacy worker private fields move atomically and remain pending consent', async () => {
  const colonyRef = db.collection('colonies').doc(COLONY_ID);
  const legacyWorkerRef = colonyRef.collection('cleanlinessWorkers').doc('legacy_worker');
  const existingWorkerRef = colonyRef.collection('cleanlinessWorkers').doc('already_private_worker');
  const existingPrivateRef = colonyRef.collection('workerPrivateProfiles').doc('already_private_worker');
  const now = Timestamp.now();

  try {
    await colonyRef.set({ name: 'Stage 6 Migration Emulator Fixture' });
    await legacyWorkerRef.set({
      fullName: 'Legacy Worker',
      phoneNumber: '9876500101',
      assignedArea: 'North Block',
      status: 'active',
      createdBy: 'stage6_test_admin',
      createdByName: 'Stage 6 Test Admin',
      createdAt: now,
      updatedAt: now,
      bloodGroup: 'O+',
      familyMemberName: 'Legacy Emergency Contact',
      familyMemberPhone: '9876500102',
    });
    await existingWorkerRef.set({
      fullName: 'Existing Private Worker',
      phoneNumber: '9876500103',
      assignedArea: 'South Block',
      status: 'active',
      createdBy: 'stage6_test_admin',
      createdByName: 'Stage 6 Test Admin',
      createdAt: now,
      updatedAt: now,
      bloodGroup: 'A+',
      familyMemberName: 'Old Contact Should Not Win',
      familyMemberPhone: '9876500104',
    });
    await existingPrivateRef.set({
      bloodGroup: 'B+',
      familyMemberName: 'Current Consented Contact',
      familyMemberPhone: '9876500105',
      consentStatus: 'granted',
      consentAt: now,
      privacyNoticeVersion: 'worker-private-v1',
      updatedAt: now,
    });

    const migrationScript = path.join(
      __dirname,
      '..',
      'scripts',
      'migrate_worker_private_profiles.js',
    );
    const output = execFileSync(
      process.execPath,
      [migrationScript, '--apply'],
      {
        encoding: 'utf8',
        env: {
          ...process.env,
          FIRESTORE_EMULATOR_HOST: HOST,
          GCLOUD_PROJECT: PROJECT_ID,
        },
      },
    );

    assert.match(output, /Migration committed to the Firestore Emulator/);

    const legacyPublicAfter = (await legacyWorkerRef.get()).data();
    assert.equal(Object.hasOwn(legacyPublicAfter, 'bloodGroup'), false);
    assert.equal(Object.hasOwn(legacyPublicAfter, 'familyMemberName'), false);
    assert.equal(Object.hasOwn(legacyPublicAfter, 'familyMemberPhone'), false);

    const movedPrivate = (await colonyRef
      .collection('workerPrivateProfiles')
      .doc('legacy_worker')
      .get()).data();
    assert.equal(movedPrivate.bloodGroup, 'O+');
    assert.equal(movedPrivate.familyMemberName, 'Legacy Emergency Contact');
    assert.equal(movedPrivate.familyMemberPhone, '9876500102');
    assert.equal(movedPrivate.consentStatus, 'pending');
    assert.equal(movedPrivate.consentAt, null);
    assert.equal(movedPrivate.privacyNoticeVersion, 'worker-private-v1');

    const existingPrivateAfter = (await existingPrivateRef.get()).data();
    assert.equal(existingPrivateAfter.bloodGroup, 'B+');
    assert.equal(existingPrivateAfter.familyMemberName, 'Current Consented Contact');
    assert.equal(existingPrivateAfter.consentStatus, 'granted');
  } finally {
    await db.recursiveDelete(colonyRef);
  }
});
