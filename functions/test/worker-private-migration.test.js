'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  buildWorkerPrivateProfile,
  legacyPrivateFieldDeleteMap,
} = require('../lib/worker_private_profile_migration');

test('legacy private details are migrated as pending worker consent', () => {
  const result = buildWorkerPrivateProfile({
    bloodGroup: 'O+',
    familyMemberName: 'Emergency Contact',
    familyMemberPhone: '9876543210',
  }, {});

  assert.deepEqual(result, {
    bloodGroup: 'O+',
    familyMemberName: 'Emergency Contact',
    familyMemberPhone: '9876543210',
    consentStatus: 'pending',
    consentAt: null,
    privacyNoticeVersion: 'worker-private-v1',
  });
});

test('an older notice version is moved back to pending consent', () => {
  const result = buildWorkerPrivateProfile(
    { bloodGroup: 'O+', familyMemberName: 'Old Contact', familyMemberPhone: '9876543210' },
    {
      bloodGroup: 'A+',
      familyMemberName: 'Current Contact',
      familyMemberPhone: '9876500000',
      consentStatus: 'granted',
      consentAt: 'old-consent-timestamp',
      privacyNoticeVersion: 'worker-private-v0',
    },
  );

  assert.equal(result.bloodGroup, 'A+');
  assert.equal(result.familyMemberName, 'Current Contact');
  assert.equal(result.consentStatus, 'pending');
  assert.equal(result.consentAt, null);
  assert.equal(result.privacyNoticeVersion, 'worker-private-v1');
});

test('current notice consent is preserved without changing the consent timestamp', () => {
  const result = buildWorkerPrivateProfile(
    {},
    {
      bloodGroup: 'B+',
      familyMemberName: 'Consented Contact',
      familyMemberPhone: '9876500006',
      consentStatus: 'granted',
      consentAt: 'current-consent-timestamp',
      privacyNoticeVersion: 'worker-private-v1',
    },
  );

  assert.equal(result.consentStatus, 'granted');
  assert.equal(result.consentAt, 'current-consent-timestamp');
  assert.equal(result.privacyNoticeVersion, 'worker-private-v1');
});

test('worker without legacy private fields receives an empty not-provided profile', () => {
  const result = buildWorkerPrivateProfile({ fullName: 'Worker' }, {});
  assert.equal(result.bloodGroup, 'Not provided');
  assert.equal(result.familyMemberName, '');
  assert.equal(result.familyMemberPhone, '');
  assert.equal(result.consentStatus, 'not_provided');
  assert.equal(result.consentAt, null);
});

test('migration only schedules deletion of legacy private fields actually present', () => {
  const deleteToken = { delete: true };
  assert.deepEqual(
    legacyPrivateFieldDeleteMap({ bloodGroup: 'O+', fullName: 'Worker' }, deleteToken),
    { bloodGroup: deleteToken },
  );
});
