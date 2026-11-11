# Timeline thumbnail prefetch distance

Baseline: `22348b2fb20049088705ce38f5b261e191b148af`.

## Current behavior

The original missing-prefetch request is already covered by completed [#160](https://github.com/timberpile/Boorusama/issues/160), closed on 2026-11-09. [RawPostGrid](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/posts/listing/src/_internal/raw_post_grid.dart) uses `ScrollCacheExtent.viewport(1)` unless a caller explicitly overrides the pixel extent. It measures the actual scroll viewport, not the whole screen. This is shared by ordinary PostGrid consumers, not a Gelbooru-only optimization.

The separate [PostGridPrefetch](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/posts/listing/src/widgets/post_grid_prefetch.dart) requests additional Post pages within two viewports of the end. It checks route/activity/foreground/error/exhaustion and paginated mode, and bounds layout-driven continuation to three dispatched requests per cycle. Do not confuse API page prefetch with image cache extent.

## Recommendation on two thumbnail viewports

Keep one viewport as the baseline until the [new Retry/recovery defect](2026-11-11-thumbnail-retry.md) is corrected. Two viewports is a reasonable experiment, not an established fix. Increasing a symmetric cache range from one to two viewport lengths changes the approximate laid-out band from three to five viewports in a long uniform grid (about 67% more cells, not automatically twice the total memory). Actual image bytes, decode cost and requests depend on grid geometry, cached entries, placeholders and quality.

A larger band may help sustained moderate scrolling on high-latency connections. It can also start more speculative image/placeholder/probe requests and worsen throttling, particularly for Realbooru's alternate image formats. Fast-fling loads can be intentionally deferred by ScrollAwareImageProvider, so cache extent alone does not guarantee all images are ready on landing.

After fixing recovery, trial `ScrollCacheExtent.viewport(2)` in the same shared location with identical content, grid size and quality. Measure visible missing-thumbnail duration after scroll settles, retry/429 counts, total requests/bytes, peak memory and decode/frame costs on an Android device. Cover Gelbooru, Realbooru and Pixiv, cold/warm cache and narrow/landscape layouts. Keep page-prefetch policy unchanged in that comparison. Prefer a single shared constant over a new user setting or site-specific exceptions; adopt two only if the measured benefit justifies its cost.

This report does not reopen #160 or assert that the new failures are caused by too little prefetch. No runtime or device performance measurements were run.
