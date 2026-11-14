# MohallaFlow

<p align="center">
  <img src="assets/branding/logo_horizontal.png" alt="MohallaFlow" width="420" />
</p>

<p align="center"><strong>Your colony. Better connected.</strong></p>

MohallaFlow is a Flutter-based residential community and colony-management application. It brings resident issue reporting, central administration, cleanliness operations, maintenance coordination, workforce workflows and community records into one role-based mobile experience.

> **Project status — 13 November 2026:** A curated public code-showcase snapshot has been published to GitHub. The six-job public CI, dependency audits, full-history Gitleaks scan and payroll Flutter SDK Emulator integration pass. This is not a production release. Production Firebase approval, store-distribution signing, live-service acceptance and legal/ownership review remain separate gates.

## Product roles

| Role | Primary responsibilities |
|---|---|
| **Admin** | Central colony administration, resident and household records, complaint oversight, notices, maintenance coordination, vendors, financial administration, governance and operational reporting. |
| **Resident** | Report colony issues to the central Admin, access announcements, view community information and use supported resident-facing workflows. |
| **Cleanliness Manager** | Receive cleanliness complaints routed by the Admin, assign colony workers, coordinate operations and track completion. |
| **Worker** | View assigned work, maintain operational profile information, record attendance where enabled and report task progress or completion. |

Role routing uses the authenticated Firebase account and active colony membership. The current data model uses user profiles at `users/{uid}` and membership records under `colonies/{colonyId}/members/{uid}`. Resident and Worker dashboard routing also expects the corresponding resident or worker record linkage.

## Product capabilities

The source tree contains modules covering the following operational areas. Individual modules may have different levels of end-to-end test coverage and may require configuration in an independently managed Firebase project.

### Colony administration and resident experience

- Resident, household and colony records.
- Complaint and issue reporting with central Admin oversight.
- Announcements, notice acknowledgement and notification centre.
- Community events, polls and amenity booking workflows.
- Move-in and move-out requests.
- Maintenance dues, recurring billing and arrears.

### Maintenance and infrastructure

- Maintenance requests, vendor coordination and service records.
- Preventive maintenance and annual maintenance contract workflows.
- SLA tracking and maintenance reporting.
- Water operations and supply records.
- Fixed assets and inventory management.
- Procurement and operational records.

### Workforce and finance

- Cleanliness task assignment and completion tracking.
- Worker operational profiles and attendance workflows.
- Staff leave and payroll.
- Budgets, expenses and RWA accounting.
- Committee permissions and delegated governance.

### Security and community operations

- Gate operations and visitor workflows.
- Security incidents and lost-and-found records.
- Emergency preparedness and response workflows.
- Operational analytics and colony reports.
- Firestore-backed document repository workflows.

These are source-level capability descriptions, not a claim that every workflow has passed production acceptance testing.

## Architecture

```text
Flutter / Dart mobile application
|
+-- Authentication and locale management
+-- Colony selection and membership resolution
+-- Admin dashboard
+-- Resident dashboard
+-- Cleanliness Manager dashboard
+-- Worker dashboard
+-- Feature screens, models and shared widgets
+-- Firebase client SDKs
    |
    +-- Firebase Authentication
    +-- Cloud Firestore
    +-- Firebase Cloud Messaging integration
    +-- Firebase App Check
    +-- Firebase Crashlytics
    +-- Firebase Performance Monitoring

Firebase backend
|
+-- Cloud Functions (Node.js 22)
    |
    +-- Resident registration workflows
    +-- Payroll approval callable
    +-- Worker-private profile migration
    +-- Notification workflows
    +-- Emergency escalation workflows
```

The application uses colony-scoped Firestore records and server-side callable workflows for sensitive operations such as payroll approval.

The project does not include the Firebase Storage SDK as an application dependency. Its document repository uses a Firestore-backed storage approach; this is not Firebase Cloud Storage.

## Technology stack

| Area | Technology |
|---|---|
| Mobile application | Flutter / Dart |
| Authentication | Firebase Authentication |
| Database | Cloud Firestore |
| Backend | Firebase Cloud Functions |
| Backend runtime | Node.js 22 |
| Notifications | Firebase Cloud Messaging integration |
| Application security | Firebase App Check |
| Crash reporting | Firebase Crashlytics |
| Performance monitoring | Firebase Performance Monitoring |
| Local preferences | `shared_preferences` |
| File selection | `file_picker` |
| External links | `url_launcher` |
| Languages | English and Hindi |

