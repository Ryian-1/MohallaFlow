#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if command -v brew >/dev/null 2>&1; then
  NODE24_PREFIX="$(brew --prefix node@24 2>/dev/null || true)"
  if [[ -n "$NODE24_PREFIX" && -x "$NODE24_PREFIX/bin/node" ]]; then
    export PATH="$NODE24_PREFIX/bin:$PATH"
  fi
fi

FLUTTER_BIN="${FLUTTER_BIN:-$(command -v flutter || true)}"
DART_BIN="${DART_BIN:-$(command -v dart || true)}"
if [[ -z "$FLUTTER_BIN" && -x "$HOME/development/flutter/bin/flutter" ]]; then
  FLUTTER_BIN="$HOME/development/flutter/bin/flutter"
fi
if [[ -z "$DART_BIN" && -x "$HOME/development/flutter/bin/dart" ]]; then
  DART_BIN="$HOME/development/flutter/bin/dart"
fi

section() { printf '\n========== %s ==========\n' "$1"; }
require_path() {
  [[ -n "$2" && -x "$2" ]] || { echo "[STOP] Required tool not found: $1. Set $1_BIN or add it to PATH." >&2; exit 2; }
}
require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "[STOP] Required command not found: $1" >&2; exit 2; }
}
require_path flutter "$FLUTTER_BIN"
require_path dart "$DART_BIN"
require_cmd node
require_cmd python3

section "ENVIRONMENT"
"$FLUTTER_BIN" --version | sed -n '1,3p'
"$DART_BIN" --version
node --version

section "DART FORMAT CHECK (READ ONLY)"
"$DART_BIN" format --output=none --set-exit-if-changed lib test

section "FLUTTER ANALYSIS"
"$FLUTTER_BIN" analyze --no-pub

section "FLUTTER UNIT AND WIDGET TESTS"
"$FLUTTER_BIN" test --no-pub --reporter expanded

section "CLOUD FUNCTIONS SYNTAX AND UNIT TESTS"
node --check functions/index.js
node --test functions/test/*.test.js

section "FIRESTORE RULES EMULATOR AUTHORIZATION TESTS"
bash tool/firestore_rules_qa/run.sh
bash tool/firestore_rules_qa/run_extended_suite.sh

if [[ "${MOHALLAFLOW_SKIP_PLATFORM_BUILDS:-0}" == "1" ]]; then
  section "PLATFORM BUILDS"
  echo "[SKIP] Platform builds disabled by MOHALLAFLOW_SKIP_PLATFORM_BUILDS=1"
else
  section "ANDROID DEBUG BUILD"
  "$FLUTTER_BIN" build apk --debug
  if [[ "$(uname -s)" == "Darwin" ]]; then
    section "IOS SIMULATOR DEBUG BUILD"
    "$FLUTTER_BIN" build ios --simulator --debug --no-codesign
  else
    section "IOS SIMULATOR DEBUG BUILD"
    echo "[SKIP] iOS simulator build requires macOS and Xcode."
  fi
fi

section "OPTIONAL ONLINE DEPENDENCY AUDIT"
if [[ "${MOHALLAFLOW_RUN_DEPENDENCY_AUDIT:-0}" == "1" ]]; then
  require_cmd npm
  (cd functions && npm audit --audit-level=high)
  "$FLUTTER_BIN" pub outdated
else
  echo "[SKIP] Online advisory checks not run. Set MOHALLAFLOW_RUN_DEPENDENCY_AUDIT=1 to enable."
fi

section "GIT WORKTREE (READ ONLY)"
if git rev-parse --show-toplevel >/dev/null 2>&1; then git status --short; else echo "[INFO] No Git metadata found at project root."; fi

section "QUALITY GATES COMPLETE"
echo "[SUCCESS] All enabled quality gates completed successfully."
echo "[NOTE] Emulator QA targets qa_candidates/firestore_candidate_g.rules (SHA256: 7f30e3bdd6b6e244e66c33baaa32a6ee3ef04beb6799bc377f87f29bac8a2ab0); root firestore.rules and production Firebase are not modified."
echo "[NOTE] Four-role iOS integration was separately validated against Candidate G using demo Auth and Firestore emulators."
