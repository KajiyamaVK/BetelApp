# Player Navigation Buttons Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Adicionar botões ⏮ (anterior/reinicia) e ⏭ (próxima) ao `AudioPlayerWidget`, com `playPrevious()` no `AudioNotifier`, substituindo o atual `showRestartButton`.

**Architecture:** `playPrevious()` é adicionado ao `AudioNotifier` com lógica baseada em `position`. O `AudioPlayerWidget` troca `showRestartButton` por `onPrevious: VoidCallback?`, reordena os botões (⏮ · ▶ · ⏭) e os redimensiona. `MusicScreen` passa ambos os callbacks. `LessonDetailScreen` remove o `showRestartButton: false` obsoleto.

**Tech Stack:** Flutter, Riverpod (`StateNotifier`), `audioplayers`, `mockito`.

---

## File Map

| Arquivo | Ação | O que muda |
|---|---|---|
| `lib/presentation/providers/audio_provider.dart` | Modify | Adiciona `playPrevious()` |
| `lib/presentation/widgets/audio_player_widget.dart` | Modify | Remove `showRestartButton`, adiciona `onPrevious`, reordena botões |
| `lib/presentation/screens/music/music_screen.dart` | Modify | Passa `onPrevious` e `onNext` ao widget |
| `lib/presentation/screens/lesson/lesson_detail_screen.dart` | Modify | Remove `showRestartButton: false` |
| `test/presentation/providers/audio_provider_test.dart` | Modify | Adiciona grupo `playPrevious` |
| `test/presentation/widgets/audio_player_widget_test.dart` | Modify | Atualiza testes para nova API |

---

### Task 1: Write failing tests for `playPrevious` and implement it

**Files:**
- Modify: `src/mobile/test/presentation/providers/audio_provider_test.dart`
- Modify: `src/mobile/lib/presentation/providers/audio_provider.dart`

- [ ] **Step 1: Adicionar grupo de testes `playPrevious` (RED)**

No arquivo `test/presentation/providers/audio_provider_test.dart`, após o grupo `auto-play on complete`, adicione:

```dart
group('playPrevious', () {
  test('seeks to zero when position >= 2s', () async {
    final songs = [
      Song(id: '1', title: 'Song A', artist: 'Artist', audioUrl: 'url_a', durationIds: 180),
      Song(id: '2', title: 'Song B', artist: 'Artist', audioUrl: 'url_b', durationIds: 200),
    ];
    await notifier.setQueue(songs, startIndex: 1);
    positionController.add(const Duration(seconds: 3));
    await Future.delayed(Duration.zero);
    clearInteractions(mockAudioPlayer);

    await notifier.playPrevious();

    verify(mockAudioPlayer.seek(Duration.zero)).called(1);
    expect(notifier.state.currentIndex, 1); // index unchanged
  });

  test('goes to previous song when position < 2s and not first song', () async {
    final songs = [
      Song(id: '1', title: 'Song A', artist: 'Artist', audioUrl: 'url_a', durationIds: 180),
      Song(id: '2', title: 'Song B', artist: 'Artist', audioUrl: 'url_b', durationIds: 200),
    ];
    await notifier.setQueue(songs, startIndex: 1);
    positionController.add(const Duration(seconds: 1));
    await Future.delayed(Duration.zero);
    clearInteractions(mockAudioPlayer);

    await notifier.playPrevious();

    expect(notifier.state.currentIndex, 0);
    expect(notifier.state.currentUrl, 'url_a');
    verify(mockAudioPlayer.setSource(any)).called(1);
  });

  test('seeks to zero when position < 2s and is first song', () async {
    final songs = [
      Song(id: '1', title: 'Song A', artist: 'Artist', audioUrl: 'url_a', durationIds: 180),
      Song(id: '2', title: 'Song B', artist: 'Artist', audioUrl: 'url_b', durationIds: 200),
    ];
    await notifier.setQueue(songs, startIndex: 0);
    positionController.add(const Duration(seconds: 1));
    await Future.delayed(Duration.zero);
    clearInteractions(mockAudioPlayer);

    await notifier.playPrevious();

    verify(mockAudioPlayer.seek(Duration.zero)).called(1);
    expect(notifier.state.currentIndex, 0);
  });

  test('seeks to zero when position < 2s and queue is empty', () async {
    positionController.add(const Duration(seconds: 1));
    await Future.delayed(Duration.zero);
    clearInteractions(mockAudioPlayer);

    await notifier.playPrevious();

    verify(mockAudioPlayer.seek(Duration.zero)).called(1);
  });
});
```

- [ ] **Step 2: Rodar testes para verificar que FALHAM (RED)**

```bash
cd /home/vkajiyama/src/BetelApp/src/mobile && flutter test test/presentation/providers/audio_provider_test.dart --no-pub 2>&1 | tail -5
```

