# MohallaFlow — Curated Publication Manifest

**Status:** Review candidate only. No files are staged or published by this manifest.

This manifest is a file-by-file proposal generated from the current Git index
and an explicit allowlist of new application source, tests, CI, configuration
templates and documentation. It is not a release approval, licence grant,
or authorization to deploy Firebase resources.

## Proposed included files

- Existing tracked paths audited: 190
- Additional reviewed publication files allowlisted: 38
- Total proposed included files: 227

- Active Firestore QA candidate: `qa_candidates/firestore_candidate_g.rules`

### File-by-file list

#### `.github/`

- `.github/ISSUE_TEMPLATE/bug_report.md`
- `.github/ISSUE_TEMPLATE/config.yml`
- `.github/ISSUE_TEMPLATE/feature_request.md`
- `.github/PULL_REQUEST_TEMPLATE.md`
- `.github/workflows/ci.yml`

#### `[root]/`

- `.firebaserc.example`
- `.gitignore`
- `.metadata`
- `CHANGELOG.md`
- `CODE_OF_CONDUCT.md`
- `CONTRIBUTING.md`
- `README.md`
- `SECURITY.md`
- `analysis_options.yaml`
- `firebase.json.example`
- `firestore.indexes.json`
- `pubspec.lock`
- `pubspec.yaml`

#### `assets/branding/`

- `assets/branding/app_icon_1024.png`

- `assets/branding/logo_horizontal.png`

- `assets/branding/monogram.png`

- `assets/branding/wordmark.png`

#### `android/`

- `android/.gitignore`
- `android/app/build.gradle.kts`
- `android/app/src/debug/AndroidManifest.xml`
- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/kotlin/com/mohallaflow/mohalla_flow/MainActivity.kt`
- `android/app/src/main/res/drawable-v21/launch_background.xml`
- `android/app/src/main/res/drawable/launch_background.xml`

- `android/app/src/main/res/drawable-nodpi/mohallaflow_launch_logo.png`
- `android/app/src/main/res/mipmap-hdpi/ic_launcher.png`
- `android/app/src/main/res/mipmap-mdpi/ic_launcher.png`
- `android/app/src/main/res/mipmap-xhdpi/ic_launcher.png`
- `android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png`
- `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png`
- `android/app/src/main/res/values-night/styles.xml`
- `android/app/src/main/res/values/styles.xml`
- `android/app/src/profile/AndroidManifest.xml`
- `android/build.gradle.kts`
- `android/gradle.properties`
- `android/gradle/wrapper/gradle-wrapper.properties`
- `android/settings.gradle.kts`

#### `docs/`

- `docs/STAGE6_ANDROID_RELEASE_SIGNING.md`

- `docs/STAGE6_FINDINGS_RESOLUTION.md`

- `docs/STAGE6_MOBILE_APP_CHECK_AND_MONITORING.md`

- `docs/STAGE6_WORKER_PRIVATE_DATA.md`

- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/FIRESTORE_DATA_MODEL.md`
- `docs/firebase/CONFIGURATION_QUICKSTART.md`
- `docs/firebase/FIREBASE_CONFIGURATION_POLICY.md`
- `docs/firebase/INDEPENDENT_FIREBASE_SETUP.md`
- `docs/publication/CURATED_PUBLICATION_MANIFEST.md`
- `docs/publication/LICENCE_AND_OWNERSHIP_REVIEW.md`
- `docs/publication/PUBLICATION_CHECKLIST.md`
- `docs/publication/SCREENSHOT_CAPTURE_PLAN.md`
- `docs/publication/STAGE4_FIREBASE_DECOUPLING.md`
- `docs/quality/QUALITY_ENGINEERING.md`
- `docs/quality/STAGE3_SOURCE_AUDIT.md`
- `docs/quality/STAGE3_WORKFLOW_MATRIX.md`
- `docs/resident_registration_phone_workflow.md`

#### `firestore-rules-tests/`

- `firestore-rules-tests/firestore-rules.test.js`

- `firestore-rules-tests/four-role-resolution-lifecycle.test.js`

- `firestore-rules-tests/membership-scope.security.test.js`

- `firestore-rules-tests/isolation-rules.test.js`
- `firestore-rules-tests/notification-rules.test.js`

- `firestore-rules-tests/payroll-rules.test.js`

- `firestore-rules-tests/staff-rules.test.js`

- `firestore-rules-tests/tenant-lease-rules.test.js`

