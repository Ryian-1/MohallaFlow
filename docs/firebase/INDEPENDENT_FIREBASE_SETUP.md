# Independent Firebase Project Setup

This guide is for a developer creating a separate test/development Firebase project. It must not point at the original MohallaFlow production project.

## 1. Prerequisites

- Flutter 3.47.9 / Dart 3.13.7 baseline (or a separately verified compatible version).
- Node.js 22 for Functions; Node.js 24.12+ for the current Rules QA scripts.
- Firebase CLI 15.34.2 for the tested QA runner.
- FlutterFire CLI (`dart pub global activate flutterfire_cli`).
- Android application signing fingerprints for phone-auth setup; macOS/Xcode for iOS app registration and builds.

## 2. Create a separate Firebase project

1. Create a new Firebase project in the Firebase Console owned by the developer/team.
2. Do not import real resident, worker or colony records. Use synthetic development fixtures only.
3. Choose the Firestore region deliberately; Functions should be deployed to a compatible region to limit latency and data-transfer costs.
4. Enable billing only after reviewing the services and pricing required by your environment.

## 3. Register platform apps and generate client options

Before running FlutterFire, create your local Firebase CLI configuration:

```bash
cp firebase.json.example firebase.json
```

This local file contains Functions and Hosting settings. Its template intentionally has no Firestore deployment entry while the Rules deployment blocker remains unresolved. FlutterFire adds project-specific local mappings during configuration.


Register Android and iOS app IDs matching the actual local platform build settings. The audited Android `applicationId` is `com.mohallaflow.mohalla_flow`; verify the iOS bundle identifier from Xcode rather than assuming it is identical.

```bash
firebase login
dart pub global activate flutterfire_cli
flutterfire configure --project YOUR_FIREBASE_PROJECT_ID --platforms android,ios,web
```

FlutterFire generates project-specific client options and native configuration. Keep environment-specific files local during development. The repository's existing Firebase options and native config in historical GitHub commits point at the original project and are not a reusable template.

The local Firebase CLI project alias (`.firebaserc`) is intentionally ignored. Add your own alias locally with:

```bash
firebase use --add
```

Never commit service-account JSON, admin private keys or CI service credentials. Client Firebase options/API keys are included in client applications by design; they are not service-account credentials, but apply API restrictions and rely on Authentication, Firestore Rules and App Check for protection.

## 4. Configure Authentication

- Enable Phone Authentication in Firebase Authentication.
- Configure platform-specific app verification and Android SHA fingerprints.
- Add the correct authorised domains if building the web target.
- Use Firebase's fictional/test phone numbers only in non-production environments.
- Do not disable app verification or use the app's test-only bypass in production.

## 5. Configure Firestore

Create a Firestore database for the development project. The intended data model has root `users/{uid}` profiles, `colonies/{colonyId}` roots, and nested colony records such as `members`, `residents`, `households`, `complaints`, `cleanlinessTasks`, `announcements`, `maintenanceJobs`, `payments`, `visitors` and `workerAttendance`.

### Critical Rules blocker

The maintainer-local root `firestore.rules` snapshot audited on 8 November 2026 measured 384,997 bytes, above Firebase's documented 256 KiB source limit. It is intentionally excluded from the distributable repository. The included candidate at `qa_candidates/firestore_candidate_v2.rules` is 232,122 bytes and is strictly a QA artifact. It passed 24 general authorization tests, 10 Worker Attendance tests and a separate 105-test standalone Emulator suite; coverage may overlap. It has not been accepted by production Firebase. Emulator success does not establish compiled rules validity, production acceptance or full authorization coverage.

Before deploying any Rules file:

1. Restructure / reduce the ruleset so it meets source and compiled rules limits.
2. Run the complete Emulator suite and add tests for every high-risk collection/operation/query.
3. Review all four roles, ownership checks, cross-colony isolation and server-managed fields.
4. Use a dedicated non-production Firebase project for a controlled validation deployment.
5. Obtain maintainer approval before any production deployment.

## 6. Indexes

`firestore.indexes.json` is tracked. In the audited snapshot it defines zero composite indexes and one field override. Add reviewed composite indexes when Firestore query errors or planned queries require them. Do not blindly deploy indexes to the production project.

## 7. Cloud Functions

Functions are under `functions/` and declare Node.js 22. They use Firebase Admin and Functions v2 APIs, including Firestore triggers, a callable resident-registration claim and scheduled emergency-alert escalation. For local work:

```bash
cd functions
npm ci
npm run lint
npm run test:resident-registration
```

Review required Firebase plan/billing, IAM roles, scheduler and FCM setup in the target project before deploying Functions. Use synthetic test data and separate environments. No deploy command is included in this guide.

## 8. Cloud Storage

The audited Flutter dependencies do not include `firebase_storage`, and the portable `firebase.json.example` has no Storage rules/deployment entry. The document repository's chunk path is represented in Firestore Rules. Do not enable or configure Firebase Storage unless a future feature explicitly adds and tests it.

## 9. Emulator tests

The current Rules QA runner uses an isolated demo project ID and synthetic fixtures:

```bash
bash tool/firestore_rules_qa/run.sh
bash tool/firestore_rules_qa/run_extended_suite.sh
```

It requires Node.js >=24.12, npm, Python 3 and Firebase CLI. It reads the pinned file in `qa_candidates/` and does not deploy production Rules or write cloud data. Keep the candidate hash check intact unless a new candidate has been independently reviewed and re-baselined.

## 10. Environment separation checklist

- Separate Firebase projects for local/test/staging/production.
- Separate app registrations and API key restrictions per environment.
- No production user data in local/emulator fixtures.
- `firebase.json`, `.firebaserc`, native Google config files and local credentials excluded from commits.
- Rules tested in Emulator before any non-production deployment.
- Functions run with least-privilege IAM and reviewed environment configuration.
- Push notifications validated independently on Android and iOS; APNs requires Apple-side setup.
