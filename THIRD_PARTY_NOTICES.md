# Third-Party Notices

MohallaFlow dependency licence inventory.

Audit snapshot: 12 November 2026.

This document records third-party dependencies and preserves available upstream licence and notice texts. It is an inventory, not legal advice or a grant of rights to the MohallaFlow application itself.

## Dependency inventory

| Ecosystem | Package records | Third-party records |
|---|---:|---:|
| Flutter / Dart | 183 pub records + 1 Dart SDK toolchain record | 182 non-app pub records + 1 Dart SDK toolchain record |
| Firebase Functions Node dependencies | 213 | 213 |
| Firestore rules QA Node dependencies | 90 | 89 |
| iOS Swift Package Manager | 14 | 14 |

Package counts are ecosystem-specific and may overlap across environments.

## Dependency manifests

- [Dart dependencies](docs/third_party_licenses/DART_DEPENDENCIES.csv)
- [Functions Node dependencies](docs/third_party_licenses/NODE_FUNCTIONS_DEPENDENCIES.csv)
- [Firestore QA Node dependencies](docs/third_party_licenses/NODE_FIRESTORE_QA_DEPENDENCIES.csv)
- [iOS Swift Package Manager dependencies](docs/third_party_licenses/IOS_SPM_DEPENDENCIES.csv)

The manifests record package name, version, declared licence, source repository, notice-text path, and any known notice gap.

## Retained licence texts

Licence texts are stored under `docs/third_party_licenses/texts/`, grouped by ecosystem. Identical texts are deduplicated by SHA-256. iOS notices retain their package and relative source-directory structure.

## Flutter and Dart SDK notices

- Flutter SDK **3.47.9 stable**, framework revision `c197ca5199e9ee5661e865596c9c07294dfab51c`,
  engine revision `89c39edfdfae2949f6806e4a315c0c08522238b7`. Shared Flutter BSD-style licence:
  `docs/third_party_licenses/texts/dart/a598db94b6290ffbe10b5ecf911057b6a943351c727fdda9e5f2891d68700a20.txt`.
- Dart SDK **3.13.7**. Separate Dart BSD-style licence:
  `docs/third_party_licenses/texts/dart/2cfa3ee8e7512e6d44c854b986510810fadc815f93f890373b3a81c1b6ccd256.txt`.

The six Flutter SDK package records without package-specific licence fields
are mapped to the shared Flutter SDK licence. The local `mohalla_flow`
record is the MohallaFlow application itself, not a third-party dependency.

## Android Gradle dependency coverage

The Android release runtime and compile graphs resolved successfully with
Gradle 9.3.1. The inventory contains 55 Maven components: 50 runtime/compile
coordinates and 5 explicitly versioned Gradle plugin implementations.

- 50 components declare Apache-2.0 in their Maven POM metadata.
- `com.google.guava:listenablefuture:1.0` has no POM licence element; Maven
  Central catalogue metadata identifies Apache-2.0.
- 4 Flutter engine artifacts have no individual POM licence
  declaration. They are recorded against Flutter engine revision
  `89c39edfdfae2949f6806e4a315c0c08522238b7` and are not automatically
  attributed to the Flutter framework's root licence.
- The Gradle 9.3.1 wrapper distribution LICENSE and NOTICE are retained
  separately as build-tooling notices.

The five versioned Maven Gradle plugins are Android Gradle Plugin 9.1.0,
Google Services 4.5.0, Firebase Crashlytics 3.0.8, Firebase Performance
2.0.2, and Kotlin Gradle Plugin 2.4.0. Flutter's own Gradle integration
plugins are supplied by the Flutter 3.47.9 SDK included build.

See [Android Gradle dependency inventory]
(docs/third_party_licenses/ANDROID_GRADLE_DEPENDENCIES.csv).

The POM inventory records declared licence metadata. It does not claim that
every package-specific upstream copyright or NOTICE file has been separately
audited.

## Upstream source-file caveats

The following packages declare MIT in their npm manifests, but their
published npm archives and exact source commits did not contain standalone
licence files. Their MIT notices are retained in this inventory using a
published third-party attribution record that lists the same package names,
versions, and copyright attributions.

| Package | Copyright attribution | Notice source |
|---|---|---|
| `stream-events@1.0.5` | 2018 Stephen Sawchuk | [Third-party attribution inventory](https://help.alteryx.com/pdf/general/TrifactaOpenSourceSoftwareLicenses.pdf) |
| `stubs@3.0.0` | 2017 Stephen Sawchuk | [Third-party attribution inventory](https://help.alteryx.com/pdf/general/TrifactaOpenSourceSoftwareLicenses.pdf) |

The text files are explicitly recorded as reconstructed/transcribed notices,
not as original files extracted from the npm archives. The npm package
metadata, author, repository, and exact source commit were independently
checked during this audit. For formal legal clearance, obtaining the
maintainer's original licence files would be preferable.

## MohallaFlow application rights

No root-level `LICENSE` file is added by this inventory. The MohallaFlow application remains without an open-source licence; this document does not grant permission to reuse, modify, or redistribute MohallaFlow's own code, branding, or generated logo.

Third-party dependencies remain subject to their own licences and notices. The Flutter engine-artifact and upstream-source caveats above, together with the separate ownership review, must be considered before treating the public release as legally cleared.
