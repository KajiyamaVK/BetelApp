---
layer: business
project: mobile
last_reviewed: 2026-06-05
---

## Propósito

Governa regras de negócio do app mobile — fluxos, validações, comportamentos esperados da aplicação independente de UI ou persistência.

## Decisões

### Autenticação

- **Sem autenticação** — o app não tem login, JWT, token refresh, ou qualquer sistema de auth. O usuário abre o app e vai direto para o conteúdo.
  - **Por quê:** Decisão intencional para a fase atual (documentada em `guidelines/4-technical-details.md`). O público-alvo são crianças + pais/professores; a fricção de login não se justifica sem features que exijam identidade do usuário.
  - Auth é item de roadmap futuro (`guidelines/_TODOS.md`).

### Sync de conteúdo (startup gate)

- **Sync obrigatório no startup** — `SplashScreen` executa `ContentSyncService.sync()` antes de liberar navegação.

- **Delta-sync por checksum** — o sync compara a `version` do manifest remoto com a `manifest_version` local (tabela `sync_meta`). Se iguais, pula o download. Se diferentes, compara checksums individuais (PDF e áudio) por lição e só baixa o que mudou.
  - **Por quê:** Evita re-download desnecessário de 24+ PDFs e áudios a cada abertura.

- **Remoção de lições obsoletas** — lições presentes no DB local mas ausentes no manifest remoto são deletadas do DB e do filesystem.
  - **Por quê:** Garante que o conteúdo local reflete exatamente o que o backend disponibiliza.

- **Aviso de dados móveis** — se o dispositivo está em dados móveis (sem Wi-Fi), o app mostra um `AlertDialog` bloqueante pedindo permissão antes de iniciar o sync. O usuário pode recusar e ir direto para o conteúdo já cacheado.
  - **Por quê:** Downloads podem ser grandes; respeita o plano de dados do usuário.

- **Offline resilience:**
  - **Primeira execução sem internet:** `SyncResult.offlineFirstBoot` — app inicia sem conteúdo (telas mostram estado vazio).
  - **Execução subsequente sem internet:** `SyncResult.offlineWithData` — app funciona normalmente com conteúdo previamente sincronizado.
  - **Por quê:** O app deve ser usável offline após o primeiro sync.

- **Timeout de download:** 5 minutos (`receiveTimeout`) por arquivo.

### Áudio — regras de reprodução

- **Arquitetura 2 camadas:**
  1. `BetelAudioHandler` (camada OS) — gerencia player `just_audio`, foreground service Android, notificação de mídia, controles de headphone.
  2. `AudioNotifier` (camada Riverpod) — gerencia queue, shuffle, repeat modes, estado para UI.

- **Repeat modes** (ciclo via `toggleRepeat()`): `off` → `all` → `one` → `off`.
  - `repeatOne`: ao completar a track, seek para `Duration.zero` e replay — não avança na queue.
  - `repeatAll`: ao chegar na última track, wrapa para index 0.
  - `off`: ao chegar na última track, para a reprodução.

- **Shuffle:** Ao ativar, cria lista de índices shuffleados com a track atual fixada na posição 0 (não repete a track que está tocando como "próxima").

- **skipToNext boundary:** No handler, `skipToNext()` é no-op se já está na última track. O wrap-around para repeat-all é controlado pelo `AudioNotifier`.

- **skipToPrevious boundary:** Se na primeira track, `skipToPrevious()` faz seek para `Duration.zero` (restart) em vez de ir para índice negativo.

- **Load dedup:** `load(url)` é no-op se `url == state.currentUrl` — evita reload da mesma track.

- **Play contract:** `play(url)` é apenas resume — `setQueue()` deve ter sido chamado antes para carregar a source. Não é cold-start.

- **Stop reseta tudo:** `stop()` retorna `AudioState` ao estado inicial (const vazio).

- **Android foreground service hack:** Ao dar autoPlay, o handler emite `playing: true` com `processingState: loading` ANTES de `setAudioSource()` completar — isso garante que `startForeground()` é chamado dentro da janela de 5 segundos do Android, evitando que o serviço seja morto.

- **URI resolution:** `audioUrl.startsWith('http')` → `Uri.parse()` (remoto); senão → `Uri.file()` (local).

- **Background stop on task removal:** `onTaskRemoved()` chama `stop()` — swipar o app dos recentes para a reprodução.

- **Notificação Android:** canal `com.betelapp.audio`, `androidNotificationOngoing: false`, `androidStopForegroundOnPause: true` — notificação dismissível, foreground service para quando pausado.

### Favoritos

- **Deduplicação na inserção** — `isFavorite()` check antes de `insert`. Composite key: `'${type}_$itemId'` (ex: `lesson_4`, `song_7`).

- **Favoritos de músicas mostram Snackbar** — ao invés de tocar diretamente, exibem "vá ao tab Músicas para ouvir". Decisão MVP documentada em comentário no código.

