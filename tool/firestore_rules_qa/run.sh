#!/usr/bin/env bash
set -euo pipefail

if command -v brew >/dev/null 2>&1; then
  NODE24_PREFIX="$(brew --prefix node@24 2>/dev/null || true)"
  if [[ -n "$NODE24_PREFIX" && -x "$NODE24_PREFIX/bin/node" ]]; then
    export PATH="$NODE24_PREFIX/bin:$PATH"
  fi
fi

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
CANDIDATE="$ROOT/qa_candidates/firestore_candidate_g.rules"
EXPECTED_SHA="7f30e3bdd6b6e244e66c33baaa32a6ee3ef04beb6799bc377f87f29bac8a2ab0"

for exe in node npm firebase python3; do
  command -v "$exe" >/dev/null 2>&1 || {
    echo "[STOP] Required command not found: $exe" >&2
    exit 2
  }
done

NODE_VERSION="$(node -p 'process.versions.node')"
NODE_MAJOR="${NODE_VERSION%%.*}"
NODE_MINOR="$(echo "$NODE_VERSION" | cut -d. -f2)"
if (( NODE_MAJOR < 24 || (NODE_MAJOR == 24 && NODE_MINOR < 12) )); then
  echo "[STOP] Firestore QA requires Node >=24.12.0; found $NODE_VERSION" >&2
  exit 2
fi

if [[ ! -f "$CANDIDATE" ]]; then
  echo "[STOP] Candidate rules file is missing: $CANDIDATE" >&2
  exit 2
fi

ACTUAL_SHA="$(shasum -a 256 "$CANDIDATE" | awk '{print $1}')"
if [[ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]]; then
  echo "[STOP] Candidate rules SHA does not match the validated Candidate G." >&2
  echo "Expected: $EXPECTED_SHA" >&2
  echo "Actual:   $ACTUAL_SHA" >&2
  exit 3
fi

QA_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/mohallaflow-rules-qa.XXXXXX")"
cp "$CANDIDATE" "$QA_ROOT/firestore.rules"
echo "[INFO] Candidate rules SHA256: $ACTUAL_SHA"
echo "[INFO] QA root: $QA_ROOT"
echo "[INFO] Tests use demo-mohallaflow Emulator fixtures only."
echo "[INFO] Production rules and data are not accessed or modified."

python3 "$HERE/MohallaFlow_Firestore_Rules_Authorization_QA.py" --root "$QA_ROOT"
python3 "$HERE/MohallaFlow_Worker_Attendance_Rules_QA.py" --root "$QA_ROOT"

echo "[SUCCESS] Firestore candidate QA complete (22 authorization + 10 attendance tests)."
rm -rf "$QA_ROOT"
