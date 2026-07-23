---
layer: data
project: mobile
last_reviewed: 2026-06-13
---

## Propósito

Governa decisões de dados no app mobile — modelos locais, sincronização com API, cache, e persistência.

## Decisões

### Arquitetura geral

- **Layered architecture com MVVM na presentation** — separação em 4 camadas:
  ```
  lib/
    core/           — infra compartilhada (DB, providers, audio, theme, connectivity)
    data/           — modelos, repositories (impl), services
    domain/         — entidades, interfaces abstratas de repository
    presentation/   — screens/, widgets/, providers/ (ViewModels)
  ```
  - **Por quê:** Clean Architecture simplificada para o tamanho do projeto. Não usa use cases como classes separadas — a lógica vive nos ViewModels e Services.

### State management

- **Riverpod 2.5.1** (`flutter_riverpod`) — único sistema de estado.
- **Providers centralizados** em `lib/core/providers.dart`.
- **Padrão de provider por tipo:**
  | Tipo | Uso |
  |------|-----|
  | `Provider<T>` | Services/repos sem estado (singletons) |
  | `StateNotifierProvider<VM, AsyncValue<T>>` | ViewModels com dados assíncronos |

- **`betelAudioHandlerProvider`** — padrão especial: throws `UnimplementedError` por default e é sobrescrito via `ProviderScope.overrides` no `main()` após `AudioService.init()` completar (inicialização assíncrona antes de `runApp`).

- **ViewModels registrados (StateNotifierProviders):**
  | Provider | ViewModel | Estado | Descrição |
  |----------|-----------|--------|-----------|
  | `favoritesViewModelProvider` | `FavoritesViewModel` | `AsyncValue<List<dynamic>>` | Lista mista de `Lesson` e `Song` favoritos. Carrega no init; `toggleFavorite()` remove ou adiciona e recarrega. Estado `dynamic` porque a lista mistura dois tipos. |
  | `reviewViewModelProvider` | `ReviewViewModel` | `AsyncValue<ReviewState>` | Contém `activeLessonIds` e `totalDueToday`. Carrega no init; `toggleReviewActive()` delega ao `ReviewRepositoryImpl` e recarrega. `ReviewState` é imutável com named constructor `empty()`. |
  | `musicViewModelProvider` | `MusicViewModel` | `AsyncValue<List<Song>>` | Lista de músicas (lições com áudio). Carrega no init. Sem mutação — read-only. |

- **Testes usam `ProviderScope.overrides`** para injetar fakes/mocks.

### Persistência local

- **SQLite via sqflite 2.3.0** — único mecanismo de persistência. Sem Hive, sem SharedPreferences, sem Isar.
  - **Por quê:** SQLite suporta queries relacionais (joins favorites + lessons) e é maduro no Flutter. O app não precisa de key-value store simples.

- **DatabaseHelper singleton** — factory constructor com `_instance`/`_database` estáticos.
  - **`resetForTesting({String? dbPath})`** — método estático que zera `_database` e `_instance`, permitindo que cada teste crie um banco fresh. Quando `dbPath` é fornecido (ex: `inMemoryDatabasePath` do `sqflite_common_ffi`), o próximo `openDatabase()` usa esse path.
- **Banco:** `betel.db`, schema version 5 (v4→v5: `ALTER TABLE contents ADD COLUMN pages_html TEXT`).

- **Tabelas:**
  | Tabela | Propósito | Colunas chave |
  |--------|-----------|---------------|
  | `lessons` | Metadata de lições sincronizadas | `id`, `title`, `audio_local_path`, `audio_ext`, `audio_checksum`, `pdf_local_path`, `pdf_checksum`, `synced_at`, `question_count` |
  | `sync_meta` | Controle de versão do manifest | `id=1`, `manifest_version`, `last_sync_at` |
  | `favorites` | Favoritos do usuário | `id` (composite: `type_itemId`), `type`, `item_id`, `added_at` |
  | `lesson_progress` | Progresso de lições (esqueleto, não usado) | `lesson_id`, `is_completed`, `is_locked`, `last_accessed` |
  | `card_progress` | Progresso Leitner por flashcard | `question_id` (PK), `lesson_id`, `bucket` (1-5), `last_reviewed_at`, `next_review_at`, `question_text`\*, `answer_text`\* |
  | `review_active` | Toggle de revisão por lição | `lesson_id` (PK), `active` (0/1) |
  | `contents` | Conteúdos dinâmicos sincronizados do portal | `id` (PK), `slug` (UNIQUE), `title`, `type`, `youtube_url`, `html`, `pages_html`, `synced_at` |

