---
layer: infra
project: mobile
last_reviewed: 2026-05-31
---

## Propósito

Governa decisões de infraestrutura do app mobile — signing, Play Store deploy, CI Docker image, Fastlane, Gradle config, e gerenciamento de credenciais.

## Decisões

### CI Docker image

- **`Dockerfile.ci`** baseado em `ghcr.io/cirruslabs/flutter:latest` — Flutter + Android SDK pré-instalados.
  - **Por quê:** Imagem oficial mantida pela Cirrus Labs, sempre atualizada com a Flutter stable mais recente. Evita gerenciar SDK manualmente.

- **Dois NDKs pré-instalados:**
  | NDK | Razão |
  |-----|-------|
  | `28.2.13676358` | Versão requerida pelo Flutter |
  | `27.0.12077973` | Versão requerida por plugins nativos |
  - **Por quê:** Pré-instalar salva ~3-4 minutos por run de CI (download + install do NDK é lento).

- **Ruby + Bundler** instalados para rodar Fastlane.
- **Gems instalados no image build** — `bundle config set --local path vendor/bundle && bundle install`. A imagem copia `Gemfile`, `Gemfile.lock` e `.bundle/config` antes de rodar `bundle install`, que baixa as gems do rubygems.org durante o `docker build`. Após a imagem criada, não há download em runtime — as gems ficam em `/app/vendor/bundle` dentro do layer da imagem.
- **Placeholder files:** O Dockerfile cria arquivos vazios em `android/key.properties`, `android/app/betelsas.keystore` e `fastlane/play-store-credentials.json` via `RUN touch ...`. Isso é necessário para que os bind-mounts do Docker substituam arquivos (não criem diretórios) quando o container é iniciado com os secrets reais.
- **Entrypoint:** `bundle exec fastlane` — o container é invocado diretamente com o lane name.

### Signing (Android)

- **`android/key.properties`** — arquivo com credenciais de signing (storePassword, keyPassword, keyAlias, storeFile).
  - Excluído do git via `android/.gitignore`. Em CI, é injetado via Jenkins credential binding (`android-key-properties`). Localmente, deve ser criado manualmente antes do primeiro build de release.

- **`android/app/betelsas.keystore`** — keystore injetado via Jenkins credential binding (`android-keystore`). Nunca commitado. O nome `betelsas` reflete o keyAlias, não o nome do app.

- **`app/build.gradle.kts`** lê `key.properties` e configura `signingConfigs.create("release")`.
  - `applicationId = "com.kajiyama.betelapp"`
  - `compileSdk`, `minSdk`, `targetSdk`, `versionCode`, `versionName` delegados a `flutter.*` (pubspec.yaml)

### Fastlane

- **Lane único: `internal`** (Android only):
  1. `sh("flutter build appbundle --release")` — gera AAB em `build/app/outputs/bundle/release/app-release.aab`
  2. `upload_to_play_store`: track `internal`, status `completed`, `aab: "build/app/outputs/bundle/release/app-release.aab"`, `skip_upload_metadata: true`, `skip_upload_images: true`, `skip_upload_screenshots: true`, `skip_upload_changelogs: false`. Changelogs são enviados à Play Store a cada upload — o arquivo `fastlane/metadata/android/pt-BR/changelogs/<versionCode>.txt` deve existir e ser não-vazio (garantido pelo pre-push hook).
  - O path do AAB é passado explicitamente porque `flutter build` é invocado via `sh()`, impedindo a auto-detecção do Fastlane.
  - **Por quê:** O app é distribuído via Play Store internal testing. Sem necessidade de tracks adicionais (alpha, beta, production).

- **Credentials:** `PLAY_STORE_JSON_KEY` env var ou fallback `fastlane/play-store-credentials.json` (excluído do git).

- **Changelog gate (pre-push hook):** O hook `.git/hooks/pre-push` bloqueia push para `main` se o arquivo `fastlane/metadata/android/pt-BR/changelogs/<versionCode>.txt` estiver ausente ou vazio. O versionCode é lido do `pubspec.yaml` em tempo real. Isso garante que cada release tenha um changelog antes de chegar ao CI.
  - Formato: texto pt-BR, máx 500 caracteres (limite da Play Store).
  - Exemplo de path: `fastlane/metadata/android/pt-BR/changelogs/25.txt`

