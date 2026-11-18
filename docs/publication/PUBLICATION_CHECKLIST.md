# MohallaFlow — Public Snapshot and Release Checklist

**Review date:** 18 November 2026  
**Publication status:** Public code-showcase snapshot and genuine four-role screenshot gallery published; **not a production or store release**.

This document distinguishes the published source snapshot, locally completed engineering evidence, public CI, and the separate requirements for a production colony deployment. Emulator test success is not production approval. An unsigned iOS build is not App Store distribution readiness.

## 1. Published GitHub snapshot

- [x] Public repository: https://github.com/Ryian-1/MohallaFlow
- [x] Default branch: `main`.
- [x] Published root commit: `1f67be9ba9541a48583ed90d8b3ca2964fd858ee` (initial publication snapshot; subsequent documentation/CI commits follow it).
- [x] Initial publication commit is an independent root commit with zero parents; previous private Git history was not pushed.
- [x] 503 tracked files were published in the initial snapshot.
- [x] Exact staged publication snapshot was scanned with Gitleaks: approximately 5.47 MB scanned, no leaks found.
- [x] Runtime Firebase configuration, credentials, environment secrets and signing keys are excluded. Clearly labelled example templates remain.
- [x] The release branch includes a SHA-pinned Firestore Rules deployment candidate under `release/firestore/`; it is not a deployed production configuration.
- [x] No production Firestore Rules, indexes or Cloud Functions have been deployed.

## 2. Verified local engineering evidence

- [x] Excluded Local Services Directory screen is absent from the published application sources.
- [x] Flutter unit/widget tests: 40 passed in the recorded local validation run.
- [x] Flutter static analysis: no issues found in the recorded local validation run.
- [x] Dart formatting check: 74 files checked, zero files changed.
- [x] Firestore targeted QA: 22 authorization scenarios and 10 attendance scenarios passed against the private Candidate G QA rules.
- [x] Firestore extended Emulator suite: 152 tests passed against the private Candidate G QA rules.
- [x] Functions lint passed.
- [x] Functions resident-registration tests: 5 passed.
- [x] Functions App Check tests: 1 passed.
- [x] Worker-private migration unit tests: 5 passed.
- [x] Functions Emulator QA previously completed successfully with 13 emulator tests and the payroll callable integration in an isolated demo project.
- [x] Four-role application integration previously passed 1/1 on the iPhone 18 Pro simulator, covering Admin, Resident, Cleanliness Manager and Worker dashboards.
- [x] Android release APK compiled successfully; recorded output approximately 69.7 MB.
- [x] iOS device Release app compiled successfully with code signing disabled; recorded output approximately 57.6 MB.
- [x] iOS AppIcon catalog: 19 entries, zero missing referenced images; 1024x1024 marketing icon matches the master branding icon.
- [x] Third-party dependency licence inventories generated for Flutter/Dart, Node, iOS Swift Package Manager and Android Gradle. Provenance caveats remain documented in `THIRD_PARTY_NOTICES.md`.

These are recorded local results from the remediation workspace. They are not a claim that every suite has been rerun from a clean public clone or against production Firebase.

## 3. Public GitHub Actions

The public workflow separates dashboard screenshot capture from full application acceptance so each Android Emulator job starts with a clean app and Emulator lifecycle.

The nine jobs are:

1. Flutter format, static analysis, unit and widget tests.
2. Cloud Functions lint and unit tests, including isolated payroll backend tests.
3. npm dependency audits for both lockfiles.
4. Full-history Gitleaks secret scanning.
5. Recursive OSV dependency vulnerability scanning.
6. Production release package integrity and deployment-script syntax.
7. Flutter payroll callable SDK integration on an Android Emulator.
8. Genuine Admin, Resident, Cleanliness Manager and Worker screenshot capture on an Android Emulator.
9. Full four-role application acceptance on a separate Android Emulator, including the resident complaint → Manager assignment → Worker completion journey, notification deduplication and maintenance payment verification.

The Emulator jobs use fictional role names, deliberately invalid placeholder phone values, the `demo-mohallaflow` project and isolated Auth/Firestore Emulators. The screenshots are uploaded as a workflow artifact and validated copies are published to the PR branch. Production Firebase is not accessed.

The exact release Rules candidate remains under `release/firestore/`; its six-suite, 122-test authorization result was produced in private Emulator CI. Other private QA fixtures and production runtime configuration remain excluded. Do not add live production credentials or resident data to the public repository.

