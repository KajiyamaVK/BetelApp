# Gemini Instructions

This file contains instructions for the Gemini CLI agent to follow when working on this project.

## Spec-Driven Development

**At the start of every session:** Read `docs/specs-index.md` to identify which specs are relevant to the task at hand, then read those specs before writing any code.

**During work:**
- If an implementation decision conflicts with a spec, signal it explicitly before proceeding — never resolve silently.
- If a spec is missing or outdated for the area being changed, note it.
- If a gap, TODO, or technical debt is identified, check GitHub issues (`gh issue list`) before flagging it. If no issue covers it, suggest creating one — all tracked work lives in GitHub Issues.

**At the end of every session:** Suggest updates to any specs impacted by the work done in that session.

Spec files live alongside their subproject code:
- `docs/specs/` — infra.md (infraestrutura compartilhada)
- `src/mobile/specs/` — ui.md, business.md, data.md, infra.md
- `src/s3-ui/specs/` — ui.md, business.md, data.md, infra.md
- `src/backend/specs/` — ui.md, business.md, data.md, infra.md

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
