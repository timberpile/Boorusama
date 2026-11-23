# Issue #176 — Screenshot-aligned presentations

**Status:** Accepted Flutter behavior with historical mockup notes below.

**Date:** 2026-11-18. **Code baseline:** `develop@a9ce9de09e4a9d8c994c24804d7c65ef8cefe270`.

The user supplied four screenshots: Pixiv Work Immersive, the same Work Detailed, a Danbooru Pool grid, and a Related Group grid. These are the source of the layout requirements. **Do not commit the source screenshots or their art** to this public branch; `index.html` contains self-authored placeholder illustrations. The downloadable personal preview may contain cropped art, but it is not part of the repository.

[Revised interactive mockup](index.html) · [Archived first study](original-study.html) · [Initial research](../2026-11-18-group-viewer-modes.md)

## Current Flutter behavior

- Swiping between viewer entries carries the active Single or Timeline
  presentation to the next supported Group. Ordinary Posts and single-image
  Pixiv Works preserve the presentation choice for the next Group. Fresh
  viewer routes use the source defaults.
- The transient member count is inset 8dp from the usable lower-right media
  canvas. It follows the visible bottom overlay in Immersive and scrolls with
  the first media canvas in Detailed. Its three-second lifetime is independent
  of zoom, media decoding, and sort reindexing.
- Related Groups offer Latest and Oldest. The saved and query keys remain
  `newest` and `oldest`. Collections and Series offer Ordered, Latest, and
  Oldest in both presentations and in the Single overflow. Pixiv Works use
  author Page order. Pixiv Works offer Timeline when at least two pages are
  known.
- Timeline retains the applied grid until the ordered page and its filters
  are ready. Single keeps the current image visible during preparation, then
  selects the first member of the new order. Saved Related preferences commit
  only after preparation.
- A fresh Series starts in Single at the first Ordered manifest slot. Single
  uses that Post's media. The opening cover handoff belongs to Pixiv Works.

See the [implementation verification](../../handoffs/176-canvas-order-verification.md).

## Correction to the initial study

The first proposal added a universal group header, a labelled mode row (A), and a separate outer-feed navigation rail. These depart unnecessarily from the current app. The user first preferred B, then explicitly selected **B+: a direct one-tap view switch in existing chrome**. This replaces the earlier A and B recommendations, the global Single default and the permanent outer rail. B (two-tap menu) and B− (overflow only) remain comparisons, not the chosen interaction.

## Related sort placement (2026-11-18)

**Related Groups open Single by default**, like Pixiv Works and Danbooru Series. General Danbooru Pools/Collections continue to open Timeline. The older prototype's **`Custom Related order` editor has been withdrawn**: the user meant the existing `Latest / Oldest` selector, not arbitrary drag/manual member rearrangement. There must be **no custom reorder mode, editor, separate local order array, or custom-order persistence**.

**One order across presentations.** Timeline exposes Latest and Oldest in the
existing sort control. Single exposes both in its upper viewer header, before
B+ and Info when shown, and through the existing overflow. The counter remains
inside the media canvas. A new sort selects the first member of its order.

**Bookmark order persistence already exists:** the current Danbooru `RelatedGallery` reads a saved `RelatedBookmark.preferredOrder` (and legacy equivalent), saves standard sort changes with `bookmarkProvider.notifier.setRelatedOrder`, and supplies `RelatedBookmarkPickerRequest.visibleOrder` when saving. The shared Single implementation should reuse **the same order state and existing bookmark persistence**, including when a Related Group is bookmarked from either of the two scoped Bookmark controls (specifically the whole-group control); do not introduce a new custom-order store. Existing saved preferred order takes precedence over a default when restoring a bookmark, subject to the current occurrence's explicitly chosen sort. The standalone HTML only simulates this preference in session state.

