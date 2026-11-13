"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  normalizeIndianMobileNumber,
  toIndianE164,
  groupMatchesByColony,
  isClaimableRegistration,
  isActiveResident,
} = require("../lib/phone");

test("normalizes a valid Indian mobile number", () => {
  assert.equal(normalizeIndianMobileNumber("9876543210"), "9876543210");
  assert.equal(toIndianE164("+91 98765 43210"), "+919876543210");
});

test("rejects invalid and non-Indian numbers", () => {
  assert.equal(normalizeIndianMobileNumber("1234567890"), null);
  assert.equal(normalizeIndianMobileNumber("+1 2025550100"), null);
  assert.equal(normalizeIndianMobileNumber(""), null);
});

test("allows a single login registration per colony across multiple colonies", () => {
  const grouped = groupMatchesByColony([{ colonyId: "a" }, { colonyId: "b" }]);
  assert.equal([...grouped.values()].every((entries) => entries.length === 1), true);
});

test("detects duplicate login registrations within the same colony", () => {
  const grouped = groupMatchesByColony([{ colonyId: "a" }, { colonyId: "a" }]);
  assert.equal([...grouped.values()].some((entries) => entries.length > 1), true);
});

test("requires a pending or linked private registration", () => {
  assert.equal(isClaimableRegistration({ status: "pending" }), true);
  assert.equal(isClaimableRegistration({ status: "linked" }), true);
  assert.equal(isClaimableRegistration({ status: "not_enabled" }), false);
  assert.equal(isActiveResident({ residentStatus: "active" }), true);
  assert.equal(isActiveResident({ residentStatus: "inactive" }), false);
});
