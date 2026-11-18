# Screenshot and Demonstration Capture Plan

Only genuine screenshots captured from the current running application may be presented as product evidence. Do not create mockups or generated images and label them as real application screens.

## Required captures

1. Admin dashboard — seeded synthetic colony, no real names, phone numbers, addresses or balances.
2. Resident dashboard — synthetic resident and household identifiers only.
3. Cleanliness Manager dashboard — synthetic work queue and masked worker names.
4. Worker dashboard — synthetic assigned task and attendance record.
5. Resident complaint submission and Admin review.
6. Cleanliness Manager assignment and Worker completion.
7. Announcement creation and resident visibility.
8. Maintenance / payment / visitor workflows where their tested state can be demonstrated accurately.

## Capture controls

- Use a dedicated demo Firebase project or Emulator fixtures.
- Create synthetic names, addresses, phone numbers, vehicle registrations, invoice IDs and payment amounts.
- Disable or redact notifications containing private data.
- Inspect image metadata and crop notifications / status bars that reveal account or device details.
- Capture the actual app at a consistent resolution and retain original captures separately from edited/redacted public copies.
- Obtain maintainer approval before adding captures to the repository.

## Automated capture and publication

The public GitHub Actions four-role Android Emulator job now captures four dashboard PNGs from the running Flutter application using authenticated synthetic accounts:

- `assets/screenshots/01-admin-dashboard.png`
- `assets/screenshots/02-resident-dashboard.png`
- `assets/screenshots/03-cleanliness-manager-dashboard.png`
- `assets/screenshots/04-worker-dashboard.png`

The capture pass checks that all four files exist, have a valid PNG signature, and meet minimum dimensions before they are published. The fixture uses the isolated `demo-mohallaflow` Auth and Firestore Emulators. Clearly invalid/masked contact values are used in the synthetic resident and worker records. Production Firebase is not accessed.

The capture step uploads an Actions artifact and publishes the validated copies into the PR branch. A separate emulator pass then runs the complete four-role acceptance suite. No mockups or generated screen illustrations are used as product screenshots.