- **Serialização de DateTime em SQLite:**
  - `favorites.added_at` → INTEGER (Unix timestamp em milissegundos). Leitura via `DateTime.fromMillisecondsSinceEpoch()`.
  - `card_progress.last_reviewed_at` / `card_progress.next_review_at` → TEXT (ISO 8601, formato `YYYY-MM-DDTHH:MM:SS.mmm`). Leitura via `DateTime.parse()`. O SQLite pode usar funções `datetime()` nativamente nesses campos (usado em `advanceOneDayForTesting()`).
  - **Inconsistência herdada do MVP** — não há decisão de padronização. Novos campos de data devem seguir o formato TEXT/ISO para compatibilidade com queries SQLite nativas.

- **Resolução de favoritos em runtime:**
  - Favoritos do tipo `'lesson'` são resolvidos fazendo lookup de `item_id` (int) na lista de lições.
  - Favoritos do tipo `'song'` **não possuem tabela própria** — são resolvidos mapeando lições com `audio_local_path IS NOT NULL` em objetos `Song` (com `id = lesson.id.toString()`), e depois fazendo lookup de `item_id` nessa lista em memória. O `item_id` armazenado em `favorites` para músicas é o `lesson.id` convertido para String.
  - Lições sem `audio_local_path` são silenciosamente excluídas da lista de favoritos de músicas (mesmo audio gate do MusicScreen).

### Modelos

- **Estratégia mista de serialização:**
  - `Lesson`, `Content`, `Favorite`, `ContentManifest`, `Flashcard`, `CardProgress` → hand-written `fromMap()`/`toMap()` ou `fromJson()`
  - `Song` → `json_serializable` com `@JsonSerializable()` + `build_runner`
  - **Sem freezed** em nenhum lugar.
  - **Por quê:** O projeto começou hand-written e migrou parcialmente para codegen. Não há decisão explícita de padronizar.

- **`AudioState`** (provider) usa `copyWith` manual (sem freezed).

- **Localização dos modelos:**
  - `Favorite` → `domain/entities/favorite.dart` — promovida ao domain layer porque é referenciada pela interface `FavoritesRepository`. Contém `fromMap()`/`toMap()` diretamente na entidade (sem separação de mapper).
  - Todos os demais modelos (`Lesson`, `Content`, `Flashcard`, `CardProgress`, `Song`, `ContentManifest`) → `data/models/` — não há entidades de domínio correspondentes.
  - **Inconsistência:** `Flashcard` e `CardProgress` são importados diretamente pela interface `ReviewRepository` em `domain/`, mesmo vivendo em `data/`. Dívida arquitetural — não seguir como padrão para novas features.

### Comunicação com backend

- **Dio 5.4.3** — HTTP client para fetch de manifest e download de arquivos.
- **Sem auth headers.** O único interceptor ativo é o `_NetworkCheckInterceptor` de `NetworkStatusNotifier` (reporta sucesso/falha para o status de rede — não é retry logic).
- **Base URL via `dart-define`:** `CONTENT_BASE_URL` — default `http://s3.kajiyama.com.br/betelapp-content` (produção). Para dev, passar `--dart-define=CONTENT_BASE_URL=http://s3.kajiyama.com.br/betelapp-content-dev`. Sem `dart-define`, URL de produção é usada.
  - Ainda HTTP (não HTTPS) — sem certificado SSL no homelab. Dívida técnica.
  - Não há flavors nem `.env` — o único mecanismo de troca de ambiente é `dart-define`.
- **`RemoteContentException`** — única exception tipada do data layer. Lançada por `fetchManifest()` e `downloadFile()` encapsulando qualquer `DioException` ou erro de parsing. Capturada em `ContentSyncService.sync()` para fallback silencioso. Nunca propagada para a UI.

### Repository pattern

- **Parcialmente implementado:**
  - `FavoritesRepository` → interface abstrata em `domain/` + implementação em `data/`. Provider tipado como `Provider<FavoritesRepository>` (abstrato) — permite substituição por mock em testes.
  - `ReviewRepository` → interface abstrata existe em `domain/`, mas o provider (`reviewRepositoryProvider`) está tipado como `Provider<ReviewRepositoryImpl>` (concreto). `ReviewViewModel` também injeta o concreto diretamente. **A interface não é usada para injeção de dependência** — testes de `ReviewViewModel` injetam o concreto, não um mock da interface.
  - `ContentRepository` → implementação direta em `data/`, sem interface abstrata.
  - **Por quê:** `FavoritesRepository` foi totalmente abstraída para testes. `ReviewRepository` tem interface por legado arquitetural mas o provider nunca foi migrado para tipagem abstrata — dívida técnica.

- **Dependência cruzada em `ReviewRepository`:** A interface `domain/repositories/review_repository.dart` importa `Flashcard` e `CardProgress` de `data/models/flashcard.dart`. Isso viola a regra de dependência do Clean Architecture (domain não deveria depender de data). `FavoritesRepository` está correto — referencia apenas `domain/entities/favorite.dart`. **Dívida arquitetural — não replicar como padrão.** Para novas interfaces em `domain/`, os tipos de parâmetro e retorno devem viver em `domain/entities/` ou ser tipos primitivos/built-in Dart.

