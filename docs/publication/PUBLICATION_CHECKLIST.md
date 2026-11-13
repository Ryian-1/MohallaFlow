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
- [x] Remote Git tree was checked after push; no `.rules` files or matching Firebase credential/configuration files were present.
- [x] Firebase/Firestore/Storage security rules, runtime Firebase configuration, credentials, environment secrets and signing keys were excluded. Clearly labelled example templates remain.
- [x] No Firebase production deployment was performed or authorized.

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
- [x] All six public GitHub Actions jobs passed on 13 November 2026, run [43381104036](https://github.com/Ryian-1/MohallaFlow/actions/runs/43381104036), commit `081fc0a82cc9464cfb5664c0494818825022c177`.
- [x] Flutter format, static analysis, unit/widget tests, Cloud Functions lint/unit tests, npm audits, recursive OSV scan and full-history Gitleaks scan passed.
- [x] Flutter payroll callable SDK integration passed on an Android Emulator against Auth, Firestore and Functions Emulators using synthetic data.
- [x] GitHub Actions updated to `actions/checkout@v7` and `actions/setup-node@v7`; the six-job run above passed with these versions.
- [x] A payroll-only test rules fixture is generated temporarily inside the CI runner and removed at job exit. It is not Candidate G and is not a production ruleset.

The public workflow covers Flutter format, analysis and unit/widget tests; Cloud Functions lint/unit tests; dependency audits; full-history secret scanning; recursive OSV scanning; and the narrow payroll Flutter SDK Emulator integration. The broader Firestore authorization suites that require the private Candidate G rules remain maintainer-only. Do not add private or production rules to the public repository to make those suites pass.

[View GitHub Actions](https://github.com/Ryian-1/MohallaFlow/actions)

## 4. Checks still requiring fresh evidence

- [x] Online `npm audit --audit-level=moderate` passed for `functions/package-lock.json` and `firestore-rules-tests/package-lock.json` in public GitHub Actions run [43381104036](https://github.com/Ryian-1/MohallaFlow/actions/runs/43381104036), 13 November 2026. No moderate-or-higher npm advisories were reported at scan time.
- [x] Recursive OSV-Scanner completed successfully against supported dependency manifests/lockfiles in the public repository in the same run; no findings were reported at scan time.
- [x] Gitleaks completed successfully against the full public Git history in the same run. This scan does not replace triage of any separate GitHub Secret Scanning alert.
- [x] Flutter payroll callable SDK integration passed on an Android Emulator with local Auth, Firestore and Functions Emulators, using synthetic test data and a temporary payroll-only rules fixture.
- [x] A fresh GitHub-hosted checkout completed all six CI jobs, including Flutter and Functions tests.
- [ ] Independently verify the contributor setup instructions on a separate maintainer-controlled Mac/Windows environment.
- [ ] Re-run the broader four-role UI/integration acceptance suite after any application-source changes.

The successful GitHub Actions run is fresh evidence for the checks listed above. It does not establish production Firebase acceptance or replace the broader private Candidate G authorization test suite.

## 5. Production and deployment blockers — keep unchecked

- [ ] Restructure, independently review and approve the production Firestore rules. The maintainer-local root rules snapshot was previously measured at 384,997 bytes, above Firebase's documented 256 KiB source limit, and remains excluded.
- [ ] Candidate G was validated in an Emulator environment only. It is not approved for production deployment and is not included in this public repository.
- [ ] Complete a fresh independent Firebase project setup and acceptance test.
- [ ] Verify production App Check enforcement and Android Play Integrity / Apple App Attest configuration in the intended Firebase projects.
- [ ] Review Firebase API-key restrictions, IAM, Functions authorization, quotas and environment separation.
- [ ] Confirm production data handling, backup/restore, privacy disclosures, retention, access controls and incident response.
- [ ] Verify real authentication and critical workflows using synthetic test data in the independent environment.
- [ ] Complete live push notification and APNs delivery verification only if push notifications are enabled for the release.
- [ ] Prepare signed Android and iOS distribution builds and complete device acceptance testing.
- [ ] Do not deploy Firebase rules or Functions as part of GitHub publication. Production deployment requires separate explicit authorization.

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

**Current decision: PUBLIC CODE SHOWCASE PUBLISHED; SIX-JOB PUBLIC CI, PAYROLL SDK EMULATOR INTEGRATION AND CURRENT DEPENDENCY/SECRET SCANS PASS; NOT READY FOR PRODUCTION DEPLOYMENT OR STORE RELEASE.**

The repository is public and the initial snapshot has an independent clean history. The remote tree contains no Firebase security rules or matching Firebase credential/configuration files. Public CI passes on a fresh GitHub checkout, including Flutter checks, Functions checks, npm advisory audits, recursive OSV scanning, full-history Gitleaks scanning and the narrow payroll SDK Emulator integration. The full Firestore authorization suites requiring private Candidate G remain private.

Production Firestore approval, independent Firebase acceptance, App Check configuration acceptance, distribution signing, legal/ownership approval and authentic screenshots remain open gates. The public payroll SDK Emulator integration is complete; the broader four-role acceptance suite remains a separate private QA gate.
