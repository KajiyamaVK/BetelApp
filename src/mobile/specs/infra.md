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
- **Gems vendorizados** — `bundle install --local path vendor/bundle`. Gems são copiados do contexto de build, sem download em runtime.
- **Entrypoint:** `bundle exec fastlane` — o container é invocado diretamente com o lane name.

### Signing (Android)

- **`android/key.properties`** — arquivo com credenciais de signing (storePassword, keyPassword, keyAlias, storeFile).
  - ⚠️ **Está commitado no repo com senhas em texto claro.** Em CI, é sobrescrito via Jenkins credentials (`android-key-properties`).

- **`android/app/betelapp.keystore`** — keystore injetado via Jenkins credential binding (`android-keystore`). Nunca commitado.

- **`app/build.gradle.kts`** lê `key.properties` e configura `signingConfigs.create("release")`.
  - `applicationId = "com.kajiyama.betelapp"`
  - `compileSdk`, `minSdk`, `targetSdk`, `versionCode`, `versionName` delegados a `flutter.*` (pubspec.yaml)

### Fastlane

- **Lane único: `internal`** (Android only):
  1. `flutter build appbundle --release` — gera AAB
  2. `upload_to_play_store`: track `internal`, status `completed`, skip metadata/images/screenshots
  - **Por quê:** O app é distribuído via Play Store internal testing. Sem necessidade de tracks adicionais (alpha, beta, production).

- **Credentials:** `PLAY_STORE_JSON_KEY` env var ou fallback `fastlane/play-store-credentials.json` (excluído do git).

- **Sem lane iOS** — o app não é publicado na App Store atualmente.

### Jenkins CI secrets

| Credential ID | Destino | Tipo |
|---------------|---------|------|
| `play-store-credentials-json` | `fastlane/play-store-credentials.json` | File |
| `android-key-properties` | `android/key.properties` | File |
| `android-keystore` | `android/app/betelapp.keystore` | File |

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
- **Atual:** `1.0.9+12`
- **Regra:** Toda mudança em `src/mobile/**` para main deve incrementar `versionCode` — a Play Store rejeita versionCodes repetidos.
- **Detalhado em:** `.claude/rules/mobile-deploy-version-bump.md`

### iOS

- Apenas configs geradas pelo Flutter (`Release.xcconfig`, `Debug.xcconfig` com `#include "Generated.xcconfig"`).
- **Sem signing, provisioning, ou deploy iOS.** Sem lane Fastlane para iOS. Sem App Store Connect.

## O que NÃO fazer

- **Não commitar `betelapp.keystore`** — é injetado via CI credentials. O `key.properties` commitado é um ⚠️ mas é sobrescrito em CI.
- **Não instalar debug APKs para testes manuais** — debug APKs triggeram o otimizador JIT do Samsung e causam tela preta. Sempre `flutter build apk --release`.
- **Não adicionar lanes de produção no Fastlane** sem configurar tracks graduais — atualmente é internal testing only.
- **Não remover o cleanup de secrets (`trap ... EXIT`)** — sem ele, credenciais podem ficar no workspace após falha.
- **Não atualizar NDKs sem verificar** qual versão o Flutter e os plugins exigem — NDK mismatch causa build failures silenciosos.
- **Não alterar `org.gradle.workers.max`** para valores altos sem aumentar a RAM do CI — o build já usa 3G de heap.
