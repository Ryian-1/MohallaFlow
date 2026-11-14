#!/usr/bin/env bash
set -Eeuo pipefail
PROJECT="mohallaflow"
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
python3 - "$CONFIG" <<'PY'
import json,sys
with open(sys.argv[1],encoding="utf-8") as f:c=json.load(f)
v=c.get("functions")
ok=(isinstance(v,dict) and v.get("source")=="functions") or (isinstance(v,list) and any(x.get("source")=="functions" for x in v))
if not ok:raise SystemExit("Firebase config must define Functions source ./functions.")
PY
npm ci --prefix "$ROOT/functions"
npm run --prefix "$ROOT/functions" lint
npm run --prefix "$ROOT/functions" test:resident-registration
npm run --prefix "$ROOT/functions" test:app-check
npm run --prefix "$ROOT/functions" test:payroll
npm run --prefix "$ROOT/functions" test:worker-private-migration
npm audit --prefix "$ROOT/functions" --audit-level=moderate
echo "This deploy updates every exported Cloud Function, including scheduled and trigger functions."
echo "Deploy Firestore indexes and Rules first; configure App Check before callable use."
read -r -p "Type DEPLOY MOHALLAFLOW FUNCTIONS to continue: " answer
[[ "$answer" == "DEPLOY MOHALLAFLOW FUNCTIONS" ]] || { echo "No Functions changed."; exit 0; }
cd "$ROOT"
firebase deploy --only functions --project "$PROJECT" --config "$CONFIG"
echo "[SUCCESS] Functions deploy command completed."
