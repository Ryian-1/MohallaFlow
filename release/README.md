# MohallaFlow deployment package

Application branch: `main`

Reviewed Firestore candidate:

- Rules SHA-256: `3b54f18560ec65a1b12366d2f5df08765ddee82e4d0c0b40b2d0649a1f85715c`
- Source bytes: 249,119 / 262,144
- Private Firestore emulator evidence: **125 passed, 0 failed, 0 skipped** across six suites.

## Included

`firestore/` contains the exact candidate rules, index manifest, and an isolated Firestore-only Firebase config. The scripts perform a read-only production membership census, deploy indexes first, wait for READY, deploy Rules second, and verify the active Ruleset SHA. A separate script validates and deploys Functions only.

## One-time setup

Install Node.js 22, Firebase CLI, Google Cloud CLI and Python 3. Authenticate and select the production project:

```bash
firebase login
gcloud auth login
gcloud config set project mohallaflow
```

The preflight uses your active gcloud account and reads all colonies and membership documents, plus each active member's user profile and linked resident/worker record. These are normal billable Firestore reads. It creates a local report in `release/firestore/reports/` without printing names, phone numbers or UIDs.

**A blocked membership report must be repaired before Rules activation.** The candidate requires exact `uid` and `colonyId` membership fields, canonical lower-case roles/status, an active user profile whose `colonyIds` contains the colony, and linked resident/worker records for those roles.

**Legacy client compatibility is preserved and emulator-tested.** The candidate restores the previous production collection-group query contract: callers may query `collectionGroup('members')` only when the query constrains `uid == request.auth.uid` and `status == 'active'`. The six private Emulator suites pass 125/125, including the allowed multi-colony filtered query and denials for unfiltered, missing-status, and cross-UID queries. This intentionally retains the previous recursive rule scope for any collection named `members`; do not create unrelated `members` subcollections containing an active record for a user's UID. The deployment script requires the acknowledgement `CONFIRMED FILTERED LEGACY MEMBER QUERY COMPATIBILITY` before proceeding.

## Deploy Firestore — one command

Run from the repository root:

```bash
bash release/firestore/scripts/deploy-firestore.sh
```

The script confirms the project and exact source hashes, runs the read-only census, and stops if any active account is incompatible. After you type `DEPLOY MOHALLAFLOW FIRESTORE`, it runs:

1. `firebase deploy --only firestore:indexes`
2. Waits until both required index configurations are READY.
3. `firebase deploy --only firestore:rules`
4. Verifies the active production Rules release matches the exact reviewed SHA.

Required index configurations:

| Resource | Scope | Definition |
|---|---|---|
| `emergencyAlerts` | `COLLECTION_GROUP` composite | `status ASCENDING`, `nextEscalationAt ASCENDING` |
| `residentLoginRegistrations.phoneNumberE164` | `COLLECTION_GROUP` single-field | `ASCENDING` (COLLECTION scope is also retained) |

If the census is blocked, fix data and rerun. If Firebase rejects the compiled Ruleset size, the Rules deploy stops and the prior active Rules release remains in place. The source-size check is not a numeric compiled-size measurement.

## Deploy Cloud Functions separately

After Firestore indexes and Rules are verified:

```bash
bash release/firestore/scripts/deploy-functions.sh
```

This installs locked dependencies, runs Functions lint and unit tests, and performs npm audit. The payroll backend suite is automatically wrapped in `firebase emulators:exec` against an isolated **`demo-mohallaflow`** project ID and the local Firestore Emulator. It does not read or write production Firestore. The emulator shuts down when the payroll test process exits. Java is required by the Firestore Emulator.

After all checks pass, the script requires two separate confirmations before deploying **only these six functions**: emergency SOS in-app notification creation/updates, scheduled emergency escalation, resident phone registration linking, account deletion requests, and payroll approval.

**Native OS push is intentionally left disabled.** The `dispatchMohallaFlowPush` FCM dispatcher is excluded from the deployment command. The Functions script also checks Gen 2 deployments with gcloud and stops if an existing `dispatchMohallaFlowPush` function is detected; it never deletes that function automatically. If it is present, review and deliberately remove only that function before rerunning the deployment. Firestore in-app notifications and emergency escalation remain included.

The included callable endpoints enforce Firebase App Check when deployed. Configure Firebase App Check for Android and iOS before relying on resident phone-link, payroll and account-deletion callables. Enable the Firebase Authentication sign-in providers actually used by your app (including Phone sign-in) before pilot sign-in. Scheduled emergency escalation requires a billing-enabled Firebase project and the Firestore index above.

## Build and publish mobile apps

Firebase deployment does not publish the mobile binaries. Ensure the genuine project config remains local and is not replaced by compile-only CI examples:

- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

Then, on the Mac with production signing configured:

```bash
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
flutter build appbundle --release
flutter build ipa --release
```

Android requires the four `MOHALLAFLOW_RELEASE_*` signing values in `android/app/build.gradle.kts`. iOS requires the correct Xcode Team, certificate and provisioning profile. Upload the AAB to Google Play Console and the IPA through your Apple distribution workflow.

## Validation boundaries

- Public CI passed formatting, analysis, Flutter unit/widget tests, Functions lint/unit tests, dependency audits, Gitleaks, OSV and Android payroll SDK integration.
- Private Firestore candidate CI passed six suites, 122/122.
- The exact Rules candidate passed all six private Firestore Emulator suites (125/125). The Android four-role job then failed before launching the app because the hosted emulator never appeared as `emulator-5554`; it is an infrastructure failure, not a test pass. The new Manager-menu assertion still needs a fresh local iPhone simulator run.
- No production Rules release, indexes or Functions were deployed while preparing this package. One previously verified mismatched duplicate Admin membership was separately deactivated with an update-time precondition; the canonical Admin membership and user profile remain active.
- After deployment, test sign-in and Admin, Resident, Cleanliness Manager and Worker flows with controlled pilot accounts before opening the app to residents.

Do not run an unscoped `firebase deploy` from the app root.
