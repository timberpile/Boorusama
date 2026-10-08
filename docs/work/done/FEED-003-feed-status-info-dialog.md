# Move Following Feed status into an Info dialog

Priority: Normal
Affected feature: Open Following Feed

## Problem

An open Following Feed currently displays checked-source counts, failures,
rate-limit status and the last-check time above its posts. These maintenance
details distract from browsing; the user wants them available on demand, as
with pinned searches.

## Expected behavior

Move these details into an Info dialog opened through the feed's context menu.

## Acceptance criteria

- [x] The open feed's normal content no longer shows checked-source counts,
  failure summaries, rate-limit details or last-check timestamps.
- [x] An Info action in the feed's context menu opens a dismissible dialog,
  following the pinned-search Info pattern. Keep the existing edit/manage action.
- [x] The dialog shows checked sources out of total, failures, any existing
  rate-limit status, and the existing last-check information, including a clear
  never-checked state. Read current cached state; opening it starts no refresh
  or network request and changes no feed/source state.
- [x] Missing/deleted feeds and empty source collections are handled safely.
  A refresh completing while the dialog is open updates its information.
- [x] Preserve feed browsing, NEW/read semantics and existing refresh behavior.
  Active refresh progress remains available; this moves maintenance details.
- [x] Reuse localized Info/status labels where possible. Verify dialog opening,
  content, dismissal and absence of status text from the normal feed view with
  focused widget tests; check narrow-screen usability.

## Context and authorization

User requested a work item on 2026-10-06. This records the request; it does not
expand the currently active implementation assignment.

- [Pinned-search and feed subsystem](../../pinned_searches.md)
- [Following Feed page](../../../lib/core/search/subscriptions/src/pages/following_feeds_page.dart)

Dependencies: None. Coordinate with FEED-001/FEED-002 if replaying prepared
changes to the same page.

## Implementation

Claimed by Codex on 2026-10-08. Branch: `agent/feed-003-status-info`.
Worktree: `.worktrees/feed-003-status-info`.
Additional scope: last-post metadata, profile-local move actions, Edit label,
and per-source Info showing existing automatic/adaptive refresh timing.

## Completion evidence

Completed locally on 2026-10-08; not integrated or published.

- Feed and opened-feed menus offer Info and Edit; overview also offers
  persisted Move up/down within the owning profile.
- Feed and member cards show localized Last post metadata. Feed timestamps use
  the newest known cached upload/source-preview timestamp, including explicit
  not-checked/no-posts states.
- Feed Info reads and watches cached state: source counts, failures, rate limits,
  oldest successful check and never-checked state. Source links and member menus
  reuse pinned-search Info with the Following Feeds scheduling scope, exposing
  individual automatic/adaptive intervals, next refresh and temporary pauses.
- Opening Info starts no requests or mutations. Existing source NEW/read state,
  browsing and refresh behavior remain intact; active refresh progress is visible.
- Verification: 77 tests passed across `following_feed_info_dialog_test.dart`,
  `following_feed_management_page_test.dart`, `pinned_search_info_dialog_test.dart`
  and `following_feed_test.dart`; an additional member Info interaction test
  passed after its addition (78 tests total).
- Dialog checks include live successful refresh completion, failure/rate-limit
  status, empty/deleted feeds, dismissal, request/state preservation, and 280dp
  width with 2x text and a keyboard inset. Existing pinned Info tests also cover
  narrow layouts in English/German and real automatic refresh outcomes.
- Affected subscriptions code and all changed test files passed Flutter analysis;
  changed Dart files were formatted and `git diff --check` passed.
- No emulator, physical-device, or live-site checks were performed. Automatic
  refresh remains the existing foreground-only policy; no new scheduler or
  per-feed interval was introduced.

## Requested follow-up (2026-10-08)

- Last post now shares the profile-caption row and aligns to its right edge,
  both in the overview and member editor, reusing pinned-search metadata.
- Added manual Refresh to the overview and opened-feed menus. The user selected
  bounded batches of ten. Each batch runs sources sequentially, chooses the
  least recently attempted/checked sources first, and stops at twenty seconds
  or a rate-limit response. Failed attempts rotate out of the next batch.
- Only one manual feed batch can be active; repeated taps share it and other
  feeds are not queued. Existing request coordination/coalescing remains intact.
  Manual refresh works with automatic refresh disabled, leaves adaptive timing
  unchanged, and rechecks current membership before dispatch.
- Final targeted regression run: 86 tests passed across the four original feed/
  pinned Info test files and `manual_feed_refresh_test.dart`. New tests cover
  25 failing sources across successive batches, single-source concurrency,
  duplicate taps, another feed not being queued, site cooldown, deadline,
  feed deletion, manual menu dispatch with automatic refresh disabled, and
  metadata geometry at normal width and 280dp with 2x text.
- Affected code and tests passed Flutter analysis and `git diff --check`.
  No device or live-site testing was performed. Changes remain local.

## Last-refresh card and sorting follow-up (2026-10-08)

- Feed source cards show localized Last refresh below Last post, right-aligned.
  The value is the last successful refresh, with a clear never-checked state;
  failed attempts do not replace a successful timestamp.
- Added persisted Last refresh (oldest first) member sorting: never-checked
  entries first, oldest successful checks next, membership order for ties.
  Membership, source state, and NEW/read semantics remain unchanged.
- 45 targeted tests passed across member sorting, sort persistence, member
  management, manual feed refresh, and feed Info. Coverage includes settings
  recreation, newer failed attempts, timestamp/row geometry, and narrow English/
  German layouts with doubled text and a reachable refresh-sort action.
- Generated i18n for the new English/German labels and formatted changed Dart.
  No device or live-site testing was performed.

## Local integration (2026-10-08)

All approved feed changes and UI skill guidance were squash-integrated into
local `develop` after its GIF export update. Combined-result verification passed:
103 targeted tests across seven feed/member/pinned Info test files, affected-
scope Flutter analysis, skill validation, translation generation, and
`git diff --check`. The approved task diff was checked against the staged tree,
including preservation of the existing develop translation changes.
The ticket remains done. No remote push or publication was performed; device
and live-site checks remain unperformed.