- `firestore-rules-tests/package-lock.json`
- `firestore-rules-tests/package.json`
- `firestore-rules-tests/remaining-rules.test.js`
- `firestore-rules-tests/write-rules.test.js`

#### `functions/`

- `functions/index.js`
- `functions/lib/phone.js`

- `functions/lib/notification_scalar_migration.js`

- `functions/lib/payroll.js`

- `functions/lib/worker_private_profile_migration.js`

- `functions/package-lock.json`
- `functions/package.json`

- `functions/scripts/migrate_notification_scalar_recipients.js`

- `functions/scripts/migrate_worker_private_profiles.js`

- `functions/test/app-check-config.test.js`

- `functions/test/emergency-escalation.emulator.test.js`

- `functions/test/four-role-app.seed.js`

- `functions/test/notification-scalar-migration.emulator.test.js`

- `functions/test/payroll-callable.integration.js`

- `functions/test/payroll-flutter-sdk.seed.js`

- `functions/test/payroll.test.js`

- `functions/test/worker-private-migration-emulator.test.js`

- `functions/test/worker-private-migration.test.js`

- `functions/test/phone.test.js`

#### `integration_test/`

- `integration_test/four_role_application_integration_test.dart`

- `integration_test/payroll_callable_sdk_test.dart`

#### `ios/`

- `ios/.gitignore`
- `ios/Flutter/AppFrameworkInfo.plist`
- `ios/Flutter/Debug.xcconfig`
- `ios/Flutter/Release.xcconfig`
- `ios/Runner.xcodeproj/project.pbxproj`
- `ios/Runner.xcodeproj/project.xcworkspace/contents.xcworkspacedata`
- `ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist`
- `ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings`
- `ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
- `ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme`
- `ios/Runner.xcworkspace/contents.xcworkspacedata`
- `ios/Runner.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist`
- `ios/Runner.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings`
- `ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved`
- `ios/Runner/AppDelegate.swift`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png`
- `ios/Runner/Assets.xcassets/LaunchImage.imageset/Contents.json`
- `ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png`
- `ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png`
- `ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png`
- `ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md`
- `ios/Runner/Base.lproj/LaunchScreen.storyboard`
- `ios/Runner/Base.lproj/Main.storyboard`
- `ios/Runner/Info.plist`

- `ios/Runner/PrivacyInfo.xcprivacy`
- `ios/Runner/Runner-Bridging-Header.h`
- `ios/Runner/Runner.Debug.entitlements`
- `ios/Runner/Runner.Release.entitlements`
- `ios/Runner/SceneDelegate.swift`
- `ios/RunnerTests/RunnerTests.swift`

#### `lib/`

- `lib/app.dart`
- `lib/firebase_options.dart.example`
- `lib/l10n/app_locale_controller.dart`
- `lib/l10n/app_translations.dart`
- `lib/main.dart`
- `lib/models/user_role.dart`

- `lib/models/notification_event_group.dart`
- `lib/screens/admin_dashboard_screen.dart`
- `lib/screens/advanced_analytics_screen.dart`
- `lib/screens/amenity_bookings_screen.dart`
- `lib/screens/announcements_screen.dart`
- `lib/screens/cleanliness_screen.dart`
- `lib/screens/colony_asset_inventory_screen.dart`
- `lib/screens/colony_budget_expense_screen.dart`
- `lib/screens/colony_selection_screen.dart`
- `lib/screens/community_events_polls_screen.dart`
- `lib/screens/community_hub_screen.dart`
- `lib/screens/complaints_screen.dart`
- `lib/screens/document_repository_screen.dart`
- `lib/screens/emergency_preparedness_screen.dart`
- `lib/screens/emergency_response_screen.dart`
- `lib/screens/gate_operations_screen.dart`
- `lib/screens/households_screen.dart`
- `lib/screens/housekeeping_screen.dart`
- `lib/screens/login_screen.dart`
- `lib/screens/maintenance_dues_screen.dart`
- `lib/screens/maintenance_screen.dart`
- `lib/screens/maintenance_sla_screen.dart`
- `lib/screens/move_in_out_screen.dart`
- `lib/screens/notification_center_screen.dart`
- `lib/screens/preventive_maintenance_screen.dart`
- `lib/screens/procurement_management_screen.dart`
- `lib/screens/recurring_maintenance_billing_screen.dart`
- `lib/screens/reports_screen.dart`
- `lib/screens/resident_dashboard_screen.dart`
- `lib/screens/resident_lease_screen.dart`
- `lib/screens/resident_self_service_screen.dart`
- `lib/screens/residents_screen.dart`
- `lib/screens/rwa_accounting_screen.dart`
- `lib/screens/rwa_committee_permissions_screen.dart`
- `lib/screens/rwa_committee_workspace_screen.dart`
- `lib/screens/rwa_governance_screen.dart`
- `lib/screens/security_incidents_screen.dart`
- `lib/screens/splash_screen.dart`
- `lib/screens/staff_leave_management_screen.dart`
- `lib/screens/staff_payroll_screen.dart`
- `lib/screens/tenant_lease_management_screen.dart`
- `lib/screens/visitor_management_screen.dart`
- `lib/screens/water_operations_screen.dart`
- `lib/screens/water_supply_screen.dart`
- `lib/screens/worker_attendance_screen.dart`
- `lib/screens/worker_dashboard_screen.dart`
- `lib/services/colony_dashboard_router.dart`
- `lib/services/notification_service.dart`
- `lib/services/push_notification_service.dart`
- `lib/services/resident_registration_activation_service.dart`
- `lib/services/user_access_service.dart`
- `lib/theme/app_theme.dart`
- `lib/widgets/app_language_toggle.dart`

