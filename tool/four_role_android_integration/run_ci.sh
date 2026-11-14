#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

for executable in node firebase flutter python3 shasum; do
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

RULES_FILE="$ROOT/release/firestore/firestore.rules"
EXPECTED_RULES_SHA="c5172f7b37059687f4545af60787eb383e5c8f1c0f79572e3ae5e975915899ed"
ACTUAL_RULES_SHA="$(shasum -a 256 "$RULES_FILE" | awk '{print $1}')"
[[ "$ACTUAL_RULES_SHA" == "$EXPECTED_RULES_SHA" ]] || {
  echo "[STOP] Firestore Emulator rules SHA does not match the reviewed candidate." >&2
  exit 3
}

RUN_ID="${GITHUB_RUN_ID:-local-$$}"
CONFIG_FILE="$(mktemp "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/mohallaflow-four-role-${RUN_ID}.XXXXXX.json")"
COMMAND_FILE="$(mktemp "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/mohallaflow-four-role-${RUN_ID}.XXXXXX.sh")"

cleanup_files() {
  rm -f "$CONFIG_FILE" "$COMMAND_FILE"
}
trap cleanup_files EXIT

python3 - "$CONFIG_FILE" "$ROOT" <<'PY'
import json
import sys
from pathlib import Path

config_path = Path(sys.argv[1])
root = Path(sys.argv[2])
config = {
    "firestore": {
        "rules": str(root / "release/firestore/firestore.rules"),
        "indexes": str(root / "release/firestore/firestore.indexes.json"),
    },
    "emulators": {
        "auth": {"port": 9099},
        "firestore": {"port": 8080},
        "ui": {"enabled": False},
        "singleProjectMode": True,
    },
}
config_path.write_text(json.dumps(config, indent=2) + "\n", encoding="utf-8")
PY

python3 - <<'PY'
import socket
import sys

ports = (8080, 9099)
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
    print(f"[STOP] Emulator port(s) occupied: {occupied}", file=sys.stderr)
    sys.exit(2)

print("[PASS] Auth and Firestore Emulator ports are available.")
PY

cat > "$COMMAND_FILE" <<'COMMAND'
#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="${GITHUB_WORKSPACE:-$(pwd)}"
cd "$ROOT"

export GCLOUD_PROJECT=demo-mohallaflow
export FIRESTORE_EMULATOR_HOST=127.0.0.1:8080
export FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099

FIXTURE_MAY_EXIST=1
cleanup_fixture() {
  local result=$?
  trap - EXIT
  if [[ "$FIXTURE_MAY_EXIST" -eq 1 ]]; then
    echo
    echo "========== CLEAN UP FOUR-ROLE EMULATOR FIXTURE =========="
    node functions/test/four-role-app.seed.js cleanup || result=1
  fi
  exit "$result"
}
trap cleanup_fixture EXIT

echo "========== SEED FOUR SYNTHETIC ROLE ACCOUNTS =========="
node functions/test/four-role-app.seed.js seed

echo
echo "========== RUN FOUR-ROLE ANDROID APPLICATION ACCEPTANCE =========="
flutter test integration_test/four_role_application_integration_test.dart \
  --device-id emulator-5554 \
  --reporter expanded \
  --dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2

echo "[PASS] Four-role UI integration completed against demo-mohallaflow."
COMMAND

chmod +x "$COMMAND_FILE"

echo "========== FOUR-ROLE ANDROID FIREBASE EMULATOR INTEGRATION =========="
echo "Node: $NODE_VERSION"
echo "Project: demo-mohallaflow"
echo "Rules SHA256: $ACTUAL_RULES_SHA"
echo "Device: Android Emulator"
echo "Production Firebase is not accessed."

firebase emulators:exec \
  --only auth,firestore \
  --project demo-mohallaflow \
  --config "$CONFIG_FILE" \
  --non-interactive \
  "bash '$COMMAND_FILE'"

echo
echo "[SUCCESS] Four-role Android integration passed."
echo "[INFO] Auth and Firestore emulator fixtures were removed."
echo "[INFO] Production Firebase was not accessed or modified."
