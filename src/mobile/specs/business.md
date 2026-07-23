---
layer: business
project: mobile
last_reviewed: 2026-06-13
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

- **Aviso de dados móveis** — se `ConnectivityService.isMobileData()` retornar `true` (mobile data ativo **E** Wi-Fi não ativo), o app mostra um `AlertDialog` bloqueante (`barrierDismissible: false`) com duas opções:
  - **"Baixar"**: prossegue com o sync normalmente.
  - **"Agora não"**: cancela o sync e navega diretamente para `MainScaffold(syncResult: SyncResult.offlineWithData)`, exibindo o conteúdo já cacheado (se houver).
  - O usuário não pode fechar o dialog tocando fora — é obrigatório escolher uma das duas opções.
  - **Dual-stack:** se o dispositivo tiver Wi-Fi e dados móveis simultaneamente, `isMobileData()` retorna `false` — sem aviso, o sync ocorre normalmente.
  - **Por quê:** `connectivity_plus` pode retornar múltiplas interfaces ao mesmo tempo. A lógica privilegia Wi-Fi: qualquer Wi-Fi ativo suprime o aviso de dados móveis. Downloads podem ser grandes; respeita o plano de dados do usuário.

- **Offline resilience:**
  - **Primeira execução sem internet:** `SyncResult.offlineFirstBoot` — app inicia sem conteúdo (telas mostram estado vazio).
  - **Execução subsequente sem internet:** `SyncResult.offlineWithData` — app funciona normalmente com conteúdo previamente sincronizado.
  - **Por quê:** O app deve ser usável offline após o primeiro sync.

- **`SyncResult` enum — valores completos:**
  | Valor | Quando é retornado |
  |-------|--------------------|
  | `offlineFirstBoot` | Sem conexão E `sync_meta` vazia (primeira execução) |
  | `offlineWithData` | Sem conexão (ou falha de rede) E `sync_meta` tem dados |
  | `upToDate` | Manifest remoto tem a mesma `version` que o local |
  | `updated` | Sync concluído com sucesso (arquivos baixados ou conteúdos atualizados) |
  | `error` | **Declarado no enum mas nunca retornado** — toda exceção é convertida em `offlineFirstBoot` ou `offlineWithData`. Reservado para uso futuro. |

- **Download resilience:** `RemoteContentService.downloadFile()` usa stall detection + retry:
  - **Stall timeout:** 3 segundos sem bytes recebidos cancela a tentativa atual.
  - **Retries:** até 3 tentativas automáticas em caso de stall (`cancel`) ou erro desconhecido (`unknown`). Erros HTTP definitivos (4xx/5xx) não são retentados.
  - **Timeout total por tentativa:** 5 minutos (`receiveTimeout` do Dio) — último recurso caso o stall timer não disparar.

### Áudio — regras de reprodução

- **Arquitetura 2 camadas:**
  1. `BetelAudioHandler` (camada OS) — gerencia player `just_audio`, foreground service Android, notificação de mídia, controles de headphone.
  2. `AudioNotifier` (camada Riverpod) — gerencia queue, shuffle, repeat modes, estado para UI.

- **Bootstrap obrigatório:** `betelAudioHandlerProvider` é declarado com `throw UnimplementedError` e **deve** ser sobrescrito no `ProviderScope` de `main()` após `AudioService.init()` completar. A função `initAudioService()` (`lib/core/audio/audio_service_initializer.dart`) retorna o `BetelAudioHandler` inicializado; `main()` injeta esse resultado via `overrides: [betelAudioHandlerProvider.overrideWithValue(handler)]`. Acessar o provider antes desse override lança exceção.

- **Sync handler → notifier (MediaItem stream):** `AudioNotifier` subscreve `handler.mediaItem` para manter `AudioState` em sincronia quando o handler avança tracks de forma autônoma (controles da notificação Android / lock screen). O `MediaItem.id` é igual ao `song.id`; o notifier faz lookup na queue por esse id para atualizar `currentUrl`, `currentTitle`, `currentArtist`, `duration`, e `currentIndex`. Sem esse listener, controles externos causariam dessincronização entre o player real e a UI.

- **`AudioState`** — classe imutável que representa o estado completo do player para a UI. Campos:
  | Campo | Tipo | Default | Descrição |
  |-------|------|---------|-----------|
  | `isPlaying` | `bool` | `false` | Se está tocando no momento |
  | `currentUrl` | `String?` | `null` | URL/path da track atual |
  | `currentTitle` | `String?` | `null` | Título exibido no player |
  | `currentArtist` | `String?` | `null` | Artista exibido no player |
  | `duration` | `Duration` | `Duration.zero` | Duração total da track |
  | `position` | `Duration` | `Duration.zero` | Posição de reprodução atual |
  | `queue` | `List<Song>` | `[]` | Fila completa |
  | `currentIndex` | `int?` | `null` | Índice da track atual na queue |
  | `repeatMode` | `AudioRepeatMode` | `off` | Modo de repetição atual |
  | `shuffleMode` | `AudioShuffleMode` | `off` | Modo shuffle atual |

  Enums: `AudioRepeatMode { off, all, one }` e `AudioShuffleMode { off, on }`.
  Estado inicial (const): todos os campos no valor default acima. `stop()` retorna para este estado.

