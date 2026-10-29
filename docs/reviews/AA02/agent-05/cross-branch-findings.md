# Cross-branch findings

The following canonical finding affects multiple independently reviewed targets. It is counted **once** in the handoff; branch reports link here rather than reproducing the full finding.

## AA02-A05-F0001 — Pixiv access token sent to media hosts

- **Kind / severity / confidence / lifecycle:** `defect` / `high` / `static-confirmed` / `open`.
- **Affected issue(s), branch(es), and target IDs:** #92 / T003 `bug/92-selection-share-image` (sharing fallback); #117 / T020 `feature/117-pixiv-favorites` (Pixiv PostGrid thumbnail path); #118 / T021 `feature/118-pixiv-following-artists` (new artist avatars/previews). Shared root is older Pixiv API Dio used for media on all these source snapshots; cross-branch occurrence is counted once.
- **Origin:** `pre-existing` auth/media-client boundary in the shared sheet; this branch newly makes that path reachable for an unhydrated image by supplying fallback URLs. Do not attribute the underlying interceptor fault to the #92 implementation.
- **Reviewed head and comparison SHAs:** target `e8816c22048b324f00d682b7637c0ab1040147ca`, merge base `422aeae087c1108e655d85d1a3dac25120456cd6`, observed `develop@84df0c2de6cf8fe0177c49babb3fb0eee880f866`.
- **Location:** `lib/core/posts/shares/src/unified_post_share_sheet.dart`, `_UnifiedPostShareSheetState._perform` lines 519–562; `lib/boorus/pixiv/client_provider.dart`, `pixivDioProvider` lines 50–155; `lib/boorus/pixiv/auth/auth_interceptor.dart`, `PixivAuthInterceptor.onRequest` lines 106–135 and `_applyBearer` lines 264–274; `share_media_preparation_io.dart`, `prepare` lines 145–161 and `_prepareImageInCache` lines 250–267.
- **Source (commit pinned):** [sheet and Dio selection](https://github.com/timberpile/Boorusama/blob/e8816c22048b324f00d682b7637c0ab1040147ca/lib/core/posts/shares/src/unified_post_share_sheet.dart#L519-L562), [Pixiv client construction](https://github.com/timberpile/Boorusama/blob/e8816c22048b324f00d682b7637c0ab1040147ca/lib/boorus/pixiv/client_provider.dart#L55-L156), [interceptor injection](https://github.com/timberpile/Boorusama/blob/e8816c22048b324f00d682b7637c0ab1040147ca/lib/boorus/pixiv/auth/auth_interceptor.dart#L106-L135), [Bearer header](https://github.com/timberpile/Boorusama/blob/e8816c22048b324f00d682b7637c0ab1040147ca/lib/boorus/pixiv/auth/auth_interceptor.dart#L264-L274), [network download](https://github.com/timberpile/Boorusama/blob/e8816c22048b324f00d682b7637c0ab1040147ca/lib/core/posts/shares/src/share_media_preparation_io.dart#L147-L165), [URL fallback](https://github.com/timberpile/Boorusama/blob/e8816c22048b324f00d682b7637c0ab1040147ca/lib/core/posts/shares/src/share_media_url_resolution.dart#L10-L31).

#### Expected versus observed source behavior

Expected: Pixiv's OAuth bearer credential is attached only to Pixiv app-API requests, not to arbitrary media/CDN URLs. Observed in source: sharing an uncached image (including fallback sample/original/thumbnail from #92) invokes `ShareMediaPreparation.prepare(url: request.url, dio: ref.read(dioForWidgetProvider(auth)))` with an absolute URL. For a Pixiv profile, that Dio is `pixivDioProvider(config)` with an unconditional `PixivAuthInterceptor`. Every outbound request enters `_applyBearer`, which sets `Authorization: Bearer <current access token>` without comparing the target host/origin to the Pixiv app API. The media URL may be on a distinct origin (Pixiv artwork URLs are served at `i.pximg.net`), and the fallback URL gate only checks scheme and whether the filename has a video extension. The other two Pixiv branches render artwork via `PostGridItem` / `BooruImage` or `PixivFollowingArtistCard` / `BooruImage`. Without a user-defined media override, that widget also chooses `dioForWidgetProvider(config)` and thus the same Pixiv API Dio for remote media.

#### Trigger and reachable failure path

With a valid Pixiv refresh token and an uncached post image, open Share → Image without prior viewer hydration, select share/copy, then media preparation calls `dio.download` for the resolved image URL. The per-profile Pixiv API interceptor prepares/refreshes the access token and attaches it to the CDN/other remote host. Host-controlled media URL data accepted by the Pixiv post parser has no share-time origin restriction. This source path demonstrably allows a credential to be sent outside the intended app-API origin. No malicious origin, intercepted header or actual exploit is claimed as observed.

#### Evidence and safeguards checked

The Pixiv repository explicitly uses `pixivDioProvider`, which installs the auth interceptor; the global `dioForWidgetProvider` chooses that repository Dio. The transfer uses `httpHeadersProvider(auth)` plus headers from the target request, then Dio's request interceptors, and `ShareMediaPreparation` downloads with those headers. Cached copies bypass the request, but cache misses and non-cached images take the network path. `PixivAuthInterceptor` does not check `options.uri.host`, `options.baseUrl` or the media request marker before setting Bearer. The existing `mediaOverrideDioProvider` is intentionally unauthenticated, but this sheet does not select it. The protection interceptor adds request headers; it does not remove the Pixiv token. Tests in the branch substitute plain `Dio()` in the sheet, so they do not exercise this credential boundary.

#### Root cause and practical impact

A single per-profile authenticated API Dio is reused to fetch absolute image URLs, and its authorization interceptor is host-agnostic. This can expose live Pixiv access tokens to a media/CDN origin or to a remote image host if an untrusted source URL is returned. Severity is high because the header contains an authenticated account bearer credential, independent of whether the real Pixiv image CDN is operated by the same provider. T021 makes it possible to trigger by viewing the new artist cards; T020 exposes the same root through Favorites artwork.

#### Minimal recommended correction

For media downloads, select a Dio with no account-auth interceptor for URLs outside the API origin (the repository already has `mediaOverrideDioProvider` for this purpose) while retaining safe host-specific Referer, cache/cancellation, proxy and DDOS handling. As defense in depth, scope `PixivAuthInterceptor.onRequest` itself to the authenticated app API origin and strip/reject bearer on unrelated hosts, including retry and redirect paths. Audit analogous cookie-based auth interceptors before applying a generic one-size-fits-all fix.

#### Suggested local verification and regression checks

Add an HTTP adapter/interceptor test that prepares an uncached Pixiv sample URL at an image/CDN host and captures outgoing request headers: no `Authorization` or refresh on the CDN request, while app-API requests still carry the valid bearer. Also test malicious/unknown media host, error, cancellation, cache hit and native Image share/copy. Run affected sharing and Pixiv authentication tests and the full final integration suite. Avoid logging actual secrets in test output.

#### Assumptions and remaining uncertainty

Static code proves unconditional bearer attachment when a Pixiv authenticated image download occurs with the shared Dio. Whether a given source returns a hostile URL and whether actual network endpoints receive the header has not been tested. The risk predates #92; this branch expands availability of the sharing path rather than creating the original auth-interceptor behavior.

#### History

- Cycle 1 at `e8816c2`: first independently observed source-confirmed finding, open. No application code changes and no local test execution.
- Cycle 1 T021 review: expanded independently verified affected source to T020 (favorites artwork) and T021 (artist cards) using the shared `BooruImage` media pipeline. Moved original finding to the cross-branch index with stable ID; no duplicate defect count.

Additional pinned sources: [generic media widget](https://github.com/timberpile/Boorusama/blob/1d02bef637966999fbd0b72ecb9c6f0e1eedce8a/lib/core/images/booru_image.dart#L91-L171), [Pixiv artist card](https://github.com/timberpile/Boorusama/blob/1d02bef637966999fbd0b72ecb9c6f0e1eedce8a/lib/boorus/pixiv/following/artist_card.dart#L14-L55), [Pixiv Favorites grid](https://github.com/timberpile/Boorusama/blob/e2929259b7725c484d11483d6ea48270079eb2f4/lib/boorus/pixiv/favorites/page.dart#L66-L92).

