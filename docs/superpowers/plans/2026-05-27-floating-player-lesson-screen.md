# Floating Audio Player on Lesson Screen — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show a floating audio player at the bottom of the lesson screen (PDF and text layouts) whenever the lesson has an associated song, visible immediately on entry in a paused state — no auto-play, no restart/previous/next buttons.

**Architecture:** Add a `showRestartButton` parameter to `AudioPlayerWidget` to hide the ⏮ button. Add a `load()` method to `AudioNotifier` that sets source/metadata without starting playback. Replace the existing `_buildAudioControl` placeholder in `LessonDetailScreen` with a new private `_LessonAudioPlayer` widget that calls `load()` on first render and passes `showRestartButton: false` to `AudioPlayerWidget`.

**Tech Stack:** Flutter, Riverpod (`StateNotifier`), audioplayers, flutter_test, mockito

---

## Files

| Action | Path |
|--------|------|
| Modify | `lib/presentation/providers/audio_provider.dart` |
| Modify | `lib/presentation/widgets/audio_player_widget.dart` |
| Modify | `lib/presentation/screens/lesson/lesson_detail_screen.dart` |
| Modify | `test/presentation/providers/audio_provider_test.dart` |
| Modify | `test/presentation/widgets/audio_player_widget_test.dart` |
| Create | `test/presentation/screens/lesson/lesson_detail_screen_test.dart` |

All paths are relative to `src/mobile/`.

---

## Task 1: Add `load()` to `AudioNotifier`

**Files:**
- Modify: `lib/presentation/providers/audio_provider.dart`
- Modify: `test/presentation/providers/audio_provider_test.dart`

### Step 1.1 — Write the failing test

Add this test inside the existing `group('AudioNotifier', ...)` block in `test/presentation/providers/audio_provider_test.dart`:

```dart
test('load() sets metadata and source without playing', () async {
  const url = 'assets/audio/lesson_4.mp3';
  const title = 'Quem é Deus?';
  const artist = 'Betel Kids';

  await notifier.load(url, title: title, artist: artist);

  expect(notifier.state.isPlaying, false);
  expect(notifier.state.currentUrl, url);
  expect(notifier.state.currentTitle, title);
  expect(notifier.state.currentArtist, artist);
  expect(notifier.state.position, Duration.zero);

  verify(mockAudioPlayer.setSource(any)).called(1);
  verifyNever(mockAudioPlayer.resume());
});
```

### Step 1.2 — Regenerate mocks and run test to confirm it fails

```bash
cd src/mobile
flutter pub run build_runner build --delete-conflicting-outputs
flutter test test/presentation/providers/audio_provider_test.dart -v
```

Expected: compilation error — `load` method does not exist.

### Step 1.3 — Implement `load()` in `AudioNotifier`

In `lib/presentation/providers/audio_provider.dart`, add this method after `play()`:

```dart
Future<void> load(String url, {required String title, required String artist}) async {
  if (url == state.currentUrl) return;

  await _player.stop();

  if (url.startsWith('assets/')) {
    final path = url.replaceFirst('assets/', '');
    await _player.setSource(AssetSource(path));
  } else {
    await _player.setSource(UrlSource(url));
  }

  state = state.copyWith(
    currentUrl: url,
    currentTitle: title,
    currentArtist: artist,
    isPlaying: false,
    position: Duration.zero,
  );
}
```

### Step 1.4 — Run test to confirm it passes

```bash
flutter test test/presentation/providers/audio_provider_test.dart -v
```

Expected: all tests PASS.

### Step 1.5 — Commit

```bash
git add lib/presentation/providers/audio_provider.dart \
        test/presentation/providers/audio_provider_test.dart
git commit -m "feat: add load() to AudioNotifier — sets source without playing"
```

---

## Task 2: Add `showRestartButton` to `AudioPlayerWidget`

**Files:**
- Modify: `lib/presentation/widgets/audio_player_widget.dart`
- Modify: `test/presentation/widgets/audio_player_widget_test.dart`

### Step 2.1 — Write the failing test

