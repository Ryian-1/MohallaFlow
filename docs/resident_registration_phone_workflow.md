# MohallaFlow Resident Registration and Phone Verification

## Agreed household/person model

- `colonies/{colonyId}/households/{householdId}.primaryPhone` is the shared household contact number. Multiple household members may share it.
- `colonies/{colonyId}/residents/{residentId}.phoneNumber` remains the resident contact number used by existing colony features. It may be the household contact number and is not a login credential.
- `loginPhoneNumber` and `phoneNumberE164` are separate optional fields for the resident's own personal app-login number.
- A family member can remain in the resident register without an individual app-login number.
- A personal login number must be a valid Indian mobile number, must not equal the shared household contact, and must be unique among resident records in each colony.
- The private registration `status` is `not_enabled`, `pending`, or `linked`. A server-linked record also has `linkedUid`, `linkedAt` and `verifiedPhoneNumberE164`.

## Registration and activation

1. Admin registers the household and its shared contact number.
2. Admin registers each resident against that household. The resident contact can use the household contact number. App login is optional; if enabled, Admin separately enters that person's own mobile number.
3. The resident signs in using Firebase Phone Authentication and completes OTP verification with their own number.
4. The app calls `claimResidentRegistration` without sending a phone number, resident ID, role, colony ID or household ID.
5. The callable reads the verified `phone_number` claim from the Firebase Auth ID token. It transactionally queries the Admin-only `residentLoginRegistrations` collection for matching personal login records, rejects duplicates inside a colony and rejects a number already linked to another UID.
6. Using the Admin SDK, it creates/updates `users/{uid}`, creates `colonies/{colonyId}/members/{uid}` and marks the private resident login registration as linked. Existing Firestore rules continue to deny client-side creation of users and memberships.
7. The normal `UserAccessService` is re-run and the existing role router opens the Resident experience.

The same individual may have one resident record in each of multiple colonies. The same verified UID receives one resident membership per colony. A second family member sharing only the household contact number cannot sign in with that shared contact; their own personal login number must be entered and OTP-verified.

## Locking and lifecycle

- The Admin can change or disable a pending login number before it is claimed.
- Once a number is linked, its login number and server linkage fields are immutable through the resident form. A secure re-verification workflow is required for number changes.
- A linked resident must be deactivated through the existing Move-in / Move-out workflow so the membership is also deactivated. The resident form prevents a conflicting direct deactivation.
- Existing `phoneNumber` contact values are never auto-promoted to personal login numbers.

## Index and existing Firestore rules note

- `firestore.indexes.json` is retained as the query-index source file for the colony-scoped Admin duplicate check and the callable's collection-group lookup on `phoneNumberE164`. The maintainer's local Firebase CLI configuration referenced this file; the portable `firebase.json.example` intentionally omits a Firestore deployment target until the Rules deployment blocker is resolved.
- The supplied uploaded rules snapshot already contains malformed detached brace blocks and duplicate `validTenantLease(data)` declarations in its tenant-lease section. This installer does not guess how to reconstruct those unrelated rules. Repair and validate the complete rules file in the Firebase Emulator before deploying any Firestore rules.

## Local setup and verification

- The installer adds `cloud_functions` to Flutter and merges one callable into the existing `functions/index.js`. Existing notification and emergency exports, dependencies and package scripts are preserved.
- Run `flutter pub get` after installation if the installer could not complete it.
- Run `cd functions && npm install && npm test` before deployment.
- Run Flutter analysis and the resident phone test with the normal project test suite.

## Deployment is intentionally not performed

The Firestore rule changes and Cloud Function source are local only. Review and test them first. Deploy rules and then the callable function only after approval. Cloud Functions deployment requires the Firebase Blaze (pay-as-you-go) plan. Review costs and create budget alerts before enabling billing. This installer does not change billing, deploy Firebase resources, alter cloud data, or push GitHub.
