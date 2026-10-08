# Following-feed overview cards

Priority: Normal
Affected feature: Following Feeds
Agent/session: `/root/finish_27_feed_initialization` (2026-10-02)
Work branch: `feature/following-feed-cards`

## Problem

The overview originally used list tiles rather than the pinned-search card structure.
The card implementation is verified below. A follow-up report requires newly
added, never-attempted feed entries to initialize on overview entry and replaces
technical last-checked timestamps with localized relative time.

## Expected behavior and acceptance criteria

- Feed cards show a title, accessible NEW state, overflow menu, and owner caption.
- Up to four newest cached thumbnails retain existing image-quality resolution and owner authentication.
- Empty and never-checked feeds omit previews until cached results exist.
- Opening the overview checks every never-attempted entry across all feeds via
  the existing bounded refresh scheduler and request gate. A persisted success
  or attempt counts as checked; no missing-thumbnail heuristic is used.
- Shared members are attempted once, rebuild/reopen does not duplicate work,
  and individual failures do not prevent other initial entries being attempted.
- Already-attempted entries do not refresh simply because the overview opens.
  Offline/network policy is respected; scheduled-refresh enablement is not
  required for first-time checks.
- Last checked uses localized just-now/minutes/hours/days semantics, including
  older dates and a clear never-checked state.
- Opening, editing, deleting, and rate-limit feedback retain their behavior.
- Narrow layouts and enlarged text remain usable.

## Context and dependencies

- Approved item 27 in `/tmp/boorusama-ready-implementation-program.md`.
- [Feed preview behavior](../done/F-025-feed-overview-previews.md) and [image-quality behavior](../done/PS-029-respect-feed-thumbnail-image-quality.md).
- Reuse existing cached snapshots, resolver, localization, profile ownership,
  refresh coordinator, request scheduling, and rate limits. Only normal read
  requests for initial never-attempted entries are added by the follow-up.
- Feed-editor preview cards are separately tracked; do not implement them here.
- No dependency on another implementation; shared Flutter resource must be coordinated.

## Progress

- Follow-up reopened on 2026-10-02 by `/root/implement_27` at `9de64b384`.
- Coordinator approved persisted-attempt eligibility and bounded all-member
  initialization. Preparing RED tests/docs while the Flutter slot is owned by
  item 18; item 23 is queued ahead. No Flutter/Dart commands until granted.
- Historical completion evidence below covers the original cached-only card
  implementation, not the follow-up requirements; new gates/review are pending.
- Follow-up root cause: the overview never requested first-time checks and the
  only automatic path required scheduled-refresh enablement. The existing feed
  detail Last checked label formatted DateTime directly.
- Corrected the widget harness to seed/preload state in one `tester.runAsync`
  callback and mount the application's foreground lifecycle wrapper. Observed
  all 13 follow-up tests RED for the missing behavior before production edits
  (`/tmp/boorusama-ready-27-followup-red.log`).
- Added overview-triggered, first-attempt-only initialization through the same
  scheduler and request gate. Bounded batches continue with existing spacing;
  foreground/network recovery resumes untouched members, including when
  scheduled refresh is disabled. Checked, attempted, and independent searches
  are excluded. Relative check time reuses localized time resources.
- Focused GREEN: all 84 tests passed across feed initialization, existing feed
  behavior, lifecycle, scheduling, request gate, service, and notifier files
  (`/tmp/boorusama-ready-27-followup-focused.log`). Coordinator's independent
  review, full-suite and emulator follow-up gates remain pending.
- Preserved [the separate feed-editor card task](../done/FEED-001-editor-preview-cards.md)
  in ready; no editor redesign is included.
- Follow-up analyzer baseline remains 227 existing informational findings,
  with no errors, warnings, or touched-file findings
  (`/tmp/boorusama-ready-27-followup-analyze.log`). `git diff --check` passes.
- Final focused repeat after lint fixes also passed all 84 tests, exit 0
  (`/tmp/boorusama-ready-27-followup-final-focused.log`).
- Review round 1 reproduced the queued-discard recovery race in both foreground
  pause and network-loss scenarios: after filling all three shared request slots,
  recovery during batch spacing never checked the untouched member. Both cases
  were observed RED before the fix (`/tmp/boorusama-ready-27-review-round1-red.log`).
- Moved session attempt suppression to the shared gate's permitted-start callback.
  Queued policy discards stay eligible; started checks remain suppressed if their
  result cannot be persisted. Both recovery regressions are GREEN, and all 87
  focused tests pass (`/tmp/boorusama-ready-27-review-round1-focused.log`).