Add this test inside `main()` in `test/presentation/widgets/audio_player_widget_test.dart`:

```dart
testWidgets('AudioPlayerWidget hides restart button when showRestartButton is false',
    (WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: ThemeData(useMaterial3: false),
        home: const Scaffold(
          body: AudioPlayerWidget(showRestartButton: false),
        ),
      ),
    ),
  );

  expect(find.byIcon(Icons.skip_previous_rounded), findsNothing);
});

testWidgets('AudioPlayerWidget shows restart button by default',
    (WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: ThemeData(useMaterial3: false),
        home: const Scaffold(
          body: AudioPlayerWidget(),
        ),
      ),
    ),
  );

  expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
});
```

### Step 2.2 — Run tests to confirm they fail

```bash
cd src/mobile
flutter test test/presentation/widgets/audio_player_widget_test.dart -v
```

Expected: FAIL — `showRestartButton` named parameter does not exist.

### Step 2.3 — Add `showRestartButton` parameter to `AudioPlayerWidget`

In `lib/presentation/widgets/audio_player_widget.dart`:

**Change the class declaration (lines 6–15) to:**

```dart
class AudioPlayerWidget extends ConsumerStatefulWidget {
  final VoidCallback? onNext;
  final bool showRestartButton;

  const AudioPlayerWidget({
    super.key,
    this.onNext,
    this.showRestartButton = true,
  });
```

**Wrap the restart button block (the Container with `Icons.skip_previous_rounded`) with a conditional. Replace lines 92–107:**

```dart
if (widget.showRestartButton) ...[
  Container(
    decoration: const BoxDecoration(
      color: AppTheme.primaryColor,
      shape: BoxShape.circle,
    ),
    child: IconButton(
      onPressed: () {
        notifier.seek(Duration.zero);
      },
      icon: const Icon(
        Icons.skip_previous_rounded,
        size: 24,
        color: Colors.black,
      ),
    ),
  ),
  const SizedBox(width: 8),
],
```

### Step 2.4 — Run tests to confirm they pass

```bash
flutter test test/presentation/widgets/audio_player_widget_test.dart -v
```

Expected: all 4 tests PASS.

### Step 2.5 — Commit

```bash
git add lib/presentation/widgets/audio_player_widget.dart \
        test/presentation/widgets/audio_player_widget_test.dart
git commit -m "feat: add showRestartButton param to AudioPlayerWidget"
```

---

## Task 3: Add `_LessonAudioPlayer` and update `LessonDetailScreen`

**Files:**
- Modify: `lib/presentation/screens/lesson/lesson_detail_screen.dart`
- Create: `test/presentation/screens/lesson/lesson_detail_screen_test.dart`

### Step 3.1 — Create the test file

Create `test/presentation/screens/lesson/lesson_detail_screen_test.dart`:

```dart
import 'package:betelsas/data/models/lesson.dart';
import 'package:betelsas/data/models/song.dart';
import 'package:betelsas/presentation/screens/lesson/lesson_detail_screen.dart';
import 'package:betelsas/presentation/widgets/audio_player_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Lesson _lessonWithSong() => Lesson(
      id: 4,
      title: 'Quem é Deus?',
      content: 'Conteúdo',
      scriptureReference: 'João 3:16',
      imageUrl: null,
      pdfUrl: null,
      flashcards: [],
      song: Song(
        id: 'song_4',
        title: 'Quem é Deus?',
        artist: 'Betel Kids',
        audioUrl: 'assets/audio/lesson_4.mp3',
        durationIds: 120,
      ),
    );

Lesson _lessonWithoutSong() => Lesson(
      id: 1,
      title: 'Sem Música',
      content: 'Conteúdo',
      scriptureReference: 'João 1:1',
      imageUrl: null,
      pdfUrl: null,
      flashcards: [],
      song: null,
    );

Widget _wrap(Widget child) => ProviderScope(
      child: MaterialApp(
        theme: ThemeData(useMaterial3: false),
        home: child,
      ),
    );

void main() {
  group('LessonDetailScreen — floating player', () {
    testWidgets('shows AudioPlayerWidget when lesson has a song', (tester) async {
      await tester.pumpWidget(_wrap(LessonDetailScreen(lesson: _lessonWithSong())));
      await tester.pump();

      expect(find.byType(AudioPlayerWidget), findsOneWidget);
    });

    testWidgets('does not show AudioPlayerWidget when lesson has no song', (tester) async {
      await tester.pumpWidget(_wrap(LessonDetailScreen(lesson: _lessonWithoutSong())));
      await tester.pump();

      expect(find.byType(AudioPlayerWidget), findsNothing);
    });

    testWidgets('player does not show restart button in lesson context', (tester) async {
      await tester.pumpWidget(_wrap(LessonDetailScreen(lesson: _lessonWithSong())));
      await tester.pump();

      expect(find.byIcon(Icons.skip_previous_rounded), findsNothing);
    });
  });
}
```