Esperado: falhas nos 4 novos testes de `playPrevious` — método não existe ainda.

- [ ] **Step 3: Implementar `playPrevious()` no `AudioNotifier`**

Em `lib/presentation/providers/audio_provider.dart`, após o método `playNext`, adicione:

```dart
Future<void> playPrevious() async {
  final queue = state.queue;
  final index = state.currentIndex;

  if (state.position.inSeconds >= 2) {
    await seek(Duration.zero);
    return;
  }

  if (queue.isEmpty || index == null || index <= 0) {
    await seek(Duration.zero);
    return;
  }

  final prevIndex = index - 1;
  final song = queue[prevIndex];
  state = state.copyWith(currentIndex: prevIndex);
  await play(song.audioUrl, title: song.title, artist: song.artist);
}
```

- [ ] **Step 4: Rodar testes para verificar que PASSAM (GREEN)**

```bash
cd /home/vkajiyama/src/BetelApp/src/mobile && flutter test test/presentation/providers/audio_provider_test.dart --no-pub 2>&1 | tail -3
```

Esperado: `+17: All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add src/mobile/lib/presentation/providers/audio_provider.dart src/mobile/test/presentation/providers/audio_provider_test.dart
git commit -m "feat: add playPrevious to AudioNotifier"
```

---

### Task 2: Refactor `AudioPlayerWidget` — nova API e layout

**Files:**
- Modify: `src/mobile/lib/presentation/widgets/audio_player_widget.dart`
- Modify: `src/mobile/test/presentation/widgets/audio_player_widget_test.dart`

- [ ] **Step 1: Atualizar testes do widget para nova API (RED)**

Substitua o conteúdo inteiro de `test/presentation/widgets/audio_player_widget_test.dart` por:

```dart
import 'package:betelsas/presentation/providers/audio_provider.dart';
import 'package:betelsas/presentation/widgets/audio_player_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AudioPlayerWidget does NOT show Previous button by default',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(useMaterial3: false),
          home: const Scaffold(body: AudioPlayerWidget()),
        ),
      ),
    );

    expect(find.byIcon(Icons.skip_previous_rounded), findsNothing);
  });

  testWidgets('AudioPlayerWidget shows Previous button when onPrevious is provided',
      (WidgetTester tester) async {
    bool previousCalled = false;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(useMaterial3: false),
          home: Scaffold(
            body: AudioPlayerWidget(
              onPrevious: () {
                previousCalled = true;
              },
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.skip_previous_rounded));
    expect(previousCalled, isTrue);
  });

  testWidgets('AudioPlayerWidget does NOT show Next button by default',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(useMaterial3: false),
          home: const Scaffold(body: AudioPlayerWidget()),
        ),
      ),
    );

    expect(find.byIcon(Icons.skip_next_rounded), findsNothing);
  });

  testWidgets('AudioPlayerWidget shows Next button when onNext is provided',
      (WidgetTester tester) async {
    bool nextCalled = false;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(useMaterial3: false),
          home: Scaffold(
            body: AudioPlayerWidget(
              onNext: () {
                nextCalled = true;
              },
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.skip_next_rounded));
    expect(nextCalled, isTrue);
  });
}
```

- [ ] **Step 2: Rodar testes para verificar que FALHAM (RED)**

```bash
cd /home/vkajiyama/src/BetelApp/src/mobile && flutter test test/presentation/widgets/audio_player_widget_test.dart --no-pub 2>&1 | tail -5
```

Esperado: falha no teste de Previous — `showRestartButton` ainda existe, `onPrevious` não.

- [ ] **Step 3: Implementar a nova API e layout no `AudioPlayerWidget`**

Substitua o conteúdo inteiro de `lib/presentation/widgets/audio_player_widget.dart` por:

