# Cross-branch findings and integration evidence

No **additional** canonical cross-branch defect is established independently of the per-branch records. Do not count the same defect once for every related branch.

## Confirmed source interaction: #117 Pixiv continuation and #113 grid exhaustion

`AA02-A04-F0005` has its **single canonical record** in [T020](branches/T020.md#finding-aa02-a04-f0005). The reviewed #117 branch's `PixivFavoritesSession` returns `PostResult(posts: [], hasMore: true)` when local Pixiv visibility filtering removes a whole page. Its inherited `PostGridController` uses `newItems.posts.isNotEmpty` instead of the explicit `hasMore`. The independently reviewed #113 branch introduces `_canLoadMore(PostResult)` and prioritizes `hasMore` when supplied, offering a plausible integration correction. **Neither branch is assumed merged with the other; do not mark F0005 resolved until the exact combined code is observed and tested.**

## Integration checks, not demonstrated defects

- #117 and #118 both extend `packages/booru_clients/lib/src/pixiv/pixiv_client.dart` with distinct Dart part files and identical optional request cancellation / redirect controls. Their changes touch the same shared file; preserve both declarations and avoid duplicating function parameters. Same-file edits do not by themselves prove a merge conflict.
- #53 and #76 both affect Realbooru metadata resolution: high quality prefetch may only use verified non-original renditions; unknown original image data requires a separate renderer fallback. Keep exact original URL semantics in storage.
- #104, #106 and #112 share the Viewer, overlay/toast/navigation/toolbar space; Android gesture and keyboard interactions are unverified and must be assessed on a final combined candidate.
- #68, #108, #114 and #116 touch group identity/selection and toolbar affordances. Test account, tiny-display and backup combinations before integration. These are **test requirements**, not separate defect findings.

No other auditors' findings were read or used for these notes. All statements are based on pinned source revisions listed in [inventory](inventory.md).