- `lib/widgets/brand_logo.dart`
- `lib/widgets/app_selectable_text.dart`
- `lib/widgets/app_text.dart`
- `lib/widgets/colony_switch_action.dart`
- `lib/widgets/notification_bell.dart`

#### `qa_candidates/`

- `qa_candidates/firestore_candidate_v2.rules`

- `qa_candidates/firestore_candidate_g.rules`

#### `test/`

- `test/hindi_button_translation_test.dart`
- `test/hindi_feature_module_title_test.dart`
- `test/models/user_role_test.dart`

- `test/models/notification_event_group_test.dart`
- `test/resident_registration_phone_test.dart`
- `test/services/resident_registration_phone_boundary_test.dart`
- `test/widget_test.dart`

#### `tool/`

- `tool/firestore_rules_qa/MohallaFlow_Firestore_Rules_Authorization_QA.py`
- `tool/firestore_rules_qa/MohallaFlow_Worker_Attendance_Rules_QA.py`
- `tool/firestore_rules_qa/run.sh`
- `tool/firestore_rules_qa/run_extended_suite.sh`
- `tool/publication/untrack_firebase_client_config.sh`
- `tool/quality_gates.sh`

- `tool/four_role_integration_v4/execute_emulator.sh`

- `tool/four_role_integration_v4/run.sh`

- `tool/functions_emulator_qa/run.sh`


#### `web/`

- `web/favicon.png`
- `web/icons/Icon-192.png`
- `web/icons/Icon-512.png`
- `web/icons/Icon-maskable-192.png`
- `web/icons/Icon-maskable-512.png`
- `web/index.html`
- `web/manifest.json`

## Explicit exclusions — preserve locally

| Path or group | Decision | Reason |
|---|---|---|
| `firebase.json` | Exclude from Git; preserve locally | Developer-local FlutterFire and Firebase CLI mappings. |
| `.firebaserc` | Exclude | Developer-local Firebase project alias. |
| `lib/firebase_options.dart` | Exclude | Generated developer-project options. |
| Android `google-services.json` | Exclude | Developer-project client configuration. |
| iOS `GoogleService-Info.plist` | Exclude | Developer-project client configuration. |
| Root `firestore.rules` | Exclude; preserve locally | Maintainer-local 384,997-byte non-deployable rules snapshot. |
| Root `package-lock.json` | Exclude; preserve locally | Accidental npm lockfile; no root `package.json` exists. |
| `README_MohallaFlow_*.txt` | Defer | Future-feature specifications, not acceptance evidence. |
| `MOHALLAFLOW_FEATURE_REGISTER.md` | Defer | Internal integration and validation tracker. |
| `README_STAGE4_FIREBASE_DECOUPLING.md` | Defer | Historical installer/change record; maintained policy is under `docs/publication/`. |
| `v2_backups/`, `v2_validation/` | Exclude | Local backup and validation workspaces. |
| `lib/screens/local_services_directory_screen.dart` | Exclude from proposed publication; preserve locally | This feature was explicitly removed from the product scope. |
| `tool/four_role_integration/` | Exclude from proposed publication; preserve locally | Superseded legacy runner; the Candidate G-pinned V4 runner is the maintained integration path. |
| `firestore-rules-tests/firestore-debug.log` | Exclude | Generated Emulator diagnostic log. |
| `*.bak`, `*.stage6-location-fix-backup` | Exclude; preserve locally | Recovery snapshots, not distributable source. |
| `.dart_tool/`, `build/`, `node_modules/` | Exclude | Generated cache, build and dependency directories. |