### Conteúdo — acesso

- **Sem controle de acesso por usuário** — todo conteúdo sincronizado é acessível livremente.

- **Audio availability gate** — tela de Músicas e Favoritos só mostram lições que possuem `audio_local_path IS NOT NULL`. Lições sem áudio baixado são silenciosamente excluídas dessas views.

### Sistema de Revisão (Leitner / Flashcards)

- **Propósito:** Permite ao usuário estudar as Q&As de uma lição via sessões de revisão com repetição espaçada (algoritmo Leitner de 5 buckets).

- **Toggle por lição:** Cada lição pode ser ativada ou desativada para revisão de forma independente. O estado fica em `review_active` (SQLite local). **O toggle começa DESLIGADO por padrão** — o usuário deve ativar manualmente as lições que quer estudar.
  - **Por quê:** Ativar automaticamente todas as lições no primeiro sync sobrecarrega o usuário com sessões de revisão antes que ele conheça o conteúdo. O usuário decide quando quer iniciar a revisão de cada lição.

- **Ativação manual:** Na tela `LessonDetailScreen`, há um toggle que chama `ReviewRepository.setReviewActive()`.

- **Reset via toggle:** Ao ativar a revisão de uma lição (`setReviewActive(active: true)`), todos os cards daquela lição são resetados para bucket=1 com `next_review_at = hoje`. Isso permite ao usuário usar desligar→ligar como mecanismo de "recomeçar do zero". Desativar (`active: false`) não altera o progresso dos cards.

- **Algoritmo Leitner:**
  - 5 buckets (1-5). Intervalo de revisão por bucket:
    | Bucket | Próxima revisão |
    |--------|----------------|
    | 1 | 1 dia |
    | 2 | 2 dias |
    | 3 | 4 dias |
    | 4 | 8 dias |
    | 5 | 16 dias |
  - Resposta correta: `bucket = min(bucket + 1, 5)`
  - Resposta errada: `bucket = 1` (volta ao início)
  - Novos cards entram em `bucket = 1` com `next_review_at = today`

- **Sessão de revisão:**
  - Carrega todos os cards com `next_review_at <= today` das lições ativas (`getActiveLessonIds()` + `getDueCards()`)
  - Progresso (`card_progress`) é **local** — nunca sincronizado com o backend

- **Sync e cards:**
  - Ao sincronizar Q&As, `upsertCards()` insere novos cards com bucket=1; nunca sobrescreve progresso existente
  - Q&As removidas do manifest são deletadas de `card_progress` (`deleteCardsForQuestionIds()`)
  - O sync **não altera `review_active`** — a escolha do usuário é preservada entre re-syncs

- **Invariante de reset:** `resetAllProgress()` zera buckets e seta `next_review_at = now` para todos os cards, mas **não altera os toggles** — lições ativas continuam ativas.

### Lesson Progress (esqueleto)

- **Definido no schema do DB mas não implementado na UI** — tabela `lesson_progress` com `is_completed` (default 0) e `is_locked` (default 1). Nenhum repository ou view model lê/escreve esses campos ainda.
  - **Por quê:** Planejado para futuro sistema de progressão sequencial (lição N desbloqueia após N-1 completar).

### Error handling

- **Sem error handler global** — sem crash reporter, sem error boundary.
- **Sync errors:** silenciosamente fallback para offline (exceção engolida).
- **Audio errors:** silenciosamente reseta para estado idle (sem notificar usuário).
- **View model errors:** convertidos em `AsyncValue.error()` e exibidos inline como `Text('Erro: $e')`.
- **Favorites toggle errors:** silenciosamente `debugPrint` — não notifica usuário.
- **Update check errors:** silenciosamente ignorados (non-critical).

### Validações

- **Sem formulários nem campos de input** — não há validação de entrada de usuário.
- **Queue bounds validation:** `setQueue()` faz early return se `songs.isEmpty` ou `startIndex` fora dos limites.
- **`mounted` checks:** Todas as callbacks assíncronas verificam `if (mounted)` antes de `setState()`.
- **Int parse safety:** `int.tryParse()` com null guard em `favorites_view_model.dart`.

## O que NÃO fazer

- **Não adicionar sistema de auth** sem decisão explícita — é item de roadmap, não requisito atual.
- **Não engolir erros silenciosamente em novas features** — o padrão atual de swallow silencioso é dívida técnica do MVP. Novas features devem ao menos registrar erros de forma visível ao dev (crashlytics futuro).
- **Não implementar lesson progress/lock** sem spec completa do fluxo de progressão — o schema existe mas a UX de desbloqueio não foi desenhada.
- **Não modificar o hack do foreground service Android** sem entender a janela de 5 segundos — é workaround necessário para evitar kill do serviço pelo OS.
- **Não chamar `play(url)` sem `setQueue()` prévio** — é resume, não cold-start. O contrato está documentado no código.
