#!/usr/bin/env bash
set -Eeuo pipefail
PROJECT="mohallaflow"
EMULATOR_PROJECT="demo-mohallaflow"
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
for cmd in firebase gcloud node npm; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "[STOP] Missing $cmd" >&2; exit 2; }
done
NODE="$(node --version)"
[[ "${NODE#v}" == 22.* ]] || { echo "[STOP] Node.js 22 required; found $NODE" >&2; exit 2; }
[[ "$(gcloud config get-value project 2>/dev/null)" == "$PROJECT" ]] || { echo "[STOP] Run gcloud config set project $PROJECT" >&2; exit 2; }
CONFIG="$ROOT/firebase.json"
[[ -f "$CONFIG" ]] || CONFIG="$ROOT/firebase.json.example"
[[ -f "$CONFIG" ]] || { echo "[STOP] Firebase config missing." >&2; exit 2; }
EMULATOR_CONFIG="$ROOT/release/firestore/firebase.json"
[[ -f "$EMULATOR_CONFIG" ]] || { echo "[STOP] Isolated Firestore Emulator config missing: $EMULATOR_CONFIG" >&2; exit 2; }
python3 - "$CONFIG" <<'PY'
import json,sys
with open(sys.argv[1],encoding="utf-8") as f:c=json.load(f)
v=c.get("functions")
ok=(isinstance(v,dict) and v.get("source")=="functions") or (isinstance(v,list) and any(x.get("source")=="functions" for x in v))
if not ok:raise SystemExit("Firebase config must define Functions source ./functions.")
PY

# The FCM dispatcher is intentionally not deployed. Also refuse to continue
# when an older deployment of that function is still active.
EXISTING_PUSH_DISPATCHER="$(
  gcloud functions list --v2 --project "$PROJECT" --format=json |
    python3 -c 'import json,sys; rows=json.load(sys.stdin); names=[r.get("name","").rsplit("/",1)[-1] for r in rows if r.get("name","").rsplit("/",1)[-1]=="dispatchMohallaFlowPush"]; print("\\n".join(names))'
)
if [[ -n "$EXISTING_PUSH_DISPATCHER" ]]; then
  echo "[STOP] Existing Gen 2 FCM dispatcher detected:" >&2
  echo "$EXISTING_PUSH_DISPATCHER" >&2
  echo "This function can send native OS push notifications." >&2
  echo "Do not deploy Functions while it exists if device push must remain disabled." >&2
  echo "Review and intentionally remove only this function, then rerun the deploy script." >&2
  exit 4
fi

npm ci --prefix "$ROOT/functions"
npm run --prefix "$ROOT/functions" lint
npm run --prefix "$ROOT/functions" test:resident-registration
npm run --prefix "$ROOT/functions" test:app-check
echo "[CHECK] Running payroll backend tests in an isolated local Firestore Emulator ($EMULATOR_PROJECT)..."
firebase emulators:exec \
  --only firestore \
  --project "$EMULATOR_PROJECT" \
  --config "$EMULATOR_CONFIG" \
  "npm --prefix \"$ROOT/functions\" run test:payroll"
npm run --prefix "$ROOT/functions" test:worker-private-migration
npm audit --prefix "$ROOT/functions" --audit-level=moderate
echo "[CHECK] Verifying Firestore indexes are READY before Functions deployment..."
python3 "$ROOT/release/firestore/scripts/wait_for_indexes.py" \
  --timeout "${MOHALLAFLOW_INDEX_WAIT_SECONDS:-3600}" \
  --interval "${MOHALLAFLOW_INDEX_POLL_SECONDS:-20}"
echo "[CHECK] Verifying the active production Rules release SHA..."
python3 "$ROOT/release/firestore/scripts/verify_rules_release.py" --project "$PROJECT"
echo "This deploys only the six selected backend functions."
echo "The FCM dispatcher (dispatchMohallaFlowPush) is deliberately excluded from the deploy."
echo "This does NOT delete or disable a dispatcher that may already be deployed."
echo "Check 'firebase functions:list --project $PROJECT' and stop if it is present."
echo "In-app notification records and emergency escalation remain included."
echo "Deploy Firestore indexes and Rules first; configure App Check before callable use."
read -r -p "Type CONFIRMED dispatchMohallaFlowPush IS ABSENT to continue: " pushCheck
[[ "$pushCheck" == "CONFIRMED dispatchMohallaFlowPush IS ABSENT" ]] || {
  echo "[STOP] FCM dispatcher absence was not confirmed. No Functions changed."
  exit 0
}
read -r -p "Type DEPLOY MOHALLAFLOW FUNCTIONS to continue: " answer
[[ "$answer" == "DEPLOY MOHALLAFLOW FUNCTIONS" ]] || { echo "No Functions changed."; exit 0; }
cd "$ROOT"
firebase deploy \
  --only "functions:notifyEmergencySOSCreated,functions:notifyEmergencySOSUpdated,functions:escalateUnacknowledgedEmergencyAlerts,functions:claimResidentRegistration,functions:requestAccountDeletion,functions:approveColonyPayrollRun" \
  --project "$PROJECT" \
  --config "$CONFIG"
echo "[SUCCESS] Functions deploy command completed."
