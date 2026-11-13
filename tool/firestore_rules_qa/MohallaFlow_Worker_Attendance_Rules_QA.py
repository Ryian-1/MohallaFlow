#!/usr/bin/env python3
"""Isolated read/write authorization tests for MohallaFlow worker attendance.

Reads the local firestore.rules file only. Runs against a demo-project Firestore
Emulator using synthetic fixtures. It does not connect to production, deploy,
write cloud data, or modify application source / firestore.rules / indexes.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import socket
import subprocess
import sys
from datetime import datetime
from pathlib import Path

PACKAGE = {
    "name": "mohallaflow-worker-attendance-rules-qa",
    "private": True,
    "version": "1.0.0",
    "scripts": {"test": "node --test attendance.rules.test.cjs"},
    "dependencies": {
        "@firebase/rules-unit-testing": "6.0.0",
        "firebase": "13.2.0",
    },
}

TEST_SOURCE = r'''const fs = require('node:fs');
const test = require('node:test');
const assert = require('node:assert/strict');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const {
  collection, doc, getDoc, getDocs, query, where,
  setDoc, updateDoc, serverTimestamp,
} = require('firebase/firestore');

const PROJECT_ID = 'demo-mohallaflow';
const PORT = Number(process.env.FIRESTORE_EMULATOR_PORT);
const RULES_PATH = process.env.MOHALLA_RULES_PATH;
const TODAY = '2026-11-08';
const COLONY = 'alpha';
let env;

if (!PORT || !RULES_PATH || !fs.existsSync(RULES_PATH)) {
  throw new Error('Missing emulator port or local rules path.');
}

function db(uid) {
  return env.authenticatedContext(uid).firestore();
}
function ref(uid, path) {
  return doc(db(uid), path);
}
function attendancePath(id, date = TODAY) {
  return `colonies/${COLONY}/workerAttendance/${id}_${date}`;
}

async function seed() {
  await env.withSecurityRulesDisabled(async (context) => {
    const d = context.firestore();
    const writes = [];
    const put = (path, data) => writes.push(setDoc(doc(d, path), data));
    for (const [uid, role, workerId] of [
      ['worker-a', 'worker', 'worker-1'],
      ['worker-b', 'worker', 'worker-2'],
      ['manager-a', 'cleanliness_manager', null],
      ['admin-a', 'admin', null],
    ]) {
      put(`colonies/${COLONY}/members/${uid}`, {
        uid, colonyId: COLONY, colonyName: 'Alpha', role,
        status: 'active', ...(workerId ? { workerId } : {}),
      });
    }
    put(`colonies/${COLONY}/cleanlinessWorkers/worker-1`, {
      fullName: 'Worker One', status: 'active',
    });
    put(`colonies/${COLONY}/cleanlinessWorkers/worker-2`, {
      fullName: 'Worker Two', status: 'active',
    });
    put(attendancePath('worker-1', '2026-11-07'), {
      workerId: 'worker-1', workerUid: 'worker-a', workerName: 'Worker One',
      attendanceDateKey: '2026-11-07', checkInAt: new Date('2026-11-07T03:00:00Z'),
      checkOutAt: null, status: 'checked_in',
      createdAt: new Date('2026-11-07T03:00:00Z'),
      updatedAt: new Date('2026-11-07T03:00:00Z'),
    });
    put(attendancePath('worker-2', '2026-11-08'), {
      workerId: 'worker-2', workerUid: 'worker-b', workerName: 'Worker Two',
      attendanceDateKey: TODAY, checkInAt: new Date('2026-11-08T03:00:00Z'),
      checkOutAt: null, status: 'checked_in',
      createdAt: new Date('2026-11-08T03:00:00Z'),
      updatedAt: new Date('2026-11-08T03:00:00Z'),
    });
    put(`colonies/beta/workerAttendance/worker-1_${TODAY}`, {
      workerId: 'worker-1', workerUid: 'worker-a', attendanceDateKey: TODAY,
    });
    await Promise.all(writes);
  });
}

test.before(async () => {
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      host: '127.0.0.1', port: PORT,
      rules: fs.readFileSync(RULES_PATH, 'utf8'),
    },
  });
  await env.clearFirestore();
  await seed();
});
test.after(async () => { if (env) await env.cleanup(); });

test('worker can read own deterministic attendance document before check-in', async () => {
  const snapshot = await assertSucceeds(
    getDoc(ref('worker-a', attendancePath('worker-1'))),
  );
  assert.equal(snapshot.exists(), false);
});

test('worker cannot read another worker attendance document', async () => {
  await assertFails(getDoc(ref('worker-a', attendancePath('worker-2'))));
});

test('worker can query only own attendance history when workerId is constrained', async () => {
  const q = query(
    collection(db('worker-a'), `colonies/${COLONY}/workerAttendance`),
    where('workerId', '==', 'worker-1'),
  );
  const result = await assertSucceeds(getDocs(q));
  assert.equal(result.size, 1);
  await assertFails(getDocs(collection(db('worker-a'), `colonies/${COLONY}/workerAttendance`)));
});

test('Admin and Cleanliness Manager can query the date-wise register', async () => {
  const adminQuery = query(
    collection(db('admin-a'), `colonies/${COLONY}/workerAttendance`),
    where('attendanceDateKey', '==', TODAY),
  );
  const managerQuery = query(
    collection(db('manager-a'), `colonies/${COLONY}/workerAttendance`),
    where('attendanceDateKey', '==', TODAY),
  );
  const adminRows = await assertSucceeds(getDocs(adminQuery));
  const managerRows = await assertSucceeds(getDocs(managerQuery));
  assert.equal(adminRows.size, 1);
  assert.equal(managerRows.size, 1);
});

test('worker cannot query other workers attendance by date alone', async () => {
  const q = query(
    collection(db('worker-a'), `colonies/${COLONY}/workerAttendance`),
    where('attendanceDateKey', '==', TODAY),
  );
  await assertFails(getDocs(q));
});

test('worker can create their own check-in with server timestamps', async () => {
  const path = attendancePath('worker-1');
  await assertSucceeds(setDoc(ref('worker-a', path), {
    workerId: 'worker-1', workerUid: 'worker-a', workerName: 'Worker One',
    attendanceDateKey: TODAY,
    checkInAt: serverTimestamp(), checkOutAt: null,
    status: 'checked_in', createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  }));
});

test('worker cannot create attendance for a different worker', async () => {
  await assertFails(setDoc(ref('worker-a', attendancePath('worker-2')), {
    workerId: 'worker-2', workerUid: 'worker-a', workerName: 'Worker One',
    attendanceDateKey: TODAY,
    checkInAt: serverTimestamp(), checkOutAt: null,
    status: 'checked_in', createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  }));
});

test('worker can check out their own checked-in attendance', async () => {
  const path = attendancePath('worker-1', '2026-11-07');
  await assertSucceeds(updateDoc(ref('worker-a', path), {
    checkOutAt: serverTimestamp(), status: 'checked_out',
    updatedAt: serverTimestamp(),
  }));
});

test('manager cannot create or modify a worker attendance record', async () => {
  await assertFails(setDoc(ref('manager-a', attendancePath('worker-1')), {
    workerId: 'worker-1', workerUid: 'worker-a', workerName: 'Worker One',
    attendanceDateKey: TODAY,
    checkInAt: serverTimestamp(), checkOutAt: null,
    status: 'checked_in', createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(ref('manager-a', attendancePath('worker-2')), {
    checkOutAt: serverTimestamp(), status: 'checked_out',
    updatedAt: serverTimestamp(),
  }));
});

test('worker cannot read attendance in a different colony', async () => {
  await assertFails(getDoc(ref('worker-a', `colonies/beta/workerAttendance/worker-1_${TODAY}`)));
});
'''


def free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.bind(("127.0.0.1", 0))
        return int(sock.getsockname()[1])


def main() -> int:
    parser = argparse.ArgumentParser(description="Test worker attendance Firestore rules against local Emulator fixtures.")
    parser.add_argument("--root", required=True, help="MohallaFlow project root")
    args = parser.parse_args()
    root = Path(args.root).expanduser().resolve()
    rules_path = root / "firestore.rules"
    node = shutil.which("node")
    npm = shutil.which("npm")
    firebase = shutil.which("firebase")
    if not root.is_dir() or not rules_path.is_file():
        print(f"[ERROR] Project/rules file not found: {root}")
        return 2
    if not all((node, npm, firebase)):
        print("[ERROR] Need node, npm and Firebase CLI on PATH.")
        return 2
    rules = rules_path.read_text(encoding="utf-8")
    if "match /workerAttendance/{attendanceId}" not in rules:
        print("[FAIL] Local rules contain no workerAttendance match block.")
        return 2
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    qa_dir = Path.home() / "Desktop" / f"MohallaFlow_Worker_Attendance_QA_{stamp}"
    qa_dir.mkdir(parents=True, exist_ok=False)
    (qa_dir / "package.json").write_text(json.dumps(PACKAGE, indent=2) + "\n", encoding="utf-8")
    (qa_dir / "attendance.rules.test.cjs").write_text(TEST_SOURCE, encoding="utf-8")
    print("MohallaFlow Worker Attendance Rules QA")
    print(f"Project: {root}")
    print(f"Rules SHA256: {hashlib.sha256(rules.encode()).hexdigest()}")
    print(f"QA workspace: {qa_dir}")
    print("Tests: 10 worker/manager/admin/ownership/date-query/CRUD/cross-colony cases")
    print("Data: synthetic Emulator fixtures only")
    print("Production Firebase: not accessed; no deployment or cloud writes")
    install = subprocess.run([npm, "install", "--no-audit", "--no-fund", "--no-save"], cwd=qa_dir, check=False)
    if install.returncode != 0:
        print(f"[FAIL] QA dependency installation failed. Workspace retained: {qa_dir}")
        return install.returncode
    port = free_port()
    config_path = root / f".firebase-attendance-qa-{os.getpid()}.json"
    config = {
        "firestore": {"rules": "firestore.rules"},
        "emulators": {"firestore": {"host": "127.0.0.1", "port": port}, "ui": {"enabled": False}, "singleProjectMode": True},
    }
    config_path.write_text(json.dumps(config, indent=2) + "\n", encoding="utf-8")
    env = os.environ.copy()
    env["MOHALLA_RULES_PATH"] = str(rules_path)
    env["FIRESTORE_EMULATOR_PORT"] = str(port)
    test_cmd = f'"{node}" --test "{qa_dir / "attendance.rules.test.cjs"}"'
    command = [firebase, "emulators:exec", "--only", "firestore", "--project", "demo-mohallaflow", "--config", str(config_path), "--non-interactive", test_cmd]
    print(f"\nStarting isolated Firestore Emulator on 127.0.0.1:{port}")
    try:
        result = subprocess.run(command, cwd=root, env=env, check=False, timeout=600)
        code = result.returncode
    except subprocess.TimeoutExpired:
        print("[FAIL] Emulator tests timed out after 10 minutes.")
        code = 124
    finally:
        config_path.unlink(missing_ok=True)
    print("\n========== ATTENDANCE QA RESULT ==========")
    print("[SUCCESS] Attendance rule scenarios passed." if code == 0 else f"[FAILED] Attendance QA exited with code {code}.")
    print(f"QA workspace retained: {qa_dir}")
    print("firestore.rules, firebase.json, application source, production Firebase and GitHub were not modified.")
    return code


if __name__ == "__main__":
    raise SystemExit(main())
