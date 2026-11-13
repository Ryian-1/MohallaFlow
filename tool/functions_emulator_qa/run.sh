#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

NODE_BIN="$(command -v node || true)"
FIREBASE_BIN="$(command -v firebase || true)"

[[ -n "$NODE_BIN" && -x "$NODE_BIN" ]] || {
  echo "[STOP] Node.js is required." >&2; exit 2;
}
[[ -n "$FIREBASE_BIN" && -x "$FIREBASE_BIN" ]] || {
  echo "[STOP] Firebase CLI is required." >&2; exit 2;
}

NODE_VERSION="$("$NODE_BIN" -p 'process.versions.node')"
[[ "${NODE_VERSION%%.*}" == "22" ]] || {
  echo "[STOP] Node 22 required; found $NODE_VERSION." >&2; exit 2;
}

CANDIDATE="$ROOT/qa_candidates/firestore_candidate_g.rules"
EXPECTED_SHA="7f30e3bdd6b6e244e66c33baaa32a6ee3ef04beb6799bc377f87f29bac8a2ab0"
ACTUAL_SHA="$(shasum -a 256 "$CANDIDATE" | awk '{print $1}')"

[[ "$ACTUAL_SHA" == "$EXPECTED_SHA" ]] || {
  echo "[STOP] Candidate G SHA mismatch." >&2
  exit 3
}

QA_TMP="$(mktemp -d "${TMPDIR:-/tmp}/mohallaflow-functions-qa.XXXXXX")"
CONFIG="$ROOT/.firebase-functions-qa-$$.json"
CLOUDSDK_CONFIG="$QA_TMP/gcloud"
ISOLATED_HOME="$QA_TMP/home"
ISOLATED_XDG="$QA_TMP/xdg"
ISOLATED_HOME="$QA_TMP/home"
ISOLATED_XDG="$QA_TMP/xdg"
mkdir -p "$CLOUDSDK_CONFIG" "$ISOLATED_HOME" "$ISOLATED_XDG" "$ISOLATED_HOME" "$ISOLATED_XDG"

cleanup() {
  rm -f "$CONFIG"
  rm -rf "$QA_TMP"
}
trap cleanup EXIT

[[ ! -e "$CONFIG" ]] || {
  echo "[STOP] Temporary Firebase config already exists." >&2
  exit 2
}

cat > "$CONFIG" <<'JSON'
{
  "functions": {
    "source": "functions",
    "runtime": "nodejs22"
  },
  "firestore": {
    "rules": "qa_candidates/firestore_candidate_g.rules",
    "indexes": "firestore.indexes.json"
  },
  "emulators": {
    "auth": {
      "host": "127.0.0.1",
      "port": 9099
    },
    "firestore": {
      "host": "127.0.0.1",
      "port": 8080
    },
    "functions": {
      "host": "127.0.0.1",
      "port": 5001
    },
    "ui": {
      "enabled": false
    },
    "singleProjectMode": true
  }
}
JSON

run_emulator() {
  local services="$1"
  local command="$2"

  env \
    -u GOOGLE_APPLICATION_CREDENTIALS \
    -u CLOUDSDK_AUTH_CREDENTIAL_FILE_OVERRIDE \
    HOME="$ISOLATED_HOME" \
    XDG_CONFIG_HOME="$ISOLATED_XDG" \
    HOME="$ISOLATED_HOME" \
    XDG_CONFIG_HOME="$ISOLATED_XDG" \
    CLOUDSDK_CONFIG="$CLOUDSDK_CONFIG" \
    GCLOUD_PROJECT=demo-mohallaflow \
    GOOGLE_CLOUD_PROJECT=demo-mohallaflow \
    "$FIREBASE_BIN" emulators:exec \
      --only "$services" \
      --project demo-mohallaflow \
      --config "$CONFIG" \
      --non-interactive \
      "$command"
}

echo "========== FUNCTIONS QA =========="
echo "Node: $NODE_VERSION"
echo "Candidate G: $ACTUAL_SHA"
echo "Project: demo-mohallaflow"
echo

python3 - <<'PY'
import socket
import sys

ports = (8080, 9099, 5001, 4400, 4500, 9150)
occupied = []

for port in ports:
    sock = socket.socket()
    try:
        sock.bind(("127.0.0.1", port))
    except OSError:
        occupied.append(port)
    finally:
        sock.close()

if occupied:
    print("[STOP] Emulator ports occupied:", occupied)
    print("Existing processes were not stopped.")
    sys.exit(2)

print("[PASS] Emulator ports available.")
PY

printf -v ROOT_Q '%q' "$ROOT"

echo
echo "========== PHASE 1: BACKEND TESTS =========="

UNIT_COMMAND="cd $ROOT_Q && export GCLOUD_PROJECT=demo-mohallaflow FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 FUNCTIONS_EMULATOR=true && node --test --test-concurrency=1 functions/test/payroll.test.js functions/test/worker-private-migration-emulator.test.js functions/test/emergency-escalation.emulator.test.js functions/test/notification-scalar-migration.emulator.test.js"

run_emulator "auth,firestore" "$UNIT_COMMAND"

echo
echo "========== PHASE 2: PAYROLL CALLABLE =========="

CALLABLE_COMMAND="cd $ROOT_Q && export GCLOUD_PROJECT=demo-mohallaflow FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 FUNCTIONS_EMULATOR=true && node functions/test/payroll-callable.integration.js"

run_emulator "auth,firestore,functions" "$CALLABLE_COMMAND"

echo
echo "[SUCCESS] Both Functions Emulator QA phases passed."
echo "[INFO] Demo project only; no production deployment."
echo "[INFO] Emulator fixtures are cleaned by the test suites."
