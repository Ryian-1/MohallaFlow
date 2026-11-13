#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

if command -v brew >/dev/null 2>&1; then
  NODE24_PREFIX="$(brew --prefix node@24 2>/dev/null || true)"
  if [[ -n "$NODE24_PREFIX" && -x "$NODE24_PREFIX/bin/node" ]]; then
    export PATH="$NODE24_PREFIX/bin:$PATH"
  fi
fi

export PATH="$HOME/development/flutter/bin:$PATH"
hash -r

NODE_BIN="$(command -v node || true)"
FIREBASE_BIN="$(command -v firebase || true)"

for pair in "node:$NODE_BIN" "firebase:$FIREBASE_BIN"; do
  name="${pair%%:*}"
  path="${pair#*:}"
  [[ -n "$path" && -x "$path" ]] || {
    echo "[STOP] Required executable missing: $name" >&2
    exit 2
  }
done

NODE_VERSION="$("$NODE_BIN" -p 'process.versions.node')"
NODE_MAJOR="${NODE_VERSION%%.*}"

if (( NODE_MAJOR < 24 )); then
  echo "[STOP] Node 24 or later is required; found $NODE_VERSION." >&2
  exit 2
fi

CANDIDATE="$ROOT/qa_candidates/firestore_candidate_g.rules"
EXPECTED_SHA="7f30e3bdd6b6e244e66c33baaa32a6ee3ef04beb6799bc377f87f29bac8a2ab0"

[[ -f "$CANDIDATE" ]] || {
  echo "[STOP] Candidate Firestore rules file is missing." >&2
  exit 2
}

ACTUAL_SHA="$(shasum -a 256 "$CANDIDATE" | awk '{print $1}')"

if [[ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]]; then
  echo "[STOP] Candidate rules SHA does not match the validated revision." >&2
  echo "Expected: $EXPECTED_SHA" >&2
  echo "Actual:   $ACTUAL_SHA" >&2
  exit 3
fi

QA_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/mohallaflow-four-role.XXXXXX")"

cleanup_workspace() {
  local result=$?
  if [[ "$result" -eq 0 && "${MOHALLAFLOW_KEEP_QA:-0}" != "1" ]]; then
    rm -rf "$QA_ROOT"
  else
    echo "[INFO] Emulator config retained at: $QA_ROOT"
  fi
}
trap cleanup_workspace EXIT

cp "$CANDIDATE" "$QA_ROOT/firestore.rules"

cat > "$QA_ROOT/firebase.json" <<'JSON'
{
  "firestore": {
    "rules": "firestore.rules"
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
    "ui": {
      "enabled": false
    },
    "singleProjectMode": false
  }
}
JSON

echo "========== FOUR-ROLE APPLICATION INTEGRATION =========="
echo "Node: $NODE_VERSION"
echo "Project: demo-mohallaflow"
echo "Firestore rules SHA256: $ACTUAL_SHA"
echo "Device: iPhone 18 Pro simulator"
echo

echo "========== EMULATOR PORT CHECK =========="

python3 - <<'PORTCHECK'
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
    print(
        "[STOP] Emulator port(s) already occupied: "
        + ", ".join(str(port) for port in occupied)
    )
    print("Existing processes were not stopped.")
    sys.exit(2)

print("[PASS] Firestore 8080 and Auth 9099 are available.")
PORTCHECK

echo
echo "========== START EMULATORS AND EXECUTE TEST =========="

"$FIREBASE_BIN" emulators:exec \
  --only auth,firestore \
  --project demo-mohallaflow \
  --config "$QA_ROOT/firebase.json" \
  --non-interactive \
  "bash \"$ROOT/tool/four_role_integration_v4/execute_emulator.sh\""

echo
echo "[SUCCESS] Four-role application integration test passed."
echo "[INFO] Auth and Firestore Emulator fixtures were cleaned up."
echo "[INFO] Production Firebase was not accessed or modified."
