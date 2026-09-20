# Add Following Feeds implementation plan

**Goal:** Make feeds a separate, source-driven feature with feed-owned search
membership, contextual follow actions, and browsable cached history.

**Architecture:** Keep the existing search refresh service and Hive aggregate
for each tracked query. Move membership to `SearchFollowingFeed.sourceIds` and
derive independent-pin visibility from feed membership. Migrate legacy
`feedId` on read. Add a session history controller for older pages.

**Tech stack:** Flutter, Riverpod AsyncNotifier, Hive CE, Slang i18n, widget
tests, Maestro Android UI check.

**Spec:** `docs/superpowers/specs/2026-09-19-following-feed-redesign-design.md`

**Global constraints:** Preserve existing stored feeds and backups; use `fvm`;
no Gelbooru OR adapter or OS background worker; no raw query editor; do not
alter independent pin NEW when viewing a feed.

## Tasks

1. Add tests for feed-owned membership, migration, independent pins, deletion,
   cache updates, and feed NEW. Update model/repository/notifier/selectors and
   make those tests pass.
2. Add the all-profile feed list and menu/desktop route. Remove the entry from
   Pinned Searches. Test owner captions and navigation.
3. Add a reusable contextual follow picker. Connect tag context menus, current
   search, and artist pages. Test membership and label/count behavior.
4. Replace the raw editor with member management, including individual open,
   refresh, and remove. Keep feed read semantics and test them.
5. Add on-demand older-page loading with bounded concurrency and deduplication;
   verify browsing past the persisted recent snapshot.
6. Update architecture docs and HTML UI mockup. Run formatting, generation,
   focused/full tests, analysis, `git diff --check`, and Maestro when available.

## Review focus

Migration safety, profile ownership, user-pin independence, and behavior with
large source counts and overlapping posts.
