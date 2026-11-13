# Stage 6 — Worker medical and emergency-contact privacy

## Data boundary

Operational worker records remain at:

`colonies/{colonyId}/cleanlinessWorkers/{workerId}`

They contain only operational fields (name, work contact number, assigned area, status and audit metadata). These may be read by the colony Admin, Cleanliness Manager and the linked worker.

Private worker data is separated at:

`colonies/{colonyId}/workerPrivateProfiles/{workerId}`

It contains blood group and optional family/emergency contact fields plus consent metadata. A worker can read and update only their own private profile. A Cleanliness Manager cannot get or list private profiles. The Colony Admin can get an individual private profile only when `consentStatus == "granted"`. Collection listing is denied.

## Consent behavior

- Medical and family emergency details are optional.
- A worker must actively opt in before their private data is shared with the Colony Admin.
- The worker may revoke consent; revocation clears the private fields and changes the status to `not_provided`.
- Legacy records migrated from the old worker document are marked `pending`, not `granted`. The Admin cannot read these records until the worker reviews the notice and opts in.
- Cleanliness Managers continue to see operational phone and assignment data needed for task allocation, but not blood group or family emergency details.

The current notice version is `worker-private-v1`. It must be reviewed by Indian privacy counsel before production use.

## Emulator-only legacy migration

The migration script is hard-blocked unless `FIRESTORE_EMULATOR_HOST` is `127.0.0.1:8080` or `localhost:8080` and the project is `demo-mohallaflow`.

Run the emulator-backed migration test from `functions/` using a temporary Firebase config (the repository intentionally has no root production `firebase.json`):

```bash
cd "$HOME/development/MohallaFlow_Stage5_Remediation/functions"
TMP_CONFIG="$(mktemp -d)"
cp ../qa_candidates/firestore_candidate_v2.rules "$TMP_CONFIG/firestore.rules"
cat > "$TMP_CONFIG/firebase.json" <<'JSON'
{
  "firestore": { "rules": "firestore.rules" },
  "emulators": { "firestore": { "port": 8080 }, "singleProjectMode": false }
}
JSON
firebase emulators:exec --only firestore --project demo-mohallaflow \
  --config "$TMP_CONFIG/firebase.json" --non-interactive \
  "npm run test:worker-private-migration-emulator"
rm -rf "$TMP_CONFIG"
```

The integration test seeds synthetic legacy records, runs the migration, and verifies the old fields are removed, legacy data is marked pending consent, and an existing consented private profile is preserved. The CLI migration defaults to dry-run; add `--apply` only after reviewing its report. The migration copies each legacy private field to the private subcollection and removes the old fields from the operational worker document in the same batch. It is idempotent and preserves an existing private profile over legacy values.

This script intentionally cannot migrate production. A production migration requires a verified backup, an approved maintenance window, explicit owner approval, a separately reviewed production migration procedure, and post-migration verification. Do not manually disable the emulator guard.

## Production rollout order (not performed)

1. Back up production Firestore and prove a restore in a separate project.
2. Obtain privacy/legal approval for notice, consent and retention text.
3. Produce a separately reviewed production migration plan and dry-run report.
4. With explicit approval, migrate legacy private fields before enforcing the new schema rules.
5. Deploy reviewed Firestore rules and Functions only after approval.
6. Release the client update and verify worker self-access, Admin consent-gated access and Manager denial.
7. Retain an audit trail of consent grants and revocations without retaining the removed private values in operational logs.

No production data has been changed by this patch.
