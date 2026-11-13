'use strict';

const LEGACY_PRIVATE_FIELDS = Object.freeze([
  'bloodGroup',
  'familyMemberName',
  'familyMemberPhone',
]);

function buildWorkerPrivateProfile(legacyWorkerData, existingPrivateData) {
  const legacy = legacyWorkerData || {};
  const existing = existingPrivateData || {};
  const hasLegacyDetails =
    (legacy.bloodGroup && legacy.bloodGroup !== 'Not provided') ||
    Boolean(legacy.familyMemberName) ||
    Boolean(legacy.familyMemberPhone);

  const bloodGroup = existing.bloodGroup ?? legacy.bloodGroup ?? 'Not provided';
  const familyMemberName = existing.familyMemberName ?? legacy.familyMemberName ?? '';
  const familyMemberPhone = existing.familyMemberPhone ?? legacy.familyMemberPhone ?? '';

  const noticeVersion = 'worker-private-v1';
  let consentStatus = existing.consentStatus;
  if (!consentStatus) {
    consentStatus = hasLegacyDetails ? 'pending' : 'not_provided';
  }

  // A grant for a different notice version is not silently reused.
  if (consentStatus === 'granted' && existing.privacyNoticeVersion !== noticeVersion) {
    consentStatus = 'pending';
  }

  let consentAt = existing.consentAt ?? null;
  if (consentStatus !== 'granted') consentAt = null;

  return {
    bloodGroup,
    familyMemberName,
    familyMemberPhone,
    consentStatus,
    consentAt,
    privacyNoticeVersion: noticeVersion,
  };
}

function legacyPrivateFieldDeleteMap(legacyWorkerData, deleteFieldValue) {
  const data = legacyWorkerData || {};
  const removals = {};
  for (const key of LEGACY_PRIVATE_FIELDS) {
    if (Object.prototype.hasOwnProperty.call(data, key)) {
      removals[key] = deleteFieldValue;
    }
  }
  return removals;
}

module.exports = {
  LEGACY_PRIVATE_FIELDS,
  buildWorkerPrivateProfile,
  legacyPrivateFieldDeleteMap,
};
