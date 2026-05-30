---
name: deploy-app
description: Use when the user wants to deploy a new version of the BetelSAS mobile app to the Play Store.
---

# Deploy App

The CI/CD pipeline (Jenkins + Docker + fastlane) handles the actual build and upload automatically on push to main. This skill's job is just to bump the version and commit.

## Steps

1. Ask the user for the new version if not provided (e.g. `1.0.3`).
2. Read `src/mobile/pubspec.yaml` and update the `version` line:
   - Increment `versionName` to the requested version
   - Increment `versionCode` (`+N`) by 1
   - Example: `version: 1.0.2+4` → `version: 1.0.3+5`
3. Show the proposed commit message and wait for approval:
   ```
   chore(mobile): bump version to X.Y.Z for Play Store deploy
   ```
4. After approval: commit and push to main. Jenkins picks it up automatically.

## How the pipeline works

- Jenkins watches `main` for changes to `src/mobile/**`
- On change: builds the Docker image (`Dockerfile.ci`), runs `flutter build appbundle --release`, then `fastlane internal`
- Credentials are managed in Jenkins (secret file `play-store-credentials-json`) — never in the repo

## Notes

- The Play Store rejects reused versionCodes — always increment `+N`
- `versionName` is what users see (e.g. `1.0.3`); `versionCode` is the internal counter
- Never push credentials to the repo — they live only in Jenkins and Bitwarden (`play-store-credentials-json`)
