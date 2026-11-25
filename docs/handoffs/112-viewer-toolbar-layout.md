# Issue #112 — local completion and manual-review handoff

[Current all-branch review](112-all-live-review-2026-10-30.md) supersedes the technical-readiness status below; this record retains its original evidence.

## Local continuation — 2026-10-29

Prepared for Timber's manual review; acceptance and integration remain pending.

Runtime candidate: **`53c8473902cd583c634a78ca4ba8e7af7f8cf6e2`**.
Continued the existing branch from `c6a0993ea9070cdc97323039f02dea4a0f3938bc`
in its isolated worktree. The pinned base and current fetched `origin/develop`
remain `422aeae087c1108e655d85d1a3dac25120456cd6`. No rebase or develop
integration was needed. All continuation commits are local; no push, PR,
issue closure, release, or branch deletion is authorized or performed.

### Review corrections

- Formatted the implementation and tests with the pinned FVM SDK. Restored
  missing generated localization/booru output using the documented bootstrap;
  no localization inputs, dependencies, or generated runtime contracts changed.
- Fixed the editor's long-press conflict: an IconButton tooltip consumed the
  gesture before its enclosing draggable could start. Editor slots retain
  visible labels and accessibility names without the competing tooltip.
  Selection no longer inserts controls during drag startup.
- Dismiss overflow when action callbacks/presentations change, including loading,
  authorization, and post state changes with unchanged action IDs. Existing
  post/auth keys and the captured source provider scope remain in place.
- Open the editor on the Settings host's application navigator. Android Back
  now returns to Image Viewer settings instead of skipping that destination.
- Retain active vote colors, accessible toggle state, and the existing
  add/remove/disabled behavior in More. Keep editor movement arrows physical
  left/right in RTL, matching the slot row.
- Keep asynchronous favorite feedback attached to the route's Scaffold.

Reviewed the full pinned-base diff and the standard, Danbooru, Moebooru, and
Sankaku callers. All current standard-toolbar favorite callers supply the typed
FavoritePostButton menu presentation; the generic fallback is not needed by a
current engine. Generic adaptive rows and Kurumi remain unchanged.

### Verification

All commands use FVM Flutter 3.47.2 and six detected physical-core workers.

- Focused and nearby consumers: **59 passed**, exit 0, on the final runtime
  candidate. Command: `fvm flutter test --no-pub --concurrency=6` with
  `test/core/settings/viewer_toolbar_{layout,settings,editor,page,backup}_test.dart`,
  `test/core/posts/details/configured_post_toolbar_test.dart`,
  `test/core/posts/details/vote_toolbar_menu_test.dart`,
  `test/application/viewer_toolbar_actions_flow_test.dart`,
  `test/core/posts/post_viewer_original_actions_test.dart`, and
  `test/application/unified_post_actions_flow_test.dart` (expand the brace list).
- `./scripts/run_regression_tests.sh`: **passed, exit 0** on the final runtime
  candidate. Application: **5,528 passed**. All 13 package/CLI suites:
  **1,608 passed**. The vendored go_router suite retains two declared skips:
  `routing config works with shell route` and
  `Obsolete branches in StatefulShellRoute are cleaned up after route
  configuration change`. Both repository shell suites passed, and all **72**
  Python tooling tests passed. No complete suite was skipped.
  The runner emitted Flutter VM finalizer diagnostics and occasional hit-test
  warnings while completing successfully; no blanket warning-free claim is made.
  Runtime, tests, dependencies, and generated runtime inputs remained unchanged
  during this final pass; only this handoff was updated afterward.
- Scoped `fvm flutter analyze --no-pub`: no errors/warnings or findings in changed
  files. Two informational `curly_braces_in_flow_control_structures` findings
  remain in unchanged `simple_post_stats_tile.dart:38` and
  `settings_page.dart:309`. This is not a blanket lint-clean result.
- Changed Dart formatting and `git diff --check`: pass.
- Android device-free QA build: `fvm flutter build apk --debug --flavor dev
  --target-platform android-x64 --no-pub`, exit 0. Installed with `adb install -r`
  on exclusively leased `emulator-5554`, without clearing data. The installed
  APK SHA-256 matches the locally built final candidate:
  `b2f7e6915803859e0348ae77780dc0c5d748a1e87d028f902ce968b8e8a9f9bb`.
  The extra universal review build was stopped at the user's request; no review
  APK delivery is required.
- Maestro exercised Apply, discard/Back, explicit replacement, tap movement,
  all-More, restart persistence, Reset/native fallback, 320/390/440-dp display
  configurations, 200% Android text, and short landscape overflow reachability.
  The final installed candidate repeated Reset and system Back successfully.
  The full Android matrix is not claimed; see the limits below.
