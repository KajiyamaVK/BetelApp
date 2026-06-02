# Music Auto-play Queue Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ao terminar uma música na aba de Músicas, o player avança automaticamente para a próxima da lista; ao chegar na última, para sem fazer nada.

**Architecture:** A lógica de fila fica centralizada no `AudioNotifier`. O notifier ganha `queue` e `currentIndex` no estado, os métodos `setQueue()` e `playNext()`, e um listener em `onPlayerComplete` que chama `playNext()` automaticamente. A `MusicScreen` passa a chamar `setQueue()` em vez de `play()` diretamente.

**Tech Stack:** Flutter, Riverpod (`StateNotifier`), `audioplayers`, `mockito` para testes.

---

## File Map

| Arquivo | Ação | O que muda |
|---|---|---|
| `lib/presentation/providers/audio_provider.dart` | Modify | `AudioState` + `AudioNotifier` |
| `lib/presentation/screens/music/music_screen.dart` | Modify | `onPressed` usa `setQueue` |
| `test/presentation/providers/audio_provider_test.dart` | Modify | Novos grupos de teste |

---

### Task 1: Expand `AudioState` with queue fields

**Files:**
- Modify: `src/mobile/lib/presentation/providers/audio_provider.dart`

- [ ] **Step 1: Adicionar import do modelo `Song` e os novos campos ao `AudioState`**

Substitua o bloco `AudioState` inteiro:

```dart
import 'package:audioplayers/audioplayers.dart';
import 'package:betelsas/data/models/song.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AudioState {
  final bool isPlaying;
  final String? currentUrl;
  final String? currentTitle;
  final String? currentArtist;
  final Duration duration;
  final Duration position;
  final List<Song> queue;
  final int? currentIndex;

  const AudioState({
    this.isPlaying = false,
    this.currentUrl,
    this.currentTitle,
    this.currentArtist,
    this.duration = Duration.zero,
    this.position = Duration.zero,
    this.queue = const [],
    this.currentIndex,
  });

  AudioState copyWith({
    bool? isPlaying,
    String? currentUrl,
    String? currentTitle,
    String? currentArtist,
    Duration? duration,
    Duration? position,
    List<Song>? queue,
    int? currentIndex,
  }) {
    return AudioState(
      isPlaying: isPlaying ?? this.isPlaying,
      currentUrl: currentUrl ?? this.currentUrl,
      currentTitle: currentTitle ?? this.currentTitle,
      currentArtist: currentArtist ?? this.currentArtist,
      duration: duration ?? this.duration,
      position: position ?? this.position,
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
    );
  }
}
```

- [ ] **Step 2: Executar os testes para garantir que nada quebrou**

```bash
cd /home/vkajiyama/src/BetelApp/src/mobile && flutter test test/presentation/providers/audio_provider_test.dart --no-pub
```

Esperado: todos os testes existentes passando.

---

### Task 2: Write failing tests for `setQueue` and `playNext`

**Files:**
- Modify: `src/mobile/test/presentation/providers/audio_provider_test.dart`

- [ ] **Step 1: Adicionar `StreamController<void>` para `onPlayerComplete` no `setUp`**

No bloco `setUp`, após as declarações existentes de controllers, adicione:

```dart
late StreamController<void> playerCompleteController;
```

No body do `setUp`, após os outros controllers:

```dart
playerCompleteController = StreamController<void>.broadcast();
when(mockAudioPlayer.onPlayerComplete).thenAnswer((_) => playerCompleteController.stream);
```

No `tearDown`, adicione:

```dart
playerCompleteController.close();
```

- [ ] **Step 2: Adicionar grupo de testes `setQueue`**

Dentro do `main()`, após o grupo `'AudioNotifier'` existente, adicione:

