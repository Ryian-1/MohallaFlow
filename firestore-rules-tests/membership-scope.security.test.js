import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';
import assert from 'node:assert/strict';

import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';

import {
  collectionGroup,
  doc,
  getDoc,
  getDocs,
  query,
  setDoc,
  where,
} from 'firebase/firestore';

const dirname = path.dirname(fileURLToPath(import.meta.url));
let env;

test.before(async () => {
  const rules = fs.readFileSync(
    process.env.CANDIDATE_RULES
      ?? path.join(dirname, '..', 'release', 'firestore', 'firestore.rules'),
    'utf8'
  );

  env = await initializeTestEnvironment({
    projectId: 'demo-mohallaflow',
    firestore: { rules },
  });

  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();

    const fixtures = [
      ['colonies/alpha/members/resident-a',
        { uid: 'resident-a', colonyId: 'alpha', role: 'resident', status: 'active' }],
      ['colonies/beta/members/resident-a',
        { uid: 'resident-a', colonyId: 'beta', role: 'resident', status: 'active' }],
      ['colonies/alpha/members/resident-b',
        { uid: 'resident-b', colonyId: 'alpha', role: 'resident', status: 'active' }],
      ['privateGroups/secret/members/other-member',
        { uid: 'unrelated-user', status: 'active', privateMarker: true }],
    ];

    for (const [documentPath, data] of fixtures) {
      await setDoc(doc(db, documentPath), data);
    }
  });
});

test.after(async () => {
  if (env) await env.cleanup();
});

test('exact-path reads preserve own multi-colony membership access', async () => {
  const db = env.authenticatedContext('resident-a').firestore();

  await assertSucceeds(getDoc(doc(db, 'colonies/alpha/members/resident-a')));
  await assertSucceeds(getDoc(doc(db, 'colonies/beta/members/resident-a')));
  await assertFails(getDoc(doc(db, 'colonies/alpha/members/resident-b')));
  await assertFails(getDoc(doc(db, 'privateGroups/secret/members/other-member')));

  console.log('[PASS] Exact-path multi-colony access remains scoped.');
});

test('legacy filtered collection-group queries work and broad queries are denied', async () => {
  const db = env.authenticatedContext('resident-a').firestore();

  const filtered = query(
    collectionGroup(db, 'members'),
    where('uid', '==', 'resident-a'),
    where('status', '==', 'active')
  );

  const result = await assertSucceeds(getDocs(filtered));
  assert.equal(result.size, 2);
  const paths = new Set(result.docs.map((snapshot) => snapshot.ref.path));
  assert.deepEqual(
    paths,
    new Set([
      'colonies/alpha/members/resident-a',
      'colonies/beta/members/resident-a',
    ])
  );

  await assertFails(getDocs(collectionGroup(db, 'members')));

  const missingStatus = query(
    collectionGroup(db, 'members'),
    where('uid', '==', 'resident-a')
  );
  await assertFails(getDocs(missingStatus));

  const crossUser = query(
    collectionGroup(db, 'members'),
    where('uid', '==', 'resident-b'),
    where('status', '==', 'active')
  );
  await assertFails(getDocs(crossUser));

  console.log('[PASS] Legacy filtered membership query works; unfiltered, missing-status and cross-UID queries are denied.');
});
