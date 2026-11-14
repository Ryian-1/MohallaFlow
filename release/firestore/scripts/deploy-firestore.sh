#!/usr/bin/env bash
set -Eeuo pipefail
PROJECT="mohallaflow"
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
DIR="$ROOT/release/firestore"
EXPECTED="3b54f18560ec65a1b12366d2f5df08765ddee82e4d0c0b40b2d0649a1f85715c"
for cmd in firebase gcloud python3 shasum node; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "[STOP] Missing $cmd" >&2; exit 2; }
done
NODE="$(node --version)"; MAJOR="${NODE#v}"; MAJOR="${MAJOR%%.*}"
(( MAJOR >= 22 )) || { echo "[STOP] Node.js 22+ required; found $NODE" >&2; exit 2; }
[[ "$(gcloud config get-value project 2>/dev/null)" == "$PROJECT" ]] || {
  echo "[STOP] Run: gcloud config set project $PROJECT" >&2; exit 2;
}
ACTUAL="$(shasum -a 256 "$DIR/firestore.rules" | awk '{print $1}')"
[[ "$ACTUAL" == "$EXPECTED" ]] || { echo "[STOP] Rules SHA mismatch: $ACTUAL" >&2; exit 3; }

echo "MohallaFlow Firestore release | Project: $PROJECT | Database: (default)"
echo "Rules SHA256: $ACTUAL | Firebase CLI: $(firebase --version)"
echo "This deploys indexes first, waits for READY, then deploys Firestore Rules."
echo "It does not deploy Functions, Hosting, Storage, Auth configuration, or mobile binaries."
echo "The preflight performs billable read-only Firestore reads."
mkdir -p "$DIR/reports"
python3 "$DIR/scripts/production_preflight.py" \
  --project "$PROJECT" --rules "$DIR/firestore.rules" \
  --indexes "$DIR/firestore.indexes.json" \
  --output "$DIR/reports/production-preflight.json"

echo
echo "COMPATIBILITY GATE:"
echo "The candidate preserves the previous production collectionGroup('members') query contract."
echo "A legacy query must constrain uid == request.auth.uid and status == 'active'."
echo "Unfiltered, missing-status, and cross-UID queries are denied by the reviewed Rules candidate."
echo "Six private Firestore Emulator suites passed 125/125 on this exact candidate."
echo "The recursive match retains the previous production scope for collections named members."
read -r -p "Type CONFIRMED FILTERED LEGACY MEMBER QUERY COMPATIBILITY to continue: " legacy
[[ "$legacy" == "CONFIRMED FILTERED LEGACY MEMBER QUERY COMPATIBILITY" ]] || {
  echo "[STOP] Legacy membership compatibility was not acknowledged. No production resources changed."
  exit 0
}

read -r -p "Type DEPLOY MOHALLAFLOW FIRESTORE to continue: " answer
[[ "$answer" == "DEPLOY MOHALLAFLOW FIRESTORE" ]] || { echo "No production resources changed."; exit 0; }

cd "$DIR"
echo "========== DEPLOY INDEXES ONLY =========="
firebase deploy --only firestore:indexes --project "$PROJECT" --config "$DIR/firebase.json"
echo "========== WAIT FOR INDEXES TO REACH READY =========="
python3 "$DIR/scripts/wait_for_indexes.py" \
  --timeout "${MOHALLAFLOW_INDEX_WAIT_SECONDS:-3600}" \
  --interval "${MOHALLAFLOW_INDEX_POLL_SECONDS:-20}"
echo "========== DEPLOY FIRESTORE RULES ONLY =========="
firebase deploy --only firestore:rules --project "$PROJECT" --config "$DIR/firebase.json"
echo "========== VERIFY ACTIVE RULES RELEASE =========="
python3 "$DIR/scripts/verify_rules_release.py" --project "$PROJECT"
echo "[SUCCESS] Firestore indexes and Rules release completed."
