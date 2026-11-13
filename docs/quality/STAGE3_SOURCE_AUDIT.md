# Stage 3 — Source Audit Record

**Snapshot:** 8 November 2026, 10:20 local time
**Input:** `MohallaFlow_Stage3_Current_Source_20261108_102040.zip` and embedded `evidence/source_manifest.json` / `evidence/git_state.json`.

## Inventory

- 119 project files collected (120 ZIP entries including the two evidence JSON files).
- 63 Dart files total.
- 46 application screens.
- 5 Dart service files.
- 4 Flutter test files and 1 Cloud Functions Node test file.
- No `integration_test/` directory in the collected source.
- 41 of 46 screens import both `firebase_auth` and `cloud_firestore` directly; approximately 255 literal collection call sites occur in screen files.

## Existing automated tests

- `test/hindi_button_translation_test.dart`
- `test/hindi_feature_module_title_test.dart`
- `test/resident_registration_phone_test.dart`
- `test/widget_test.dart` (splash → login smoke test)
- `functions/test/phone.test.js`

The existing Flutter tests do not demonstrate auth/membership service testing, feature widget-state coverage or cross-role integration workflows.

## Firestore rules provenance

- `project/firestore.rules` is 384,997 bytes and has SHA-256 `d6ad52d1e91917104c05b87e39e56567592690d0b5af1a61b7d667c22260f768`.
- `qa_candidates/firestore_candidate_v2.rules` is a separate candidate, 232,122 bytes, SHA-256 `97effc7277be6ad0415250206d38d9570eed9cafe9c1fd50e5861e069e8e4b6b`.
- The latter is the exact candidate reported by the user as passing 24 general + 10 worker-attendance Emulator tests.
- The original local rules file and tested candidate must not be conflated. Production has not been deployed by this process.

## Git worktree

The captured branch is `main`, HEAD `fd009acd602f103b3eb2eaaa930c35839daf58b2`, with numerous modified tracked files and many untracked application, rules, documentation and QA paths. The repository is not a clean baseline. Do not use `git reset`, `git clean`, mass checkout, or broad generated-file deletion. Any Stage 3 patch must be additive and must preserve existing local work.

## Checks executed against this uploaded source in the analysis environment

- `node --check functions/index.js`: PASS.
- `node --test functions/test/phone.test.js`: 5/5 PASS.
- JSON parsing for `firebase.json`, `firestore.indexes.json`, `functions/package-lock.json`: PASS.
- Flutter/Dart SDK is not installed in the analysis container; Flutter analysis, Dart formatting, Flutter tests and platform builds were not run here.

The user separately supplied a local Emulator result for the v2 candidate: 24/24 authorization tests and 10/10 attendance tests passed. This is user-provided execution evidence, not a test run performed against production.

## Risks requiring subsequent Stage 3 work

1. Extract repositories from high-value screens without changing behaviour.
2. Build controlled Firebase Auth/Firestore test seams for `UserAccessService`.
3. Add role-specific widget tests and integration workflows.
4. Add a workflow-level query/index inventory; the current index file contains one field override and no composite index declarations.
5. Run online Pub/npm advisory review and triage; no vulnerability database query was performed in this source audit.
6. Verify live production schemas and rules separately from Emulator fixtures.