- Final process log checks found no matched disposed-state/deactivated-context,
  invalid-ref, or Android fatal signatures. This is a targeted log check.
- Restored the original active profile, native toolbar override, 720x1600/320-dpi
  display, font scale 1.0, automatic rotation 1, and user rotation 0. The emulator
  lease was released. Existing accounts/data were preserved; test searches and
  one thumbnail download were not erased.

### Manual acceptance limits

- The five-action cap, center retention, full-row replacement affordance, and
  edit-strip discoverability remain prototype choices for Timber's review.
  At 320 dp with Android text at 200%, some slot labels truncate; controls
  and the full selected-action label remain available.
- Widget tests exercise long-press dragging; a Maestro slow swipe did not
  establish a successful physical drag. Real finger/assistive-technology and
  hardware-keyboard acceptance remain manual.
- Live Danbooru signed-out overflow opened Share, Bookmark Groups, chosen-quality
  Download, and Comments. A thumbnail download closed both menus. Signed-in
  Danbooru exposed Favorite, Upvote, and Downvote in More, but the attempted
  Favorite action did not establish a confirmed state change. Successful
  favorite/unfavorite and server vote removal are not claimed.
- The generic Safebooru profile returned no posts during its live attempt.
  Moebooru was not configured on the device. The application action harness
  verifies real Download/Bookmark/Share widgets under a different source scope,
  but this is not live mixed-account or Moebooru acceptance.
- RTL, keyboard insets, short menus, and light-theme layout have widget coverage;
  a complete Android locale/theme/account matrix and physical-device acceptance
  remain manual. No CI or remote branch verification is claimed for local fixes.

### Review path

No review APK is requested. Review the branch at the runtime candidate and
use the installed development build for UI inspection if useful. Open Settings
→ Image Viewer → Toolbar / Customize UI. Opening alone keeps native defaults. Try
movement, transfer, replacement, Apply, Back, all-More, and Reset, then open
post details. Reset clears the override and restores the engine's own order.

The original remote handoff below is retained as provenance. Its statements
about unrun tools predate this local continuation; the verification recorded
above and in the final report supersedes them.

---

## Starting point and authorization

