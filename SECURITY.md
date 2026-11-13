# Security Policy

## Supported versions

Only the actively maintained default branch is currently considered for security fixes. No stable public release series has been established.

## Reporting a vulnerability

**Do not report exploitable vulnerabilities in a public issue.** Use GitHub's private vulnerability reporting feature if it is enabled for this repository. If it is not enabled, contact the repository owner through a private channel listed on the owner's GitHub profile and ask for a secure reporting route.

Please include:

- A concise description and impact.
- Affected commit, file, platform and environment.
- Reproduction steps using synthetic data.
- Any proposed mitigation.

Do not attach resident records, production database exports, credentials, access tokens or live device identifiers.

## Security principles

- Firestore access must be authenticated, colony-scoped and role/ownership constrained.
- Security Rules are not a substitute for server-side validation in privileged Cloud Functions.
- Never commit service-account JSON, private keys, signing material, passwords or access tokens.
- Firebase client configuration is shipped to client applications and is not equivalent to a service-account credential; restrict API keys and protect data with Rules and App Check.
- Test authorization with Firebase Emulator and synthetic fixtures. Do not run destructive tests against production.
- Rotate an actual exposed secret at its issuing service; removing it from the latest commit is not sufficient.
