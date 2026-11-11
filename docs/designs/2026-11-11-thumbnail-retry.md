# Thumbnail failure recovery and Retry hit testing

Source baseline: `22348b2fb20049088705ce38f5b261e191b148af`.
User report: fast Gelbooru scrolling leaves many tiles at Retry; tapping Retry opens the Post, and returning lets thumbnails load. No device reproduction or captured HTTP failure was available in this investigation.

## Confirmed source defects and evidence

1. [ImageGridItem._buildImage](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/posts/post/src/widgets/image_grid_item.dart) places the image first in a Stack, then a full-size Material/InkWell with the Post-opening callback. The Retry control is inside the image below that hit-test surface. This directly explains why the visible button opens the Post instead of retrying. It is a shared-grid defect, not a Gelbooru-only button implementation.
2. [BooruRawImage](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/images/booru_image.dart) already supplies an owned ExtendedImageController, cache clearing and ImageRetryButton. Reuse these rather than adding another retry implementation.
3. [FetchStrategyBuilder](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/packages/retriable/lib/src/fetch_strategy.dart) defaults to five attempts, a 30-second attempt timeout and a one-minute total budget. BooruImage overrides the initial backoff to 500 ms. Its default transient statuses include 408 and selected 5xx responses, but not 429. Retry-After participates in the delay only after the failure passes retry eligibility.
4. [DioExtendedNetworkImageProvider._loadNetwork](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/packages/extended_image/lib/src/dio_extended_image_provider.dart) catches errors and returns null; the outer loader turns that into a generic StateError. This loses HTTP/cancellation classification. [ExtendedImage](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/packages/extended_image/lib/src/extended_image.dart) distinguishes cancelled from failed, but cannot do so when the original error is erased.

The cause of the initial network failures is NOT established: CDN throttling, timeouts, transport cancellation and stream/cache lifecycle need distinguishing evidence. ScrollAwareImageProvider deliberately defers loading while scrolling fast; deferral alone should not display Retry. Opening a Post may populate the cache or trigger dependency/stream resolution, so successful loading after Back is not proof of any one cause.

## Proposed correction

Move ordinary tile activation to an ancestor of image content (or otherwise keep explicit image controls above the tap surface), so a child Retry button wins hit testing. Preserve splash appearance, quick actions, metadata IgnorePointer behavior, selection, long-press and context menus. Do not simply disable all Post navigation when an image fails.

Retain typed transport failures through the image provider. Cancellation due to loss of demand must not become a persistent failed tile. A still-visible tile whose cancelled/deferred load has no active attempt must resume when eligible; do not immediately restart offscreen work or revive stale profile/access requests.

For genuine transient image failures, use one bounded retry owner with host-wide cooldown and Retry-After support. Include 429 for this safe media GET path; do not broaden mutation replay. After a bounded recovery budget, show a working explicit Retry. Avoid unlimited retry-on-build loops, synchronous retry storms and retrying 401/403/404 as though they were transient. The existing API quota coordinator and media requests are separate concerns; verify media scheduling before sharing their budgets.

A manual Retry should reset only the failed rendition's relevant cache/stream state, obtain a fresh request, show loading and stay on the timeline. Do not clear all image caches or require Viewer navigation.

## Verification design

Use a fake transport and a production-composition grid widget test, not only a standalone Retry button test:

- Initial thumbnail failure -> tap the actual Retry text -> exactly one new eligible load, zero navigation callbacks; successful image appears in the same tile.
- Tap elsewhere on a failed tile -> normal Post navigation remains available.
- 429 + Retry-After -> no request before the cooldown, bounded recovery, no parallel retry storm.
- Timeout/503 -> bounded retries; 403/404 -> no automatic loop.
- Rapid scroll out/in, request coalescing, cancellation and scroll-idle -> visible eligible tiles eventually load without opening a Post.
- Retry while changing profile/route or disposing a tile -> no stale image, credential crossover or post-disposal updates.
- Selection mode, quick actions and fallback thumbnails retain their intended interactions.

Then reproduce fast scrolling on Android with Gelbooru, using sanitized status/failure-class/attempt-count diagnostics. Do not record credentials or sensitive full URLs. Compare one versus two cache viewports only AFTER failure recovery works; increasing prefetch can increase pressure and cannot repair hit testing.

No implementation or runtime verification was performed here.