[View GitHub Actions](https://github.com/Ryian-1/MohallaFlow)

## 4. Current CI evidence

- [x] npm dependency audits have passed in public GitHub Actions.
- [x] Recursive OSV-Scanner has completed successfully; rerun after dependency changes.
- [x] Gitleaks has completed successfully against the full public Git history.
- [x] Flutter payroll callable SDK integration has passed on an Android Emulator using isolated Auth/Firestore/Functions Emulators and synthetic data.
- [x] Four-role screenshot capture has passed on an Android Emulator; four genuine dashboard PNGs are included under `assets/screenshots/`.
- [ ] The full four-role application acceptance job must pass on the current PR head; a screenshot-only pass is not a substitute.
- [ ] Independently verify the contributor setup instructions on a separate maintainer-controlled Mac/Windows environment.

Live run status is authoritative at [GitHub Actions](https://github.com/Ryian-1/MohallaFlow/actions). CI success does not establish production Firebase acceptance or replace the broader private Candidate G authorization test suite.

## 5. Production and deployment blockers — keep unchecked

- [x] A SHA-pinned Firestore Rules candidate and index manifest are included in the release branch; the exact candidate passed six private Emulator suites (122 passed, 0 failed, 0 skipped).
- [ ] Complete independent production Rules review and compatibility acceptance. Production membership preflight now passes, but older installed app builds or an external integration may exist and their `collectionGroup('members')` usage has not been established.
- [ ] Deploy the required production Firestore indexes, wait for READY, deploy the reviewed Rules candidate, and verify the exact active Rules release SHA only after the legacy-client compatibility gate is cleared.
- [ ] Complete a fresh independent Firebase project setup and acceptance test.
- [ ] Verify production App Check enforcement and Android Play Integrity / Apple App Attest configuration in the intended Firebase projects.
- [ ] Review Firebase API-key restrictions, IAM, Functions authorization, quotas and environment separation.
- [ ] Confirm production data handling, backup/restore, privacy disclosures, retention, access controls and incident response.
- [ ] Verify real authentication and critical workflows using synthetic test data in the independent environment.
- [ ] Complete live push notification and APNs delivery verification only if push notifications are enabled for the release.
- [ ] Prepare signed Android and iOS distribution builds and complete device acceptance testing.
- [ ] Deploy the six allowlisted Cloud Functions only after Firestore indexes and Rules are successfully deployed and verified. Native OS push dispatcher remains excluded by design.
- [ ] Complete production acceptance on controlled pilot accounts before resident rollout.

## 6. Legal, assets and product presentation

- [ ] Confirm first-party code ownership and rights for every contribution, generated/copied template and commissioned component.
- [ ] Confirm rights to logos, fonts, icons, screenshots and other visual assets.
- [x] Generate documented third-party dependency licence inventories. Four Flutter engine artifacts and two reconstructed Node MIT notices retain explicit source-provenance caveats; the inventory is not legal clearance.
- [x] Keep the repository unlicensed / all rights reserved for this public showcase; no open-source licence is granted. Revisit only after ownership and redistribution rights are confirmed.
- [x] Capture genuine, sanitised Admin, Resident, Cleanliness Manager and Worker dashboard screenshots from the current application using fictional demo identities; originals are published under `assets/screenshots/`.
- [x] README, architecture, data-model, Firebase setup, security and troubleshooting pages are present and their public CI/setup relationship is documented. Final human acceptance review remains advisable.
- [ ] Prepare release notes and select a version only after the included snapshot is frozen.
- [ ] Decide whether to make a separate public release announcement after the review gates are cleared.

No open-source licence is currently granted in this repository. Public visibility is not a licence to reuse, modify, redistribute or commercially deploy the original project code or brand assets.

## 7. Release decision

**Current decision: PUBLIC CODE SHOWCASE AND FOUR-ROLE SCREENSHOT GALLERY PUBLISHED; PORTFOLIO PRESENTATION IS SEPARATE FROM PRODUCTION DEPLOYMENT OR STORE RELEASE.**

The repository is public, the initial publication history is independent, and the genuine four-role dashboard screenshot gallery is included in the repository. The release branch contains the SHA-pinned Firestore deployment candidate, but production Rules/indexes and Functions remain undeployed. The public CI pipeline covers Flutter, Functions, dependency/security scans, release integrity, payroll SDK integration, screenshot capture and full four-role Android acceptance. The broader Firestore authorization evidence remains in private Emulator CI.

Production legacy-client compatibility, Firestore deployment and verification, Functions deployment, App Check configuration acceptance, signed Android/iOS distribution and legal/ownership approval remain open gates. This repository is suitable as a portfolio code showcase only after the current CI acceptance job is green; it must not be described as a production colony deployment or store release.
