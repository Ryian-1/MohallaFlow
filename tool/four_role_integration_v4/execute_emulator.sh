#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

export FIRESTORE_EMULATOR_HOST="127.0.0.1:8080"
export FIREBASE_AUTH_EMULATOR_HOST="127.0.0.1:9099"

NODE_BIN="$(command -v node)"
FLUTTER_BIN="$HOME/development/flutter/bin/flutter"
SEED="$ROOT/functions/test/four-role-app.seed.js"
DEVICE_ID="41EED4CF-A244-41CF-8FC5-39C488312916"
PLIST="$ROOT/ios/Runner/GoogleService-Info.plist"

PLIST_BACKUP=""
PLIST_MODIFIED=0
ORIGINAL_PLIST_SHA=""
SEEDED=0

cleanup() {
  local result=$?
  local restored=1
  trap - EXIT

  if [[ "$PLIST_MODIFIED" -eq 1 ]]; then
    echo
    echo "========== RESTORE ORIGINAL IOS FIREBASE PLIST =========="

    if [[ -f "$PLIST_BACKUP" ]] && cp -p "$PLIST_BACKUP" "$PLIST"; then
      touch "$PLIST"
      RESTORED_SHA="$(shasum -a 256 "$PLIST" | awk '{print $1}')"

      if [[ "$RESTORED_SHA" == "$ORIGINAL_PLIST_SHA" ]]; then
        echo "[PASS] Original plist content restored exactly."
        PLIST_MODIFIED=0
      else
        echo "[STOP] Restored plist SHA does not match original." >&2
        restored=0
        result=1
      fi
    else
      echo "[STOP] Could not restore the original plist." >&2
      echo "[RECOVERY] Backup: $PLIST_BACKUP" >&2
      restored=0
      result=1
    fi
  fi

  if [[ "$restored" -eq 1 && -n "$PLIST_BACKUP" ]]; then
    rm -f "$PLIST_BACKUP"
  elif [[ -n "$PLIST_BACKUP" ]]; then
    echo "[RECOVERY] Original plist backup retained: $PLIST_BACKUP" >&2
  fi

  if [[ "$SEEDED" -eq 1 ]]; then
    echo
    echo "========== CLEAN UP FOUR-ROLE FIXTURES =========="
    if ! "$NODE_BIN" "$SEED" cleanup; then
      echo "[WARNING] Emulator fixture cleanup failed." >&2
      result=1
    fi
  fi

  exit "$result"
}
trap cleanup EXIT

echo "========== VERIFY IOS PLIST SAFETY =========="

if [[ ! -f "$PLIST" ]]; then
  echo "[STOP] Required iOS GoogleService-Info.plist is missing." >&2
  exit 2
fi

if git ls-files --error-unmatch ios/Runner/GoogleService-Info.plist >/dev/null 2>&1; then
  echo "[STOP] Refusing to modify a tracked Firebase plist." >&2
  exit 2
fi

if ! git check-ignore -q -- ios/Runner/GoogleService-Info.plist; then
  echo "[STOP] Firebase plist is not ignored by Git. Refusing to modify." >&2
  exit 2
fi

ORIGINAL_PROJECT_ID="$(plutil -extract PROJECT_ID raw -o - "$PLIST")"

if [[ "$ORIGINAL_PROJECT_ID" != "mohallaflow" ]]; then
  echo "[STOP] Unexpected original plist project ID: $ORIGINAL_PROJECT_ID" >&2
  echo "Expected mohallaflow. No plist modification made." >&2
  exit 2
fi

ORIGINAL_PLIST_SHA="$(shasum -a 256 "$PLIST" | awk '{print $1}')"
PLIST_BACKUP="$(mktemp "${TMPDIR:-/tmp}/mohallaflow-google-service.XXXXXX")"
cp -p "$PLIST" "$PLIST_BACKUP"

echo "[PASS] Original plist is ignored and backed up."
echo "[INFO] Original plist SHA256: $ORIGINAL_PLIST_SHA"

echo
echo "========== SEED AUTH + FIRESTORE EMULATORS =========="
SEEDED=1
"$NODE_BIN" "$SEED" seed

echo
echo "========== TEMPORARILY CONFIGURE IOS FOR DEMO PROJECT =========="

# Set the flag before editing so EXIT cleanup restores even after a
# partially completed plist write.
PLIST_MODIFIED=1

python3 - "$PLIST" <<'PY'
import plistlib
import sys
from pathlib import Path

path = Path(sys.argv[1])

with path.open("rb") as stream:
    data = plistlib.load(stream)

if data.get("PROJECT_ID") != "mohallaflow":
    raise SystemExit("Unexpected plist project ID; refusing to modify.")

data["PROJECT_ID"] = "demo-mohallaflow"

with path.open("wb") as stream:
    plistlib.dump(data, stream, sort_keys=False)

print("Temporarily changed only PROJECT_ID for the emulator test.")
PY

plutil -lint "$PLIST"

TEMP_PROJECT_ID="$(plutil -extract PROJECT_ID raw -o - "$PLIST")"
if [[ "$TEMP_PROJECT_ID" != "demo-mohallaflow" ]]; then
  echo "[STOP] Temporary plist project ID validation failed." >&2
  exit 3
fi

echo "[PASS] iOS native Firebase project ID is demo-mohallaflow."

echo
echo "========== RUN FOUR-ROLE IOS INTEGRATION TEST =========="

"$FLUTTER_BIN" test \
  "$ROOT/integration_test/four_role_application_integration_test.dart" \
  --device-id "$DEVICE_ID" \
  --reporter expanded
