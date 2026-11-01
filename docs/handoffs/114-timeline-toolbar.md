# Issue #114 — timeline toolbar local completion

[Current all-branch review](114-all-live-review-2026-10-30.md) supersedes the technical-readiness status below; this record retains its original evidence.

## Branch and boundaries

Continue `feature/114-timeline-toolbar`, based on
`422aeae087c1108e655d85d1a3dac25120456cd6`. Read the current `AGENTS.md`, issue
#114 and applicable repository workflow before changing anything. Inspect the
remote head and issue comments; preserve other agents' work.

The user authorized source implementation and publication to this task branch,
not a merge, PR, release, or issue closure. #115 must not start until #114 is
merged into develop. This branch intentionally contains no #115 search actions,
compact total formatting, or unmerged #113 pagination changes.

## Source implementation

- A measured `TimelineHeaderSliver` uses Flutter's floating header for default
  hide-down/reveal-up behavior and a pinned header for the optional persistent
  mode. Motion follows the existing reduce-animation setting.
- The shared horizontal header retains its post count and fixed trailing menu.
  Its remaining content scrolls horizontally instead of reducing touch targets.
- Blacklist matches add a compact count/action; a Kurumi anchored popup reuses
  existing per-rule controls and their show-all/hide-all operations. Disabling
  all matching rules leaves a zero-hidden action available. The unique active
  tag-rule union determines the count, not the sum of matches.
- Popup content listens to the source controller and preserves the source
  Riverpod container and inherited theme. Changing its scope closes it by key.
  The existing vertical blacklist-only panel stays inline.
- `ImageListingSettings.keepTimelineToolbarVisible` is independently serialized
  and defaults to false globally and in profile settings. The old
  `showPostListConfigHeader` field/key remains readable for old callers/backups
  but no longer hides this functional toolbar and is never treated as a pinning
  preference. The old settings switch now controls the new value.
- The two setting strings use a small `context.t` translation extension with
  English fallback and German text, following the existing fork-local bridge
  pattern. Review whether to move these resources into the normal Slang JSON
  catalog during finalization; do not retain duplicate translation sources.

## Verification performed remotely

The original five modified files were reconstructed from the pinned GitHub
sources and verified against their Git blob SHAs. The final diff was reviewed
for unrelated changes. `git diff --check`, UTF-8/newline checks and relative
path inspection were performed. These are source checks, not Dart compilation.

Four behavior test files were prepared before the source changes. The focused
`fvm flutter test --no-pub` command could not start: `fvm`, Flutter and Dart are
not installed (exit 127). No formatter, analyzer, Flutter test, Android build,
device test, or independent review passed in the remote environment.

## Local completion

Use an isolated worktree for the existing branch. The remote authoring workspace
was a partial source snapshot, not a complete runnable checkout.

1. Resolve dependencies/generated files with the pinned FVM SDK as required.
   Format changed Dart files and analyze their scope. Check exports of
   `SliverFloatingHeader`, `PinnedHeaderSliver` and `AnimationStyle` through the
   existing Kurumi/material bridge on the pinned SDK.
2. Run the focused tests:

   ```bash
   fvm flutter test --no-pub \
     test/core/settings/timeline_toolbar_settings_test.dart \
     test/core/posts/listing/active_blacklist_count_test.dart \
     test/core/posts/listing/timeline_header_sliver_test.dart \
     test/core/posts/listing/timeline_toolbar_widget_test.dart
   ```

3. Run neighboring grid/controller, search-follow and settings/backup tests.
   Audit consumers of `PostListConfigurationHeader`, including the vertical
   blacklist panel, and old tests that intentionally hid the configuration
   header. Update expectations to the new product contract, not by dropping
   coverage.
4. Add/complete an integration test of real blacklist controls inside the open
   popup: overlapping rules, disable one, reveal all, restore rules, new page
   arrives, profile changes, backdrop/back dismissal. Verify actual count and
   filter changes without popup or list-position jumps. Check any URL blacklist
   presentation separately; this change does not alter URL filtering semantics.
5. On Android, test 320/390 logical-pixel widths, enlarged text, light/dark,
   horizontal toolbar scrolling with fixed overflow, downward/upward reversal,
   repeated pin toggles, empty/refresh/error states, selection mode, keyboard,
   paginated mode's horizontal gestures, and nested popup scrolling. Follow
   emulator leases and Maestro instructions. Check that floating headers do not
   overlap the existing floating search/navigation chrome.
6. Before integration, run the complete repository regression suite on the
   final combined candidate as required by AGENTS.md. Record commands, failures,
   skips, exact candidate and remaining manual checks. Prepare a development
   build for Timber's manual review; no public publication is authorized.

The approved HTML mockups were direction references, not verified Flutter UI.
Do not label this task review-ready until local technical checks succeed.
