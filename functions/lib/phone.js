"use strict";

function normalizeIndianMobileNumber(input) {
  if (typeof input !== "string") return null;
  let digits = input.replace(/[^0-9]/g, "");
  if (digits.length === 12 && digits.startsWith("91")) digits = digits.slice(2);
  if (!/^[6-9][0-9]{9}$/.test(digits)) return null;
  return digits;
}

function toIndianE164(input) {
  const digits = normalizeIndianMobileNumber(input);
  return digits ? `+91${digits}` : null;
}

function groupMatchesByColony(matches) {
  const grouped = new Map();
  for (const match of matches) {
    const colonyId = match && typeof match.colonyId === "string" ? match.colonyId : "";
    const values = grouped.get(colonyId) || [];
    values.push(match);
    grouped.set(colonyId, values);
  }
  return grouped;
}

function isClaimableRegistration(data) {
  return !!data && ["pending", "linked"].includes(String(data.status || ""));
}

function isActiveResident(data) {
  return !!data && String(data.residentStatus || "").toLowerCase() === "active";
}

module.exports = {
  normalizeIndianMobileNumber,
  toIndianE164,
  groupMatchesByColony,
  isClaimableRegistration,
  isActiveResident,
};
