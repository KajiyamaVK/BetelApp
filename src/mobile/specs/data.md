---
layer: data
project: mobile
last_reviewed: 2026-06-05
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

- **Testes usam `ProviderScope.overrides`** para injetar fakes/mocks.

### Persistência local

- **SQLite via sqflite 2.3.0** — único mecanismo de persistência. Sem Hive, sem SharedPreferences, sem Isar.
  - **Por quê:** SQLite suporta queries relacionais (joins favorites + lessons) e é maduro no Flutter. O app não precisa de key-value store simples.

- **DatabaseHelper singleton** — factory constructor com `_instance`/`_database` estáticos.
- **Banco:** `betel.db`, schema version 3.

- **Tabelas:**
  | Tabela | Propósito | Colunas chave |
  |--------|-----------|---------------|
  | `lessons` | Metadata de lições sincronizadas | `id`, `title`, `audio_local_path`, `audio_ext`, `audio_checksum`, `pdf_local_path`, `pdf_checksum`, `synced_at`, `question_count` |
  | `sync_meta` | Controle de versão do manifest | `id=1`, `manifest_version`, `last_sync_at` |
  | `favorites` | Favoritos do usuário | `id` (composite: `type_itemId`), `type`, `item_id`, `added_at` |
  | `lesson_progress` | Progresso de lições (esqueleto, não usado) | `lesson_id`, `is_completed`, `is_locked`, `last_accessed` |
  | `card_progress` | Progresso Leitner por flashcard | `question_id` (PK), `lesson_id`, `bucket` (1-5), `last_reviewed_at`, `next_review_at`, `question_text`, `answer_text` |
  | `review_active` | Toggle de revisão por lição | `lesson_id` (PK), `active` (0/1) |

### Modelos

- **Estratégia mista de serialização:**
  - `Lesson`, `Favorite`, `ContentManifest`, `Flashcard`, `CardProgress` → hand-written `fromMap()`/`toMap()` ou `fromJson()`
  - `Song` → `json_serializable` com `@JsonSerializable()` + `build_runner`
  - **Sem freezed** em nenhum lugar.
  - **Por quê:** O projeto começou hand-written e migrou parcialmente para codegen. Não há decisão explícita de padronizar.

- **`AudioState`** (provider) usa `copyWith` manual (sem freezed).

### Comunicação com backend

- **Dio 5.4.3** — HTTP client para fetch de manifest e download de arquivos.
- **Sem interceptors, sem auth headers, sem retry logic.**
- **Base URL hardcoded:** `http://s3.kajiyama.com.br/betelapp-content` (HTTP, não HTTPS).
  - **Por quê:** MinIO rodando no homelab sem certificado SSL configurado. Dívida técnica.
- **Sem configuração de ambiente** — sem flavors, sem `dart-define`, sem `.env`. Para trocar ambiente, a constante precisa ser alterada no source.

### Repository pattern

- **Parcialmente implementado:**
  - `FavoritesRepository` → interface abstrata em `domain/` + implementação em `data/`
  - `ContentRepository` → implementação direta em `data/`, sem interface abstrata
  - **Por quê:** Somente `FavoritesRepository` foi abstraída porque seus testes precisavam de mocking independente.

### Content sync

- **Manifest-driven:** `RemoteContentService.fetchManifest()` baixa `/manifest.json` do MinIO.
- **Modelo `ContentManifest`:**
  - `version` (int) — comparado com `sync_meta.manifest_version`
  - `updatedAt` (DateTime)
  - `lessons[]` — cada uma com `ManifestLesson` contendo `ManifestFileEntry` (pdf), `ManifestAudioEntry?` (audio), e `List<ManifestQuestion>` (questions, default `[]`)
  - `ManifestQuestion`: `id`, `question` (de `"q"`), `answer` (de `"a"`)
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
  | `setReviewActive(lessonId, active)` | Upsert em `review_active` com `ConflictAlgorithm.replace` |
  | `activateReviewIfNew(lessonId)` | Insert em `review_active` com `active=1` e `ConflictAlgorithm.ignore` — usado apenas onde se quer ativar sem sobrescrever escolha existente. **Não é chamado pelo sync.** |
  | `getActiveLessonIds()` | Retorna lesson_ids com `active=1` |
  | `resetAllProgress()` | Zera buckets de todos os cards; não altera `review_active` |

- **Tabela `review_active` — semântica de ausência:**
  - Linha ausente = toggle desligado (`isReviewActive` retorna `false`)
  - `active = 0` = toggle explicitamente desligado pelo usuário
  - `active = 1` = toggle ligado pelo usuário
  - O sync nunca insere nessa tabela — é território exclusivo do usuário

- **Algoritmo Leitner:** 5 buckets. Intervalo de dias por bucket: 1→1d, 2→2d, 3→4d, 4→8d, 5→16d. Resposta correta: bucket+1 (max 5). Resposta errada: bucket=1. Novos cards entram em bucket=1 com `next_review_at = today`.
- **Progresso local:** `card_progress` nunca é sincronizado com o backend — permanece local ao dispositivo.

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
- **Não confiar que `Song.durationIds` é o nome correto** — provavelmente é typo de `durationInSeconds`. Verificar se o campo é realmente consumido.
- **Não criar novos models com `json_serializable`** sem decisão explícita de padronização — o projeto está inconsistente entre hand-written e codegen.
- **Não acessar MinIO via HTTPS** sem antes configurar o certificado — a base URL é HTTP intencional.
- **Não implementar retry/interceptors no Dio** sem considerar o impacto no sync (o sync já trata falha com fallback silencioso para offline).
