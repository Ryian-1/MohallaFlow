#!/usr/bin/env bash
set -euo pipefail

MODE="${1:---dry-run}"
if [[ "$MODE" != "--dry-run" && "$MODE" != "--apply" ]]; then
  echo "Usage: $0 [--dry-run|--apply]" >&2
  exit 2
fi

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "[STOP] Run this inside the MohallaFlow Git repository." >&2; exit 2;
}
cd "$ROOT"

TARGETS=(
  "android/app/google-services.json"
  "ios/Runner/GoogleService-Info.plist"
  "lib/firebase_options.dart"
)
TRACKED=()
for p in "${TARGETS[@]}"; do
  if git ls-files --error-unmatch -- "$p" >/dev/null 2>&1; then
    if [[ ! -f "$p" ]]; then
      echo "[STOP] Tracked local config is missing from working tree: $p" >&2
      exit 3
    fi
    if ! git diff --cached --quiet -- "$p"; then
      echo "[STOP] $p already has staged changes. Inspect before proceeding." >&2
      exit 4
    fi
    TRACKED+=("$p")
  else
    echo "[UNCHANGED] Not tracked: $p"
  fi
done

if [[ ${#TRACKED[@]} -eq 0 ]]; then
  echo "[OK] No tracked Firebase client configuration remains. Local files were not changed."
  exit 0
fi

echo "Firebase client configuration files that would be removed from the Git index:"
for p in "${TRACKED[@]}"; do echo "  - $p (local file will be retained)"; done

echo
echo "This operation stages deletions only. It does NOT delete local files, commit, push, or rewrite history."
if [[ "$MODE" == "--dry-run" ]]; then
  echo "[DRY RUN] No Git index changes made. Run with --apply only after reviewing this exact list."
  exit 0
fi

read -r -p "Type UNTRACK-LOCAL-FIREBASE-CONFIG to stage these index removals: " CONFIRM
if [[ "$CONFIRM" != "UNTRACK-LOCAL-FIREBASE-CONFIG" ]]; then
  echo "[CANCELLED] No changes made."
  exit 0
fi

git rm --cached -- "${TRACKED[@]}"
echo "[SUCCESS] Files are staged for removal from the next commit; local copies remain in place."
echo "Review with: git diff --cached --name-status"
