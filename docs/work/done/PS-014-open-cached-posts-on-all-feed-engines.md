# Open cached feed posts on Shimmie2 and E-shuushuu

Priority: Normal
Affected feature: Following-feed post details and engine integration
Review severity: P2
Agent: `/root/feed_engine_details` (2026-09-20)
Work branch: `feature/17-following-feeds`

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

- [x] Cached Shimmie2 and E-shuushuu posts open native post details successfully.
- [x] Engine-specific detail widgets receive compatible native post objects.
- [x] Deleted, unavailable, or inaccessible posts produce a handled failure.
- [x] Opening the feed itself remains a cache read without scanning its sources.
- [x] Regression coverage exercises both affected engines; validate the
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

## Completion evidence (2026-09-20)

- Shimmie2 resolves IDs through the Danbooru XML API or GraphQL according to
  the active profile and verifies the returned ID. E-shuushuu resolves IDs
  through `/api/v1/images/{id}` and verifies its returned `image_id`. Both
  repositories convert the DTO to their native post type.
- Six focused engine-detail tests passed, covering Shimmie2 REST, GraphQL,
  mismatched GraphQL ID, E-shuushuu, and unavailable responses for both.
  Four feed history tests passed, including cache-only initial loading.
  Existing Shimmie2 client tests passed (five cases); targeted analysis
  reported no issues.
- Live read-only API probes confirmed Shimmie2 `find_posts?id=14126` returned
  matching XML on a public instance and E-shuushuu `/api/v1/images/1`
  returned a matching image object. The E-shuushuu API returned HTTP 500
  for an unavailable ID; the details route handles the repository failure.
- Maestro on Android opened a cached post from a newly created E-shuushuu
  feed and displayed the native image details with its Comments action.
  A Shimmie2 emulator profile was not used; its two API modes were exercised
  with controlled responses in tests.

## Dependencies

None. Follow the [development workflow](../../development_workflow.md) when
implementing.
