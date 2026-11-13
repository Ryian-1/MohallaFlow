# MohallaFlow — Stage 6 pre-launch findings and closure gates

**Assessment date:** 9 November 2026
**Source:** `remediation/stage5-hardening` source snapshot supplied for the Stage 6 audit.
**Production status:** Not approved for real-colony operational dependence.
**Deployment policy:** No production Firebase changes, store submissions, GitHub publication or push activation without explicit owner approval.

This document distinguishes code that is already present from owner-controlled steps that require a real Firebase project, signing material, a public web domain, or legal/retention decisions. A local implementation is not marked production-complete until the relevant environment-specific test is recorded.

## Eight findings

| # | Finding | Source evidence / current state | Closure status |
|---|---|---|---|
| 1 | Multi-colony security | Candidate rules are colony-scoped. `tenant-isolation-exhaustive.test.js` contains 124 unique match-path templates and checks get/list denial for Admin, Resident, Cleanliness Manager and Worker identities from Tenant A against Tenant B. It also includes cross-tenant write probes. The complete rules suite contains 115 named tests across seven files. | **Test source present; execution required.** The audit runtime could not complete `npm ci` within its command window, so this audit did not reproduce the suite. Run `bash tool/firestore_rules_qa/run_extended_suite.sh` on the Node 24.12+ development machine. The candidate SHA pinned by both QA runners must match before any rules are considered for deployment. A passing client-rules suite still does not replace separate callable/Admin SDK tenant-authorization tests. |
| 2 | Account deletion and data lifecycle | All four role dashboards expose an in-app deletion-request route. `AccountDeletionRequestScreen` calls `requestAccountDeletion`; the callable records an authenticated, idempotent request. It intentionally does not remove Auth or colony records automatically. | **In-app initiation present; end-to-end deletion incomplete.** Apple expects users to initiate account deletion in-app and expects deletion of the account and associated data not legally required to be retained. Google Play additionally requires a functional external web resource that permits a deletion request without reinstalling the app. A verified web identity flow, external page/domain, case processing, completion evidence, lawful-retention reasons and user notifications remain required. Do not delete financial/payroll/safety/audit records blindly. |
| 3 | Android release signing | `android/app/build.gradle.kts` defines a dedicated release signing config and deliberately fails release packaging unless a local keystore and passwords are supplied. `docs/STAGE6_ANDROID_RELEASE_SIGNING.md` documents local key generation. Debug build succeeded; no release AAB has been signed. | **Fail-closed code present; owner key setup required.** Generate and back up the upload key outside the repo, set local environment variables, build an AAB, inspect its signature and compare the certificate fingerprint with Play Console. Do not send key material to chat or commit it. |
| 4 | App Check and monitoring | Flutter initializes App Check, Crashlytics and Performance Monitoring. Debug uses debug providers; release selects Play Integrity (Android) and App Attest (Apple). Crash and performance collection are disabled in debug and enabled in non-debug builds. | **Client integration present; callable enforcement added in this patch.** The three v2 callable Functions now enforce App Check by default outside the Functions Emulator. The Emulator bypass is explicit to preserve local testing. Firebase Console app registration, registered debug tokens for test devices, Firestore App Check enforcement, production attestation smoke tests and Crashlytics symbolication remain owner/environment checks. App Check is not a replacement for Firebase Authentication or tenant authorization. |
| 5 | Firestore backups and restore | No verified production backup schedule or restore exercise was supplied. Firestore managed scheduled backups require Blaze and can retain backups for up to 14 weeks; backup storage and restore operations are billed. | **Not configured or verified.** Before launch, obtain explicit approval for billing and backup setup. Create a daily schedule (retention to be approved), record the backup resource, restore a chosen backup into an isolated staging database/project, verify documents and indexes, and record measured RPO/RTO. Never restore over live production as a test. |
| 6 | Document-version retention and deletion | The repository stores file content as Firestore 512 KiB chunks under immutable version documents. The UI explicitly says versions are retained and cannot be deleted in-app; archival only removes publication access. Client rules deny direct deletes. | **Retention policy and deletion workflow incomplete.** Do not weaken client rules or add a generic client-side recursive delete. Approve category-specific retention periods, legal holds, user-request handling, audit evidence and purge authority with counsel. Implement a server-side, tenant-authorized, idempotent purge after the retention date and legal-hold check; test recursive removal of version/chunk subcollections and verify the audit trail remains. No retention duration has been invented in this patch. |
| 7 | Remote push | `PushNotificationService._remotePushEnabled` is deliberately `false`; the in-app notification centre remains. | **Intentionally deferred by product decision, not silently enabled.** Keep remote OS push disabled until APNs credentials, FCM delivery, Android channels, permission disclosures, token lifecycle and real-device delivery are tested. The pilot must not rely on background SOS push while it is disabled; define an alternative escalation/contact procedure. |
| 8 | Worker personal-data exposure | Work contact and assigned area live in `cleanlinessWorkers`. Blood group and family/emergency contact are separated into `cleanlinessWorkerPrivateDetails`; rules allow private document get only to Admin or the linked worker, with collection listing denied. The Cleanliness Manager sees work details only. `stage6_data_migrations.js` migrates legacy fields and defaults to dry-run / emulator-only. | **Code separation present; migration and regression proof required.** Run the dry-run against seeded emulator data, inspect the counts, apply only in the emulator, and rerun the private-data rules tests. A staging migration needs a separately approved staging target and a verified backup. Never run `--apply` against production during this preflight. |

