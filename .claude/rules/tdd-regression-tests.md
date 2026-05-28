# TDD Regression Rule

**Every new bug discovered in production or during manual testing MUST produce a new automated test before — or alongside — its fix.**

## Rule

When a bug is found:
1. Write a failing test that reproduces the bug
2. Verify the test fails (red)
3. Apply the fix
4. Verify the test passes (green)
5. Commit the test and the fix together

Never commit a bug fix without a corresponding regression test.

## Why

Bugs that reach manual testing slipped past the test suite. A fix without a test will regress silently the next time someone touches the same code.

## How to apply

- Before writing any fix code, write the test that would have caught the bug
- The test description should describe the observable failure, not the root cause (e.g. "slider position is preserved during drag even when parent rebuilds", not "ValueKey prevents _isDragging reset")
- If the bug requires a test helper (e.g. `_RebuildableParent`), that helper is part of the regression test file — add it there, not in production code
- This applies to all layers: unit tests, widget tests, integration tests — whichever is the most direct way to reproduce the bug

## Example (from this project)

Bug: audio player slider resets to zero on touch when the music screen rebuilds during playback.  
Root cause: `ConsumerWidget` parent rebuild discards `_isDragging` state when `AudioPlayerWidget` has no stable `Key`.  
Regression test: `_RebuildableParent` helper + "slider position is preserved during drag even when parent rebuilds" test in `test/presentation/widgets/audio_player_widget_test.dart`.
