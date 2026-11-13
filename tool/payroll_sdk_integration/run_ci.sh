#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

for executable in node firebase flutter python3; do
  command -v "$executable" >/dev/null 2>&1 || {
    echo "[STOP] Required command not found: $executable" >&2
    exit 2
  }
done

NODE_VERSION="$(node -p 'process.versions.node')"
[[ "${NODE_VERSION%%.*}" == "22" ]] || {
  echo "[STOP] Node.js 22 is required; found $NODE_VERSION." >&2
  exit 2
}

RUN_ID="${GITHUB_RUN_ID:-local-$$}"
RULES_FILE="$ROOT/.firestore-payroll-sdk-qa-${RUN_ID}.rules"
CONFIG_FILE="$ROOT/.firebase-payroll-sdk-qa-${RUN_ID}.json"
COMMAND_FILE="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/mohallaflow-payroll-sdk-${RUN_ID}.sh"

cleanup_files() {
  rm -f "$RULES_FILE" "$CONFIG_FILE" "$COMMAND_FILE"
}
trap cleanup_files EXIT

for file in "$RULES_FILE" "$CONFIG_FILE"; do
  [[ ! -e "$file" ]] || {
    echo "[STOP] Temporary QA file already exists: $file" >&2
    exit 2
  }
done

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
    print("[STOP] Emulator port(s) occupied:", occupied)
    print("Existing processes were not stopped.")
    sys.exit(2)

print("[PASS] Firebase Emulator ports are available.")
PY

cat > "$RULES_FILE" <<'RULES'
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isActiveColonyAdmin(colonyId) {
      return request.auth != null
        && exists(
          /databases/$(database)/documents/colonies/$(colonyId)/members/$(request.auth.uid)
        )
        && get(
          /databases/$(database)/documents/colonies/$(colonyId)/members/$(request.auth.uid)
        ).data.uid == request.auth.uid
        && get(
          /databases/$(database)/documents/colonies/$(colonyId)/members/$(request.auth.uid)
        ).data.colonyId == colonyId
        && get(
          /databases/$(database)/documents/colonies/$(colonyId)/members/$(request.auth.uid)
        ).data.role == 'admin'
        && get(
          /databases/$(database)/documents/colonies/$(colonyId)/members/$(request.auth.uid)
        ).data.status == 'active';
    }

    match /colonies/{colonyId}/colonyPayrollRuns/{runId} {
      allow get: if isActiveColonyAdmin(colonyId);

      match /entries/{entryId} {
        allow get: if isActiveColonyAdmin(colonyId);
      }
    }
  }
}
RULES

cat > "$CONFIG_FILE" <<JSON
{
  "functions": {
    "source": "functions",
    "runtime": "nodejs22"
  },
  "firestore": {
    "rules": "$(basename "$RULES_FILE")"
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

cat > "$COMMAND_FILE" <<'COMMAND'
#!/usr/bin/env bash
set -Eeuo pipefail

export GCLOUD_PROJECT=demo-mohallaflow
export FIRESTORE_EMULATOR_HOST=127.0.0.1:8080
export FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099
export FUNCTIONS_EMULATOR=true

cleanup_fixture() {
  node functions/test/payroll-flutter-sdk.seed.js cleanup
}
trap cleanup_fixture EXIT

node functions/test/payroll-flutter-sdk.seed.js seed

flutter test integration_test/payroll_callable_sdk_test.dart \
  --device-id emulator-5554 \
  --reporter expanded \
  --dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2
COMMAND

chmod +x "$COMMAND_FILE"

echo "========== PAYROLL FLUTTER SDK EMULATOR INTEGRATION =========="
echo "Node: $NODE_VERSION"
echo "Project: demo-mohallaflow"
echo "Fixture: temporary payroll-only read rules; not production rules"
echo "Device: Android Emulator"
echo

firebase emulators:exec \
  --only auth,firestore,functions \
  --project demo-mohallaflow \
  --config "$CONFIG_FILE" \
  --non-interactive \
  "bash '$COMMAND_FILE'"

echo
echo "[SUCCESS] Flutter payroll callable SDK integration passed."
echo "[INFO] Only the demo-mohallaflow Emulator project was used."
echo "[INFO] Temporary QA rules/configuration were removed."
echo "[INFO] Production Firebase was not accessed or modified."
