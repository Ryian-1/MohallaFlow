# MohallaFlow Android release signing

## Policy

- Debug APK builds continue to use the standard Android debug key.
- Release APK/AAB tasks fail early unless a dedicated upload keystore exists and all four release-signing values are configured.
- The release build type never references `signingConfigs.debug`.
- Keystore files and passwords must remain outside the repository and must never be sent in chat or committed to Git.

## Create the upload keystore locally

Run `keytool` from a trusted JDK and enter passwords interactively. Choose a keystore path outside the project, such as a private folder under your home directory. Keep an independent encrypted backup of the keystore and its credentials. Losing the upload key can delay future Play releases; do not rely on the development Mac as the only copy.

Example command (the tool prompts for passwords; do not add them to the command):

```bash
mkdir -p "$HOME/Library/Application Support/MohallaFlow/keys"
chmod 700 "$HOME/Library/Application Support/MohallaFlow/keys"
keytool -genkeypair -v \
  -keystore "$HOME/Library/Application Support/MohallaFlow/keys/mohallaflow-upload.jks" \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias mohallaflow-upload
```

## Configure the local Gradle user properties

Create or edit `~/.gradle/gradle.properties` (not the project's `android/gradle.properties`) and add the following four properties with your actual local values:

```properties
MOHALLAFLOW_RELEASE_STORE_FILE=/absolute/path/to/mohallaflow-upload.jks
MOHALLAFLOW_RELEASE_STORE_PASSWORD=your-local-keystore-password
MOHALLAFLOW_RELEASE_KEY_ALIAS=mohallaflow-upload
MOHALLAFLOW_RELEASE_KEY_PASSWORD=your-local-key-password
```

Protect the file:

```bash
chmod 600 "$HOME/.gradle/gradle.properties"
```

Do not paste this file or its values into ChatGPT, a ticket, a shared terminal transcript, or source control. Prefer a secret manager for CI builds.

## Validate locally

First confirm that a release build fails with the explicit missing-signing message when the properties are absent. Then configure the key locally and build:

```bash
cd "$HOME/development/MohallaFlow_Stage5_Remediation"
flutter build appbundle --release
```

Inspect the resulting AAB signature with `jarsigner -verify -verbose -certs` and extract the certificate SHA-256 fingerprint with `keytool -list -v -keystore <keystore-path> -alias mohallaflow-upload`. Compare it with the upload certificate registered in Play Console.

A successful local signature check is not a Play Console upload or store approval. Do not submit the AAB without explicit owner approval.
