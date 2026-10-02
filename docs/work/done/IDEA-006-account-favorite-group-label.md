# IDEA-006: Account favorite-group wording

Priority: Normal

Affected feature or branch: `fix/account-favorite-group-label`

Agent/session: Codex child agent `/root/implement_06`, 2026-10-02

Work branch: `fix/account-favorite-group-label`

Dependencies: None

## Problem

The Danbooru post action is labeled “Add to favorite group,” which does not
make clear that it adds the post to an account-owned Danbooru group.

## Expected behavior

The action and its selection dialog use account-specific wording through the
existing localized resources. Group selection and mutation behavior remain the
same.

## Acceptance criteria

- The Danbooru action and matching dialog title clearly refer to an account
  favorite group.
- Existing translations continue to provide both message keys.
- Favorite-group selection and add behavior are unchanged.
- A focused regression test covers the visible localized wording.

## Relevant context

- Implementation program: `/tmp/boorusama-ready-implementation-program.md`,
  Task 06.
- The action is used from the Danbooru post context menu.

## Completion evidence

- Updated the existing action and dialog-title wording in all applicable
  translation files; preserved 21 action-key and 18 dialog-title locale
  entries.
- The new widget test failed before the resource edits because the expected
  account wording was absent, then passed after generation.
- Focused action-label and favorite-group tests passed (10 tests) during the
  initial implementation.
- `./gen.sh` completed successfully; Dart formatting and `git diff --check`
  passed.
- `fvm flutter analyze --no-pub` reported 227 info findings, matching the
  stated base count.
- Initial full-suite runs had 23 and 24 failures; the current coordinated final
  gate is recorded below and in `/tmp/boorusama-ready-06-report.md`.
- Review round 1 replaced the synthetic action-label assertion with a widget
  test of `DanbooruMultiSelectionActions`, corrected Russian action wording,
  and preserved the existing dialog-title check. The focused suite now passes
  11 tests; analyzer findings remain at 227. See the report appendix for
  red/green commands and evidence.
- Coordinated final gate: focused tests still pass (11), and analyzer parity is
  still 227 info findings. The full suite did not pass: 1,464 passed and 22
  failed. All 22 failures reported the same Flutter shader-stage mismatch;
  isolated reproduction and the exact log are documented in the report. This
  task remains in `done/` based on its previously verified acceptance criteria,
  not on the failed full-suite gate.
- Retry final gate after Flutter cache cleanup: `fvm flutter clean`, CLI setup
  (`cd packages/boorusama_cli && fvm dart pub get`), and `./gen.sh` completed;
  generation left no tracked drift. With Flutter 3.47.2, exact `fvm flutter
  test` passed all 1,486 tests, including the localized action test. The
  focused action/favorite-group command passed all 11 tests, analyzer remained
  at 227 info findings, and `git diff --check` passed. The earlier shader
  failure did not reproduce after cleanup. Full log:
  `/tmp/boorusama-ready-06-retry-suite.log`.

## Follow-up: multi-select action availability

- Root cause: the Danbooru rating editor was represented by
  `MultiSelectButton.shrink()` while the account profile was loading, errored,
  or lacked contributor-level permissions. The shared overflow bar still
  converted that placeholder into a button with an empty accessibility label.
- The rating editor is reachable for unrestricted Danbooru accounts, so it is
  retained with a localized `post.action.edit_rating` key in all 23 locales.
  Unavailable/loading/error/logged-out paths now contribute no extra action.
- RED/GREEN: the actual Danbooru multi-select widget test first exposed an
  empty-labeled overflow button for an unavailable/member profile; after
  removing the placeholder, the test passed. The French contributor case
  verifies localized action text, and tap tests verify the group-selection
  route for one and two selected posts plus the rating-editor sheet callback.
- `fvm flutter test --no-pub --reporter expanded --timeout 20s test/danbooru_favorite_group_action_label_test.dart test/favorite_groups_test.dart` — 19 passed.
- `fvm flutter test` — all 1,494 tests passed.
- `fvm flutter analyze --no-pub` — 227 info findings, equal to the recorded
  base count; no new info findings remain.
- `fvm flutter build apk --debug --flavor dev --target-platform android-x64` —
  passed. Installed with `adb -s emulator-5564 install -r` to preserve app data.
  Maestro inspection showed the pre-existing active profile was Gelbooru, not
  Danbooru. Per the device-preservation constraint, no profile/credentials
  were changed; Danbooru-specific on-device supported/unsupported menu cases
  were not run. The app was stopped after inspection.
- `git diff --check` — passed.

## Follow-up: toolbar label truncation

- Root cause: once the unavailable rating placeholder was removed, the three
  remaining actions all fit in the fixed-width toolbar slots. The long,
  account-specific favorite-group label was therefore rendered directly as
  “Add to account…” instead of appearing in the overflow menu with its full
  text.
- The account favorite-group action now explicitly stays in the overflow menu,
  while Download and Bookmark remain directly accessible. Its localized label,
  enabled state, and navigation behavior are unchanged.
- A widget regression test covers the 360-pixel phone layout and verifies that
  the full wording appears after opening the overflow menu. Existing tap tests
  continue to verify the group-selection route for one and two selected posts.
- Focused action, dialog, and shared-toolbar tests passed (21 tests).
- Two full-suite runs each passed 1,494 tests and failed only the existing
  timing-sensitive `Session Resume should mark dry run session as pending when
  interrupted` case. Its complete 33-test file passed immediately in
  isolation. Focused analysis reported no issues, and `git diff --check`
  passed.
- Review follow-up: menu-only placement now applies only while the action is
  executable. With no selected posts, the account favorite-group action stays
  directly visible with disabled semantics instead of appearing as an enabled
  no-op in the overflow menu. A focused semantics regression test covers this
  state.
- Narrow-layout review follow-up: adaptive overflow entries now preserve each
  action's enabled state. At 210 pixels, the zero-selection account
  favorite-group action remains visibly disabled, exposes no tap callback, and
  does not close the menu when tapped. Non-empty selections still show the full
  localized label as an enabled overflow action.
