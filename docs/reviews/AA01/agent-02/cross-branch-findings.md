# Cross-branch findings

## AA01-A02-F0002 — Pixiv bookmark continuation lost without #113 grid fix

- **Kind / severity / confidence / lifecycle:** defect / medium / static-confirmed / open until #113 continuation fix is integrated.
- **Affected:** #117 `feature/117-pixiv-favorites` T004, with #113 `bug/113-collection-pagination` T001 as source of the focused remedy. Count this finding once.
- **Origin:** interaction: a new cursor source exposes an inherited GridController exhaustion bug. #113 does not introduce the bug.
- **Source:** #117 `e2929259b7725c484d11483d6ea48270079eb2f4`, #113 `a1bc1d42903861a46e7230349515946bae678357`, comparison/merge base `422aeae087c1108e655d85d1a3dac25120456cd6`.
- **Locations:** [Pixiv session 63–70](https://github.com/timberpile/Boorusama/blob/e2929259b7725c484d11483d6ea48270079eb2f4/lib/boorus/pixiv/favorites/session.dart#L63-L70); [Pixiv parser 26–44](https://github.com/timberpile/Boorusama/blob/e2929259b7725c484d11483d6ea48270079eb2f4/lib/boorus/pixiv/posts/parser.dart#L26-L44); [baseline GridController 359–373 and 399–409](https://github.com/timberpile/Boorusama/blob/e2929259b7725c484d11483d6ea48270079eb2f4/lib/core/posts/listing/src/widgets/post_grid_controller.dart#L359-L409); [#113 remedy](https://github.com/timberpile/Boorusama/blob/a1bc1d42903861a46e7230349515946bae678357/lib/core/posts/listing/src/widgets/post_grid_controller.dart#L381-L392).

### Expected versus observed source behavior

The Pixiv cursor may validly advertise more pages while all artwork in a current page is unavailable/restricted. `illustDtosToPosts` removes invisible or URL-less illusts; thus `PixivFavoritesSession` returns an empty list with `hasMore:true`. The #117 branch inherits `PostGridController` from develop, which ignores explicit `hasMore` and treats an empty parsed page as terminal on refresh and fetchMore. Later bookmarked artworks cannot be reached.

### Trigger and reachable failure path

1. API page contains only hidden/unrenderable illustrations with a valid next cursor. 2. The session advertises continuation yet yields zero post items. 3. The grid assigns `_hasMore = newItems.posts.isNotEmpty`, suppressing next fetch. The same happens on intermediate pages. Source code establishes this conditional failure; authenticated frequency is unknown.

### Evidence and safeguards checked

The #117 session/decoder preserve cursor metadata and are not responsible for the lost flag. In the #113 branch, `_canLoadMore` prioritizes `result.hasMore` and preserves a final nonempty page, addressing the failure. The #113 change has not been integrated into #117, and combined execution was not tested.

### Root cause and practical impact

GridController conflates rendered/filtered items and remote source continuation. Favorites may appear blank/truncated despite existing later items.

### Minimal recommended correction

Integrate #113 before #117, or apply equivalent focused GridController continuation handling in the final combined candidate. Do not compensate with eager cursor walking.

### Suggested local verification and regression checks

With FVM tests and an authorized Pixiv profile, exercise first/intermediate all-filtered pages with next cursors, last nonempty terminal page, retry, view state, profile/private switching and no stale old-account results. Run #113 + #117 suites and final regression.

### Assumptions and remaining uncertainty

Supported by source parser conditions and `PixivBookmarkPage` next cursor contracts; no live response was observed. This is a static-confirmed conditional path, not a measured incidence claim.

### History

Cycle 1 2026-10-29T17:38:27.906Z: opened on #117 source. Keep open until the combined branch contains #113 or equivalent and is reviewed.

## AA01-A02-F0005 — Pixiv media client can attach API bearer to CDN requests

- **Kind/severity/confidence/lifecycle:** risk / high / high-confidence / open.
- **Affected:** #117 T004, #118 T005; origin pre-existing on develop, not created by either target.
- **Pinned source:** #117 e2929259b7725c484d11483d6ea48270079eb2f4, #118 1d02bef637966999fbd0b72ecb9c6f0e1eedce8a, develop 422aeae087c1108e655d85d1a3dac25120456cd6.
- **Locations:** [BooruImage L78-122](https://github.com/timberpile/Boorusama/blob/1d02bef637966999fbd0b72ecb9c6f0e1eedce8a/lib/core/images/booru_image.dart#L78-L122); [dioForWidgetProvider L104-115](https://github.com/timberpile/Boorusama/blob/1d02bef637966999fbd0b72ecb9c6f0e1eedce8a/lib/core/http/client/src/providers/providers.dart#L104-L115); [PixivRepository.dio L93-96](https://github.com/timberpile/Boorusama/blob/1d02bef637966999fbd0b72ecb9c6f0e1eedce8a/lib/boorus/pixiv/pixiv_repository.dart#L93-L96); [PixivAuthInterceptor.onRequest L105-135](https://github.com/timberpile/Boorusama/blob/1d02bef637966999fbd0b72ecb9c6f0e1eedce8a/lib/boorus/pixiv/auth/auth_interceptor.dart#L105-L135); [Bearer setter L264-274](https://github.com/timberpile/Boorusama/blob/1d02bef637966999fbd0b72ecb9c6f0e1eedce8a/lib/boorus/pixiv/auth/auth_interceptor.dart#L264-L274).

### Expected versus observed source behavior

A Pixiv thumbnail request to an image CDN should only need the media Referer, not an app-api access bearer. The new artist card passes pixiv CDN URLs to BooruImage, which selects the engine repository Dio. PixivRepository supplies pixivDioProvider with PixivAuthInterceptor; that interceptor performs token refresh and applies Authorization: Bearer to outgoing requests **without a host/origin test**, including non-app-api media requests. The same pre-existing path serves normal Pixiv grid thumbnails and new #117 Favorites images.

### Trigger and reachable failure path

On a logged-in Pixiv account, render an artist thumbnail hosted on i.pximg.net using BooruImage. The selected Dio has the API auth interceptor, which applies the bearer to requests irrespective of domain. Unnecessary OAuth information can therefore reach the Pixiv-owned CDN or its infrastructure. This does not assert theft by an unrelated third party or actual production token logging.

### Evidence and safeguards checked

Initial image-host validation in #118 restricts to HTTPS pximg.net. PixivDio disables redirects. Explicit media overrides use a separate unauthenticated media Dio. These constrain exfiltration but do not suppress the bearer on ordinary media requests. Source path is high-confidence; no packet/network trace was obtained.

### Root cause and practical impact

API authentication and image transport share the same Dio. Credentials can be transmitted to another service origin and media-only requests can unnecessarily trigger OAuth refresh.

### Minimal recommended correction

Use an unauthenticated Pixiv media Dio with existing Referer, proxy, TLS and caching semantics, or ensure PixivAuthInterceptor only attaches tokens to the exact intended API host. Do not drop auth for actual API calls.

### Suggested local verification and regression checks

With an intercepting adapter, assert app-api requests have Authorization, pximg.net GET requests do not, and image-only loads do not refresh access tokens. Validate both #117/#118, media headers/proxy and existing Pixiv grids. Never log credential values.

### Assumptions and remaining uncertainty

Transport library behavior and CDN observations were not verified live. This is a pre-existing risk revealed by tracing new target paths, not a claim of a new #118 vulnerability.

### History

Cycle 1 2026-10-29T17:46:39.061Z: opened; single canonical record across both Pixiv feature surfaces.

## AA01-A02-F0007 — Independent Pixiv client edits need deliberate combined integration

- **Kind/severity/confidence/lifecycle:** risk / medium / high-confidence / open.
- **Affected:** #117 T004 and #118 T005, integration interaction only.
- **Source:** #117 e2929259b7725c484d11483d6ea48270079eb2f4, #118 1d02bef637966999fbd0b72ecb9c6f0e1eedce8a, common develop base 422aeae087c1108e655d85d1a3dac25120456cd6.
- **Location:** [#117 PixivClient entry](https://github.com/timberpile/Boorusama/blob/e2929259b7725c484d11483d6ea48270079eb2f4/packages/booru_clients/lib/src/pixiv/pixiv_client.dart#L1-L12), [#118 PixivClient entry](https://github.com/timberpile/Boorusama/blob/1d02bef637966999fbd0b72ecb9c6f0e1eedce8a/packages/booru_clients/lib/src/pixiv/pixiv_client.dart#L1-L12), their shared request helper around lines 205-230, plus each branch's navigation_capabilities.dart.

### Expected versus observed source behavior

Both independent branches add a different client part declaration and the same cancellation/redirect parameters to the private GET helper. Each is correct alone; a combined source must retain **both** client parts/extensions and options only once. #117 also adds Pixiv Favorites eligibility, while #118 adds Following Artists navigation. A careless overlapping-change resolution could remove one feature or fail compilation.

### Trigger and reachable failure path

Merging independently changed versions of PixivClient and navigation capability files can overwrite another branch's part declaration or case. No merged branch was actually executed; this is a concrete integration risk, not a confirmed current source failure or a claimed observed merge conflict.

### Evidence and safeguards checked

The two part files have distinct names and compatible request helper needs. Both branch handoffs note the independence. A focused merge retaining both is straightforward.

### Root cause and practical impact

Concurrent changes to the same source regions. Loss of either part/capability can break both independent acceptance criteria.

### Minimal recommended correction

Reconcile one combined PixivClient with both part lines, the shared request options once, both navigation additions and all client tests. Do not add an unnecessary abstraction.

### Suggested local verification and regression checks

Review the final integration diff against both pinned branch SHAs, compile the package, execute both client suites, navigation and Flutter full regression.

### Assumptions and remaining uncertainty

No merge operation was run; specific Git conflict output is not available.

### History

Cycle 1 2026-10-29T17:46:39.061Z: opened as a merge checklist item, not a source defect.
