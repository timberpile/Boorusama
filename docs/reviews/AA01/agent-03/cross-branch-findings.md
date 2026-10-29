# Cross-branch findings

### AA01-A03-F0001 — Pixiv Favorites cannot follow an empty nonterminal page without #113

- **Kind / severity / confidence / lifecycle:** defect / **medium** / **static-confirmed** / open
- **Affected issues / branches / targets:** #117 `feature/117-pixiv-favorites` (T004, affected feature), #113 `bug/113-collection-pagination` (T001, separate corrective branch). These are independent heads based on `develop`, not stacked branches.
- **Origin:** pre-existing shared-grid defect exposed by new Pixiv Favorites source; cross-branch integration dependency, *not* proof that #117 introduced the shared controller bug.
- **Reviewed heads / comparison:** #117 `e2929259b7725c484d11483d6ea48270079eb2f4`, #113 `a1bc1d42903861a46e7230349515946bae678357`; develop and merge base `422aeae087c1108e655d85d1a3dac25120456cd6`.
- **Location / precise source:**
  - [#117 session, lines 63–70](https://github.com/timberpile/Boorusama/blob/e2929259b7725c484d11483d6ea48270079eb2f4/lib/boorus/pixiv/favorites/session.dart#L63-L70): publishes filtered post list and the correct `hasMore`.
  - [Pixiv parser, lines 26–43](https://github.com/timberpile/Boorusama/blob/e2929259b7725c484d11483d6ea48270079eb2f4/lib/boorus/pixiv/posts/parser.dart#L26-L43): a hidden or restricted artwork may produce no displayable post.
  - [develop controller, lines 359–373 and 399–409](https://github.com/timberpile/Boorusama/blob/422aeae087c1108e655d85d1a3dac25120456cd6/lib/core/posts/listing/src/widgets/post_grid_controller.dart#L359-L409): uses only `newItems.posts.isNotEmpty` to decide continuation, disregarding `PostResult.hasMore`/maxPage.
  - [#113 controller fix, lines 366–392](https://github.com/timberpile/Boorusama/blob/a1bc1d42903861a46e7230349515946bae678357/lib/core/posts/listing/src/widgets/post_grid_controller.dart#L366-L392): honors explicit continuation metadata before considering raw post count.

#### Expected versus observed source behavior

When a Pixiv bookmarks response returns an empty parsed page of artworks but `next_url` is present, the UI must continue to offer Load More. `PixivFavoritesSession` emits `hasMore: true`; the inherited develop `PostGridController` sets its own `_hasMore` to false because `posts` is empty. Conversely a nonempty final response is reported as having more data and produces redundant Load More.

#### Trigger and reachable failure path

Open shared Favorites for an eligible Pixiv profile (#117) on a combined tree **without the independent #113 controller change**. The first or later bookmark page may contain only Pixiv artworks the parser excludes (`visible: false`, muted or missing original URL). With an actual server cursor, the source still has another page; grid refresh or fetch-more then sets `_hasMore=false` and cannot load it. The path is code-reachable, not runtime-reproduced by this agent.

#### Evidence and safeguards checked

The existing #117 session/package tests assert the correct emitted `hasMore` but do **not** exercise `PostGridController`. The #113 branch independently changes controller handling and adds focused exhaustion tests. Both branches were compared against the same unchanged `develop` head, not tested as a combined candidate.

#### Root cause and practical impact

Continuation semantics are lost at the shared grid adapter boundary. Authenticated Pixiv users may never see later favorites pages, particularly when content is restricted; complete pages can leave a redundant Load More button. No persistent data or remote Pixiv bookmark state is modified.

#### Minimal recommended correction

Integrate/compose the already scoped #113 fix before accepting #117, without duplicating pagination logic in the Pixiv feature. Verify the **combined** final tree against both issues and preserve explicit cursor continuation even after all-local-filtered pages.

#### Suggested local verification and regression checks

Add a combined controller + Pixiv session integration test with (1) empty first source page with a continuation cursor, (2) intermediate page whose rendered posts all disappear, (3) nonempty terminal page, (4) no further request after terminal, and (5) a failed-page retry. Use the FVM SDK, then Android authenticated acceptance.

#### Assumptions and remaining uncertainty

The parser suppression and source cursor are explicit in code; the frequency of these server combinations and exact authenticated Pixiv responses is not established. Source-derived behavior is static-confirmed, device impact not reproduced. Revalidate after merge order/branch-head changes.

#### History

- 2026-10-29T17:42:56.048Z: created after tracing #117 source through the pinned develop grid and comparing #113 independently. Open until a tested combined candidate resolves it.