## Special file decisions

- The two empty iOS entitlement dictionaries are included because the Xcode project references them.
- `firestore.indexes.json` is included as a query-index source artifact. The portable Firebase template does not expose a Firestore deployment target.
- `qa_candidates/firestore_candidate_v2.rules` is retained as a historical QA comparator. Its current working-tree SHA-256 is `6f690403e53bcefff28ab69472b7f97444881033ae7ca8c9eb1b6060a8493472`; its committed `HEAD` blob has SHA-256 `522b0c69cad0a3593a7ec9a0ee5ea9c3ffbb290f5cc437756b07baf8b2a8488f`. Review this difference before any commit.
- `qa_candidates/firestore_candidate_g.rules` is the active repository QA candidate, SHA-256 `7f30e3bdd6b6e244e66c33baaa32a6ee3ef04beb6799bc377f87f29bac8a2ab0`. It is pinned by both Firestore QA runners and the permanent V4 integration runner. It is Emulator-validated only and is not approved for production deployment.
- `docs/publication/SCREENSHOT_CAPTURE_PLAN.md` is included. Genuine application screenshots remain pending.
- All ten Firestore Rules Emulator test files and their package manifest and lockfile are included. The repository's targeted and extended QA runners execute them in isolated Emulator projects.
- The root npm lockfile is not part of either package-specific dependency graph.

## Verified local validation evidence

- Candidate G targeted Firestore QA passed: 22 authorization and 10 attendance scenarios.
- Candidate G extended Firestore Emulator suite passed: 152 tests, zero failures, zero skipped.
- The permanent Candidate G-pinned V4 iPhone 18 Pro simulator integration runner passed: four-role authentication and dashboard routing plus the issue-resolution journey, 1/1 integration test.
- The integration runner restored the original iOS Firebase plist exactly and cleaned up its demo Auth and Firestore fixtures.
- Flutter analysis and the 40-test Flutter suite passed in the local validation run.
- Cloud Functions Node 22 CI-equivalent checks passed locally: lint; resident-registration 5/5; App Check 1/1; worker-private migration 5/5; emulator-backed backend tests 13/13; and the payroll callable HTTP integration. The repository Functions CI job invokes these unit and Emulator suites.
- Clean Node 22 installation verified with `npm ci`. The Functions and Firestore Rules test package audits reported zero vulnerabilities after pinning `fast-xml-parser` to 5.12.0.
- Android release APK build and signing inspection succeeded. The iOS release build was compiled without distribution code signing.

## Release blockers — not cleared by this manifest

1. No `LICENSE` file exists. Confirm first-party ownership, contributor rights and third-party asset/dependency obligations before granting public reuse rights.
2. The maintainer-local root Firestore rules snapshot remains excluded. Candidate G is validated for Emulator QA only; production Rules approval and deployment have not occurred.
3. The dependency licence inventory is documented in `THIRD_PARTY_NOTICES.md` and the ecosystem CSV files, including Android Gradle components. Its explicit caveats are four Flutter engine artifacts without individual POM licence declarations and two reconstructed Node MIT notices. The separate whole-project dependency advisory audit remains outstanding.
4. Genuine, privacy-safe application screenshots have not been captured.
5. GitHub Actions has not yet run against a pushed commit. No push is authorized by this manifest.
6. The Flutter payroll SDK integration (`integration_test/payroll_callable_sdk_test.dart`) remains a separate device/simulator integration gate and is not covered by the Node-based Functions CI job.
7. Production Firebase acceptance and iOS distribution signing remain outstanding. Remote push is intentionally disabled; no production push-delivery acceptance is claimed.

## Git and deployment safety

- This manifest does not stage files, create commits or push to GitHub.
- Existing staged Firebase client-configuration removals remain separate from this proposed file list and must be reviewed before any commit.
- No Firebase production deployment is authorized by this document.
- Public release remains blocked until licensing, Rules, integration and publication reviews are resolved.


## Public snapshot security exclusions — 13 November 2026

Firebase, Firestore and Storage security-rule files, including QA and emulator candidates, are excluded from this public snapshot. Firebase runtime configuration, credentials, environment secrets and signing keys are also excluded from the published tree and its Git history. Clearly labelled example templates may remain.