The dependency manifests and lockfiles define the exact package versions.

## Verified engineering baseline

**Local verification baseline: 11 November 2026.** The following results were obtained from local project runs; they are not a claim that every suite has been rerun from a clean public clone:

| Verification | Result |
|---|---|
| Flutter unit and widget tests | 40 passed |
| Flutter static analysis | No issues found |
| Dart formatting | 74 files checked; no changes required |
| Firestore targeted QA | 22 authorization and 10 attendance scenarios passed |
| Firestore extended Emulator suite | 152 tests passed |
| Functions resident-registration tests | 5 passed |
| Functions App Check tests | 1 passed |
| Worker-private migration tests | 5 passed |
| Functions Emulator suite | 13 tests passed, plus payroll callable integration |
| Four-role application integration | 1 integration test passed across all four roles |
| Android release build | APK successfully generated |
| iOS device release build | Successfully compiled without code signing |
| iOS app icon catalog | 19 entries valid; marketing icon matches master artwork |
| Published snapshot security scan | 503 tracked files; approximately 5.47 MB scanned by Gitleaks; zero leaks found |

The four-role integration runner used the iPhone 18 Pro simulator and an isolated demo Firebase project. Functions and Firestore tests also use local emulators and synthetic fixtures. The public GitHub Actions run on 13 November 2026 passed all six jobs, including the Flutter payroll callable SDK integration on an Android Emulator with a temporary payroll-only test rules fixture.

The Android release APK generated during verification was approximately 69.7 MB. The unsigned iOS device application build was approximately 57.6 MB.

These results do not establish App Store distribution signing, Play Store publication, production Firebase acceptance or live notification delivery. The latest consolidated test attempt also encountered unavailable package registries and occupied local Emulator ports; previously passing isolated suites remain separate evidence and should not be interpreted as a fresh pass from that interrupted run.

## Firestore security status

This public repository intentionally contains **no Firebase, Firestore or Storage security-rule files**. The production rules and the privately retained Emulator QA candidate are excluded from the public Git tree and its history.

The maintainer's Candidate G has passed targeted authorization/attendance checks and the extended isolated Emulator suite in a private QA workspace. It is Emulator-validated only, is not included in this repository and is not approved for production deployment.

Do not add private rules to the public repository to make CI pass. Do not deploy any rules or replace production rules without a separate independent review, full authorization acceptance and explicit deployment approval.

## Requirements

The verified local development baseline is:

- Flutter 3.47.9 stable.
- Dart 3.13.7.
- Node.js 22 for Cloud Functions.
- Node.js 24 for Firestore QA tooling.
- Firebase CLI 15.34.2 for the current rules QA scripts.
- Java 21 for Firebase Emulator suites.
- Android SDK and Gradle toolchain for Android builds.
- macOS and Xcode for iOS builds.
- Python 3 for repository QA scripts.

Toolchain upgrades should be checked for compatibility with the pinned Firebase Flutter plugins and Android Gradle configuration.

## Independent Firebase setup

Use your own Firebase project. Do not use the original maintainer project or production resident data.

1. Install Flutter, Dart, Node.js and the required platform toolchains.
2. Copy the provided configuration templates:

   ```bash
   cp .firebaserc.example .firebaserc
   cp firebase.json.example firebase.json
   cp lib/firebase_options.dart.example lib/firebase_options.dart
   ```

3. Register your own Android and iOS applications in Firebase.
4. Configure FlutterFire for your project and generate your own platform configuration.
5. Enable the required Authentication providers and configure Firestore, Cloud Functions and App Check.
6. Configure the Android package identifier, iOS bundle identifier and signing fingerprints for your applications.
7. Keep local Firebase configuration and credentials out of source control.

See:

- [Independent Firebase setup](docs/firebase/INDEPENDENT_FIREBASE_SETUP.md)
- [Firebase configuration quickstart](docs/firebase/CONFIGURATION_QUICKSTART.md)
- [Firebase configuration policy](docs/firebase/FIREBASE_CONFIGURATION_POLICY.md)

Do not deploy Firestore rules from this repository. The supplied QA candidate is not a production ruleset.

## Local development