```dart
group('setQueue', () {
  test('stores queue in state and sets currentIndex to startIndex', () async {
    final songs = [
      Song(id: '1', title: 'Song A', artist: 'Artist', audioUrl: 'url_a', durationIds: 180),
      Song(id: '2', title: 'Song B', artist: 'Artist', audioUrl: 'url_b', durationIds: 200),
      Song(id: '3', title: 'Song C', artist: 'Artist', audioUrl: 'url_c', durationIds: 150),
    ];

    await notifier.setQueue(songs, startIndex: 1);

    expect(notifier.state.queue, songs);
    expect(notifier.state.currentIndex, 1);
  });

  test('plays the song at startIndex', () async {
    final songs = [
      Song(id: '1', title: 'Song A', artist: 'Artist', audioUrl: 'url_a', durationIds: 180),
      Song(id: '2', title: 'Song B', artist: 'Artist', audioUrl: 'url_b', durationIds: 200),
    ];

    await notifier.setQueue(songs, startIndex: 0);

    expect(notifier.state.currentUrl, 'url_a');
    expect(notifier.state.currentTitle, 'Song A');
  });

  test('defaults to startIndex 0 when not provided', () async {
    final songs = [
      Song(id: '1', title: 'Song A', artist: 'Artist', audioUrl: 'url_a', durationIds: 180),
      Song(id: '2', title: 'Song B', artist: 'Artist', audioUrl: 'url_b', durationIds: 200),
    ];

    await notifier.setQueue(songs);

    expect(notifier.state.currentIndex, 0);
    expect(notifier.state.currentUrl, 'url_a');
  });
});
```

- [ ] **Step 3: Adicionar grupo de testes `playNext`**

```dart
group('playNext', () {
  test('advances to the next song in the queue', () async {
    final songs = [
      Song(id: '1', title: 'Song A', artist: 'Artist', audioUrl: 'url_a', durationIds: 180),
      Song(id: '2', title: 'Song B', artist: 'Artist', audioUrl: 'url_b', durationIds: 200),
    ];
    await notifier.setQueue(songs, startIndex: 0);
    clearInteractions(mockAudioPlayer);

    await notifier.playNext();

    expect(notifier.state.currentIndex, 1);
    expect(notifier.state.currentUrl, 'url_b');
    verify(mockAudioPlayer.setSource(any)).called(1);
  });

  test('does nothing when already on the last song', () async {
    final songs = [
      Song(id: '1', title: 'Song A', artist: 'Artist', audioUrl: 'url_a', durationIds: 180),
      Song(id: '2', title: 'Song B', artist: 'Artist', audioUrl: 'url_b', durationIds: 200),
    ];
    await notifier.setQueue(songs, startIndex: 1);
    clearInteractions(mockAudioPlayer);

    await notifier.playNext();

    expect(notifier.state.currentIndex, 1);
    verifyNever(mockAudioPlayer.setSource(any));
    verifyNever(mockAudioPlayer.resume());
  });

  test('does nothing when queue is empty', () async {
    await notifier.playNext();

    verifyNever(mockAudioPlayer.setSource(any));
  });
});
```

- [ ] **Step 4: Adicionar grupo de testes `auto-play on complete`**

```dart
group('auto-play on complete', () {
  test('calls playNext when onPlayerComplete fires', () async {
    final songs = [
      Song(id: '1', title: 'Song A', artist: 'Artist', audioUrl: 'url_a', durationIds: 180),
      Song(id: '2', title: 'Song B', artist: 'Artist', audioUrl: 'url_b', durationIds: 200),
    ];
    await notifier.setQueue(songs, startIndex: 0);
    clearInteractions(mockAudioPlayer);

    playerCompleteController.add(null);
    await Future.delayed(Duration.zero); // allow microtask to process

    expect(notifier.state.currentIndex, 1);
    expect(notifier.state.currentUrl, 'url_b');
  });

  test('stops on last song when onPlayerComplete fires', () async {
    final songs = [
      Song(id: '1', title: 'Song A', artist: 'Artist', audioUrl: 'url_a', durationIds: 180),
      Song(id: '2', title: 'Song B', artist: 'Artist', audioUrl: 'url_b', durationIds: 200),
    ];
    await notifier.setQueue(songs, startIndex: 1);
    clearInteractions(mockAudioPlayer);

    playerCompleteController.add(null);
    await Future.delayed(Duration.zero);

    expect(notifier.state.currentIndex, 1); // unchanged
    verifyNever(mockAudioPlayer.setSource(any));
  });
});
```