### Step 3.2 — Run tests to confirm they fail

```bash
cd src/mobile
flutter test test/presentation/screens/lesson/lesson_detail_screen_test.dart -v
```

Expected: FAIL — tests fail because the current `LessonDetailScreen` shows the placeholder container (not `AudioPlayerWidget`) before the user taps play.

### Step 3.3 — Add `_LessonAudioPlayer` widget and update `_buildAudioControl`

In `lib/presentation/screens/lesson/lesson_detail_screen.dart`:

**Add this import at the top (after existing imports):**

```dart
import 'package:betelsas/data/models/song.dart';
```

**Replace the entire `_buildAudioControl` method (lines 232–313) with the new private widget.** Delete `_buildAudioControl` completely, then add `_LessonAudioPlayer` as a new class at the bottom of the file (before the last `}`):

```dart
class _LessonAudioPlayer extends ConsumerWidget {
  final Song song;

  const _LessonAudioPlayer({required this.song});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioState = ref.watch(audioProvider);
    final isLoaded = audioState.currentUrl == song.audioUrl;

    if (!isLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(audioProvider.notifier).load(
          song.audioUrl,
          title: song.title,
          artist: song.artist,
        );
      });
    }

    return const AudioPlayerWidget(showRestartButton: false);
  }
}
```

**In `_buildPdfLayout`, replace the `if (widget.lesson.song != null) Align(...)` block (lines 114–118) with:**

```dart
if (widget.lesson.song != null)
  Align(
    alignment: Alignment.bottomCenter,
    child: _LessonAudioPlayer(song: widget.lesson.song!),
  ),
```

**In `_buildTextLayout`, replace the equivalent `if (widget.lesson.song != null) Align(...)` block (lines 222–226) with:**

```dart
if (widget.lesson.song != null)
  Align(
    alignment: Alignment.bottomCenter,
    child: _LessonAudioPlayer(song: widget.lesson.song!),
  ),
```

**Remove the unused import for `audio_player_widget.dart` if it's now only used via `_LessonAudioPlayer` — keep it since `AudioPlayerWidget` is still referenced indirectly.**

### Step 3.4 — Run all tests

```bash
cd src/mobile
flutter test -v
```

Expected: all tests PASS. Zero regressions.

### Step 3.5 — Commit

```bash
git add lib/presentation/screens/lesson/lesson_detail_screen.dart \
        test/presentation/screens/lesson/lesson_detail_screen_test.dart
git commit -m "feat: show floating audio player on lesson screen from entry"
```

---

## Task 4: Manual Smoke Test

Run the app on the connected device and verify the golden path:

```bash
cd src/mobile
flutter run --debug -d 192.168.0.15:34759
```

**Checklist:**
- [ ] Open a lesson that has a song (e.g. Lição 4) — player visible immediately at bottom, paused state
- [ ] Open a lesson without a song — no player visible
- [ ] Tap play on the lesson screen — music starts, button changes to pause
- [ ] Drag seek bar — position updates correctly
- [ ] Navigate to Music tab — ⏮ button still visible there (not broken)
- [ ] Navigate back to lesson — player reflects current audio state
