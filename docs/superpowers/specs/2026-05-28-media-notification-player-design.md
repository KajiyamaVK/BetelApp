# Media Notification Player — Design Spec

**Date:** 2026-05-28  
**Status:** Approved  
**Scope:** Android (Phase 1), iOS (Phase 2)

---

## 1. Goal

Play audio in the background and surface a native Android media notification with title, artist, and playback controls (Previous, Play/Pause, Next). When the user dismisses the notification, playback stops and the service shuts down.

---

## 2. Package Migration

| Before | After |
|--------|-------|
| `audioplayers: ^6.0.0` | `just_audio: ^0.9.x` |
| _(none)_ | `audio_service: ^0.18.x` |

`audioplayers` is removed entirely. `just_audio` is the audio engine. `audio_service` wraps it in an Android Foreground Service that owns the media session and notification.

---

## 3. Architecture

```
┌─────────────────────────────────────────────┐
│  UI Layer (unchanged)                       │
│  AudioPlayerWidget  ←→  AudioNotifier       │
│  MusicScreen        ←→  (Riverpod)          │
└────────────────┬────────────────────────────┘
                 │ delegates commands
┌────────────────▼────────────────────────────┐
│  BetelAudioHandler  (extends BaseAudioHandler│
│  + QueueHandler + SeekHandler)              │
│  Runs in background isolate via             │
│  audio_service. Owns MediaSession.          │
│  Commands: play, pause, seek,               │
│  skipToNext, skipToPrevious, stop           │
└────────────────┬────────────────────────────┘
                 │ drives playback
┌────────────────▼────────────────────────────┐
│  just_audio (AudioPlayer)                   │
└─────────────────────────────────────────────┘
```

`AudioState` (the Riverpod state shape) is **unchanged**. The UI consumes the same fields it does today.

---

## 4. New Files

### `lib/core/audio/betel_audio_handler.dart`

Implements `AudioHandler` from `audio_service`. Responsibilities:

- Holds and controls the `just_audio` `AudioPlayer`.
- Translates `AudioService` commands (`play`, `pause`, `seek`, `skipToNext`, `skipToPrevious`, `stop`) into `just_audio` calls.
- Builds `MediaItem` (title, artist) and pushes it to `mediaItem` stream so Android renders the notification.
- Exposes streams: `playbackState`, `mediaItem` — consumed by `AudioNotifier`.
- Implements `onTaskRemoved()`: calls `stop()` and clears state when user dismisses the notification.
- Accepts queue injection via a `setQueue(List<Song>, {int startIndex})` method (not part of the standard `AudioHandler` interface — called directly by `AudioNotifier`).

### `lib/core/audio/audio_service_initializer.dart`

Single function `initAudioService()` called in `main()` before `runApp()`. Registers `BetelAudioHandler` with `AudioService.init(...)`. Returns the handler instance, which is then injected into `AudioNotifier` via Riverpod.

---

## 5. Modified Files

### `lib/presentation/providers/audio_provider.dart`

`AudioNotifier` is refactored to delegate to `BetelAudioHandler` instead of owning an `AudioPlayer` directly:

- Constructor receives `BetelAudioHandler` (injectable for testing).
- `play()`, `pause()`, `resume()`, `seek()`, `stop()` → forward to handler methods.
- `setQueue()`, `playNext()`, `playPrevious()` → logic stays in `AudioNotifier`, but the actual `play()` call goes through the handler.
- Listens to `handler.playbackState` and `handler.mediaItem` streams to update `AudioState`.

`AudioState` struct is **unchanged**.

### `pubspec.yaml`

- Remove: `audioplayers`
- Add: `just_audio`, `audio_service`

### `android/app/src/main/AndroidManifest.xml`

- Add `FOREGROUND_SERVICE` and `FOREGROUND_SERVICE_MEDIA_PLAYBACK` permissions.
- Register the `AudioService` service entry.

---

## 6. Notification Behavior

- **Controls shown:** Previous, Play/Pause, Next (full set).
- **Dismissal:** Dismissing the notification calls `onTaskRemoved()` → stops playback → clears `AudioState`. App may remain open in foreground but with no audio.
- **Persistence:** Notification is not pinned — standard Android media notification, dismissible by swipe.
- **Visual:** Title and artist from `AudioState.currentTitle` / `currentArtist`. No album art in Phase 1.

---

## 7. UI Layer — No Changes

`AudioPlayerWidget` and `MusicScreen` are **not modified**. The widget's visual design, button styles (`_CircleButton`), slider behavior, and `onPrevious`/`onNext` callback pattern are preserved exactly as-is.

The `ValueKey('music-screen-player')` on the widget stays — it's load-bearing for the slider drag regression test.

---

## 8. Testing Strategy

### `BetelAudioHandler` (new tests)

Unit tests in `test/core/audio/betel_audio_handler_test.dart`:

- Mock the `just_audio` `AudioPlayer` (inject via constructor).
- Verify `play()` calls `setAudioSource()` + `play()` on the underlying player.
- Verify `skipToNext()` / `skipToPrevious()` advance/decrement the queue and call `play()`.
- Verify `onTaskRemoved()` calls `stop()`.
- Verify `mediaItem` stream emits the correct title/artist when a new song starts.

### `AudioNotifier` (rewritten provider tests)

File: `test/presentation/providers/audio_provider_test.dart`

- Replace `MockAudioPlayer` (audioplayers) with `MockBetelAudioHandler`.
- All existing test scenarios are preserved: queue management, play/pause, seek, playNext, playPrevious, auto-advance on complete.
- Mock the handler's `playbackState` and `mediaItem` streams (same pattern as current `onPlayerStateChanged` / `onDurationChanged`).

### `AudioPlayerWidget` (no changes)

`test/presentation/widgets/audio_player_widget_test.dart` is **not touched**. All existing tests pass as-is.

---

## 9. Phase 2 — iOS

No architectural changes required. Steps:

1. Add `audio` to `UIBackgroundModes` in `ios/Runner/Info.plist`.
2. Configure `AVAudioSession.setCategory(.playback)` in the handler's `onNotificationActionTriggered` or app delegate.
3. Test on a physical iOS device (simulator does not support background audio).

`BetelAudioHandler` is the same class — `audio_service` handles the platform differences internally.

---

## 10. Out of Scope

- Album art in the notification.
- Lock screen seek bar (requires `MediaMetadata` extras — can be added later).
- Shuffle / repeat modes.
- Car mode / Android Auto integration.
