# MohallaFlow — Quality Engineering System

## Scope and operating rules

This quality system is additive. It does not rewrite production screens, alter Firestore rules, change Firebase configuration, add Flutter dependencies, deploy Firebase resources, or push Git commits.

The local quality-gate entry point is:

```bash
bash tool/quality_gates.sh
```

The gate performs, in order:

1. Dart format check (read-only).
2. `flutter analyze`.
3. Flutter unit and widget tests.
4. Cloud Functions JavaScript syntax and unit tests.
5. Firestore rules Emulator authorization tests against the pinned v2 candidate.
6. Android debug APK build.
7. iOS simulator debug build on macOS/Xcode.

Optional online dependency advisory checks can be enabled with:

```bash
MOHALLAFLOW_RUN_DEPENDENCY_AUDIT=1 bash tool/quality_gates.sh
```

This runs `npm audit --audit-level=high` for Functions and `flutter pub outdated`. It requires network access and may identify advisories that need triage; do not automatically upgrade packages.

To skip platform builds on a machine without the platform toolchains:

```bash
MOHALLAFLOW_SKIP_PLATFORM_BUILDS=1 bash tool/quality_gates.sh
```

## Firebase security test boundary

`tool/firestore_rules_qa/run.sh` uses `qa_candidates/firestore_candidate_v2.rules`, whose pinned SHA-256 is:

`97effc7277be6ad0415250206d38d9570eed9cafe9c1fd50e5861e069e8e4b6b`

It runs 24 general authorization scenarios and 10 worker-attendance scenarios against the local Firestore Emulator using the `demo-mohallaflow` project and synthetic fixtures. It refuses to run if the candidate hash differs or Node is older than 24.12.0.

This suite does **not** test the currently deployed production rules. It does not deploy the candidate. It does not write cloud data. Never reinterpret an Emulator pass as a production deployment or a complete end-to-end app test.

## Current architecture observations (8 November 2026 source snapshot)

- 46 screen files.
- 5 files under `lib/services/`.
- 41 of 46 screens import both Firebase Auth and Cloud Firestore directly.
- Approximately 255 literal `.collection(...)` call sites exist across screens.
- No `integration_test/` directory was included in the collected source.
- The only dedicated application model file is `lib/models/user_role.dart`; most feature data shapes remain screen-local or map-based.
- Existing Flutter tests cover translation strings, phone-number normalization, and a splash-to-login smoke test. A Node test file covers resident-registration phone helpers.

This structure makes cross-screen data-flow testing expensive. Extract repository/service boundaries incrementally, beginning with authentication/membership, complaints, cleanliness dispatch and worker completion. Do not perform a broad rewrite purely to make tests easier.

## Test taxonomy and required evidence

| Layer | Required evidence |
|---|---|
| Unit | Deterministic valid, invalid, missing, boundary, duplicate and error cases |
| Widget | Rendering, role-specific visibility, form validation, action callbacks and loading/empty/error/retry states |
| Service/repository | Query paths, payload validation, server timestamps, error mapping and persistence |
| Integration | A real workflow across the four roles using emulator fixtures |
| Security | Document and query authorization, ownership, protected fields, cross-colony isolation and invalid writes |
| Regression | Full gate after every service/model/security change |

## Data-flow acceptance workflow priorities

1. Resident submits a complaint.
2. Admin reads it, acknowledges it, and handles maintenance or forwards cleanliness work.
3. Cleanliness Manager receives the authorized cleanliness work and assigns an active worker.
4. Worker sees only their assigned task, records progress/completion, and cannot alter another worker's records.
5. Admin sees the completion and can close the original complaint.
6. Admin posts an announcement; residents of the correct colony can read it; unauthorized colonies cannot.
7. Maintenance vendor/job/bill/payment records preserve ownership, amount and lifecycle rules.
8. Admin records water-supplier delivery; authorized operational roles can view the correct delivery/stock data.
9. Visitor check-in/check-out records are visible only to the authorized colony roles.

For each workflow test both success and denial/failure paths. Verify the persisted record, not just the UI message.

## Limits and release interpretation

- Unit and widget tests do not prove Firebase authorization.
- Fake Firestore implementations do not enforce production Security Rules; use the Emulator for authorization.
- Emulator fixtures do not establish that live production documents match the assumed schema.
- Device tests for phone OTP, push delivery/APNs, offline behaviour and real payment interactions require a controlled device/backend environment and must be reported separately.
- Coverage percentage is not a release criterion. Prioritise security and critical data-flow assertions.
