# Licence and Ownership Review — blocker

No licence file is added by this preparation package. Publishing a licence without evidence of ownership and third-party rights would be unsafe.

Before selecting an open-source licence, the maintainer must verify:

1. Who authored and owns every first-party Dart, Swift, Kotlin, JavaScript, Python, shell and documentation file.
2. Whether any code was generated, copied from a tutorial, derived from a template, commissioned or contributed by another person under separate terms.
3. Whether all contributors have granted the rights needed to distribute their contributions.
4. Whether fonts, icons, illustrations, logos, screenshots, sound, images and other assets have licenses that permit the intended redistribution.
5. Whether third-party API terms, SDK terms and Firebase service terms impose obligations beyond the source-code licence.
6. Whether trademarks / product name / logo rights are owned or licensed.

A dependency licence inventory has now been generated for Flutter/Dart, Firebase Functions and Firestore QA Node dependencies, iOS Swift Package Manager dependencies, and Android Gradle runtime/build components. See `THIRD_PARTY_NOTICES.md` and the per-ecosystem CSV inventories. The inventory records the two reconstructed Node MIT notices and four Flutter engine artifacts without individual POM licence declarations as explicit provenance/coverage caveats. This inventory is not legal clearance or confirmation of first-party ownership and redistribution rights.

## Recommendation process

- If the owner confirms sole ownership of all first-party code and assets and wants broad reuse, compare permissive licences such as MIT and Apache-2.0; Apache-2.0 adds an express patent grant and more detailed terms.
- If the owner wants reciprocal source-sharing obligations, evaluate an appropriate copyleft licence with counsel/maintainer review.
- Do not choose a licence based only on popularity or because a tool generated a default.

Until approval, keep `LICENSE` absent and describe the repository as unlicensed / rights not yet granted. Do not imply that no licence means the code is public domain.
