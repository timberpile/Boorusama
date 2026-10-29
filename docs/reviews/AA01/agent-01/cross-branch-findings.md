# Cross-branch evidence

Canonical findings and interactions will be documented here after source verification. Do not treat overlapping paths as proof of an integration defect.

## Planned integration comparisons

- #113 shared pagination semantics consumed by #117 Favorites.
- #117 and #118 both touch Pixiv client part declarations and authenticated request options; integration must preserve both, without duplicating shared methods.
- #114 and #116 both affect toolbar/follow UX but have independent branches and later integration dependencies.

## AA01-A01-F0001 — Pixiv Favorites inherits Grid continuation defect

- **Kind / severity / confidence / lifecycle:** defect / medium / static-confirmed / open in the #117 branch; fixed only in the independent #113 branch (not yet integrated).
- **Affected:** #117 T004; correction prepared by #113 T001.
- **Origin:** inherited from `develop`, not introduced by #117.
- **Reviewed head/base:** #117 `e2929259b7725c484d11483d6ea48270079eb2f4` / `422aeae087c1108e655d85d1a3dac25120456cd6`; #113 `a1bc1d42903861a46e7230349515946bae678357` / same base.
- **Location:** `lib/core/posts/listing/src/widgets/post_grid_controller.dart` lines 359–373 and 399–411 in #117; `lib/boorus/pixiv/favorites/session.dart` lines 64–75 in #117.
- **Source:** [old Grid continuation at pinned #117 source](https://github.com/timberpile/Boorusama/blob/e2929259b7725c484d11483d6ea48270079eb2f4/lib/core/posts/listing/src/widgets/post_grid_controller.dart#L359-L373), [old Grid next-page condition](https://github.com/timberpile/Boorusama/blob/e2929259b7725c484d11483d6ea48270079eb2f4/lib/core/posts/listing/src/widgets/post_grid_controller.dart#L398-L410), [Pixiv session metadata](https://github.com/timberpile/Boorusama/blob/e2929259b7725c484d11483d6ea48270079eb2f4/lib/boorus/pixiv/favorites/session.dart#L64-L75), [separate #113 correction](https://github.com/timberpile/Boorusama/blob/a1bc1d42903861a46e7230349515946bae678357/lib/core/posts/listing/src/widgets/post_grid_controller.dart#L367-L392).

### Expected versus observed source behavior

The Pixiv session exposes source `hasMore` independently of the number of parsed posts. However the #117 branch's unmodified `PostGridController` sets `_hasMore = newItems.posts.isNotEmpty` on first refresh and subsequent fetches. If the server reports more pages but a page maps to zero valid posts, the grid suppresses the next fetch. Conversely, if the final successful source page has posts and `hasMore=false`, the grid displays a redundant load-more action.

### Trigger and reachable failure path

`PixivFavoritesPage` → `PostScope(fetcher: session.getPosts)` → `PixivFavoritesSession._fetch` → `PostResult(posts: illustDtosToPosts(...), hasMore: result.hasMore)` → `PostGridController._performRefresh/fetchMore` ignores `hasMore`. `illustDtoToPosts` can return no posts for invisible/muted/missing-original entries even when the source cursor still exists. Thus both cases are statically reachable.

### Evidence and safeguards checked

The #117 source has no branch-local #113 controller changes; source parser explicitly drops some illusts, and a session test includes a filtered nonterminal first page. The #113 branch honors the metadata. This finding is **not** a claim of observed live Pixiv reproduction or a failure introduced by #117.

### Root cause and practical impact

Generic Grid pagination consumes only raw parsed post-list nonemptiness rather than the source continuation contract. On inherited source this makes an eligible Favorites list appear empty or prematurely finished, or require a useless final load-more.

### Minimal recommended correction

Integrate/merge the scoped #113 Grid fix into the combined candidate in approved workflow (without silently cherry-picking unrelated branch contents), preserve explicit `hasMore` before `maxPage` and `total`, and test with empty intermediate and full final source pages. Do not change Pixiv-specific cursor validation to conceal the Grid defect.

### Suggested local verification and regression checks

Focused Grid controller exhaustion tests; Pixiv favorites session/provider/view tests with empty-but-continuing and nonempty-but-terminal pages; final candidate device pagination and profile/privacy selection; full integration regression.

### Assumptions and remaining uncertainty

Assumes Pixiv can yield a page with zero *presentable* artworks due to documented parser rejection/filter behavior; the generic bug itself is statically proven regardless of live prevalence. Real API behavior and prevalence remain unverified.

### History

- 2026-10-29 cycle 1: identified inherited impact at pinned #117 head and confirmed independent correction at #113 head. Open until integrated and retested.

## AA01-A01-F0008 — Refresh can process stale cancelled fetchMore and corrupt the Grid page

- **Kind / severity / confidence / lifecycle:** risk / medium / high-confidence / open.
- **Affected:** #117 T004 (Pixiv Favorites); #113 T001 (generic Grid lifecycle fix boundary).
- **Origin:** inherited preexisting Grid concurrency race, made particularly reachable by #117's intentional cancellation of its old cursor session during refresh; not an error introduced by the Pixiv endpoint itself.
- **Reviewed heads/base:** #117 `e2929259b7725c484d11483d6ea48270079eb2f4`, #113 `a1bc1d42903861a46e7230349515946bae678357`, common base `422aeae087c1108e655d85d1a3dac25120456cd6`.
- **Location:** `lib/core/posts/listing/src/widgets/post_grid_controller.dart` lines 279–320, 341–376, 381–425 in #117; `lib/boorus/pixiv/favorites/session.dart` lines 33–75; `lib/core/posts/listing/src/_internal/raw_post_grid.dart` lines 284–297.
- **Sources:** [Grid concurrent refresh](https://github.com/timberpile/Boorusama/blob/e2929259b7725c484d11483d6ea48270079eb2f4/lib/core/posts/listing/src/widgets/post_grid_controller.dart#L341-L375), [Grid stale rollback/error](https://github.com/timberpile/Boorusama/blob/e2929259b7725c484d11483d6ea48270079eb2f4/lib/core/posts/listing/src/widgets/post_grid_controller.dart#L381-L425), [Pixiv session cancel-on-refresh](https://github.com/timberpile/Boorusama/blob/e2929259b7725c484d11483d6ea48270079eb2f4/lib/boorus/pixiv/favorites/session.dart#L33-L75), [pull-to-refresh trigger](https://github.com/timberpile/Boorusama/blob/e2929259b7725c484d11483d6ea48270079eb2f4/lib/core/posts/listing/src/_internal/raw_post_grid.dart#L284-L297).

### Expected versus observed source behavior

A refresh should replace previous results and restore page 1 without stale page-2 failure messages. `PostGridController.refresh` does not prevent an in-flight `fetchMore` and synchronously sets `_page=1`. `PixivFavoritesSession._fetch(1)` then cancels the old session token to prevent stale results. A pending page-2 `getPosts` may resolve to `RequestCancelledError`. The old `fetchMore` handler still executes `if(errors.value != null) _setPage(_page - 1)` against *the shared mutable current page*; if refresh has set page 1, this rolls back to page **0**, not to the page associated with the cancelled fetch. It can also assign stale `errors.value` and suppress the functional header or confuse continuation.

### Trigger / safeguards checked

Initiate page 2, keep its network future pending, then trigger refresh from the grid (e.g. pull-to-refresh or another refresh action). Refresh resets the Grid page and cancels the cursor fetch before new page-1 response is processed. There is no request generation/page identity check in old `fetchMore`; Grid `_refreshPending` guards only queued refreshes, not page fetches. The separate #113 fix still has the same relative rollback and error-notifier paths.

### Root cause / impact

Concurrency ownership is tracked separately for refresh and load-more but page/error state is shared. A stale completion rolls back the latest page rather than its captured page and may surface a misleading cancellation error. It can cause a duplicated first-page request, page-0 state and interrupted pagination after otherwise successful refresh. Interleaving and user-visible outcome require a controlled runtime test, so the confidence is high rather than claiming device reproduction.

### Minimal recommended correction

Coordinate refresh/fetch-more via a generation/request identity (or cancellation-aware stale completion suppression). Do not decrement shared `_page` if the fetch belongs to an obsolete generation or page; suppress expected cancellation errors and keep the refreshed source state. Preserve Pixiv session cancellation and source/profile isolation. Add a gated test around `refresh` during `fetchMore` and repeat with #113 combined, including failure/retry and disposal.

### Remaining uncertainty / history

The described interleaving is reachable by source design, but it has not been executed; actual scheduling depends on Dio/cancel timing and UI gesture ordering. Existing refresh-vs-refresh and fetch-more coalescing tests do not exercise this exact race. Cycle 4, 2026-10-29 — static concurrency risk recorded; open.
