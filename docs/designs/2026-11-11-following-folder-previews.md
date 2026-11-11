# Following folder previews for untracked Topics

Baseline: `22348b2fb20049088705ce38f5b261e191b148af`. Source-confirmed producer/consumer mismatch; no Android reproduction performed.

## Cause

[FollowingTopicPreview](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/search/following_topics/src/widgets/following_topic_preview.dart) recognizes unsupported tracking and watches `untrackedTopicPreviewProvider`. That provider supplies up to four thumbnail URLs independently of tracking state, as required by #65.

[selectFollowingTopicFolderPreviews](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/search/following_topics/src/widgets/following_topic_folder_card.dart) reads only `topic.previews.firstOrNull`. Those stored previews come from tracking. It never reads the untracked preview provider, so fetching images for a Realbooru Topic does not make them available to the parent folder. It also takes at most one image per Topic, leaving a one-Topic folder unable to fill four slots from that Topic's four previews.

The [untracked provider](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/search/following_topics/src/providers/untracked_topic_preview_provider.dart) already has useful safeguards: full profile/query/revision identity, one raw first-page request, shared loader gate, API preload admission, cancellation, five-minute successful caching and a 30-second failure cache. It intentionally does not write checkpoints or unread counters.

## Proposed solution

Extract a small shared effective-Topic-preview provider used by both Topic cards and folder mosaics. It returns stored tracking previews for tracked Topics and the existing untracked result for unsupported Topics, preserving cached fallback/error distinctions. Do not copy these UI-only thumbnails into `FollowingTopic.previews` through a fake tracking success.

For visible folder cards, choose candidate Topics from the correct folder/subtree scope in stable organization order. Fill up to four unique source-scoped previews round-robin: first image of each candidate Topic, then second images if slots remain. This preserves variety while allowing one Realbooru Topic to fill all four positions. Skip missing profiles and empty URLs; do not mix auth contexts or deduplicate solely by numeric Post ID across sites.

Reuse provider identity so opening a folder does not repeat a successful Topic preview request. Bound candidate scanning and concurrent network work; do not subscribe to every Topic in every descendant folder merely to produce four images. Reuse cached/stored previews first and lazily inspect additional candidates within an explicit small request budget. Keep the thumbnail grid's existing dimensions and auth-aware BooruImage rendering.

The folder selector currently iterates `folder.searchIds`; inspect the caller's recursive projection before changing descendant behavior. Define and test the chosen folder/subtree scope consistently rather than accidentally broadening it.

## Verification

Provider/selector tests: an untracked Realbooru Topic fills its parent mosaic; mixed tracked/untracked Topics; one Topic with four images; missing/deleted profile; nested folders; duplicate URLs; provider cache sharing; cancellation/auth changes; failed previews do not alter tracking state or NEW counts. Widget-test the production folder card with provider overrides, followed by a short Android check.

Reuse #65 context rather than reimplementing its loader. No runtime fix was made by this investigation.
