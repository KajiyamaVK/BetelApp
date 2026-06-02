# Design: Botões de Navegação do Player (Anterior / Próxima)

**Data:** 2026-05-27
**Status:** Aprovado

## Contexto

O `AudioPlayerWidget` atualmente tem um botão de restart (seek para 0) e suporte opcional a um botão "próxima" via prop `onNext`. Esta feature substitui o botão de restart por um botão ⏮ com comportamento inteligente, adiciona o botão ⏭ sempre visível, e centraliza o play/pause entre os dois.

## Comportamento

### Botão ⏮ (anterior/reinicia)
- Se `position >= 2s`: reinicia a música atual (seek para `Duration.zero`)
- Se `position < 2s` e há música anterior na fila: toca a música anterior
- Se `position < 2s` e é a primeira música (ou fila vazia): reinicia (`seek(Duration.zero)`)

### Botão ▶/⏸ (play/pause)
- Sem mudança de comportamento

### Botão ⏭ (próxima)
- Já implementado via `playNext()` no notifier
- Sempre visível quando `onNext` for passado

---

## Seção 1: `AudioNotifier` — novo método `playPrevious()`

```dart
Future<void> playPrevious() async {
  final index = state.currentIndex;
  final queue = state.queue;

  // Se progresso >= 2s, reinicia
  if (state.position.inSeconds >= 2) {
    await seek(Duration.zero);
    return;
  }

  // Se é a primeira música ou fila vazia, reinicia
  if (queue.isEmpty || index == null || index <= 0) {
    await seek(Duration.zero);
    return;
  }

  // Volta para a música anterior
  final prevIndex = index - 1;
  final song = queue[prevIndex];
  state = state.copyWith(currentIndex: prevIndex);
  await play(song.audioUrl, title: song.title, artist: song.artist);
}
```

---

## Seção 2: `AudioPlayerWidget` — layout revisado

### Props removidas
- `showRestartButton` — removida (o botão ⏮ substitui)

### Props mantidas / adicionadas
- `onNext: VoidCallback?` — mantida
- `onPrevious: VoidCallback?` — nova

### Layout dos botões (linha superior, lado direito)
```
⏮ (34×34)  ▶/⏸ (42×42)  ⏭ (34×34)
```
- ⏮ e ⏭ sempre visíveis quando seus callbacks forem não-nulos
- ▶/⏸ sempre no centro, tamanho ligeiramente maior

---

## Seção 3: `MusicScreen` — wiring dos callbacks

```dart
AudioPlayerWidget(
  onPrevious: () async => await audioNotifier.playPrevious(),
  onNext: () async => await audioNotifier.playNext(),
)
```

---

## Seção 4: Testes — `audio_provider_test.dart`

### Grupo `playPrevious`

| Cenário | Entrada | Esperado |
|---|---|---|
| position >= 2s | position = 3s, qualquer fila | seek(0), índice não muda |
| position < 2s, há anterior | position = 1s, index = 1 | toca song[0], currentIndex = 0 |
| position < 2s, primeira música | position = 1s, index = 0 | seek(0), índice não muda |
| position < 2s, fila vazia | position = 0s, queue = [] | seek(0) |

---

## Compatibilidade com `LessonDetailScreen`

A `LessonDetailScreen` usa `AudioPlayerWidget` com `showRestartButton: true` atualmente. Com a remoção dessa prop, o comportamento de restart passa para o botão ⏮ (que reinicia quando `position >= 2s` ou não há anterior). Não é necessário passar `onPrevious` na `LessonDetailScreen` — sem o callback, o botão ⏮ simplesmente não aparece, mantendo o comportamento atual de não mostrar navegação.
