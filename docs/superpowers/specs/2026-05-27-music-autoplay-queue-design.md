# Design: Auto-play com Fila de Músicas

**Data:** 2026-05-27
**Status:** Aprovado

## Contexto

Na aba de Músicas, ao dar play em uma música, o player não avançava automaticamente para a próxima ao terminar. Esta feature adiciona auto-play via fila centralizada no `AudioNotifier`, com arquitetura extensível para a futura aba de Favoritos.

## Decisões de Design

- **Comportamento ao terminar a última música:** Para sem fazer nada (sem loop).
- **Localização da lógica de fila:** No `AudioNotifier`, não nas telas — evita duplicação quando a aba de Favoritos for implementada.
- **Método `play()` existente:** Permanece inalterado para uso avulso (ex: `LessonDetailScreen`).

---

## Seção 1: Estado e Modelo

### `AudioState` — campos adicionados

```dart
final List<Song> queue;     // fila atual, default []
final int? currentIndex;    // índice da música tocando na fila, default null
```

O modelo `Song` não sofre alterações.

---

## Seção 2: `AudioNotifier` — novas responsabilidades

### Novos métodos

**`setQueue(List<Song> songs, {int startIndex = 0})`**
- Armazena a fila no estado
- Define `currentIndex = startIndex`
- Chama `play()` na música do `startIndex`
- Substitui completamente qualquer fila anterior

**`playNext()`**
- Incrementa `currentIndex + 1`
- Se já estiver na última música: para sem fazer nada
- Caso contrário: chama `play()` na próxima música da fila

### Listener adicionado em `_initListeners()`

```dart
_player.onPlayerComplete.listen((_) {
  playNext();
});
```

---

## Seção 3: `MusicScreen` — mudanças

No `onPressed` do botão play de cada `ListTile`, substituir:

```dart
// Antes
audioNotifier.play(song.audioUrl, title: song.title, artist: song.artist);

// Depois
audioNotifier.setQueue(songs, startIndex: index);
```

O `AudioPlayerWidget` já suporta botão "próxima" via prop `onNext`, mas ele **não é exposto** na `MusicScreen` — o avanço é automático via notifier.

---

## Seção 4: Testes

Arquivo: `audio_provider_test.dart`

### Grupo 1 — `setQueue`
- Estado reflete a fila correta após `setQueue`
- `currentIndex` é igual ao `startIndex` passado
- `play()` é chamado na música do índice correto

### Grupo 2 — `playNext`
- Avança para a música seguinte corretamente
- Na última música: não chama play e não estoura o índice

### Grupo 3 — Auto-play ao completar
- Quando `onPlayerComplete` dispara, `playNext()` é invocado automaticamente

Arquivos **sem novos testes:**
- `audio_player_widget_test.dart` — comportamento visível não muda
- `music_screen` — sem lógica nova que exija teste de widget

---

## Extensibilidade futura

Para a aba de Favoritos, basta chamar:

```dart
audioNotifier.setQueue(musicasFavoritas, startIndex: index);
```

Nenhuma mudança no notifier será necessária.