- **Repeat modes** (ciclo via `toggleRepeat()`): `off` → `all` → `one` → `off`.
  - `repeatOne`: ao completar a track, `BetelAudioHandler` faz `seek(Duration.zero)` + `play()` diretamente no player (necessita acesso direto sem passar pelo notifier). O `AudioNotifier._onTrackCompleted()` tem early return para `repeatMode.one` — apenas atualiza `position: Duration.zero, isPlaying: true` na UI e **não avança a queue**, evitando double-advance. A flag `_repeatOne: bool` no handler é sincronizada via `handler.setRepeatOne()` chamado por `toggleRepeat()`.
    - **`stop()` não reseta `_repeatOne`** no handler — reseta apenas o estado do player e emite idle `playbackState`. O `AudioNotifier` é responsável por resetar `_repeatOne` para `false` quando necessário.
  - `repeatAll`: ao chegar na última track, wrapa para index 0.
  - `off`: reprodução sequencial — ao completar cada track, avança automaticamente para a próxima. Ao completar a última track da queue, para a reprodução (`isPlaying: false`). Não wrapa.

- **Shuffle:** Ao ativar (`toggleShuffle()`), `_rebuildShuffleIndices()` cria `_shuffledIndices`: lista com todos os índices da queue em ordem aleatória, com a track atual fixada na posição 0 (evita tocar a track atual como "próxima imediata").
  - **Navegação com shuffle ativo:** `playNext()` e `playPrevious()` percorrem `_shuffledIndices` com aritmética modular — a queue wrapa circularmente. O shuffle tem precedência sobre `repeatMode`: em modo shuffle, a conclusão de uma track sempre avança para a próxima posição shuffleada (nunca para a reprodução), independentemente de `repeatMode` ser `off`.
  - **`repeatMode.one` com shuffle:** o handler trata `repeatOne` diretamente (seek+replay); o `AudioNotifier._onTrackCompleted()` retorna cedo sem avançar a fila.

- **skipToNext boundary:** No handler, `skipToNext()` é no-op se já está na última track. O wrap-around para repeat-all é controlado pelo `AudioNotifier`.

- **skipToPrevious boundary:** Se na primeira track, `skipToPrevious()` faz seek para `Duration.zero` (restart) em vez de ir para índice negativo.

- **`skipToIndex(index)` — navegação direta:** método adicional no `BetelAudioHandler` (fora do contrato `BaseAudioHandler`) que carrega e toca qualquer track da queue por índice absoluto. Usado pelo `AudioNotifier` para shuffle e repeat-all wrap-around, onde o índice de destino não é necessariamente `current ± 1`. Faz bounds check (no-op se queue vazia ou índice fora dos limites). Também usado para seleção direta de track pelo usuário na lista.

- **`load(url)` — pre-load sem autoplay:** usado exclusivamente pelo `LessonDetailScreen` para carregar uma única track (a lição com áudio) sem iniciar a reprodução. Internamente chama `_handler.setQueue([song], autoPlay: false)`. A queue passa a ter um único item. O player fica pronto para `resume()` sem precisar de `setQueue()`. Também faz dedup: se `url == state.currentUrl`, é no-op.
  - **Contraste com `setQueue()`:** `setQueue()` sempre faz autoPlay=true (inicia reprodução imediatamente). `load()` carrega sem tocar.

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

### Conteúdos dinâmicos (headless CMS)

- **Padrão headless CMS:** O portal cria conteúdos (VIDEO ou TEXT). O mobile os sincroniza e o dev hardcoda onde cada conteúdo aparece por slug.
  - **O admin no portal decide** o que o conteúdo diz.
  - **O dev no código decide** onde o conteúdo aparece — hardcoded por slug (ex: `contentRepository.loadContentBySlug('welcome-video')`).

- **Tipos de conteúdo:**
  - **VIDEO:** URL do YouTube, renderizado via `youtube_player_flutter` embutido no `BetelDialog`.
  - **TEXT:** HTML gerado pelo editor Tiptap no portal, renderizado nativamente via `flutter_widget_from_html_core` no `BetelDialog`.
    - **Single-page:** campo `html` — renderizado como uma única `HtmlWidget` com scroll.
    - **Multi-page:** campo `pages_html` — array de HTML por página, renderizado como múltiplos `pages` no `BetelDialog` (swipe horizontal entre páginas). Quando `pages_html` está presente, tem precedência sobre `html`. Coluna adicionada na migração SQLite v4→v5.

- **Publish/unpublish:** Não há campo `published` no mobile. A presença do conteúdo no array `contents[]` do `manifest.json` significa publicado; a ausência significa despublicado. O sync reflete isso automaticamente — conteúdos removidos do manifest são deletados do SQLite local.

- **Slug:** Identificador estável e único. Gerado automaticamente no portal a partir do título (lowercase, espaços→dashes, sem acentos). O dev usa o slug para referenciar conteúdo no código Flutter.

- **Sem download de arquivo:** Conteúdo VIDEO é apenas um `youtubeUrl`; conteúdo TEXT tem HTML inline no manifest. Nenhum binário é baixado para o filesystem local.

### Lesson Progress (esqueleto)

- **Definido no schema do DB mas não implementado na UI** — tabela `lesson_progress` com `is_completed` (default 0) e `is_locked` (default 1). Nenhum repository ou view model lê/escreve esses campos ainda.
  - **Por quê:** Planejado para futuro sistema de progressão sequencial (lição N desbloqueia após N-1 completar).

### Error handling

- **Sem error handler global** — sem crash reporter, sem error boundary.
- **Sync errors:** silenciosamente fallback para offline (exceção engolida).
- **Audio errors:** Quando `setAudioSource()` lança exceção em `BetelAudioHandler._loadAndPlay()`, o handler emite `playbackState` com `playing: false` e `processingState: idle`, restaurando os três controles (prev, **play**, next) para permitir retry pelo usuário. O `mediaItem` não é limpo — o item que falhou permanece visível na notificação. Nenhuma exceção é relançada e nenhuma notificação é mostrada ao usuário.
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
