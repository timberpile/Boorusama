# F-017 Add Following Feeds

- Priority: High
- Feature/branch: Following feeds / `feature/17-following-feeds`
- GitHub issue: [#17](https://github.com/timberpile/Boorusama/issues/17)
- Agent: Codex `/root`

## Problem

Following Feeds must be added as a separate feature on top of Pinned Searches.
The earlier feed prototype is kept only as a starting point on this branch;
its nested navigation, raw query editor, reverse ownership and fixed browsing
limit do not meet the intended behavior.

## Expected behavior

- Feeds have a separate menu entry and an all-profile list with owner captions.
- A user follows a tag, current search, or artist into one or more existing feeds,
  or creates a feed from that starting point. Artist buttons show Follow or
  Following and the number of feeds containing the artist tag.
- Feed records own their search IDs. User pins are separate search records even
  when their queries equal a feed source. Existing feed records migrate safely.
- Feed NEW derives from member searches. Opening a feed marks only its members
  read. Its management view can open and refresh individual searches.
- A feed opens from its recent cache while member refreshes proceed incrementally
  in the foreground. Browsing can load older posts beyond the recent cache.
- The Gelbooru OR batching and OS background service remain separate work.

## Context and dependencies

See `docs/superpowers/specs/2026-09-19-following-feed-redesign-design.md` and
`docs/superpowers/plans/2026-09-19-following-feed-redesign.md`.

## Progress

- Claimed for implementation on 2026-09-19.
- Pinned-search branch was stripped of feed product code and verified separately;
  issue #17 and `feature/17-following-feeds` now hold the feed work.
- Feed records own source IDs, with migration from legacy Hive feed IDs. The
  all-profile page, menu entry, contextual Follow controls, management view and
  session-only older-page browsing are implemented.
- [UI behavior mockup](../../superpowers/mockups/2026-09-20-following-feeds-ui.html)
  shows the separate navigation, follow dialog and management flow.
- Focused repository, feed and backup tests and targeted static analysis pass.
  Android Maestro confirmed the separate menu entry, empty state, search Follow
  dialog, feed creation, Following label and count, owner caption, cached feed
  opening and per-source management controls.
- The short-cache browsing threshold now waits for user scrolling, with a Load
  older posts action when a list is too short to scroll. Android Maestro showed
  50 cached posts on open and 150 after the first scroll on the test feed.
- Review fixes restrict Pinned Searches' Refresh All to independent pins, force
  infinite feed scrolling, preserve an active history view across cache updates,
  expose updated posts on request, and keep failed history cursors retryable.
  Following a source refreshes only that source.
- `./gen.sh`, targeted Dart analysis, `git diff --check`, and the full
  `fvm flutter test --no-pub` suite passed (1,149 tests). The prod-flavor APK
  built and installed on the Android emulator. Maestro also opened the feed
  picker from a tag context menu and verified the final build's cached feed.
- Open engine-detail and profile-site-change defects are recorded in PS-014 and
  PS-016 and require separate verification before this task can be completed.