Fetch locked Flutter dependencies:

```bash
flutter pub get --enforce-lockfile
```

Run Flutter checks:

```bash
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
```

Run Cloud Functions checks:

```bash
npm ci --prefix functions
npm --prefix functions run lint
npm --prefix functions run test:resident-registration
npm --prefix functions run test:app-check
npm --prefix functions run test:worker-private-migration
npm audit --prefix functions
```

### Payroll Flutter SDK integration

The public CI runs the payroll Flutter SDK integration on an Android Emulator using a demo project, synthetic Auth/Firestore data and a temporary payroll-only Firestore rules fixture. The fixture is generated in the CI workspace and removed at job exit; it is neither Candidate G nor a production ruleset. To run the same runner locally, use a Linux host with an Android Emulator already available as `emulator-5554`, Node.js 22, Flutter 3.47.9, Java 21 and Firebase CLI 15.34.2:

```bash
bash tool/payroll_sdk_integration/run_ci.sh
```

### Maintainer-only Emulator and integration QA

The following runners require the privately retained, SHA-pinned Candidate G rules file. That file is deliberately excluded from the public repository, so these commands will stop in a public-only clone until the maintainer privately provisions the reviewed QA fixture:

```bash
bash tool/firestore_rules_qa/run.sh
bash tool/firestore_rules_qa/run_extended_suite.sh
bash tool/functions_emulator_qa/run.sh
bash tool/four_role_integration_v4/run.sh
```

Use only isolated demo project configuration and synthetic data. Never commit the private rules candidate or production rules to make these commands work. Read each runner before use; the runners are not production deployment commands.

## Build

Android release APK:

```bash
flutter build apk --release
```

iOS device build without distribution signing:

```bash
flutter build ios --release --no-codesign
```

iOS App Store distribution requires a separate Apple Developer signing and release configuration. A successful unsigned build is not a distribution-ready IPA.

## Screenshots and product media

Genuine, sanitised product screenshots have not yet been approved for this publication snapshot. Do not represent mockups as screenshots of the working application.

Use the [screenshot capture plan](docs/publication/SCREENSHOT_CAPTURE_PLAN.md) to prepare authentic Admin, Resident, Cleanliness Manager and Worker visuals.

## Security and privacy

- Never commit Firebase service-account credentials, private keys, signing certificates, resident records or production exports.
- Use an independent Firebase project for development and testing.
- Keep App Check enforcement and server-side authorization enabled and reviewed in the target environment.
- Treat Firestore rules as security-critical code; do not weaken rules to work around permission errors.
- Review data collection, retention, access and privacy disclosures before deployment.
- Read the [Security Policy](SECURITY.md) before reporting a vulnerability.

## Known release limitations

- Production Firestore rules have not been approved or deployed.
- Production Firebase acceptance testing remains outstanding.
- App Check enforcement must be verified in each target Firebase environment.
- Live push notification and APNs delivery require separate environment-specific acceptance.
- iOS distribution signing and App Store packaging remain outstanding.
- Public GitHub Actions passed all six jobs on 13 November 2026, including the payroll SDK Emulator integration, npm audits, recursive OSV scan and full-history Gitleaks scan. The broader Candidate G authorization suite remains maintainer-only.
- Keep dependency advisory scanning and Dependabot enabled; rerun after dependency/lockfile changes.
- Genuine release screenshots and ownership/licensing review remain outstanding.

See the [publication checklist](docs/publication/PUBLICATION_CHECKLIST.md) for the remaining release gates.

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md), [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) and [SECURITY.md](SECURITY.md) before proposing changes.

Include relevant test evidence in pull requests. Do not submit local Firebase bindings, credentials, private resident information, backup artifacts or generated dependency directories.

## License and ownership

No open-source licence has been granted in this repository. The repository is a public code showcase, not an open-source grant. Publication does not grant permission to reuse, modify, redistribute or commercially deploy the original project code or brand assets.

Third-party dependencies and components remain subject to their respective licences. Ownership and redistribution rights for all original and third-party assets must be reviewed before any future open-source licence is assigned.

## Firebase deployment

The reviewed Firestore Rules/indexes, read-only production membership preflight, index-readiness gate, Rules release verification and separate Functions deployment script are in [release/README.md](release/README.md). Use the isolated commands there; do not run an unscoped Firebase deployment from the app root.
