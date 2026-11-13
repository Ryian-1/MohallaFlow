# Contributing to MohallaFlow

Thank you for considering a contribution. MohallaFlow is an active Flutter + Firebase application; correctness, tenant isolation and preservation of existing workflows take priority over the size of a change.

## Before starting

- Check existing issues and discussions before proposing a large change.
- For substantial work, open an issue first and describe the user workflow, roles affected, data changes and security implications.
- Do not use production resident data, credentials or real phone numbers in tests or screenshots.
- Do not add dependencies without explaining why existing Flutter/Firebase APIs are insufficient.
- The repository currently has no approved open-source licence. Contribution and redistribution terms must be confirmed by maintainers before external contributions are accepted.

## Development setup

Follow the project README and [`docs/firebase/INDEPENDENT_FIREBASE_SETUP.md`](docs/firebase/INDEPENDENT_FIREBASE_SETUP.md). Use a personal development Firebase project or the Emulator Suite. Never point local experiments at a colony's production project.

## Change expectations

- Make the smallest coherent change; avoid broad rewrites and duplicate Firestore collections.
- Preserve the navy / white / grey visual system and existing localisation conventions.
- Keep Firestore authorization tenant-scoped. Do not solve a denied operation by broadening access without a threat-model review.
- Include loading, empty, error and retry behavior for asynchronous UI where applicable.
- Add/update unit, widget, service, Emulator or integration tests at the layer where behavior is implemented.
- Update architecture, data-model and setup documentation when a change affects them.

## Before opening a pull request

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
(cd functions && npm ci && npm run lint && npm run test:resident-registration)
bash tool/firestore_rules_qa/run.sh
bash tool/firestore_rules_qa/run_extended_suite.sh
```

Also build Android debug on an Android-capable environment and iOS Simulator on macOS with Xcode when platform files are changed. State clearly which checks were not run and why.

## Pull request content

Use the pull request template. Include the affected roles, Firestore paths/rules/index changes, tests executed, screenshots for UI changes (synthetic data only), migration/backward-compatibility notes, and known limitations. Never include secrets or private resident information in logs or test output.