- **Metadata structure:** Apenas changelogs são versionados no repo — `fastlane/metadata/android/pt-BR/changelogs/<versionCode>.txt`. Store listing (título, descrição, screenshots) é gerenciado diretamente na Play Console, não pelo Fastlane (`skip_upload_metadata: true`, `skip_upload_images: true`, `skip_upload_screenshots: true`). Changelogs devem ser escritos em português, máx 500 caracteres.

- **Sem lane iOS** — o app não é publicado na App Store atualmente.

### Jenkins CI secrets

| Credential ID | Destino | Tipo |
|---------------|---------|------|
| `betelapp-play-store-credentials-json` | `fastlane/play-store-credentials.json` | File |
| `android-key-properties` | `android/key.properties` | File |
| `android-keystore` | `android/app/betelsas.keystore` | File |

- **Staging pattern:** Jenkins copia secrets para `src/mobile/.ci-secrets/` (mode 700) com cleanup via `trap 'rm -rf "$STAGE"' EXIT`.
  - **Por quê:** Secrets nunca ficam no workspace após o build — cleanup automático mesmo em caso de falha.

### Gradle

- **JVM args:** `-Xmx3G -XX:MaxMetaspaceSize=1G -XX:ReservedCodeCacheSize=256m -XX:+HeapDumpOnOutOfMemoryError`
  - **Por quê:** O build Android é memory-intensive. 3G de heap evita OOM em máquinas com RAM limitada.

- **Workers:** `org.gradle.workers.max=2` — limita paralelismo para estabilidade.
- **Gradle version:** 8.14 (via `gradle-wrapper.properties`).
- **Cache persistente em CI:** `/var/cache/betelapp/gradle` bind-mounted do host no Docker run.
  - **Por quê:** Cache de Gradle entre builds evita re-download de dependências. ~1-2 minutos economizados por build.

### Integration tests

- **`scripts/run_integration_tests.sh`:**
  - Detecta primeiro device Flutter disponível (ignora web/desktop)
  - `flutter test integration_test -d $DEVICE_ID` com timeout de 180s
  - Timeout (exit 124) tratado como **skip, não falha** — handles Wi-Fi ADB drop
  - **Por quê:** Testes de integração rodam em device real via ADB. Conexão Wi-Fi pode cair durante o teste.

### Versionamento

- **Formato:** `version: <versionName>+<versionCode>` em `pubspec.yaml`
- **Fonte de verdade:** `pubspec.yaml` — o spec não mantém o número atual, pois ele muda a cada release. Consulte `pubspec.yaml` para o valor correto.
- **Regra:** Toda mudança em `src/mobile/**` para main deve incrementar `versionCode` — a Play Store rejeita versionCodes repetidos.
- **Detalhado em:** `.claude/rules/mobile-deploy-version-bump.md`

### iOS

- Apenas configs geradas pelo Flutter (`Release.xcconfig`, `Debug.xcconfig` com `#include "Generated.xcconfig"`).
- **Sem signing, provisioning, ou deploy iOS.** Sem lane Fastlane para iOS. Sem App Store Connect.

### SQLite local database

- **File:** `betel.db` (managed by `sqflite`, stored in the platform databases path).
- **Current schema version:** 5
- **Singleton:** `DatabaseHelper` — manual singleton (not Riverpod-managed). Injected via `databaseHelperProvider` (a Riverpod `Provider`).

- **Tables:**
  | Table | Created in version | Purpose |
  |-------|--------------------|---------|
  | `lesson_progress` | 1 | Lesson completion/lock state (schema only — not yet used in UI) |
  | `favorites` | 1 | User favorites (lessons + songs) |
  | `lessons` | 2 | Synced lesson metadata + file paths + checksums (`audio_checksum`, `pdf_checksum`, `audio_ext`) |
  | `sync_meta` | 2 | Delta-sync cursor (`manifest_version`, `last_sync_at`) |
  | `card_progress` | 3 | Leitner card state per question |
  | `review_active` | 3 | Per-lesson review toggle |
  | `contents` | 4 | Headless CMS content (VIDEO/TEXT) |
  | `contents.pages_html` | 5 | Multi-page HTML support added to contents |

