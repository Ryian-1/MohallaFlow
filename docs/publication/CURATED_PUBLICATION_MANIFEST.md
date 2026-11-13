# MohallaFlow — Public Snapshot Manifest

**Publication date:** 13 November 2026  
**Repository:** https://github.com/Ryian-1/MohallaFlow  
**Published branch:** `main`  
**Initial snapshot commit:** `1f67be9ba9541a48583ed90d8b3ca2964fd858ee`  
**Initial snapshot size:** 503 tracked files.

This is a record of the public snapshot that was pushed to GitHub. It supersedes the earlier local proposal that described a 227-entry candidate manifest. It does not authorize Firebase deployment, grant an open-source licence, or approve production release.

## Included content

The published snapshot contains the reviewed Flutter application source, Android and iOS project files, Cloud Functions source, tests, CI workflow, setup templates, architecture and quality documentation, and third-party dependency notices/inventories.

The actual published file list is available from the repository's `main` branch and its Git tree.

## Intentional security exclusions

The publication process excluded:

- All Firestore, Firebase and Storage security-rule files, including production rules and QA/emulator candidate rules.
- Developer-specific Firebase runtime configuration, including `.firebaserc`, `firebase.json`, generated `lib/firebase_options.dart`, Android `google-services.json` and iOS `GoogleService-Info.plist`.
- Environment secret files, credentials, service-account JSON files, private keys, certificates, signing stores and provisioning profiles.
- Local/private data, generated build output, dependency directories and backup/recovery artifacts.

Clearly labelled example templates such as `.firebaserc.example`, `firebase.json.example` and `lib/firebase_options.dart.example` may remain in the repository. They are templates, not live project credentials.

## History and secret-scan evidence

- The initial publication commit is a root commit with zero parents. The previous private Git history was not included in the public push.
- Gitleaks scanned the exact staged publication snapshot (approximately 5.47 MB) and reported no leaks.
- The continuous Gitleaks GitHub Action also passed against the full published Git history: https://github.com/Ryian-1/MohallaFlow/actions/runs/43371915159.
- Dependabot is configured for weekly Flutter/Dart Pub, Functions npm, Firestore QA npm and GitHub Actions updates.
- The remote Git tree was checked after publication; no `.rules` files or matching Firebase credential/configuration files were present.
- The previous private-history backup was retained locally by the maintainer.

A secret scan is evidence for the scanned snapshot, not a guarantee that future changes cannot introduce secrets. Continue scanning each proposed public change.

## CI boundary

Public GitHub Actions runs Flutter formatting, static analysis and unit/widget tests, plus Cloud Functions lint and Node.js unit tests.

Firestore and Functions Emulator suites that require the privately retained Candidate G rules file are maintainer-only validation. The rules candidate is intentionally not published to make public CI pass. Production rules are not present and must not be deployed from this repository.

## Release and licensing limitations

- Candidate G is Emulator-validated only and is not approved for production.
- Production Firebase acceptance, App Check enforcement, IAM review, data protection and backup/restore acceptance remain outstanding.
- Android/iOS store-distribution signing and release acceptance remain outstanding.
- Genuine sanitised screenshots and legal/ownership review remain outstanding.
- No open-source licence has been granted. Public visibility does not grant reuse, modification, redistribution or commercial deployment rights for first-party code or brand assets.
- Third-party components remain subject to their respective licences; see `THIRD_PARTY_NOTICES.md` and the per-ecosystem inventories. The documented provenance caveats remain open for review.

## Deployment safety

No Firebase production deployment was performed by this publication. Any future deployment of Firestore rules, Cloud Functions or other Firebase resources requires separate review and explicit authorization.
