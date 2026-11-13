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
    process.env.CANDIDATE_RULES ?? path.join(dirname, '..', 'firestore.rules'),
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
      ['privateGroups/secret/members/resident-a',
        { uid: 'resident-a', status: 'active', privateMarker: true }],
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
  await assertFails(getDoc(doc(db, 'privateGroups/secret/members/resident-a')));

  console.log('[PASS] Exact-path multi-colony access remains scoped.');
});

test('filtered and unrestricted collection-group queries are denied', async () => {
  const db = env.authenticatedContext('resident-a').firestore();

  const filtered = query(
    collectionGroup(db, 'members'),
    where('uid', '==', 'resident-a'),
    where('status', '==', 'active')
  );

  await assertFails(getDocs(filtered));
  await assertFails(getDocs(collectionGroup(db, 'members')));

  console.log('[PASS] Collection-group queries remain denied.');
});
