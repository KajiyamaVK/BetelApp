---
name: deploy-app
description: Use when deploying a new version of the BetelSAS mobile app to the Google Play Store internal testing track.
---

# Deploy App

Builds and uploads the Android AAB to the Play Store internal track via fastlane.

## Steps

1. Bump version in `src/mobile/pubspec.yaml` — increment both `versionName` (e.g. `1.0.3`) and `versionCode` (e.g. `+5`). The Play Store rejects any reused versionCode.
2. Build the release AAB:
   ```bash
   cd src/mobile
   flutter build appbundle --release
   ```
3. Upload via fastlane:
   ```bash
   cd src/mobile
   export PATH="$HOME/.local/share/gem/ruby/3.2.0/bin:$PATH"
   bundle exec fastlane internal
   ```

## Setup (already done)

- Fastlane gems installed to `src/mobile/vendor/bundle` (bundler path configured in `.bundle/config`)
- Play Store credentials at `src/mobile/fastlane/play-store-credentials.json` (gitignored — stored in Bitwarden as `BetelApp Play Store Service Account`)
- Service account: `fastlane-play-store@betelapp-497909.iam.gserviceaccount.com`
- Google Play Android Developer API enabled on project `betelapp-497909`

## Common Errors

| Error | Fix |
|-------|-----|
| `Version code X has already been used` | Increment `+N` in pubspec.yaml and rebuild |
| `PERMISSION_DENIED` | Enable Google Play Android Developer API in Cloud Console |
| `The caller does not have permission` | Add service account email to Play Console → Users and permissions |
| `bundle: command not found` | Add `export PATH="$HOME/.local/share/gem/ruby/3.2.0/bin:$PATH"` |
