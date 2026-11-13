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

NODE_BIN="$(command -v node || true)"
NPM_BIN="$(command -v npm || true)"
FIREBASE_BIN="$(command -v firebase || true)"

for pair in \
  "node:$NODE_BIN" \
  "npm:$NPM_BIN" \
  "firebase:$FIREBASE_BIN"; do
  name="${pair%%:*}"
  path="${pair#*:}"
  [[ -n "$path" && -x "$path" ]] || {
    echo "[STOP] Required executable missing: $name" >&2
    exit 2
  }
done

NODE_VERSION="$("$NODE_BIN" -p 'process.versions.node')"
IFS=. read -r NODE_MAJOR NODE_MINOR _ <<< "$NODE_VERSION"

if (( NODE_MAJOR < 24 || (NODE_MAJOR == 24 && NODE_MINOR < 12) )); then
  echo "[STOP] Extended Rules QA requires Node >=24.12.0; found $NODE_VERSION" >&2
  exit 2
fi

CANDIDATE="$ROOT/qa_candidates/firestore_candidate_g.rules"
TEST_SOURCE="$ROOT/firestore-rules-tests"
EXPECTED_SHA="7f30e3bdd6b6e244e66c33baaa32a6ee3ef04beb6799bc377f87f29bac8a2ab0"

for file in \
  "$CANDIDATE" \
  "$TEST_SOURCE/package.json" \
  "$TEST_SOURCE/package-lock.json"; do
  [[ -f "$file" ]] || {
    echo "[STOP] Required file missing: $file" >&2
    exit 2
  }
done

ACTUAL_SHA="$(shasum -a 256 "$CANDIDATE" | awk '{print $1}')"

if [[ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]]; then
  echo "[STOP] Candidate rules SHA mismatch." >&2
  echo "Expected: $EXPECTED_SHA" >&2
  echo "Actual:   $ACTUAL_SHA" >&2
  exit 3
fi

QA_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/mohallaflow-extended-rules.XXXXXX")"
QA_TESTS="$QA_ROOT/firestore-rules-tests"

cleanup() {
  local result=$?
  if [[ "$result" -eq 0 && "${MOHALLAFLOW_KEEP_QA:-0}" != "1" ]]; then
    rm -rf "$QA_ROOT"
  else
    echo "[INFO] QA workspace retained: $QA_ROOT"
  fi
}
trap cleanup EXIT

mkdir -p "$QA_TESTS" "$QA_ROOT/qa_candidates"

cp "$CANDIDATE" "$QA_ROOT/firestore.rules"
cp "$CANDIDATE" "$QA_ROOT/qa_candidates/firestore_candidate_g.rules"
cp "$TEST_SOURCE/package.json" "$QA_TESTS/package.json"
cp "$TEST_SOURCE/package-lock.json" "$QA_TESTS/package-lock.json"

shopt -s nullglob
TEST_FILES=("$TEST_SOURCE"/*.test.js)
shopt -u nullglob

if [[ "${#TEST_FILES[@]}" -eq 0 ]]; then
  echo "[STOP] No standalone Firestore test files found." >&2
  exit 4
fi

cp "${TEST_FILES[@]}" "$QA_TESTS/"

cat > "$QA_ROOT/firebase.json" <<'JSON'
{
  "firestore": {
    "rules": "firestore.rules"
  },
  "emulators": {
    "firestore": {
      "port": 8080
    },
    "singleProjectMode": false
  }
}
JSON

echo "========== EXTENDED FIRESTORE RULES QA =========="
echo "Node: $NODE_VERSION"
echo "Firebase CLI: $("$FIREBASE_BIN" --version)"
echo "Candidate SHA256: $ACTUAL_SHA"
echo "Test files: ${#TEST_FILES[@]}"
echo "Workspace: $QA_ROOT"
echo

echo "========== FIRESTORE EMULATOR PORT CHECK =========="

python3 - <<'PORTCHECK'
import socket
import sys

sock = socket.socket()
try:
    sock.bind(("127.0.0.1", 8080))
except OSError:
    print("[STOP] Port 8080 is occupied. Existing processes will not be stopped.")
    sys.exit(2)
finally:
    sock.close()

print("[PASS] Port 8080 is available.")
PORTCHECK

echo
echo "========== CLEAN LOCKFILE INSTALL =========="

(
  cd "$QA_TESTS"
  "$NPM_BIN" ci --no-audit --no-fund
)

echo
echo "========== DEPENDENCY SECURITY AUDIT =========="

(
  cd "$QA_TESTS"
  "$NPM_BIN" audit --audit-level=moderate
)

echo
echo "========== RUN ALL STANDALONE TESTS =========="

printf -v QA_TESTS_Q '%q' "$QA_TESTS"
printf -v NODE_BIN_Q '%q' "$NODE_BIN"

printf -v QA_RULES_Q '%q' "$QA_ROOT/firestore.rules"
TEST_COMMAND="cd $QA_TESTS_Q && CANDIDATE_RULES=$QA_RULES_Q $NODE_BIN_Q --test --test-concurrency=1 --test-reporter=spec ./*.test.js"

cd "$QA_ROOT"

"$FIREBASE_BIN" emulators:exec \
  --only firestore \
  --project demo-mohallaflow \
  --config "$QA_ROOT/firebase.json" \
  --non-interactive \
  "$TEST_COMMAND"

echo
echo "[SUCCESS] Extended Firestore Rules Emulator suite passed."
echo "[INFO] Candidate rules were tested in an isolated demo project."
echo "[INFO] Production Firebase was not accessed or modified."