```dart
import 'package:betelsas/core/theme/app_theme.dart';
import 'package:betelsas/presentation/providers/audio_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AudioPlayerWidget extends ConsumerStatefulWidget {
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const AudioPlayerWidget({
    super.key,
    this.onPrevious,
    this.onNext,
  });

  @override
  ConsumerState<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends ConsumerState<AudioPlayerWidget> {
  bool _isDragging = false;
  double? _dragValue;

  String _formatTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final audioState = ref.watch(audioProvider);
    final notifier = ref.read(audioProvider.notifier);

    final currentPosition = _isDragging
        ? Duration(seconds: _dragValue?.toInt() ?? 0)
        : audioState.position;

    final maxDuration = audioState.duration.inSeconds.toDouble();
    final value = currentPosition.inSeconds
        .toDouble()
        .clamp(0.0, maxDuration > 0 ? maxDuration : 0.0);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.music_note_rounded,
                      color: AppTheme.primaryColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        audioState.currentTitle ?? 'Desconhecido',
                        style: AppTheme.heading2.copyWith(fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        audioState.currentArtist ?? 'Desconhecido',
                        style: AppTheme.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Botões: ⏮ (34px) · ▶/⏸ (42px) · ⏭ (34px)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.onPrevious != null) ...[
                      _CircleButton(
                        size: 34,
                        onPressed: widget.onPrevious!,
                        icon: Icons.skip_previous_rounded,
                        iconSize: 20,
                      ),
                      const SizedBox(width: 6),
                    ],
                    _CircleButton(
                      size: 42,
                      onPressed: () {
                        if (audioState.isPlaying) {
                          notifier.pause();
                        } else {
                          notifier.resume();
                        }
                      },
                      icon: audioState.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      iconSize: 26,
                    ),
                    if (widget.onNext != null) ...[
                      const SizedBox(width: 6),
                      _CircleButton(
                        size: 34,
                        onPressed: widget.onNext!,
                        icon: Icons.skip_next_rounded,
                        iconSize: 20,
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(_formatTime(currentPosition), style: AppTheme.caption),
                Expanded(
                  child: Slider(
                    min: 0,
                    max: maxDuration > 0 ? maxDuration : 1.0,
                    value: value,
                    activeColor: AppTheme.primaryColor,
                    inactiveColor: Colors.grey.withValues(alpha: 0.3),
                    onChangeStart: (_) => setState(() => _isDragging = true),
                    onChangeEnd: (val) {
                      setState(() {
                        _isDragging = false;
                        _dragValue = null;
                      });
                      notifier.seek(Duration(seconds: val.toInt()));
                    },
                    onChanged: (val) {
                      setState(() => _dragValue = val);
                    },
                  ),
                ),
                Text(_formatTime(audioState.duration), style: AppTheme.caption),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final double size;
  final VoidCallback onPressed;
  final IconData icon;
  final double iconSize;

  const _CircleButton({
    required this.size,
    required this.onPressed,
    required this.icon,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppTheme.primaryColor,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        icon: Icon(icon, size: iconSize, color: Colors.black),
      ),
    );
  }
}
```

- [ ] **Step 4: Rodar testes do widget para verificar que PASSAM (GREEN)**

```bash
cd /home/vkajiyama/src/BetelApp/src/mobile && flutter test test/presentation/widgets/audio_player_widget_test.dart --no-pub 2>&1 | tail -3
```

Esperado: `+4: All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add src/mobile/lib/presentation/widgets/audio_player_widget.dart src/mobile/test/presentation/widgets/audio_player_widget_test.dart
git commit -m "feat: refactor AudioPlayerWidget with previous/next navigation buttons"
```

---

### Task 3: Wire callbacks em `MusicScreen` e fix em `LessonDetailScreen`

**Files:**
- Modify: `src/mobile/lib/presentation/screens/music/music_screen.dart`
- Modify: `src/mobile/lib/presentation/screens/lesson/lesson_detail_screen.dart`

- [ ] **Step 1: Atualizar `MusicScreen` para passar `onPrevious` e `onNext`**

Em `lib/presentation/screens/music/music_screen.dart`, encontre o trecho:

```dart
if (audioState.currentUrl != null)
   const Align(
     alignment: Alignment.bottomCenter,
     child: AudioPlayerWidget(),
   ),
```

Substitua por:

```dart
if (audioState.currentUrl != null)
  Align(
    alignment: Alignment.bottomCenter,
    child: AudioPlayerWidget(
      onPrevious: () async => await audioNotifier.playPrevious(),
      onNext: () async => await audioNotifier.playNext(),
    ),
  ),
```

- [ ] **Step 2: Atualizar `LessonDetailScreen` para remover `showRestartButton: false`**

Em `lib/presentation/screens/lesson/lesson_detail_screen.dart`, no método `build` de `_LessonAudioPlayerState`, encontre:

```dart
return const AudioPlayerWidget(showRestartButton: false);
```

Substitua por:

```dart
return const AudioPlayerWidget();
```

- [ ] **Step 3: Rodar a suite completa**

```bash
cd /home/vkajiyama/src/BetelApp/src/mobile && flutter test --no-pub 2>&1 | tail -3
```

Esperado: todos os testes passando sem regressões.

- [ ] **Step 4: Commit**

```bash
git add src/mobile/lib/presentation/screens/music/music_screen.dart src/mobile/lib/presentation/screens/lesson/lesson_detail_screen.dart
git commit -m "feat: wire previous/next callbacks in MusicScreen and LessonDetailScreen"
```

---

## Verificação Final

```bash
cd /home/vkajiyama/src/BetelApp/src/mobile && flutter test --no-pub 2>&1 | tail -3
```
