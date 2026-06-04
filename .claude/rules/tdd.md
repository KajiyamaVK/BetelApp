# TDD Rule (non-negotiable)

**Every code change follows Red-Green-Refactor. No exceptions.**

## New features and changes

1. Define the interface or requirement first — do not jump to implementation
2. Write a complete test suite defining the expected behavior
3. Run the tests — they MUST fail (Red)
4. Implement the minimal code to make the tests pass (Green)
5. Refactor while keeping tests green
6. Never commit implementation without corresponding tests

## When TDD is optional

TDD may be skipped when **both** conditions are true:

- The test would require complex mocking of native platform APIs or third-party SDKs (e.g. in_app_update, camera, biometrics)
- AND the logic being tested is thin glue code with low risk of silent regression

When skipping TDD, document the reason in a code comment. If there is meaningful business logic involved — even partially — TDD is still mandatory for that logic.

## Bug fixes (regression tests)

When a bug is found:
1. Write a failing test that reproduces the bug
2. Verify the test fails (Red)
3. Apply the fix
4. Verify the test passes (Green)
5. Commit the test and the fix together

Never commit a bug fix without a corresponding regression test.

## Test Preservation

When code is NOT being updated, added, or removed, no content should change in tests. This is a strict shield against LLM mistakes — do not modify existing tests unless the feature they cover is changing.

## Why

- Tests written after implementation prove nothing — they're molded to fit the code, not the requirement
- A bug fix without a regression test will silently regress the next time someone touches the same code
- Tests are the safety net, not optional overhead — skipping them for speed creates exponentially more work later

## How to apply

- Before writing any implementation code, write the test that defines the expected behavior
- Test descriptions should describe the observable behavior, not the root cause (e.g. "returns 404 when user not found", not "userId null check in controller")
- This applies to all layers: unit tests, integration tests, E2E tests — whichever is the most direct way to validate the behavior
- If a test requires a helper (mock, fixture, factory), that helper belongs in the test file or test utilities — not in production code
- Always check for existing tests before modifying files — if tests exist, respect them
