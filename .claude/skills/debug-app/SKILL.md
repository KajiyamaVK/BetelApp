---
name: debug-app
description: Use when the user wants to run the BetelApp mobile app in debug mode on a connected Android device. Triggers on phrases like "run the app", "debug mode", "start the app on the phone", "launch on device", or any request to install and run BetelApp on an Android device for development/testing.
---

# Debug App

Runs the BetelApp Flutter mobile app in debug mode on a connected Android device.

## Steps

### 1. Check device connection

```bash
adb devices
```

If no device is listed (output is just `List of devices attached` with no entries below), **stop and tell the user**: "No Android device is connected. Please connect your phone via USB and ensure USB debugging is enabled, then try again."

### 2. Uninstall existing app (if installed)

```bash
adb shell pm list packages | grep -i betel
```

If `com.kajiyama.betelapp` is found:

```bash
adb uninstall com.kajiyama.betelapp
```

### 3. Build and run in debug mode

Navigate to the mobile source directory and run:

```bash
cd /home/vkajiyama/src/BetelApp/src/mobile
flutter run -d <device-id> > /tmp/flutter_run.log 2>&1 &
```

Use the device ID from `adb devices` output (the alphanumeric string before `device`).

Then wait for the build to complete by polling the log:

```bash
sleep 30 && tail -20 /tmp/flutter_run.log
```

If needed, wait another 60 seconds for Gradle:

```bash
sleep 60 && tail -20 /tmp/flutter_run.log
```

### 4. Confirm success

The app is running successfully when the log contains a line like:

```
A Dart VM Service on <device> is available at: http://127.0.0.1:<port>/...
```

Report the DevTools URL to the user so they can attach a debugger or profiler if needed.

## Notes

- This runs a **debug** build (no AOT). This is intentional for development. For manual QA testing, use `/deploy-app` or build a release APK manually.
- The `flutter run` process stays alive in the background. The user can stop the app by killing the process or by attaching interactively and pressing `q`.
- Hot reload (`r`) and hot restart (`R`) are available if the user attaches to the process.
