# Gemini Instructions

This file contains instructions for the Gemini CLI agent to follow when working on this project.

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
