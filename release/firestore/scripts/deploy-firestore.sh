#!/usr/bin/env bash
set -Eeuo pipefail
PROJECT="mohallaflow"
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
DIR="$ROOT/release/firestore"
EXPECTED="c5172f7b37059687f4545af60787eb383e5c8f1c0f79572e3ae5e975915899ed"
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
echo "The reviewed app uses direct member-document reads."
echo "The reviewed Rules candidate removes the old recursive collection-group member list permission."
echo "Do not continue if an older deployed app or external integration still queries collectionGroup('members')."
read -r -p "Type CONFIRMED NO LEGACY MEMBER QUERIES to continue: " legacy
[[ "$legacy" == "CONFIRMED NO LEGACY MEMBER QUERIES" ]] || {
  echo "[STOP] Legacy-client compatibility was not confirmed. No production resources changed."
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