Source: [RelatedGallery](https://github.com/timberpile/Boorusama/blob/develop/lib/boorus/danbooru/posts/related/related_gallery.dart), [RelatedPostsOrder](https://github.com/timberpile/Boorusama/blob/develop/lib/core/posts/related/related_posts_order_value.dart), [Related bookmark target](https://github.com/timberpile/Boorusama/blob/develop/lib/core/bookmarks/src/types/bookmark_picker_request.dart), [Bookmark picker actions](https://github.com/timberpile/Boorusama/blob/develop/lib/core/bookmarks/src/providers/bookmark_picker_actions.dart).

## Latest Series default and Detailed content (2026-11-18)

**Accepted:** Danbooru **Series open in Single by default**, using source/Ordered member sorting. Pixiv Works also open Single; general Danbooru Pool/Collection continues to default to Timeline; Related Groups also open Single by default. Users may switch freely using B+ without changing member identity.

**Simplified Details proposal, reflected in the mockup:** do **not** introduce the previously discussed expandable `In Series / In Pool` metadata section. Danbooru Post Details already expose Pool/Series membership through the existing `DanbooruPoolTiles` part of `danbooruPostDetailsUiBuilder`. Keep it; do not duplicate the same link, title, dates or description. Detailed continues to show information about the **current Post**. The full Pool/Series **description remains in Timeline**, reached by B+ or by the existing pool link. The mockup makes its example Post-to-Pool link navigate to Timeline; production should preserve the established link behavior unless changing it is separately agreed. The two independent Bookmark actions already provide direct current-Post and whole-Group storage, so this need not create a second action row.

**Exceptions:** Pixiv Work Detailed already owns Work-scoped title/caption/artist and keeps them. Related Group lacks descriptive group metadata and adds no invented context card. No additional always-on header or hint is needed for default-Single Series.

Source: [Danbooru Post Details builder](https://github.com/timberpile/Boorusama/blob/develop/lib/boorus/danbooru/posts/details/src/details_ui_builder.dart) (`DetailsPart.pool: DanbooruPoolTiles`).

## Shared viewer architecture (verified on develop)

**There is no Pixiv-specific fullscreen viewer.** The existing `PostDetailsPageView` is the shared viewer shell for ordinary Posts and group media: it owns navigation, overlays, gestures, zoom presentation and the Immersive-to-Details transition. `PostDetailsPageScaffold` composes it; `MediaGroupPage` provides the inner member pager for media-first groups using the same post-media components. `MixedPostDetailsPage` dispatches group entries through the registered group capability and shared presentation scope.

Current group presentation is **selected by source capability**, not by an available user choice: `GroupLayout.mediaPager` currently activates the inner pager for Pixiv Works, while `GroupLayout.memberGrid` uses `ContentGroupPage` and the engine's group-detail/grid presentation. `ContentGroupPage` is a group-content presentation dispatcher, not a competing fullscreen post viewer. Issue #176 should introduce a **viewer/occurrence-owned presentation choice above the existing group dispatcher**, permitting both representations for eligible groups, without forking a second fullscreen viewer, adding Pixiv-specific viewer logic, or changing shared post/group identities.

Post details are supplied through `PostPagePresentationScope` and the engine's `detailsBuilder(post)` (with generic fallback); group facts/actions use `BooruGroupCapability` and optional status/bookmark/selection presentation interfaces. Preserve these site-specific extensions **at the content/action layer**, not as duplicated viewer shells. The B+ switch changes the group's presentation only; Single's Immersive and Detailed states and the selected member remain intact.

Source references: [shared viewer](https://github.com/timberpile/Boorusama/blob/develop/lib/core/posts/details_pageview/src/post_details_page_view.dart), [shared scaffold](https://github.com/timberpile/Boorusama/blob/develop/lib/core/posts/details/src/widgets/post_details_page_scaffold.dart), [group entry dispatch](https://github.com/timberpile/Boorusama/blob/develop/lib/core/posts/details/src/widgets/mixed_post_details_page.dart), [member pager](https://github.com/timberpile/Boorusama/blob/develop/lib/core/posts/details/src/widgets/media_group_page.dart), [group page](https://github.com/timberpile/Boorusama/blob/develop/lib/core/posts/details/src/widgets/content_group_page.dart), and [site-specific post presentation](https://github.com/timberpile/Boorusama/blob/develop/lib/core/posts/details/src/widgets/post_page_presentation_scope.dart).

### B+ interaction contract

- **One tap, no menu:** in Single show the grid/Timeline destination icon; in Timeline show the single-image destination icon. The icon indicates where the action takes the user, never the current state.
- Give the action a localized tooltip/accessibility label (`Switch to Timeline` / `Switch to Single view`), adequate touch target and focus semantics. Keep the existing overflow's labelled `View as…` alternative if useful, but do not require it to change modes.
- Place the button within existing controls (alongside Info in Immersive, without overlapping the counter in Detailed; next to current sort/overflow on Timeline). Do not add a permanent toolbar row or outer-feed rail.
- Apply identically for Pixiv, Pool, Series and Related. For a standalone Post without a group, no group-mode switch is necessary.
- Preserve the group occurrence/member key, source/profile authorization, current sort and scroll anchor when toggling. The view switch is presentation state, not a new Post or group navigation route.

## Preserve the current visual surfaces

| Group | Default | Single mode | Timeline mode | Member order |
| --- | --- | --- | --- | --- |
| Pixiv Work | Single | Existing shared viewer with an inner Work Page pager and Immersive/Details | Newly available Pool-like thumbnail grid with Work title, author, page count and Work-level actions | Author Page order |
| Danbooru Pool | Timeline | The same shared viewer with each selected Post (not a separate Pixiv viewer) | **Keep current** group title/description, header actions, sortable count row, two-column grid and bottom nav | Ordered / Latest / Oldest |
| Series | **Single** | Same shared Post media viewer | Existing Series/Pool presentation with title/description | Ordered / Latest / Oldest |
| Related Group | **Single** | Shared viewer; compact Latest/Oldest dropdown in upper header | **Keep current** Back/share/bookmark header, count/sort toolbar and two-column grid, no imposed bottom nav | Latest / Oldest, saved in Related bookmark |

**Immersive and Detailed are states within Single, not third and fourth group presentation modes.** Timeline is the existing group image list/grid, not the outer feed, a chronological promise or a second fullscreen viewer.

### Single (screenshots 1 and 2)

Keep circular Back and Info overlays, existing page counter, fitted media, post/work action toolbar, gestures/zoom, and the media-to-Details transition. Use the same full-screen layout for Pool/Series/Related member Posts. In Detailed the media moves upward with margins, and the current metadata scrolls below the existing toolbar. Pixiv retains author/Work metadata; other groups show the current Post information and existing Pool/Series link where available, without an additional Group-context card. The new view button must not obscure the counter or disappear on a bright image.

### Timeline (screenshots 3 and 4)

Retain source-specific group title/description and actions, count/sort row, card design, existing toolbar region, and the app's normal scrolling/footer behavior. Pixiv Works receive a Timeline with page-number tiles and the Work's title/artist/actions; **do not add a per-page heart** because Pixiv favourite/bookmark is Work-scoped. Pool and Related tiles keep their Post actions. Existing card grouping/badges remain unchanged.

## Compact view switch options (no new vertical chrome)

| Option | Single | Timeline | Trade-off |
| --- | --- | --- | --- |
| **B (comparison)** | Compact view button next to Info opens `Single image / Timeline` menu with current choice checked. | Same button placed in the existing count/sort toolbar before overflow. | Named choices; two taps, no extra height |
| **B+ (selected)** | Target grid icon switches directly to Timeline. | Target single-image icon switches directly to Single. | One tap, no new row; icon always signifies the **destination**, with accessible label/tooltip |
| **B−** | Existing `… → View as…` action. | Existing `… → View as…` action. | No extra icon, harder to discover and slower |

Implement with existing Kurumi popup patterns, not a raw Material surface. Keep `Order` independent from B+ `View as`. In Single, the Related, Pool and Series selector is available in the upper viewer header and through existing overflow; no Custom editor.

## Model, state and navigation

- Source, site, profile, group and member occurrence identity are invariant across presentation changes. Preserve `GroupMember.memberKey`, source position, unavailable/restricted slots, source metadata and authorization. Never compact or merge repeated member occurrences.
- Initial modes: **Pixiv Works, Danbooru Series and Related Groups open Single**; general Danbooru Collections/Pools open Timeline. Explicit B+ mode changes preserve the selected member. Sorting uses the same state in both modes; the HTML simulates bookmarks in session state.
- Switching by the view action preserves selected member key and the Timeline's scroll anchor. Passive Timeline scrolling does not select a different member. Tapping a tile opens Single on that member.
- **Back proposal requiring confirmation:** a tile drill-in returns to that Timeline as it currently does; an explicit display-choice switch is not another Back-stack route. Existing source return navigation remains correct. This distinction is tested in HTML but needs Flutter route/gesture validation.
- Preserve existing inner-vs-outer pager ownership and boundary behavior. Do **not** silently replace the current outer-feed edge handoff with the earlier prototype's group-end stop and permanent rail. Review #140 and neighboring viewer branches before any gesture change.
- Pixiv bookmark/favorite is Work-level; Page download/share is Page-level. Pool/Series/Related Single actions target the current Post, while their Group actions and details remain available in context/overflow. No cross-profile cached content leak.
- Related sorting offers **Latest and Oldest**, using the existing engine/source order and saved bookmark `preferredOrder`. No arbitrary local manual reordering; both Single and Timeline operate on the same order without losing member occurrence identity.


## Earlier expandable group metadata proposal (superseded)

**Historical alternative only: the expandable Pool/Series Group-context row is no longer recommended. The latest design below uses existing Post links and Timeline descriptions.** This follows the user's questions about Pixiv Work summaries, what a Timeline tile opens, and how a default-Single Series can still reveal its Pool metadata. Keep the established single shared viewer and B+ mode switch; avoid a separate group-details viewer or a second persistent toolbar.

### Verified metadata and UI entry points

- **Pixiv Works:** `pixivWorkSummary` maps Work title and page count; `pixivWorkDetails` maps caption, creator, tags and creation date. Page posts intentionally remove the Work caption from their per-Page facts. `PixivWorkInformation` already reads group details from `mediaGroupProvider` inside the shared Detailed view. The mockup's literal artist/title/caption strings are demo data, but the underlying fields are real. Artist requires loaded Details, so never fabricate a placeholder name.
- **Danbooru Pools and Series:** both are the same source/group implementation distinguished by category. `DanbooruGroupSource` maps Pool name, member count, category, DText description, created/updated dates; each member Post separately has its own metadata and actions. `PoolDetailContent` currently presents Pool title/last-updated/description above its grid.
- **Related families:** `DanbooruGroupSource.loadDetails` intentionally returns only a bare group summary. `RelatedFamilyReference` identifies the anchor Post (`related:<anchorId>`, query `parent:<anchorId>`). No descriptive group title or rich group information exists to show; never invent it.

Source references: [Pixiv mapper](https://github.com/timberpile/Boorusama/blob/develop/lib/boorus/pixiv/works/work_mapper.dart), [Pixiv Detailed UI](https://github.com/timberpile/Boorusama/blob/develop/lib/boorus/pixiv/works/work_information.dart), [Danbooru group source](https://github.com/timberpile/Boorusama/blob/develop/lib/boorus/danbooru/pools/content_group_source.dart), [Danbooru Pool details](https://github.com/timberpile/Boorusama/blob/develop/lib/boorus/danbooru/pools/details/src/pool_detail_page.dart), and [Related family identity](https://github.com/timberpile/Boorusama/blob/develop/lib/core/posts/related/related_family.dart).

### Presentation proposal

| Content kind | Timeline above thumbnails | Single / Detailed view |
| --- | --- | --- |
| Pixiv Work | Compact Work title; optional creator only if loaded. Show page count once in the existing count toolbar. Do not duplicate the full caption. | Work information is the **primary** description in Detailed; member Page has media/file facts but no invented Page caption. |
| Danbooru Pool / Collection | Retain existing Pool title, update time, description and grid. | Current **Post** details and actions; retain existing Post-to-Pool link. **No additional expandable Group-context row.** |
| Danbooru Series | Retain existing Pool/Series title, description and three sort choices. | Current **Post** details and existing Series/Pool link. **No new Group description here. Series opens Single by default.** |
| Related family | No invented descriptive group summary or extra content area. Existing count/order toolbar suffices; optionally identify the anchor Post in the existing header/menu if useful. | Current Post information and existing related links only. No extra Related Group description or action row. |

**Current proposal:** do **not** add an expandable Pool/Series Group-context row. The existing Danbooru `DanbooruPoolTiles` Post-detail section already links to memberships; the two distinct Bookmark buttons make a separate Group-action row unnecessary. Keep complete Pool/Series description, dates and metadata in Timeline. Pixiv is different: its caption is genuinely Work-scoped and remains in the existing Work Detailed presentation. No extra Immersive header/cue is required.

**Navigation contract (proposal):** a tile tapped in Timeline opens Single at the selected member, retaining group context and effective order, not an unrelated standalone Post context; Back from this drill-in returns to the previous Timeline position. The B+ presentation switch itself is not a new route. This differs from the current Pool/Related grid implementation, where tile taps call `goToPostDetailsPageFromController` and open the normal Post viewer through the gallery controller; that code must be reviewed for group-context retention before reusing it. [Pool grid source](https://github.com/timberpile/Boorusama/blob/develop/lib/boorus/danbooru/pools/details/src/widgets/danbooru_infinite_post_id_list.dart), [Related grid source](https://github.com/timberpile/Boorusama/blob/develop/lib/boorus/danbooru/posts/related/related_gallery.dart).

**Rejected alternative for now:** a full Post/Group tab inside Detailed adds a second view-mode selector and can obscure essential Post actions. The already available Post-to-Pool links, B+ switch and two scope-specific Bookmark buttons provide access without another Detailed UI section. Native checks still need to validate large descriptions, long names, group data loading after Post loading, and small-screen text scale.


## Previous split-action alternative (superseded)

**Status: historical exploration, superseded by the accepted two-button layout below. Not an implementation.** The user explicitly requires local Bookmarks at both the full-group and individual-member levels, while remote Favorites target the object supported by each site's engine. This is orthogonal to Single/Timeline, Immersive/Details and the B+ presentation switch.

### Verified current functionality

- **Local bookmarks:** `BookmarkPickerRequest` already distinguishes `ContentGroupBookmarkPickerRequest` (native group reference), `RemotePoolBookmarkPickerRequest`, `RelatedBookmarkPickerRequest`, and `PostBookmarkPickerRequest`. These persist distinct entities; saving a group is **not** implicitly saving every member Post. [Requests](https://github.com/timberpile/Boorusama/blob/develop/lib/core/bookmarks/src/types/bookmark_picker_request.dart)
- **Pixiv:** `PixivWorkBookmarkButton` presents Work as its primary bookmark target. Its long-press alternative presents **Bookmark Work** and **Bookmark Page**, using a source-validated, frozen Page request; Work and Page have independent local membership indicators. This is a useful established pattern, not a reason to lock both scopes into one storage identity. [Current interaction](https://github.com/timberpile/Boorusama/blob/develop/lib/boorus/pixiv/works/bookmark_actions.dart)
- **Danbooru Pool/Series:** Timeline/header uses `PoolBookmarkButton` to bookmark the Pool; an ordinary Post viewer uses `BookmarkPostButton`. [Pool header](https://github.com/timberpile/Boorusama/blob/develop/lib/boorus/danbooru/pools/details/src/widgets/pool_gallery_header.dart) · [Post toolbar](https://github.com/timberpile/Boorusama/blob/develop/lib/boorus/danbooru/posts/details/src/widgets/danbooru_post_action_toolbar.dart)
- **Danbooru Related:** Timeline/header already has `RelatedBookmarkPickerRequest` for the family; opening a thumbnail currently opens the normal Post viewer, with its Post Bookmark. Group metadata has no description, but the group bookmark target is real. [Related gallery](https://github.com/timberpile/Boorusama/blob/develop/lib/boorus/danbooru/posts/related/related_gallery.dart)
- **Remote Favorites are a different capability:** Danbooru's engine overrides `FavoriteRepository` for individual Posts. `PixivRepository` currently inherits `BooruRepositoryDefault.favorite`, which returns `EmptyFavoriteRepository`, so **Pixiv remote Favorite mutations are not currently implemented**, even though Pixiv's remote favorites list can be read. Never mislabel a *local* Pixiv Work bookmark as a writable Pixiv Favorite. [Default repository](https://github.com/timberpile/Boorusama/blob/develop/lib/core/boorus/defaults/src/booru_repository_default.dart) · [Pixiv repo](https://github.com/timberpile/Boorusama/blob/develop/lib/boorus/pixiv/pixiv_repository.dart) · [Danbooru repo](https://github.com/timberpile/Boorusama/blob/develop/lib/boorus/danbooru/danbooru_repository.dart)

### Recommended compact action design — stable action slot, explicit scope

**Single / Immersive and Detailed:** keep the existing bottom Post-action toolbar. **Bookmark** remains one compact **split action** in that established slot (the current Pixiv Work control already has an alternative affordance). The primary tap retains the site's established frequent target to avoid regressions: **Work** for Pixiv Works, **current Post** for Danbooru Pool/Series/Related. The adjacent, clearly operable chevron opens a labelled *target chooser* when two local Bookmark targets exist:

- `Bookmark current Page / Post` (member occurrence; the currently resolved member).
- `Bookmark Work / Pool / Series / Related Group` (group reference; never mass-add all Posts).

Each chooser row shows its **own** saved state/count, not one misleading combined saved check. Choosing a row opens the **existing bookmark folder/group picker** for that entity. The primary control's tooltip/semantics must name its **actual target** (e.g., `Bookmark Work`, `Bookmark Post`), never generically promise a Group. Tap/long-press/chevron must be accessible without relying only on long-press. Preserve current behavior and accessible target markers when extending the Pixiv control. This is a proposal to generalize the existing pattern, **not** an assertion that Danbooru currently offers a split control.

**Timeline:** preserve existing **group Bookmark** in the group header (Pixiv Timeline should add the same Work target; Pool and Related already have it). Member thumbnails retain existing site-specific quick actions/context menu. Members can also be bookmarked after tapping a tile, which opens the same Single viewer with the selected member. For Pixiv, no per-Page heart is added: a Page bookmark is not a remote Pixiv favorite.

**Detailed content (previous alternative, superseded):** an expandable Group context/action section was considered before the two always-visible Bookmark buttons were selected. Do not implement an extra Detailed group card. Reuse existing Post-to-Pool/Series links and the two scoped Bookmark buttons; the Timeline provides Group descriptions.

**Favorites:** visually and semantically separate from local Bookmarks (existing heart vs bookmark icon). A heart only appears when the engine supplies a **real writable Favorite capability for that captured site/profile/object scope**: Post heart in the member toolbar if Post-scoped; group heart in group actions if Group-scoped. If an engine genuinely supports both, expose two explicitly named targets in a scoped chooser rather than changing favorite target based on presentation mode. Do not invent a group Favorite operation merely because a group Bookmark exists, or falsely label the remote favorites listing as mutability. Keep independent `favoriteState` and `bookmarkState` for each entity.

**Overflow:** use existing `…` actions for less frequent Group-wide Share, Download all, source navigation and other engine-specific capabilities; do **not** make Group Bookmark only accessible via deep overflow. On very narrow screens, retain the Bookmark split action as a visible priority over secondary toolbar controls, using the existing `BooruMenuButtonRow`/Kurumi overflow behavior. B+ remains a separate destination-mode toggle in existing chrome, not an action-scope toggle.

### Alternatives and tradeoffs

| Layout | Benefit | Cost |
| --- | --- | --- |
| **Recommended:** one Bookmark split action + Group context/actions | Reuses Pixiv pattern and existing bottom toolbar, two targets reachable with no extra permanent action row | Primary target can differ by engine; explicit tooltip/choosing affordance and independent states are essential |
| Two separate always-visible bookmarks (Post at bottom, Group in overlay header) | Immediate distinction by location | Adds a new visible header icon beside B+ and Info; may crowd narrow screens and hidden immersive chrome |
| One bookmark button always opens a scope chooser | Uniform gesture and no accidental scope | An extra tap even for the frequent one-target action; unnecessary for standalone Posts |

### Implementation boundaries and review cases

1. Define group/member **action targets** in shared viewer context, resolved through the existing Bookmark request types and source-scoped access. Do not introduce a new storage entity or conflate local Group and Page records.
2. Captured group reference, source/site/profile access generation and current member key must remain fixed when an asynchronous picker opens. If the account changes, disable the stale action; a subsequent swipe must not change an open Page picker to a neighboring Page.
3. Bookmarking Group must not mark all members bookmarked. Bookmarking Post must not mark Group bookmarked. Status must update independently in Single, Timeline and Details, including after Undo/removal.
4. Remote Favorite may be absent, loading, disabled or failed. Keep it out of the UI if no capability; if available show pending, confirmation/failure and accurate scope, without changing local bookmark state.
5. Exercise normal post-only viewer, Pixiv Work/Page, Danbooru Series/Pool, Related, missing/restricted member, a group with one member, 320dp/large text and keyboard/screen-reader semantics. No runtime UI or full integration review has been performed.

**Decision to seek:** whether to generalize the existing Pixiv split Bookmark affordance across groups (recommended) or make two explicit target buttons visible. The exact default target must be clear before any implementation. Keep this proposal separate from the already accepted B+ display switch.



## Accepted dual Bookmark buttons (design decision, 2026-11-18)

**User decision:** use **two separate, simultaneously visible local Bookmark buttons**, each displaying a **small scope icon**. This replaces the split-action chooser recommended in the previous section. It does not change the accepted B+ mode switch or introduce another viewer. The existing toolbar height is retained.

**Single (both Immersive and Detailed):** place both Bookmarks together at the start of the existing lower action row. The **first** is the current **Page/Post** bookmark, shown as the familiar outline/filled Bookmark icon with a small *image* corner badge. The **second** is the **whole Work/Pool/Series/Related Group** bookmark, with the same Bookmark icon and a small *stacked-layer* corner badge. Each is a separate full-size tap/focus target, not one split-button target and not a long-press-only alternative. The scope appears in the accessible label and tooltip: `Bookmark current Page/Post` or `Bookmark entire Work/Pool/Series/Related Group`. A filled Bookmark means that *that particular entity* has a saved folder membership.

**Actions:** each button directly opens the existing local Bookmark folder/group picker with its own frozen, identity- and access-bound target. Never insert a redundant Work-vs-Page target choice. Group Bookmark never means “bookmark all members”; individual Post/Page Bookmark never marks the Group saved. Their memberships, counts and disabled/loading states update independently during member paging, presentation switching, undo and profile changes. The mockup uses separate session-only demo folder selections (`Favorites`, `To review`), not real persistence, account data or production UI for the existing picker.

**Timeline:** retain the whole-Group Bookmark in the existing top header, now also carrying the *stacked-layer* scope badge. Member bookmarking remains accessible from each member's context actions and after opening it in the shared Single viewer; do not add per-Pixiv-Page Favorite hearts or a second permanent toolbar. Both visual presentations observe the same Group saved state.

**Favorites:** keep the website Favorite action distinct from both local Bookmark controls (heart icon, separate server state). Danbooru Posts can expose a Post-scoped heart; the currently inspected Pixiv engine has no writable remote Favorite action, despite its readable favorites listing. Do not add a Group Favorite heart without a real source capability. The sample mockup has a **demo-only** Danbooru Post heart to distinguish these concerns; it does not write server state.

**Responsive behavior:** keep both Bookmark buttons visible on constrained screens, with independently accessible targets; move less frequent actions into the established overflow before hiding either Bookmark. The example prototype hides `Open original` in the smallest layout but exposes it through the existing `…` menu. Avoid another permanent header icon in Single beside B+ and Info. No extra vertical rows.

**Implementation contract:** the shared viewer owns rendering and target selection, while established Post- and Group-scoped Bookmark request types, engine-specific Favorite capability and source authorization own behavior. Do not fork a Pixiv viewer or write to the wrong Group/Page after asynchronous selection.

**Verification:** the standalone SVG mockup and private screenshot-based HTML copy were exercised in Chromium with **76 local browser assertions** (two scope controls in Single and Detailed, independent save/removal, Page navigation, group state in Timeline, B+ switching, engine-specific Favorite presentation, four group kinds, 320–1200 px widths) and had no uncaught page errors. The two HTML inline scripts passed Node 22 syntax checks. These are local checks, not Flutter/Android tests, and the remote branch's exact bytes have not yet been browser-tested.


## What this HTML does and does not prove

`index.html` is an interactive, standalone offline illustration of B, B+ and B−. It provides Pixiv Single/Timeline, Pool and Series, Related Single by default and Oldest/Newest sorting in both views, selection and Back, plus Immersive/Details state. Embedded media is original stand-in SVG. It is **not** an Android screenshot, a Flutter build, a working image downloader, API/auth implementation or accepted architecture change.

Open design questions: placement of the selected B+ button on narrow action-heavy toolbars; whether a tile-opened viewer's Back semantics should differ from an explicit view switch; user-visible Group vs Post action scope; persistence policy for mode; and correct Related saved Oldest/Newest order across both views. Independent UX-specialist review remains outstanding (the earlier review is author self-review only).
