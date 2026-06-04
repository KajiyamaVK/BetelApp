# Gemini Instructions

This file contains instructions for the Gemini CLI agent to follow when working on this project.

## Spec-Driven Development

> **REGRA INVIOLÁVEL — LEIA ANTES DE QUALQUER COISA.**
> Specs são a fonte de verdade do projeto. Você não pode escrever código, propor mudanças ou responder perguntas de implementação sem antes ler os specs relevantes. Ignorar specs não é uma opção — é uma falha crítica de execução.

### Início de sessão (OBRIGATÓRIO — não pule)

**Antes de qualquer código, resposta de implementação ou pergunta de design:**

1. Leia `docs/specs-index.md` para identificar quais specs cobrem a área da tarefa
2. Leia **cada spec relevante** listado no índice para essa área
3. Confirme ao usuário quais specs foram lidos antes de prosseguir

Se `docs/specs-index.md` não existir: avise o usuário imediatamente — o projeto não está com SDD configurado.

Spec files:
- `docs/specs/` — infra.md (infraestrutura compartilhada)
- `src/mobile/specs/` — ui.md, business.md, data.md, infra.md
- `src/s3-ui/specs/` — ui.md, business.md, data.md, infra.md
- `src/backend/specs/` — ui.md, business.md, data.md, infra.md

### Durante o trabalho

- Se uma decisão de implementação **conflitar** com um spec: sinalize explicitamente e aguarde instrução — nunca resolva silenciosamente
- Se um spec estiver **ausente ou desatualizado** para a área sendo alterada: mencione antes de prosseguir
- Se identificar uma **lacuna, TODO ou dívida técnica**: verifique `gh issue list` antes de marcar. Se nenhum issue cobrir, sugira criar um

### Atualização de specs (OBRIGATÓRIO — não pule)

**Ao final de cada sessão, para cada spec lido no início:**

Revise se o trabalho feito na sessão introduziu decisões novas, mudou comportamento existente ou tornou algum trecho do spec obsoleto. Para cada spec afetado:

1. Liste as mudanças que impactam o spec
2. Proponha o texto atualizado ou o novo bloco a adicionar
3. Peça confirmação ao usuário antes de escrever

**Critérios para atualização:**
- Nova decisão técnica tomada (biblioteca, padrão, abordagem)
- Comportamento existente modificado (fluxo, validação, regra de negócio)
- Campo ou modelo de dados adicionado/removido/renomeado
- Infra alterada (Dockerfile, env vars, deploy, CI)
- Trecho do spec que descrevia algo que deixou de existir

Se nenhum spec precisar de atualização: diga explicitamente "nenhum spec foi impactado por esta sessão" — não fique em silêncio.

## Instructions

- **Update Documentation**: Every time we add, remove, or update API endpoints or features, update `README.md` with detailed usage instructions.
- **Test Preservation**: When code is not being updated, added, or removed, no content should change in tests. This is a strict shield against LLM mistakes; do not modify existing tests unless the feature they cover is changing.
- **Strict TDD**: Always start by developing tests first (TDD). Run tests -> Fail -> Build solution to pass.
- **Consult Guidelines**: Always consult the `guidelines/` directory for detailed context, screen designs (in `0-screens-designs`), and data structures (`5-data-layer.md`). These guidelines are the source of truth for the app's design and architecture.
- **Design Compliance**: All screen design images are located in the `guidelines/0-screens-designs` directory. It is mandatory to follow these designs strictly, including colors and components, although text and labels may change in the future.

## Vibe Coding & TDD Workflow

We follow "Vibe Coding" principles where the AI acts as an Orchestrator and TDD is the safety net.

### The Workflow

1. **Define Intent (The Blueprint)**
   - Define the interface or requirement first. Do not jump to code.
   - Example: "Define a TypeScript interface for a service that handles..."

2. **Generate Tests First (The Contract)**
   - Write or update a complete test suite defining the expected behavior.
   - Do NOT implement the service yet (or if backfilling, verify behavior).
   - The test suite is the "Contract" that defines success.

3. **The Red-to-Green "Vibe"**
   - Run the tests. Failures reveal the gap.
   - Implement the service/controller to make these specific tests pass.
   - Do not write bloat; only fulfill the contract.

4. **Shadow Technical Debt Prevention**
   - Always check for existing tests before searching for files.
   - Never skip tests for speed.

### When TDD is optional

TDD may be skipped when **both** conditions are true:
1. The test would require complex mocking of native platform APIs or third-party SDKs
2. AND the logic is thin glue code with low risk of silent regression

When skipping, document the reason with a code comment. If meaningful business logic is involved, TDD remains mandatory for that logic.

## Project Structure

- **Mobile App**: The source code for the mobile application is located in `src/mobile`. tests related to the mobile app should be run from this directory (e.g., `flutter test` inside `src/mobile`).

## Android Build & Install Notes

### Always install RELEASE builds for manual testing on device

**Never install debug APKs for manual testing.** Debug APKs have no AOT compilation, which triggers Samsung's background JIT optimizer (`dex2oat` via `IpmAdcpController`/`adcp`) on first launch. This grabs system resources mid-startup and causes a permanent black screen — the app is running but cannot draw.

Release APKs are pre-compiled (AOT) and do not trigger this optimizer.

**To build and install a release APK:**
```bash
cd src/mobile
flutter build apk --release
adb install build/app/outputs/flutter-apk/app-release.apk
```

The signing key is at `android/key.properties` (credentials in Bitwarden if needed).

### The push hook installs debug — ignore it for device testing

The pre-push hook runs `flutter drive` / integration tests using a debug build. This is fine for CI. For real device testing, always do a manual `flutter build apk --release` + `adb install` afterward.