- **Upgrade strategy:** Cumulative `if (oldVersion < N)` guards in `onUpgrade` — each version adds only what is new. No destructive migrations.

- **Testing seam:** `DatabaseHelper.resetForTesting({String? dbPath})` replaces the static singleton and optionally redirects to a test-specific path. Call before each test that touches the database.

- **Por quê:** Using `sqflite` with a manually-managed singleton (rather than a Drift/Isar ORM) keeps the dependency footprint small and keeps migrations explicit and auditable.

### Audio service bootstrap

- **`initAudioService()`** (`lib/core/audio/audio_service_initializer.dart`) é chamado em `main()` **antes de `runApp()`** — deve completar antes da widget tree iniciar.
  - **Por quê:** `audio_service` exige que `AudioService.init()` seja aguardado antes de qualquer método do handler ser chamado. Chamar após `runApp()` cria race condition entre o primeiro frame e a disponibilidade do handler.

- **Provider injection:** O `BetelAudioHandler` resultante é injetado no Riverpod via `betelAudioHandlerProvider.overrideWithValue(audioHandler)` no `ProviderScope` em `main()`.
  - Se este override estiver ausente, qualquer provider ou widget que ler `betelAudioHandlerProvider` lançará `UnimplementedError` em runtime.

- **`AudioServiceConfig` values:**
  | Parameter | Value |
  |-----------|-------|
  | `androidNotificationChannelId` | `com.betelapp.audio` |
  | `androidNotificationChannelName` | `Betel Música` |
  | `androidNotificationOngoing` | `false` |
  | `androidStopForegroundOnPause` | `true` |

### Runtime network status

- **`NetworkStatusNotifier`** (Riverpod `StateNotifier<NetworkStatus>`) — rastreia qualidade da conexão com três estados:
  | State | Meaning |
  |-------|---------|
  | `ok` | API base URL acessível |
  | `serverDown` | Google acessível mas API não |
  | `noInternet` | Nenhum acessível |

- **Detection flow:**
  1. Stream do `connectivity_plus` dispara `check()` imediato quando todas as interfaces reportam `none`.
  2. `_NetworkCheckInterceptor` no Dio compartilhado chama `reportSuccess()` em toda resposta bem-sucedida e `check()` em erros de rede — sem round-trips extras durante operação normal.
  3. Quando status não é `ok`, um `Timer.periodic` de 1 minuto faz polling de ambos os endpoints até restaurar `ok`.

- **API base URL:** constante compile-time via `--dart-define=CONTENT_BASE_URL`; default `http://s3.kajiyama.com.br/betelapp-content`.

- **Provider:** `networkStatusProvider` exposto via `lib/core/providers.dart`. A UI lê este provider para exibir banners offline.

- **Por quê:** Distinguir `serverDown` de `noInternet` permite que a UI mostre mensagens diferentes sem adicionar tratamento de erro per-request em cada view model.

## O que NÃO fazer

- **Não commitar `betelsas.keystore`** — é injetado via CI credentials. `key.properties` é excluído do git via `.gitignore` — não commitar.
- **Não instalar debug APKs para testes manuais** — debug APKs triggeram o otimizador JIT do Samsung e causam tela preta. Sempre `flutter build apk --release`.
- **Não adicionar lanes de produção no Fastlane** sem configurar tracks graduais — atualmente é internal testing only.
- **Não remover o cleanup de secrets (`trap ... EXIT`)** — sem ele, credenciais podem ficar no workspace após falha.
- **Não atualizar NDKs sem verificar** qual versão o Flutter e os plugins exigem — NDK mismatch causa build failures silenciosos.
- **Não alterar `org.gradle.workers.max`** para valores altos sem aumentar a RAM do CI — o build já usa 3G de heap.