- Issue: [Customize Post Viewer Toolbar Layout](https://github.com/timberpile/Boorusama/issues/112).
- Continue **`feature/112-viewer-toolbar-layout`**; do not create a replacement task branch.
- Base: `422aeae087c1108e655d85d1a3dac25120456cd6` (`develop` when work began).
- Implementation commit: **`37514da0128da32ddeda9b5c079d86368b3ea824`**.
- The following handoff-only commit does not change runtime behavior.
- Design contract: [Configurable Post Viewer toolbar](../designs/2026-10-29-viewer-toolbar-layout.md).

The user authorized remote implementation followed by local completion, testing,
and preparation for **manual review**. This is not a merge, PR, production-release,
or public APK-publication request. Do not integrate into `develop`, close #112,
delete the branch, create a PR, or publish a release without the corresponding
approval. Keep unrelated work and other agents' branches intact. Issue #108 and
the other recently created issues are out of scope.

Read the current `AGENTS.md`, applicable `.agents/skills/implement-change/SKILL.md`,
`docs/development_workflow.md`, and `docs/issue_workflow.md` before continuing.
Inspect the latest issue comments and branch head. The remote session
`chatgpt-112-20261029` is releasing its claim for this handoff; add your own concise
claim before making changes. The issue remains open with required technical
verification outstanding, not ready for acceptance/integration.

## What is in the branch

The source implementation is present, but **has not been compiled or run**.

1. `ViewerToolbarLayout` is an immutable model with stable action IDs, JSON
   normalization, explicit slot replacement, and a pure responsive projection.
   It stores separate ordered Toolbar and More lists. Five visible assignments
   are the prototype limit; resizing never rewrites the saved arrangement.
2. `Settings.viewerToolbarLayout` is nullable and global. Missing, malformed,
   and unsupported schemas use the existing engine toolbar. The optional key is
   omitted when unset. `copyWith` supports explicit reset to null. Profile-level
   `ImageViewerSettings`/`ViewerConfigs` deliberately do not contain this value.
3. Image Viewer Settings opens a draft editor outside the profile-settings
   interaction blocker. The editor includes an inert live preview, draggable
   slots and More entries, tap-select move/transfer controls, and an explicit
   replacement chooser when full. Apply persists; Back discards; Reset clears
   the override and closes. A failed write keeps the draft, and a concurrent
   layout replacement is not overwritten.
4. Standard and Danbooru viewer toolbars use `CustomizablePostToolbar`. The null
   preference takes the original `BooruMenuButtonRow` path with original order,
   required flags, and visibility limits. Moebooru already uses the standard
   toolbar. The configured path filters by actions actually supplied by the
   engine, retains the center on narrow widths, and fixes More at the right.
5. Bookmark, Favorite, Share, and Download controls have menu presentations
   using their existing operations. Download retains its quality submenu.
   Danbooru votes have explicit toggle/remove callbacks. Menus capture the
   source provider container, and the toolbar is keyed by post/profile to
   discard stale menus. Generic adaptive rows and Kurumi itself are unchanged.

The editor seed is Comments, Download, Bookmark, Favorite, Share; it is **not**
a new application default. Reset means native engine defaults, not this seed.
Unauthorized or unavailable actions disappear from the runtime projection but
remain in saved preferences. Find on Other Profiles, Settings, and existing
fixed utility entries stay in More. No action discovery/network requests are
added by the editor or layout model.

All current UI labels reuse existing `context.t` translations; move descriptions
use Flutter's `WidgetsLocalizations`. No dependency or generated localization
input was added. The current menu entry is labeled Toolbar with Customize as
its subtitle, rather than adding a new translation key.

## Source map

- Model/persistence: `lib/core/settings/src/types/viewer_toolbar_layout.dart`,
  `settings.dart`.
- Editor: `lib/core/settings/src/pages/viewer_toolbar_layout_page.dart`,
  `widgets/viewer_toolbar_editor.dart`, `widgets/viewer_toolbar_action_labels.dart`,
  and the entry in `pages/image_viewer_page.dart`.
- Rendering: `lib/core/posts/details_parts/src/toolbars/customizable_post_toolbar.dart`.
- Consumers: standard toolbar, common post buttons, Danbooru toolbar, and
  Bookmark/Download/Favorite/Share button widgets.
- Tests: the five files listed in the commands below.

The approved HTML mockup was a chat attachment, not an existing repository file.
The linked design document captures the essential agreed behavior independently
of that attachment. The implementation uses a compact settings page, not the
mockup's desktop demonstration shell; its preview and renderer share code.

## Verification actually performed remotely

- Read the issue, current instructions, relevant settings/action widgets, and
  the existing Kurumi popup/adaptive-row APIs.
- Verified the nine reconstructed original file contents against GitHub blob
  SHAs before editing; retained unrelated source text.
- Checked UTF-8, final newlines, trailing whitespace, and basic delimiter balance
  across the changed Dart files. These are mechanical checks, **not** a Dart
  parser, formatter, analyzer, or test runner.
- Reviewed the source for placement, callback, reset, scope, and lifecycle paths.
  Corrected unsupported popup arguments and added explicit provider-scope
  preservation for overflow menus.
- Matched uploaded file blobs against local prepared content and verified the
  published implementation compare: 20 files, one commit ahead of the pinned
  base, with no unrelated files or protected-branch changes.
- Attempted the focused `fvm flutter test` invocation; it could not start
  because `fvm` is absent (exit 127). Flutter and Dart executables are absent too.

**Not performed:** Dart formatting, Flutter analysis, compilation, execution of
any new or existing Dart test, the full regression suite, Android builds,
Maestro/emulator runs, physical-device checks, and an independent code review.
No passing red/green cycle, build, device behavior, or manual-review readiness is
claimed. The five test files are prepared test cases, not passed tests.

The remote work used a partial source workspace and GitHub Git-object operations,
not a full local Git checkout. Establish/reuse a normal isolated worktree before
continuing; do not treat that partial workspace as a buildable checkout.

## Required local completion

### 1. Establish the worktree and inspect

Fetch `origin/develop` and `origin/feature/112-viewer-toolbar-layout`. Inspect
`git worktree list`, local modifications, and existing branch ownership first.
Reuse the isolated worktree if it exists; otherwise use the repository worktree
helper/procedure to attach this existing branch. Do not overwrite an occupied
checkout or blindly reset the remote branch.

Confirm the implementation commit is in the branch history. Review the diff
against the pinned base, then inspect intervening `develop` changes for conflicts
in settings and post actions. Keep any reconciliation on the task branch and
record a new candidate SHA. Do not merge the task into `develop` as part of this
handoff.

### 2. Format, compile, and run focused tests

Use the pinned FVM SDK and the repository's normal dependency/bootstrap process.
Generate missing outputs only when required by `AGENTS.md`; no new translation
keys require generation in this patch. Run from the task worktree:

```bash
fvm flutter pub get

git diff -z --name-only --diff-filter=ACM \
  422aeae087c1108e655d85d1a3dac25120456cd6 HEAD -- '*.dart' \
  | xargs -0 -r fvm dart format

test_workers="$(python3 scripts/physical_core_count.py)"
fvm flutter test --no-pub "--concurrency=$test_workers" \
  test/core/settings/viewer_toolbar_layout_test.dart \
  test/core/settings/viewer_toolbar_settings_test.dart \
  test/core/settings/viewer_toolbar_editor_test.dart \
  test/core/settings/viewer_toolbar_page_test.dart \
  test/core/posts/details/configured_post_toolbar_test.dart
```

Run Flutter analysis for the affected settings, viewer action, and test scope;
resolve compile errors, lint findings, and test-fixture dependencies. The page
tests use the real SettingsNotifier with an external in-memory repository; keep
that boundary instead of replacing production state logic with a fake notifier.
Do not report the tests as passing until actually executed. Add missing behavior
coverage rather than relying on source-only assertions.

### 3. Review action integration carefully

Review every engine caller of the shared toolbar, not only Danbooru. In particular:

- Exercise every action after placing it in More, including Bookmark loading
  state, favorite/unfavorite, vote removal, Share before viewer media is loaded,
  and Download with a chosen quality. Preserve existing operations and errors.
- Inspect nested-anchor dismissal for Download quality. Selection should execute
  once, close the appropriate menus, and retain a valid source profile/notifier.
- Check popup lifetime when the post, profile, authentication, or available
  actions change. No stale callbacks, detached contexts, or wrong-account writes.
- Check the fallback for a non-FavoritePostButton custom favorite widget; ensure
  the real engine's semantics remain usable in More, not merely a decorative
  icon. Extend explicit menu presentation where an engine requires it.
- The preview is inert and shows a catalog, not current account capabilities.
  Do not trigger remote favorite/vote/download calls from editor interactions.
- Confirm settings export/import actually carries the new field through the
  complete backup flow; model serialization tests alone are not end-to-end proof.

Include nearby consumer tests such as
`test/core/posts/post_viewer_original_actions_test.dart`,
`test/application/unified_post_actions_flow_test.dart`, and relevant bookmark,
sharing, settings, and backup tests. Inspect current paths before running them.

### 4. Exercise Android UI and refine the prototype

Before using an emulator, follow `docs/android_emulator.md` and acquire its
exclusive lease. Prefer Maestro for Android control and real configured services.
Do not wipe existing signed-in data or expose `.test_credentials`. Any clean-data
scenario requires the appropriate agreed test setup.

Verify these observable cases:

- Native default before customization, Apply, Back, Reset, restart persistence,
  legacy/malformed settings import, and settings export/import round trip.
- Global configuration under profiles with custom media/viewer settings.
- Rearrange within both sections, drag between them, explicit replacement when
  full, all-More layout, and tap/keyboard alternatives without dragging.
- 320/390/440-dp widths, enlarged text (including 200%), rotation, short panes,
  keyboard insets, light/dark themes, and RTL. More must stay reachable at right.
- Danbooru signed in/out, a generic supported engine, Moebooru where available,
  and a mixed-source Bookmark viewer whose active global profile differs from
  the displayed post's source. Verify actual target accounts for mutations.
- Resize/capability changes must never rewrite the saved order. Restore hidden
  actions to their saved arrangement when they become available again.
- Every menu action should retain loading, failure and cancellation behavior;
  navigation and popup closing must not leave exceptions or stale controls.

The five-action cap, center retention, long-press drag discovery, full-row
replacement affordance, and horizontally scrollable edit strip are trial UX
choices. Check that dragging toward either end and choosing More entries feel
predictable. Improve these details within the agreed direct-placement design;
do not quietly replace it with a priority list. No actual device acceptance has
been recorded yet.

### 5. Regression and manual-review delivery

Because this change touches shared settings and action widgets, run the complete
local suite after fixes and before presenting an integration-ready candidate:

```bash
./scripts/run_regression_tests.sh
git diff --check
```

That runner includes the application, every package/CLI test suite, and repository
tooling. Inspect failures and skips; record exact commands/results and the checked
commit. Reuse a complete pass only for the same final runtime candidate. Changes
needed to combine with newer `develop` require verification of that new candidate.

Perform an independent focused review if available, fix findings, and rerun the
relevant tests. Build/install the repository's documented development review
artifact using FVM and the correct flavor. Give Timber the actual candidate
commit, artifact location, clear reproduction steps, executed test results,
remaining limitations, and manual checks still needed. Do not claim an artifact
exists until the build succeeded.

Commit scoped completion changes with #112 in the Conventional Commit subject.
Update this handoff with actual local outcomes. When required technical checks
pass, prepare the issue for manual acceptance with a concise comment and the
appropriate workflow status; do not close it or merge without approval. Never
publish credentials, personal payloads, or machine-local paths as shared docs.
