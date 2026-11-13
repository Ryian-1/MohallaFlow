const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const source = fs.readFileSync(path.join(__dirname, '..', 'index.js'), 'utf8');

test('deployed callable Functions enforce App Check while Emulator tests remain exempt', () => {
  assert.match(
    source,
    /const enforceCallableAppCheck = process\.env\.FUNCTIONS_EMULATOR !== 'true';/,
  );

  for (const name of [
    'claimResidentRegistration',
    'requestAccountDeletion',
    'approveColonyPayrollRun',
  ]) {
    const marker = `exports.${name} = onCall(`;
    const start = source.indexOf(marker);
    assert.notEqual(start, -1, `${name} callable must exist`);
    const optionsStart = source.indexOf('{', start + marker.length);
    const optionsEnd = source.indexOf('},', optionsStart);
    assert.ok(optionsStart > start && optionsEnd > optionsStart, `${name} options block must parse`);
    const options = source.slice(optionsStart, optionsEnd);
    assert.match(options, /enforceAppCheck: enforceCallableAppCheck/,
      `${name} must enforce App Check outside the emulator`);
  }
});
