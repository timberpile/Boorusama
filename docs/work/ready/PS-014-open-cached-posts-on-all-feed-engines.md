# Open cached feed posts on Shimmie2 and E-shuushuu

Priority: Normal
Affected feature: Following-feed post details and engine integration
Review severity: P2

## Problem and reproduction

Feeds are enabled for Shimmie2 and E-shuushuu, but tapping a cached thumbnail
always routes through single-post lookup. Both engines currently implement
`fetchSingle` by returning null, so their feed thumbnails cannot open details.

1. Create a feed on a supported Shimmie2 or E-shuushuu profile.
2. Refresh a source that returns posts and open the cached feed.
3. Tap a thumbnail. The single-post route receives no post and displays an
   invalid-post page instead of details.

## Expected behavior

Cached thumbnails open the correct native engine post on every engine that
offers feeds, using the owning profile's authentication and post identity.

## Acceptance criteria

- [ ] Cached Shimmie2 and E-shuushuu posts open native post details successfully.
- [ ] Engine-specific detail widgets receive compatible native post objects.
- [ ] Deleted, unavailable, or inaccessible posts produce a handled failure.
- [ ] Opening the feed itself remains a cache read without scanning its sources.
- [ ] Regression coverage exercises both affected engines; validate the
  user-facing path with Maestro on Android.

## Context and review evidence

Reviewed `16b2e4b0f` and follow-ups through `2e5f4ead9` on 2026-09-19.
Confirmed by tracing the feed action through the single-post route to both
null-returning loaders. These engine-specific failures were not reproduced on
the emulator during review; Android checks covered navigation only.

- [Feed thumbnail action](../../../lib/core/search/subscriptions/src/pages/following_feeds_page.dart)
- [Shimmie2 post repository](../../../lib/boorus/shimmie2/posts/providers.dart)
- [E-shuushuu post repository](../../../lib/boorus/eshuushuu/posts/providers.dart)
- [Single-post route](../../../lib/core/posts/details/src/routes/routes.dart)
- [Subsystem documentation](../../pinned_searches.md)

## Dependencies

None. Follow the [development workflow](../../development_workflow.md) when
implementing. This ticket records the finding; no fix has been applied.
