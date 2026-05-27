# Floating Audio Player on Lesson Screen

**Date:** 2026-05-27  
**Status:** Approved

## Summary

When a user opens a lesson that has an associated song, a floating audio player appears at the bottom of the screen — both in the PDF layout and the text layout. The player is visible immediately upon entering the screen, in a paused state. No auto-play occurs. The player has no previous/next or restart buttons; only play/pause and a seek bar.

## Behavior

- On entering a lesson screen, if `lesson.song != null`, the floating player renders immediately at the bottom of the screen.
- The player starts **paused** — title and artist are shown, progress bar is at 0:00, play button is visible.
- The user initiates playback by tapping the play button.
- While playing, the player shows the pause button and the seek bar advances normally.
- The user can seek by dragging the progress bar.
- No restart (⏮), previous, or next buttons are shown in this context.
- This behavior applies to both `_buildPdfLayout` and `_buildTextLayout`.

## Out of Scope

- Auto-play on screen entry.
- Previous/next song navigation.
- Restart button (⏮).
- Any change to the Music tab screen behavior.

## Architecture

### `audio_player_widget.dart`

Add a named parameter:

```dart
const AudioPlayerWidget({
  super.key,
  this.onNext,
  this.showRestartButton = true, // new
});
```

The ⏮ button block (currently lines 92–107) is wrapped in `if (widget.showRestartButton)`. No other logic changes.

### `lesson_detail_screen.dart`

**`_buildAudioControl` is removed entirely.**

Both `_buildPdfLayout` and `_buildTextLayout` replace their existing `Align(bottomCenter, child: _buildAudioControl(ref))` with:

```dart
if (widget.lesson.song != null)
  Align(
    alignment: Alignment.bottomCenter,
    child: _LessonAudioPlayer(song: widget.lesson.song!),
  ),
```

A new private widget `_LessonAudioPlayer` is introduced in the same file:

```dart
class _LessonAudioPlayer extends ConsumerWidget {
  final Song song;
  const _LessonAudioPlayer({required this.song});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioState = ref.watch(audioProvider);
    final isLoaded = audioState.currentUrl == song.audioUrl;

    if (!isLoaded) {
      // Load into provider without playing, so widget shows title/artist
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(audioProvider.notifier).load(song.audioUrl,
          title: song.title,
          artist: song.artist,
        );
      });
    }

    return AudioPlayerWidget(showRestartButton: false);
  }
}
```

### `audio_provider.dart`

A `load` method is added to `AudioNotifier` — loads the audio URL and metadata into state **without starting playback**. This is the only provider-level change required.

## Data Flow

```
LessonDetailScreen opens
  → lesson.song != null?
      yes → _LessonAudioPlayer renders
               → audioProvider.load(url, title, artist)  [no playback]
               → AudioPlayerWidget(showRestartButton: false) renders paused
      no  → no player shown

User taps ▶
  → audioProvider.play(url, title, artist)
  → AudioPlayerWidget shows ⏸, seek bar advances
```

## Testing

- Lesson with song: player visible immediately on screen open, paused state.
- Lesson without song: no player visible.
- Play button starts audio; pause button pauses it.
- Seek bar allows repositioning.
- Navigating away from lesson: audio continues playing in background (global provider persists). Returning to the lesson: player reflects current audio state (playing or paused — not reset).
- Music tab: behavior unchanged — ⏮ button still present.
