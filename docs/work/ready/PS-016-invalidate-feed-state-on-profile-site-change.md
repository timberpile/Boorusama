# Invalidate old-site feed state when a profile's site changes

Priority: Normal
Affected feature: Following-feed profile ownership and cached post identity
Review severity: P2

## Problem and reproduction

Ordinary profile updates can change the site's URL while retaining the profile
ID. Feed caches and hidden-source runtime state remain attached to that ID.
The grid can then show old-site thumbnails while opening their numeric post
IDs against the newly configured site.

1. Create and refresh a feed on site A.
2. Edit the same profile to point at another site B using that engine.
3. Open the feed: cached thumbnails from A remain visible.
4. Tap a cached post: its ID is resolved against B, potentially opening an
   unrelated post or failing to load.

## Expected behavior

Feed runtime state must not cross site identities. Define and document whether
feed definitions are retained or removed on a site change; neither choice may
reuse the old site's cached posts or checkpoints for the new site.

## Acceptance criteria

- [ ] A change of portable site URL or engine identity invalidates incompatible
  cached posts, previews, checkpoints, recent identities, and NEW/error state.
- [ ] If source definitions are retained, their first successful refresh on the
  new site establishes a fresh baseline.
- [ ] Refreshes started against the old site cannot repopulate feed state after
  the profile change.
- [ ] Equivalent site identity and ordinary display-name edits preserve usable
  feed state; unrelated profiles remain unaffected.
- [ ] Regression coverage verifies site changes, in-flight refreshes, and
  same-site edits. Validate the profile-edit/feed flow with Maestro on Android.

## Context and review evidence

Reviewed `16b2e4b0f` and follow-ups through `2e5f4ead9` on 2026-09-19.
Confirmed by tracing profile update, feed ownership by profile ID, and cached
post navigation. The full profile-edit reproduction was not run on Android.
Backup profile replacement already compares booru type and portable URL; use
that established identity rule when assessing ordinary profile updates.

- [Profile update](../../../lib/core/configs/manage/src/providers/booru_config_provider.dart)
- [Feed cache model](../../../lib/core/search/subscriptions/src/types/search_following_feed.dart)
- [Cached post navigation](../../../lib/core/search/subscriptions/src/pages/following_feeds_page.dart)
- [Backup profile replacement](../../../lib/core/backups/sources/booru_configs_source.dart)
- [Subsystem documentation](../../pinned_searches.md)

## Dependencies

None. Follow the [development workflow](../../development_workflow.md) when
implementing. This ticket records the finding; no fix has been applied.
