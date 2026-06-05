# debug-app rule (BetelApp)

When running `/debug-app` in this project, always pass `--dart-define=CONTENT_BASE_URL=http://s3.kajiyama.com.br/betelapp-content-dev` to `flutter run` so the app reads from the **dev** MinIO bucket instead of production.

```bash
flutter run -d <device-id> --dart-define=CONTENT_BASE_URL=http://s3.kajiyama.com.br/betelapp-content-dev > /tmp/flutter_run.log 2>&1 &
```

The app never talks directly to PostgreSQL — it reads `manifest.json` from MinIO. Without this flag, debug builds silently use the production bucket (`betelapp-content`).
