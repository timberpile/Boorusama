# Separate feed creation from the follow selector

Priority: Normal
Affected feature: Following Feeds / `feature/17-following-feeds`
Agent/session: Codex `/root`, 2026-09-20
Work branch: `feature/17-following-feeds`

## Problem

The Add to feed selector always shows a feed-name input, even when no feed
exists. Create feed and Done sit beside each other, making the first action
unclear. The input also competes with the existing-feed list.

## Expected behavior

The selector shows existing feed memberships and a Create feed action, with no
name input. Create feed opens a separate dialog containing the name input and
the current source context. Creating a feed follows that source and closes both
dialogs. Cancellation returns to the selector without creating a feed.

## Acceptance criteria

- [x] The selector has no text field in either empty or populated states.
- [x] The empty selector explains why the list is empty and offers Create feed.
- [x] Create feed opens a separate name dialog with the current source visible.
- [x] Successful creation follows the source and closes both dialogs; failure
  keeps the name and shows an error.
- [x] Cancelling creation returns to the selector without changing membership.
- [x] Widget tests and Android Maestro verify the two-dialog flow.

## Context

The existing source entry points and profile-scoped feed model remain in use.
This follows the user's approved UI design in the current conversation.

## Dependencies

None. Follow [development workflow](../../development_workflow.md).

## Completion evidence

- 2026-09-20: `fvm flutter test --no-pub --concurrency=1` passed 1,168 tests;
  focused picker tests passed 3/3.
- `fvm dart analyze` reported no issues, and the prod debug APK built.
- Maestro on `emulator-5554` verified selector without a name input, separate
  creation dialog with source context, Cancel returning to selector, successful
  creation closing both dialogs, and Following badge changing to 1.
- HTML mockup script passed `node --check`.
