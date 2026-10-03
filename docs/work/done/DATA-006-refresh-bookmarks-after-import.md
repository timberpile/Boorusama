# Refresh bookmarks after package import

Priority: High

Affected feature: `feature/backup-sharing-mockup`

Agent/session: Codex `/root`

Work branch: `feature/backup-sharing-mockup`

## Problem

After a successful `.bsexport` import, new or updated bookmark groups may
remain empty or stale until another event reloads the bookmark library. The
reported small update changed a group from two to three bookmarks and still
showed a long delay.

## Expected behavior

Once Import complete is shown, opening a bookmark group immediately shows its
committed membership. The import must not expose partially applied data during
the transaction or incorrectly call a committed import a failure if only the
subsequent UI refresh fails.

## Acceptance criteria

- [x] A newly imported group and its bookmarks appear immediately after
      completion without leaving and reopening the bookmark view.
- [x] Updating a group from two to three bookmarks publishes the new
      membership before completion.
- [x] A refresh failure is clearly distinguished from transaction failure.
- [x] Focused regressions, full Flutter tests, static analysis, and relevant
      Android UI behavior are verified.

## Completion evidence

- Three bookmark refresh regressions and the completion-warning widget test
  passed, including a preloaded two-to-three member update.
- The full Flutter suite passed (1,937 tests); focused Dart analysis found no
  issues and `git diff --check` passed.
- On emulator-5554, the fresh Dev APK imported a bookmark-group copy from a
  clipboard export. The success screen appeared, and its new group immediately
  opened with one bookmark. The live two-to-three update was not reproduced on
  the emulator; that path is covered by the focused repository/provider test.

## Dependencies

The unified `.bsexport` import on this branch.