- [ ] **Step 5: Rodar testes para verificar que FALHAM (red)**

```bash
cd /home/vkajiyama/src/BetelApp/src/mobile && flutter test test/presentation/providers/audio_provider_test.dart --no-pub
```

Esperado: falhas nos grupos `setQueue`, `playNext`, e `auto-play on complete` — métodos ainda não existem.

---

### Task 3: Implement `setQueue`, `playNext`, and `onPlayerComplete` listener

**Files:**
- Modify: `src/mobile/lib/presentation/providers/audio_provider.dart`

- [ ] **Step 1: Adicionar listener `onPlayerComplete` em `_initListeners()`**

Dentro do método `_initListeners()`, após os listeners existentes, adicione:

```dart
_player.onPlayerComplete.listen((_) {
  playNext();
});
```

- [ ] **Step 2: Adicionar método `setQueue` ao `AudioNotifier`**

Após o método `seek`, adicione:

```dart
Future<void> setQueue(List<Song> songs, {int startIndex = 0}) async {
  state = state.copyWith(
    queue: songs,
    currentIndex: startIndex,
  );
  final song = songs[startIndex];
  await play(song.audioUrl, title: song.title, artist: song.artist);
}
```

- [ ] **Step 3: Adicionar método `playNext` ao `AudioNotifier`**

Após `setQueue`, adicione:

```dart
Future<void> playNext() async {
  final queue = state.queue;
  final index = state.currentIndex;
  if (queue.isEmpty || index == null) return;
  if (index >= queue.length - 1) return;

  final nextIndex = index + 1;
  final song = queue[nextIndex];
  state = state.copyWith(currentIndex: nextIndex);
  await play(song.audioUrl, title: song.title, artist: song.artist);
}
```

- [ ] **Step 4: Rodar testes para verificar que PASSAM (green)**

```bash
cd /home/vkajiyama/src/BetelApp/src/mobile && flutter test test/presentation/providers/audio_provider_test.dart --no-pub
```

Esperado: todos os testes passando, incluindo os novos grupos.

- [ ] **Step 5: Commit**

```bash
git add src/mobile/lib/presentation/providers/audio_provider.dart src/mobile/test/presentation/providers/audio_provider_test.dart
git commit -m "feat: add queue-based auto-play to AudioNotifier"
```

---

### Task 4: Update `MusicScreen` to use `setQueue`

**Files:**
- Modify: `src/mobile/lib/presentation/screens/music/music_screen.dart`

- [ ] **Step 1: Substituir chamada `play()` por `setQueue()` no `onPressed`**

Encontre o bloco `onPressed` do `IconButton` dentro do `itemBuilder`. Substitua:

```dart
// Antes
onPressed: () {
  if (isPlayingThis) {
    audioNotifier.pause();
  } else {
    audioNotifier.play(
      song.audioUrl,
      title: song.title,
      artist: song.artist,
    );
  }
},
```

Por:

```dart
// Depois
onPressed: () {
  if (isPlayingThis) {
    audioNotifier.pause();
  } else {
    audioNotifier.setQueue(songs, startIndex: index);
  }
},
```

- [ ] **Step 2: Rodar todos os testes do projeto**

```bash
cd /home/vkajiyama/src/BetelApp/src/mobile && flutter test --no-pub
```

Esperado: todos os testes passando sem regressões.

- [ ] **Step 3: Commit**

```bash
git add src/mobile/lib/presentation/screens/music/music_screen.dart
git commit -m "feat: wire MusicScreen to use setQueue for auto-play"
```

---

## Verificação Final

Após todas as tasks, rodar a suite completa e confirmar zero falhas:

```bash
cd /home/vkajiyama/src/BetelApp/src/mobile && flutter test --no-pub
```