### Content sync

- **Manifest-driven:** `RemoteContentService.fetchManifest()` baixa `/manifest.json` do MinIO.

- **`SyncProgress`** — emitido via callback `onProgress` durante o download de lições:
  - `current` (int): índice da lição sendo baixada (1-based)
  - `total` (int): total de lições a baixar neste sync
  - `lessonTitle` (String): título da lição atual (para exibir na splash)

- **`ContentSyncService.sync()` — assinatura completa:**
  ```
  Future<SyncResult> sync({
    void Function(SyncProgress)? onProgress,
    Future<String> Function()? getDocsDir,
  })
  ```
  - `onProgress`: opcional; chamado uma vez por lição com arquivo novo/atualizado
  - `getDocsDir`: injetável para testes (evita chamada real a `getApplicationDocumentsDirectory()`)
- **Modelo `ContentManifest`:**
  - `version` (int) — comparado com `sync_meta.manifest_version`
  - `updatedAt` (DateTime)
  - `lessons[]` — cada uma com `ManifestLesson` contendo `ManifestFileEntry` (pdf), `ManifestAudioEntry?` (audio), e `List<ManifestQuestion>` (questions, default `[]`)
  - `ManifestQuestion`: `id`, `question` (de `"q"`), `answer` (de `"a"`)
  - `contents[]` — cada um com `ManifestContent` contendo `id`, `slug`, `title`, `type` ('VIDEO'/'TEXT'), `youtubeUrl?`, `html?`, `pages?` (`List<String>?` — multi-page HTML). Default `[]` para backward compat com manifests antigos.
  - **`ManifestFileEntry`** — representa um arquivo versionado: `active` (String, caminho relativo à base URL para download), `checksum` (String), `history` (List<String>, paths anteriores — desserializado mas não consumido pela lógica de sync).
  - **`ManifestAudioEntry`** — extends `ManifestFileEntry`, adiciona `ext` (String, ex: `"mp3"`) usado para construir o nome local `audio.<ext>`.
- **Lógica de detecção de mudanças por lição:**
  | Mudança detectada | Ação |
  |-------------------|------|
  | Checksum de PDF ou áudio diferente | Re-download dos arquivos + sync de Q&As |
  | Apenas título diferente | `UPDATE lessons SET title = ?` sem re-download |
  | Apenas `question_count` diferente | Sync de Q&As sem re-download |
  | Título **e** Q&As diferentes | Ambas as ações acima (independentes) |

- **Sync de Q&As:** Após salvar cada lição, `ContentSyncService` chama `ReviewRepositoryImpl.upsertCards()` com as Q&As do manifest (insert-only, preserva progresso Leitner existente). Q&As removidas do manifest são deletadas via `deleteCardsForQuestionIds()`.
  - **O sync NÃO altera `review_active`** — o toggle de revisão por lição é escolha exclusivamente do usuário. Lições novas ficam com toggle **desligado por padrão** até o usuário ativar manualmente.
  - **Por quê:** Ativar revisão automaticamente forçava o usuário a estudar todas as lições sincronizadas, sem controle. A ativação manual preserva a autonomia do usuário.

- **`ReviewRepository`** — interface abstrata + `ReviewRepositoryImpl`:
  | Método | O que faz |
  |--------|-----------|
  | `upsertCards(flashcards)` | Insere novas Q&As em `card_progress` com bucket=1; nunca sobrescreve existentes |
  | `recordAnswer(questionId, correct, answeredAt?)` | Avança/reseta bucket Leitner; calcula `next_review_at` |
  | `getDueCards(lessonIds, today?)` | Retorna cards com `next_review_at <= today` das lições passadas; popula `questionText`/`answerText` |
  | `deleteCardsForQuestionIds(ids)` | Remove cards do `card_progress` |
  | `isReviewActive(lessonId)` | Retorna `true` se há linha em `review_active` com `active=1`; retorna `false` se linha ausente |
  | `setReviewActive(lessonId, active)` | Upsert em `review_active` com `ConflictAlgorithm.replace`. Quando `active=true`, também reseta todos os cards da lição em `card_progress` para bucket=1, `last_reviewed_at=null`, `next_review_at=now` — mecanismo de "recomeçar do zero" via toggle |
  | `activateReviewIfNew(lessonId)` | Insert em `review_active` com `active=1` e `ConflictAlgorithm.ignore` — usado apenas onde se quer ativar sem sobrescrever escolha existente. **Não é chamado pelo sync.** |
  | `getActiveLessonIds()` | Retorna lesson_ids com `active=1` |
  | `resetAllProgress()` | Zera buckets de todos os cards; não altera `review_active` |
  | `advanceOneDayForTesting()` | Subtrai 1 dia de cada `next_review_at` em `card_progress`, tornando os cards de amanhã devidos hoje. **Dev/test only** — chamado via menu de debug oculto na UI (`MainScaffold`). Parte da interface abstrata `ReviewRepository`. |

