# MohallaFlow — Public Snapshot and Release Checklist

**Review date:** 13 November 2026  
**Publication status:** Public code-showcase snapshot published; **not production-ready**.

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

The first workflow run on the publication commit exposed an incorrect CI boundary:

- [x] Flutter formatting, static analysis and unit/widget tests passed on GitHub Actions.
- [x] Cloud Functions lint and Node.js unit tests passed on GitHub Actions.
- [x] The original Functions job failed only at its subsequent Emulator step because its runner requires the deliberately excluded private Candidate G rules file.
- [x] The original Firestore job failed because the private Candidate G rules file is deliberately absent from the public repository.
- [x] Public CI workflow corrected to run checks that can execute from the public snapshot without private security rules or production Firebase configuration.
- [x] All seven public GitHub Actions jobs passed on 14 November 2026, run [43553930997](https://github.com/Ryian-1/MohallaFlow/actions/runs/43553930997), release-branch head `d65d579bf190bb7e2da05ebf6ff2dc6d296153e1`.
- [x] All seven public GitHub Actions jobs also passed on the final documentation-only PR head in run [43566338360](https://github.com/Ryian-1/MohallaFlow/actions/runs/43566338360); the earlier run above remains the application-code validation run.
- [x] Flutter format, static analysis, unit/widget tests, Cloud Functions lint/unit tests, npm audits, recursive OSV scan and full-history Gitleaks scan passed.
- [x] Flutter payroll callable SDK integration passed on an Android Emulator against Auth, Firestore and Functions Emulators using synthetic data.
- [x] GitHub Actions updated to `actions/checkout@v7` and `actions/setup-node@v7`; the seven-job run above passed with these versions.
- [x] A payroll-only test rules fixture is generated temporarily inside the CI runner and removed at job exit. It is not Candidate G and is not a production ruleset.

The public workflow covers Flutter format, analysis and unit/widget tests; Cloud Functions lint/unit tests; dependency audits; full-history secret scanning; recursive OSV scanning; release-package integrity; and the payroll Flutter SDK Emulator integration. The exact release Rules candidate is present under `release/firestore/`; its six-suite, 122-test authorization result was produced in private Emulator CI. Other private QA fixtures and production runtime configuration remain excluded. Do not add live production credentials or resident data to the public repository.

[View GitHub Actions](https://github.com/Ryian-1/MohallaFlow/actions)

## 4. Checks still requiring fresh evidence

- [x] Online `npm audit --audit-level=moderate` passed for `functions/package-lock.json` and `firestore-rules-tests/package-lock.json` in public GitHub Actions run [43553930997](https://github.com/Ryian-1/MohallaFlow/actions/runs/43553930997), 14 November 2026. No moderate-or-higher npm advisories were reported at scan time.
- [x] Recursive OSV-Scanner completed successfully against supported dependency manifests/lockfiles in the same run; no findings were reported at scan time.
- [x] Gitleaks completed successfully against the full public Git history in the same run. This scan does not replace triage of any separate GitHub Secret Scanning alert.
- [x] Flutter payroll callable SDK integration passed on an Android Emulator with local Auth, Firestore and Functions Emulators, using synthetic test data and a temporary payroll-only rules fixture.
- [x] A fresh GitHub-hosted checkout completed all seven CI jobs, including Flutter, Functions, security scans, release integrity and payroll SDK emulator integration.
- [ ] Independently verify the contributor setup instructions on a separate maintainer-controlled Mac/Windows environment.
- [ ] Re-run the broader four-role UI/integration acceptance suite after any application-source changes.

The successful GitHub Actions run is fresh evidence for the checks listed above. It does not establish production Firebase acceptance or replace the broader private Candidate G authorization test suite.

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
- [ ] Capture genuine, sanitised screenshots from the current application using synthetic demo data for all four roles and key workflows.
- [x] README, architecture, data-model, Firebase setup, security and troubleshooting pages are present and their public CI/setup relationship is documented. Final human acceptance review remains advisable.
- [ ] Prepare release notes and select a version only after the included snapshot is frozen.
- [ ] Decide whether to make a separate public release announcement after the review gates are cleared.

No open-source licence is currently granted in this repository. Public visibility is not a licence to reuse, modify, redistribute or commercially deploy the original project code or brand assets.

## 7. Release decision

**Current decision: PUBLIC CODE SHOWCASE PUBLISHED; SEVEN-JOB PUBLIC CI AND PAYROLL SDK EMULATOR INTEGRATION PASS; NOT READY FOR PRODUCTION DEPLOYMENT OR STORE RELEASE.**

The repository is public and the initial snapshot has an independent clean history. The release branch contains the SHA-pinned Firestore deployment candidate, but production Rules/indexes and Functions remain undeployed. Seven public CI jobs pass on a fresh GitHub checkout, including Flutter checks, Functions checks, npm audits, recursive OSV, full-history Gitleaks, release package integrity and payroll SDK Emulator integration. The broader Firestore authorization evidence remains in private Emulator CI.

Production legacy-client compatibility, Firestore deployment and verification, Functions deployment, App Check configuration acceptance, signed Android/iOS distribution, legal/ownership approval, authentic screenshots and a fresh four-role simulator test for the new Manager-menu assertion remain open gates. The public payroll SDK Emulator integration is complete.
