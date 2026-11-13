# MohallaFlow — Publication Readiness Checklist

**Review date:** 13 November 2026
**Status:** Curated publication candidate; **not yet approved for public release**.

This checklist records evidence available from the local remediation work and separates verified local results from outstanding production, legal and publication gates. A passing emulator test is not production approval. A successful unsigned iOS build is not App Store distribution readiness.

## 1. Verified local engineering evidence

- [x] Curated publication manifest: 227 unique entries, zero missing files and zero duplicate entries.
- [x] Excluded Local Services Directory screen is absent from the curated snapshot; no Dart imports or class references to that screen were found in the snapshot's `lib/` sources.
- [x] Developer-specific Firebase configuration files are excluded from the curated snapshot: `google-services.json`, `GoogleService-Info.plist`, generated `lib/firebase_options.dart`, local `firebase.json`, `.firebaserc` and root `firestore.rules`.
- [x] Gitleaks directory scan of the exact 227-file publication snapshot: zero findings.
- [x] Gitleaks scan of the local remediation Git history: zero findings across three local commits.
- [x] Flutter unit/widget tests: 40 passed using `flutter test --no-pub`.
- [x] Flutter static analysis: no issues found.
- [x] Dart formatting check: 74 files checked, zero files changed.
- [x] Firestore targeted QA: 22 authorization scenarios and 10 attendance scenarios passed.
- [x] Firestore extended Emulator suite: 152 tests passed.
- [x] Functions lint passed.
- [x] Functions resident-registration tests: 5 passed.
- [x] Functions App Check tests: 1 passed.
- [x] Worker-private migration unit tests: 5 passed.
- [x] Functions Emulator QA: previously completed successfully with 13 emulator tests and the payroll callable integration. A later consolidated rerun was blocked because port 8080 was occupied; the runner correctly stopped without terminating the existing process.
- [x] Four-role application integration: previously passed 1/1 on the iPhone 18 Pro simulator, covering Admin, Resident, Cleanliness Manager and Worker dashboards. A later consolidated rerun was blocked because port 8080 was occupied.
- [x] Android release APK compiled successfully; recorded output approximately 69.7 MB.
- [x] iOS device Release app compiled successfully with code signing disabled; recorded output approximately 57.6 MB.
- [x] iOS AppIcon catalog: 19 entries, zero missing referenced images; 1024x1024 marketing icon SHA-256 matches the master branding icon.
- [x] Branding asset bundle verified to contain only `logo_horizontal.png` and `monogram.png`; the source `.bak` file remains preserved and is not bundled.
- [x] Updated README installed into the temporary publication snapshot; nine internal links validated with zero broken links.
- [x] `git diff --check` passed during the local preflight.

## 2. Checks that need a fresh run or were inconclusive

- [ ] Rerun online npm audit when registry connectivity is available. An earlier Functions audit reported zero vulnerabilities, but the latest run failed to reach `registry.npmjs.org`.
- [ ] Rerun OSV lockfile scan when `api.osv.dev` is reachable. An earlier scan reported no findings across the three scanned lockfiles; the latest run could not reach the OSV API and is not a fresh security pass.
- [ ] Rerun Flutter tests only if source changes after the recorded 40/40 pass.
- [ ] Rerun Functions Emulator and four-role integration if required after source changes, using a verified free-port environment. Do not terminate existing processes automatically.
- [ ] Execute the Flutter payroll SDK integration test on a simulator/device against its dedicated local emulator fixture. The Functions-side callable integration passed; this separate Flutter SDK integration test has not yet been evidenced as executed.
- [ ] Validate a clean clone and documented setup from a separate environment.
- [ ] Review CI workflow syntax and confirm all intended files are included in formatting checks; then observe actual GitHub Actions results on the publication branch/PR.

## 3. Production and deployment blockers — keep unchecked

- [ ] Restructure, independently review and approve the production Firestore rules. The maintainer-local root rules snapshot was previously measured at 384,997 bytes, above Firebase's documented 256 KiB source limit, and is intentionally excluded.
- [ ] Candidate G (`qa_candidates/firestore_candidate_g.rules`, SHA-256 `7f30e3bdd6b6e244e66c33baaa32a6ee3ef04beb6799bc377f87f29bac8a2ab0`) is emulator-validated only. It is not approved for production deployment.
- [ ] Complete a fresh independent Firebase project setup and acceptance test.
- [ ] Verify production App Check enforcement and Android Play Integrity / Apple App Attest configuration in the intended Firebase projects.
- [ ] Review Firebase API-key restrictions, IAM, Functions authorization, quotas and environment separation.
- [ ] Complete live push notification and APNs delivery verification if push is enabled for the release.
- [ ] Confirm production data handling, backup/restore, privacy disclosures, retention, access controls and incident response.
- [ ] Do not deploy Firebase rules or Functions as part of GitHub publication. Production deployment requires a separate explicit authorization.

## 4. Legal, assets and public repository readiness — keep unchecked until evidenced

- [ ] Confirm first-party code ownership and rights for every contribution, generated/copied template and commissioned component.
- [ ] Confirm rights to logos, fonts, icons, screenshots and other visual assets.
- [x] Generate documented third-party dependency licence inventories for Flutter/Dart, Node, iOS Swift Package Manager and Android Gradle. See `THIRD_PARTY_NOTICES.md`; four Flutter engine artifacts and two reconstructed Node MIT notices retain explicit source-provenance caveats.
- [ ] Decide whether the repository remains unlicensed / all rights reserved or receives an explicitly approved open-source licence. Do not add a licence until ownership and redistribution rights are confirmed.
- [ ] Capture genuine, sanitised screenshots from the current application using synthetic demo data for all four roles and key workflows. Do not label mockups as real application screenshots.
- [ ] Complete README, architecture, data-model, Firebase setup, security and troubleshooting review.
- [ ] Prepare release notes and select a version only after the included snapshot is frozen.
- [ ] Confirm a clean publication history and perform secret scanning on the exact release tree and its new history.
- [ ] Verify GitHub Actions on the publication commit/PR.
- [ ] Obtain explicit approval before pushing, changing repository visibility, creating tags/releases or publishing the LinkedIn announcement.

## 5. GitHub history and publication strategy

The existing GitHub repository is separate from the local remediation repository. The remote repository's `main` history contains five commits and historically tracked Firebase client configuration files. Those files are currently excluded from the curated snapshot, and the local three-commit remediation history passed Gitleaks. This does not make the remote history equivalent to the clean snapshot.

Recommended publication approach:

1. Preserve the existing private repository and its history.
2. Publish the reviewed 227-file curated snapshot with a fresh Git history, after the final snapshot review and owner approval.
3. Keep developer Firebase configuration, local aliases, the excluded Local Services Directory and generated artifacts out of the public tree.
4. Verify the resulting remote tree, default branch, README, licence notice, CI run and secret scan before changing repository visibility or announcing the project.

## 6. Release decision

**Current decision: NOT READY for a production deployment or an unconditional public release.**

The curated source snapshot has passed its file-count, README-link and Gitleaks checks. Local functional, emulator and build evidence is substantial. Production Firestore approval, independent Firebase acceptance, distribution signing, legal/ownership approval, authentic screenshots, current online dependency scans and actual GitHub Actions execution remain open gates.

Public code showcase publication may be considered separately from production deployment, but only after the owner approves the legal/asset position, the clean-history repository plan and the exact final tree.