## Additional cost-related correction

The current emergency escalation scheduler does **not** scan all open alerts. It queries only `open` / `escalated` alerts whose `nextEscalationAt` is due, orders by that timestamp, uses a collection-group composite index and limits each run to 250 alerts. It runs every minute in `asia-south1` with `maxInstances: 1`. Monitor actual scheduled-function invocations and due-alert backlog during pilot; do not treat the old “full scan” description as a current defect.

## App Check callable policy in this patch

`functions/index.js` now uses:

```js
const enforceCallableAppCheck = process.env.FUNCTIONS_EMULATOR !== 'true';
```

All three callable Functions pass `enforceAppCheck: enforceCallableAppCheck`. This makes missing/invalid App Check attestations fail closed for deployed callable endpoints while preserving emulator-based integration tests. It does not automatically enable Firestore App Check enforcement in Firebase Console. For real test devices, register only their debug App Check tokens in the correct project; keep tokens private and never ship a debug build/token to production.

## Exact preflight commands

Run from the remediation workspace on the Mac (Node 24.12+ on PATH):

```bash
export PATH="$(brew --prefix node@24)/bin:$HOME/development/flutter/bin:$PATH"
hash -r
node --version
bash tool/firestore_rules_qa/run_extended_suite.sh
```

Then validate the backend source and the App Check policy test:

```bash
cd functions
node --check index.js
npm run test:app-check
npm run test:resident-registration
npm run test:payroll
cd ..
```

Run the worker-private migration first in dry-run mode against the Firestore Emulator only. Start the emulator with `demo-mohallaflow`, set `FIRESTORE_EMULATOR_HOST=127.0.0.1:8080`, and run `node functions/scripts/stage6_data_migrations.js` without `--apply`. Seed synthetic workers/alerts first or the dry-run will report zero records. Then rerun with `--apply` only against the emulator and verify the old public private fields are absent and the new private documents are present.

## Owner approvals required before production

1. Approve Firebase billing plan and backup retention/cost; execute a staging restore rehearsal.
2. Approve registration/enforcement of Android Play Integrity and Apple App Attest, including safe debug-token handling for test devices.
3. Supply/register the Android upload certificate in Play Console; keep the private keystore outside source control.
4. Provide an owned public domain and verified support/identity workflow for the external account-deletion resource required by Google Play.
5. Approve document retention and legal-hold policy with Indian counsel before implementing automated purge.
6. Decide whether remote push remains out of scope for the pilot or authorise the APNs/FCM readiness work.
7. Approve a synthetic-data staging migration and record the resulting validation evidence.
8. Review privacy notices, processor/controller terms, incident response and resident/worker deletion notices with qualified counsel.

## Acceptance rule

Do not label the application `READY FOR CONTROLLED PILOT` until cross-colony rules and callable tests pass, the staged private-data migration is validated, deletion requests have a functioning route and case process, release signing is proven, and the pilot's monitoring, backups/recovery and SOS fallback are documented. Do not label it `READY FOR GENERAL PRODUCTION` until the production controls above have been activated and evidenced, legal review is complete, and real-device Android/iOS release tests and supervised colony UAT pass.