- **Tabela `review_active` — semântica de ausência:**
  - Linha ausente = toggle desligado (`isReviewActive` retorna `false`)
  - `active = 0` = toggle explicitamente desligado pelo usuário
  - `active = 1` = toggle ligado pelo usuário
  - O sync nunca insere nessa tabela — é território exclusivo do usuário

- **Algoritmo Leitner:** 5 buckets. Intervalo de dias por bucket: 1→1d, 2→2d, 3→4d, 4→8d, 5→16d. Resposta correta: bucket+1 (max 5). Resposta errada: bucket=1. Novos cards entram em bucket=1 com `next_review_at = today`.
- **Progresso local:** `card_progress` nunca é sincronizado com o backend — permanece local ao dispositivo.

- **Sync de conteúdos:** Após o sync de lessons, `ContentSyncService` sincroniza `contents[]` do manifest:
  - Remove conteúdos locais cujos IDs não estão no manifest
  - Upsert de cada conteúdo com `ConflictAlgorithm.replace`
  - **Sem download de arquivo** — conteúdo VIDEO tem só `youtubeUrl`; conteúdo TEXT tem HTML inline no manifest
  - Mecanismo de publish: presença no `contents[]` = publicado, ausência = despublicado (sem campo `published`)

- **ContentRepository** — implementação direta em `data/`, sem interface abstrata. Métodos:
  | Método | O que faz |
  |--------|-----------|
  | `loadLessons()` | Retorna todas as lições da tabela `lessons`, ordenadas por `id ASC` |
  | `loadLessonsWithAudio()` | Retorna lições com `audio_local_path IS NOT NULL` (usada nas telas de Músicas e Favoritos) |
  | `loadContents()` | Retorna todos os conteúdos da tabela `contents`, ordenados por `id ASC` |
  | `loadContentBySlug(slug)` | Busca conteúdo por `slug`; retorna `null` se não encontrado |

  O dev usa `loadContentBySlug` para vincular conteúdo hardcoded no app.

- **`\*` Desnormalização em `card_progress`:** `question_text` e `answer_text` são cópias desnormalizadas do texto da Q&A. Escritas em `upsertCards()` e lidas diretamente por `getDueCards()` — sem join a nenhuma outra tabela. Simplifica queries de revisão ao custo de duplicar texto que também existe no manifest.

- **Files no filesystem:** PDFs e áudios são salvos em `getApplicationDocumentsDirectory()/betelapp/lessons/{id}/lesson.pdf` e `.../audio.{ext}`.
- **DB armazena só paths e checksums** — conteúdo binário nunca fica no SQLite.

### Testes

- **Mockito** com `@GenerateMocks` / `@GenerateNiceMocks` + `build_runner`.
- **SQLite em memória** via `sqflite_common_ffi` com `databaseFactoryFfi` — testes rodam queries reais sem platform channel.
- **`BehaviorSubject` (rxdart)** para simular streams do audio handler em testes.
- **Platform channel mocking** via `TestDefaultBinaryMessengerBinding` para connectivity.
- **Testes de regressão de áudio** cobrem: shuffle navigation, repeat-all loop-back, repeat-one slider reset, mediaItem stream sync.

### Assets legados

- `assets/data/lessons.json`, `assets/pdf/`, `assets/audio/` — dados estáticos do MVP original antes do sistema de sync. Ainda presentes no bundle mas **não usados em runtime** (o app consome apenas do sync).

## O que NÃO fazer

- **Não usar SharedPreferences** — SQLite é o storage unificado. O guidelines/4-technical-details.md menciona SharedPreferences mas a implementação real migrou inteiramente para SQLite.
- **Não alterar o schema do SQLite sem incrementar a version** — migrações dependem do version number em `DatabaseHelper`.
- **`Song.durationIds` não é consumido** — o campo existe no modelo (`json_serializable`) e é quase certamente um typo de `durationInSeconds`, mas nunca é lido em runtime. Todos os call sites constroem `Song` com `durationIds: 0`. A duração real vem do `durationStream` do `just_audio` via `BetelAudioHandler`. Dívida técnica: o campo pode ser removido sem impacto funcional.
- **Não criar novos models com `json_serializable`** sem decisão explícita de padronização — o projeto está inconsistente entre hand-written e codegen.
- **Não acessar MinIO via HTTPS** sem antes configurar o certificado — a base URL é HTTP intencional.
- **Não implementar retry/interceptors no Dio** sem considerar o impacto no sync (o sync já trata falha com fallback silencioso para offline).
