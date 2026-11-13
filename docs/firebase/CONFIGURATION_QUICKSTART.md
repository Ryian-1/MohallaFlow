# Firebase configuration setup

Firebase CLI and client configuration are specific to each developer's Firebase project.

## 1. Create your local Firebase CLI configuration

From the repository root, copy the portable template:

```bash
cp firebase.json.example firebase.json
```

The local `firebase.json` is intentionally ignored by Git. Do not replace an existing working local copy unnecessarily.

The portable example includes:
- Cloud Functions configuration (Node.js 22).
- Firebase Hosting configuration for the Flutter web build.

It deliberately omits a top-level Firestore deployment configuration. The repository's current root `firestore.rules` file exceeds the documented source-size limit, and the separately tested candidate is not approved for production deployment. Do not add a Firestore deployment entry or deploy Rules until a reviewed, deployment-ready ruleset is approved.

The Emulator QA scripts generate their own temporary Firebase configuration and use the pinned QA candidate. They do not require the local `firebase.json` to contain a Firestore deployment section.

## 2. Configure your own Firebase project

Create or select a Firebase project that you own. Register the Android and iOS application IDs and configure the authentication providers and Firestore database required by your development environment.

Install FlutterFire CLI and run:

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project YOUR_FIREBASE_PROJECT_ID --platforms android,ios,web
```

FlutterFire generates project-specific client configuration, including:
- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

Keep these files local. They are ignored by Git.

Select your own Firebase CLI project:

```bash
firebase login
firebase use --add
```

The generated `.firebaserc` is also local and ignored.

## 3. CI configuration

GitHub Actions copies `lib/firebase_options.dart.example` to the ignored `lib/firebase_options.dart` path. The example contains nonfunctional placeholder values solely to allow analysis and compilation. It must not be used to run the app against a real Firebase backend.

## 4. Deployment boundary

Do not run a broad `firebase deploy` command for this repository until the Firestore Rules deployment blocker has been resolved and all deployment targets have been independently reviewed.

Functions and Hosting may be deployed separately to a Firebase project you own, after reviewing their configuration, environment, billing, IAM permissions and production readiness. This guide does not authorize deployment to the maintainer's Firebase project.