- The initially recorded singular template boundary is resolved by the
  locale-aware formatter polish below.
- Review-fix final initialization repeat passed all 16 tests, exit 0
  (`/tmp/boorusama-ready-27-review-round1-final-focused.log`); touched-file
  analysis reports no issues (`/tmp/boorusama-ready-27-review-round1-analyze.log`).
  Formatting and `git diff --check` pass.
- Relative-time polish reuses `timeago.format` and the locale messages already
  registered by i18n, matching pinned-search cards. English one-minute/hour/day
  and German one-minute behavior was observed RED before replacing the manual
  templates (`/tmp/boorusama-ready-27-timeago-red.log`). TimePulse, the localized
  Last checked wrapper, and Never checked remain in use.
- Formatter polish GREEN: all 49 focused feed/initialization tests passed,
  exit 0 (`/tmp/boorusama-ready-27-timeago-focused.log`), including the formatter's
  a-moment and months conventions as well as singular and German cases.
- Formatter polish touched analysis reports no issues, exit 0
  (`/tmp/boorusama-ready-27-timeago-analyze.log`); formatting and diff checks pass.
- Read workflow, queue, Following Feed documentation, and related completed tasks.
- Fresh-worktree CLI dependencies and `./gen.sh` completed without tracked generated changes.
- RED: focused feed file failed for five expected missing-card/NEW cases; 24 checks passed (`/tmp/boorusama-ready-27-red.log`).
- Replaced overview tiles with pinned-style Card/InkWell layout, visible localized NEW semantics, title/header overflow, existing cached previews, and compact owner caption.
- Preserved opening, editing, delete confirmation, rate-limit feedback, cached decoding, quality resolution, and owner authentication.
- GREEN: all 29 focused tests pass (`/tmp/boorusama-ready-27-green.log`), including four newest cached images for the inactive owning profile, empty/never-checked feeds, NEW/read/navigation, menu operations, and 280px/2x text with NEW and thumbnails. Overview requests remain empty.
- Analyzer: 227 info findings, matching the documented base, with no findings in touched Dart files (`/tmp/boorusama-ready-27-analyze.log`). `git diff --check` passes.

## Completion evidence

- Integrated regression run on `develop`: all 80 focused feed, lifecycle,
  request-gate, scheduler, and service tests passed. Targeted analysis of the
  eight touched Dart files reported no issues. The combined lifecycle behavior
  initializes unchecked feed members while scheduled refresh remains disabled.

- Fresh focused run: all 29 tests passed (`/tmp/boorusama-ready-27-final-focused.log`).
- Isolated full suite: all 1,489 tests passed, exit 0 (`/tmp/boorusama-ready-27-final-full.log`).
- Final analyzer: exactly 227 existing info findings, no errors/warnings or touched-file findings (`/tmp/boorusama-ready-27-final-analyze.log`).
- Independent review `/root/review_27` approved with no Critical/Important findings, as recorded in coordinator history.
- Fresh Dev x64 APK built successfully from production commit `f50c3b066` and installed without clearing data on assigned `emulator-5564`. APK SHA-256: `886dd7567539b78607fa987c67f0a6769789b2dc3d126715aac0bd356366d7d0` (`/tmp/boorusama-ready-27-final-build.log`).
- Maestro verified the live empty overview and its accessibility labels at normal size and 280dp width with 2x text. The device has no existing feeds; coordinator accepted focused widget evidence for populated cards, four cached thumbnails, NEW, owner captions, edit/delete behavior, and never-checked feeds.
- A coordinator-authorized temporary-feed attempt was stopped after automatic approval review rejected query-chip removal as potentially deleting a stored pin. None of the rejected flows ran; no temporary feed, remote follow, account change, or credential access occurred.
- Feed organization file hash remained identical before/after (`6554f6ae6d2d97abfde4cdd1d499f3ad5b5d7d910b4fe27c22cc1ae7ea1391ee`). Existing pins and cat NEW remained visible. The subscription Hive file's physical hash changed after explicit navigation through an already-read pin; the existing mark-read implementation always writes again. Byte-identical subscription-file restoration is not claimed.
- Restored original profile, font scale 1.0, physical 1080x2400 with no override, density 420; stopped the Dev app before device release.
- Verbose native-hook evidence explains the repeated file-modified warning: a cached `libavif` dependency directory is passed as a file URI, causing hooks_runner to classify it as missing and repeatedly invalidate the cache. Tests and APK build succeed; no app source changes were detected. Recorded the tooling constraint in [development workflow](../../development_workflow.md).
- Final `git diff --check` passes. No push, merge, or worktree/branch deletion performed.
