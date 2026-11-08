# Decision 3 — Pixiv Series, User Search, Related Works and Metadata

**Status:** API-informed research proposal, not a successful authenticated live test. No Pixiv API client or UI implementation changed.
**Scope:** [Expand Pixiv Search Capabilities (#83)](https://github.com/timberpile/Boorusama/issues/83), [Present Pixiv Multi-Image Works (#140)](https://github.com/timberpile/Boorusama/issues/140), [Bookmark Pixiv Works and Images (#141)](https://github.com/timberpile/Boorusama/issues/141), [Support Pixiv Artwork Bookmark Actions (#124)](https://github.com/timberpile/Boorusama/issues/124). Android is the primary platform. Implement remaining Pixiv work **after** shared group architecture.

## Current Boorusama reality

- The Pixiv parser currently flattens each `illust/manga` DTO into one `Post` per image page; `PixivPostData` retains `illustId`, `pageIndex`, `pageCount`, `userId`, `userName`, `userAccount`, `seriesTitle`, and selected stats. Per-page stable key: `work-page:<illustId>:<zeroBasedIndex>`.
- `PixivIllustDto` already provides `title`, `caption`, user, Series `id/title`, `metaPages`, bookmark/view counts and AI fields. The mapping presently discards the title and serializes some missing counters as 0; translated tags may be flattened into the canonical tag set. Fix data fidelity before adding richer details.
- `PixivClient` currently has `/v1/illust/detail`, `/v1/search/illust`, `/v1/user/illusts`, `/v1/user/detail`, and read-only user Bookmarks. `getUserIllusts` currently hardcodes `type=illust` (not Manga).
- `PixivRepository` inherits `EmptyFavoriteRepository` for source Favorite writes; do not imply account bookmark actions are implemented because the Favorites page can *read* them.
- Existing `PixivSeries` is a small ID/title DTO, not a Series member loader.

## Three distinct objects

**Pixiv Work:** one artwork identity and title/caption/artist, containing one or more image pages; `ugoira` is **one animation media item**, not a group of independent frame Posts.

**Pixiv Manga Series:** an ordered group of **Manga Works**. Pixiv's Help Center explicitly says ordinary illustrations cannot be added to the Manga Series feature; Novels are a different feature family. Series should not be displayed as a flat page list. Official references:
- [Illustrations cannot create a Manga Series](https://www.pixiv.help/hc/en-us/articles/115000316794-I-want-to-create-an-illustration-series)
- [Collection (Beta)](https://www.pixiv.help/hc/en-us/articles/48871761081369-What-is-the-Collection-Feature-Beta): a separate mixed feature capable of text, links and other resource kinds, outside current scope.

**Related Works:** algorithmic suggestions from a different endpoint, not members of either Work or Manga Series.

## Candidate API endpoints and the evidence level

| Need | Candidate | Confidence / missing verification |
| --- | --- | --- |
| Find users by name | `GET /v1/search/user?word=…` | Implemented in current PixivPy; authenticate, verify results/pagination and Unicode handling |
| User by stable ID | `GET /v1/user/detail?user_id=…` | Already exists in Boorusama |
| Work details/pages | `GET /v1/illust/detail?illust_id=…` | Already exists in Boorusama; verify restricted/removed/page completeness |
| More by same artist | `GET /v1/user/illusts?user_id=…&type=illust|manga` | Current Boorusama client uses `illust` only; verify Manga pagination/filter and mixed artist sections |
| Related Works | `GET /v2/illust/related?illust_id=…` | Third-party PixivPy implementation exists; response, `next_url`, filtering and auth not yet live-tested |
| Manga Series | `GET /v1/illust/series` with `illust_series_id` | Seen in third-party Pixiv integrations and endpoint catalogs; cursor/ordering, detail shape, actual reliability need a pinned authenticated spike |
| Remote Work bookmark | `POST /v2/illust/bookmark/add`, delete via `/v1/illust/bookmark/delete`; detail via `/v2/illust/bookmark/detail` | Existing third-party clients; require authenticated write/read-back tests, public/private and cancel/error handling |

Endpoint names from [PixivPy](https://github.com/upbit/pixivpy/blob/master/pixivpy3/aapi.py) and [contemporary endpoint catalog](https://pkg.go.dev/github.com/FlanChanXwO/pixiv-cli/internal/services/pixiv/protocol). These are reverse-engineered App API calls, **not an official stability contract**.

## Recommendation: user-name search

- Accept numerical ID directly, artist `@account` where resolvable, and an official **display name** as user inputs.
- Query /search/user for name discovery, display real Pixiv-provided name, account and avatar in a selectable list, with ID accessible in details.
- Store and navigate by the immutable **numeric user ID**. Name/account are mutable presentation fields and caches, not bookmark identity.
- Avoid declaring ambiguous partial name results a unique exact match. For `user:<id>` chips, resolve ID to user detail lazily and cache; never replace serialized ID with the changing display name.
- Do not invent or infer an **official badge** from a matching name. Show one only when source metadata actually verifies that status.
- Preserve [Search Capabilities issue (#83)](https://github.com/timberpile/Boorusama/issues/83) restrictions: artist listing scope may not be silently combined with ordinary text search/filters. This scope switching must be explicit.

Official numeric user ID documentation: [pixiv Help Center](https://www.pixiv.help/hc/en-us/articles/235583588-What-is-a-user-ID). The [Pixiv official-account badge](https://www.pixiv.help/hc/en-us/articles/55002843574681-About-pixiv-official-accounts) is a distinct concept.

## Recommendation: Work and Series details UI

Reuse existing Danbooru/Kurumi sections while making Pixiv **media first**:
1. Current page preview/pager (horizontal). Keep page indicator visible for multi-page Works; enable focus Image View.
2. Artist row with existing name/avatar/username and source profile link.
3. Work-level actions; Page-level choices in overflow/long-press as described in [Decision 2](2026-11-05-decision-02-work-page-ux-and-actions.md).
4. Original Work title/caption, tags, Work type, series link where actually present, properly optional views/bookmark counts, AI status only when known.
5. `More by This Artist` section (artist listing) followed by `Related Works` section (recommendations), each lazy and failure-isolated.

A Manga Series instead shows Work cards, title, author/cover/known Work count. Selecting one opens a Work occurrence and preserves Series scroll state. Do not fetch all pages in all Works up front.

## Engineering risks to verify

- **Pagination:** validate `next_url` host, path, scope, cursor progress, and maximum request size exactly as the current user Bookmarks implementation does. Do not blindly follow remote next URLs.
- **Auth:** account token expiry and concurrent scope changes cancel/invalidate stale results. Private/protected Works must not leak through a generic result cache. Respect R18/safe filtering.
- **Ugoira:** media-specific animation playback/frames are not general GroupMember Pages.
- **Metadata:** distinguish `null` from true zero for view/bookmark counts. Preserve title and Series ID before serializing snapshots.
- **Page identity:** work-page key/index survives missing or reordered image data; work Favorite and Group actions must use `illustId`, not the synthetic Post ID.
- **Resource budget:** do not issue a User detail or Related Works request for every visible thumbnail; lazy-load when shown, deduplicate and cache per access context. A failed optional recommendations request should not break the Work viewer.
- **Source evolution:** account names, manga/illustration classification and Series metadata are not stable identity fields.

## Minimal authenticated validation matrix (not yet run)

Using an authorized existing test profile and the repo's Android test setup, without sending credentials through chat:
1. Search a unique user by display name and a common ambiguous name; select and verify stable IDs.
2. Resolve a known numeric `user:<id>` to display name/avatar; test renamed account.
3. Open a single and multi-page Manga Work and confirm Series ID/title and page ordering.
4. Page through a Manga Series; verify cursor/finish and removed/restricted item behavior.
5. Load and paginate Related Works; compare to More by Artist; verify no cross-account data contamination.
6. Read Work bookmark status, add Public then Private via separate safe test cases, delete, verify known status and failure cases. Avoid writing to third-party content unless explicitly authorized by the owner.

**Status:** public source/docs and repository inspection done; no authenticated endpoints invoked and no Android E2E executed.

## Proposed decision

Treat Pixiv Work as an addressable Group with page Posts; Manga Series as a Group of Works; Related Works as a separately loaded recommendation list. Add User Search by name with stable IDs and optional cached display data. Preserve Work/Page action targets and defer exact Series API adapter implementation until the authenticated spike succeeds.

**Still discuss together:** Work entry layout and Work/Series return behavior (partly addressed in Decision 2), whether Manga Series is within the first Pixiv feature release, and what metadata is worth displaying by default versus in the expanded details sheet.
