# Content Architecture: User Feedback and Research Supplement

Date: 2026-11-04. Baseline: `e306ff5338a2255a89731c61bd0672336a933344`.
Status: accepted product constraints plus explicitly labeled design candidates. No application changes are authorized by publishing these documents.

Read this supplement after [the preserved rereview](2026-11-03-content-architecture-rereview.md). Later user instructions below supersede conflicting recommendations in that historical review. Issue references always include a descriptive title; numbers alone are not sufficient context for the user.

## 1. Accepted changes and unresolved choices

| Topic | Accepted user direction | Still open |
| --- | --- | --- |
| Platforms | Android is primary; desktop is optional. Web is not a current delivery requirement. | Which desktop acceptance cases belong to an individual feature. |
| Sequence | Finish current work/bugs and establish a clean baseline; architecture next; new Pixiv/nhentai features afterward. | Exact stabilization cohort, excluding explicitly deferred architecture-dependent features. |
| Post | Retain the existing media Post type. | Final names and narrow shared group/listing contracts. |
| Pixiv Work layout | Media should lead; scrolling down reveals artist, description and details. Do not blindly copy Pool Header -> Description -> Grid. | Cover-first, inline pager or viewer/details-first interaction. |
| Shared UI | Reuse Danbooru/Kurumi structures and details components, with useful source extensions such as artist avatars. | Which composition to use for each resource role. |
| Viewer controls | `Viewer Controls on Open` only initializes a newly opened viewer. Do not reapply it when changing Posts. | No new default has been approved; preserve Visible/Hidden saved values. |
| Double-tap | Prefer Classic's one-in/next-out interaction; make the first target aspect-aware rather than fixed 3x. | Minimum useful zoom, panorama cap, Comic baseline and transition details. |
| Favorites visibility | A true Timeline Toolbar filter follows that toolbar; the existing separate Pixiv Public/Private row need not reappear away from the top. | Move to a Header menu, toolbar selector, or retain the separate top-only row. |
| nhentai tags | Aim for complete coverage over time, not a blocking startup crawl. Popularity-first loading is attractive. | Exact warmup budget, full-sync schedule, and whether to ship a seed. |
| Sharing | Use the established lightweight `.bslink` architecture. | Final parser/reference class names are implementation details to align with the group contract. |

Previously accepted smaller decisions remain: outlined stacked Bookmark navigation icon; Title Case for `Viewer Controls on Open`; compatible retirement of the separate Original Image route; independent grid spacing/padding defaults of 4 dp. This document does not claim these remaining UI changes are all already implemented.

## 2. nhentai catalog: correct scope and staged initialization

### User-provided observation

The user observed approximately 40 pages of about 100 general tags on `https://nhentai.net/tags?sort=popular&page=1`, around 4,000 tags in that listing. Around the fifth page, individual tag counts were about 100, versus roughly 240,000 for the most popular tag.

These are the user's website observations, not a new API measurement. Official page/API retrieval was attempted again during this task and failed at the tool retrieval layer. No actual HTTP/CORS diagnosis follows from that failure.

### What the observation changes

The prior review's 100,000-tag example was explicitly hypothetical and should not drive the initial implementation. If the general-tag list has about 4,000 entries, a 100-entry API page implies roughly 40 requests for that category; five warmup pages would yield up to 500 entries. Confirm the API page size and category totals before coding fixed assumptions.

The `/tags` website listing is not proof of the size of every taxonomy category. Artist, character, parody, group, language and category indexes must be measured separately. The previously inspected schema distinguishes tag types.

Popularity counts overlap: one Work may carry many popular tags. Summing their counts cannot prove a percentage of distinct Works covered. Measure actual unresolved-ID rates on representative loaded results instead. Initial popularity coverage can be useful without making an unsupported completeness claim.

### Recommended loading policy (proposal, not final implementation approval)

1. Render browsing from available summaries immediately. Do not block startup on the tag catalog.
2. Resolve missing IDs required by the current screen in deduplicated batches, with cancellation and request budgets.
3. Warm up the first five popular general-tag pages at lower priority; do not run duplicate work for IDs already resolved.
4. Continue through the remaining category pages opportunistically, persisting progress. Smaller categories may be completed earlier after measuring their sizes.
5. Reconcile stale names, type assignments and merged IDs without treating a temporary network failure as deletion.

The cache should record source namespace, numeric ID, type, canonical name/slug, optional count, observation time and provenance. Track completeness per category and synchronization generation, not one application-wide `complete=true`. Query results can contain new IDs even after an earlier full pass.

Popular ordering is a useful bootstrap but an unstable checkpoint: counts can move entries between pages during a crawl. Deduplicate by ID and periodically reconcile; do not promise an exact snapshot from a page-based popularity sweep. Use stable cursor/ID ordering only if the actual API supports it. The mirrored schema's text mentions cursors, but its inspected parameter list does not establish a usable cursor parameter.

Unknown tag metadata must not be equated with a safe/non-blacklisted result. Keep existing privacy/rating/filter policies and explicit unknown coverage, especially before showing persisted covers. Name-based search availability and ID resolution are related but not identical.

### Bundled catalog seed

A bundled, versioned ID/name/type seed is technically feasible, but it is not automatically the simplest first release.

Benefits: useful offline names and fewer cold-start requests. Costs: refresh process, stale/merged IDs, package size, distribution permission/provenance, and possible category-size underestimation. A seed does not replace live lookup and does not prove current source availability.

Recommendation: initially ship the staged live cache. Measure initial missing-ID rate, compressed metadata size and source stability. Only then decide whether a small popular seed or complete catalog has material value.

If a seed is adopted later:

- Include only permitted public tag metadata, no credentials or media.
- Record source URL, capture date, schema version, category scope and checksum.
- Make generation reproducible and review the redistribution basis before packaging.
- Prefer fresher runtime observations over packaged data; a new app version must not downgrade the cache.
- Treat the asset as bootstrap evidence, never authoritative completeness or permission to expose blocked content.
- Keep seed failure optional: browsing and live ID resolution must continue.

No catalog crawl, package bundling, or source data redistribution was performed by this documentation task.

## 3. Platform scope and delivery order

Android-native behavior is the acceptance target. Desktop may reuse the same architecture where existing capabilities permit. Web CORS, browser storage and Web authentication are not blockers for this plan and should not trigger a general Web rewrite. Preserve existing Web compilation/interfaces where the eventual change touches them, but do not promise new source parity.

The implementation sequence is now:

1. Finish the current stabilization work, including begun branches and known defects; verify a clean combined develop candidate.
2. Rebase/revalidate this architecture proposal against that candidate, agree on remaining design choices, then implement the focused group/reference/presentation generalization.
3. Implement the remaining Pixiv Work features and nhentai on that architecture.

Research and design fixtures can continue now. They are not premature runtime feature implementation.

There is a scope ambiguity worth keeping visible: some open issues already describe the future features meant to wait for architecture, notably **Present Pixiv Multi-Image Works (#140)** and **Bookmark Pixiv Works and Images (#141)**. Interpreting 'all open issues first' literally would create a circular prerequisite. Do not silently include those deferred features in stabilization, close them, or override their design dependencies. Agree the current-work cohort before assigning implementation.

The immediate UI items remain **Fix Browse Search Toolbar Overlap (#146)**, **Unify Android Timeline System Bars (#147)**, **Standardize Timeline Header Scrolling (#148)** and **Fix Floating Pixiv Titlebar Background (#131)**. The latter's filter behavior needs the placement decision below. Existing Feed-freeze and keyboard-dismiss reports still need reproduced evidence rather than assumed fixes.

## 4. Pixiv Public/Private control variants

The user does not need frequent visibility switching while deep in a Favorites list. The current separate row was selected for consistency with other Pixiv controls, not because it must always be visible. Its vertical cost is a valid concern.

| Variant | Vertical cost | Scroll behavior | Tradeoff |
| --- | --- | --- | --- |
| Separate segmented row | One additional row at top | Scrolls away; does not automatically return | Familiar, explicit; uses the most space. |
| Header visibility menu | No extra row | Returns with Header | Compact; current Public/Private value must remain discoverable. |
| Timeline Toolbar selector | No additional standalone row | Follows configured toolbar behavior | Reuses sorting/filter pattern; consumes horizontal toolbar space. |

Preferred candidate: a compact Header menu showing the active value (for example, `Public` with a chevron), rather than an unlabeled gear hiding the current scope. Compare it with the other variants; it is not yet approved.

No `All` option is assumed. The current client deliberately defines `PixivBookmarkVisibility { public, private }` and validates cursor scope against visibility. Its comment states that All support is unverified. A native combined endpoint or a correctly merged pair of independent paginated streams would be separate work; do not fake All by concatenating one page of each.

Source: `packages/booru_clients/lib/src/pixiv/pixiv_client_bookmarks.dart` at the pinned baseline.

## 5. Viewer Controls on Open: desired behavior

The accepted label uses Title Case. The saved preference initializes visibility only on creation of a new viewer session/route. It is not a recurring policy on every page.

Required behavior for eventual implementation:

- New viewer: initialize from Visible/Hidden once.
- User tap toggles controls; preserve that choice while swiping between Posts in the same viewer session.
- Opening/closing details and temporary source loading must not re-read the initial preference as a command.
- Back to an existing viewer restores its session state rather than initializing again.
- Group pages may need their own navigation Header; showing that Header must not overwrite the media-overlay state restored when returning to a Post.
- A genuinely newly opened member viewer is a new session; distinguish that from changing pages in an existing session.
- Accessibility/keyboard escape and visible recovery controls must remain available when appropriate; do not inherit stale hidden-only controls into an error page.

The current code reapplies `initialHideOverlay` on compact-layout post changes in `post_details_page_view.dart`. This is a required behavior change, not just a string rename. Default values and stored enum values stay compatible. No production change is made here.

## 6. Double-tap: experiment with an aspect-aware Classic interaction

### Accepted interaction

One double-tap zooms in; the next returns. No mandatory three-step cycle. Snap to Fit is not the reported problem. Particularly tall images use the existing Comic behavior rather than imposing a giant default double-tap jump on all media.

Current Classic normally uses 3x and switches to other-dimension fitting for a large aspect mismatch. The target is therefore not always 3x. Fit Cycle adds a second enlarged stage; removing that stage and improving the first target are separate changes.

### Geometry

Let image ratio be `a = imageWidth / imageHeight` and actual usable viewport ratio be `v = viewportWidth / viewportHeight`.

From Contain Fit, the multiplier required to fit the other dimension is:

`q = max(a / v, v / a)`.

For an illustrative 400x800 viewport: a square needs 2x to fit height; a 1200x1800 portrait needs 1.333x; a 1600x900 landscape needs 3.556x; a 4000x1000 panorama needs 8x. These are geometric calculations, not preferred final settings.

The viewport is the actual media rectangle after UI displacement/insets, not blindly the whole physical screen. Recalculate after orientation/layout changes. Guard invalid dimensions and finite values.

### Candidates to compare visually

- **Other Fit:** `q`. Closest to the user's square-image example, but nearly matching images barely change and extreme panoramas can jump too far.
- **Bounded Fit:** `clamp(q, minimumUsefulZoom, maximumDoubleTapZoom)`. Simple, predictable. Prototype values 1.35 and 4.0 are exploratory controls, not accepted constants.
- **Soft-Capped Fit:** retain ordinary aspect fit through a threshold, then increase more gently for extreme wide images. More complex; include only as a comparison, not an automatic preference.

The prototype should expose thresholds and actual targets so the user can compare square, portrait, screen-matched, landscape, panorama and Comic cases. Pinch zoom remains independent; a double-tap cap is not a new global pinch maximum. Preserve video seek and profile-configured gesture overrides.

### Reset and Comic cases

Proposed reset: return to the meaningful pre-double-tap baseline, including its pan position, rather than always `Matrix4.identity()` when Comic mode established a fit-to-width reading position. From an already manually zoomed state, the next double-tap should move toward that baseline instead of advancing another zoom cycle. The exact baseline after manual panning and orientation changes requires testing.

For Comic mode, compare a modest detail increment from the current reading baseline versus a dedicated Overview/Read toggle. Do not silently select either. An explicit overview action may be clearer than overloading ordinary zoom/reset.

Test near-equal aspect ratios, low-resolution media, unknown dimensions, source quality upgrades, cancelled animations, double taps near edges, selected text/details, rotations, restored viewer state and previous/next navigation. Tests should use tolerances and animation completion, not exact floating-point identity as the only notion of reset.

## 7. Pixiv Related Works: feasibility and integration

### Evidence

The PixivPy implementation exposes `GET /v2/illust/related` with `illust_id`, `filter` and continuations that can include `offset`, `seed_illust_ids[]` and `viewed[]`. This is a concrete independently maintained client implementation, not an official Pixiv API stability guarantee or an authenticated acceptance pass for Boorusama.

Boorusama's current `PixivClient` has `/v1/illust/recommended`, which is a personalized feed, but no Work-specific related method. Those endpoints are not interchangeable.

References:

- https://github.com/upbit/pixivpy/blob/master/pixivpy3/aapi.py (inspected blob `f6ffd24f9ea6e21e8810fa63a2d5c072f5817e9e`, `illust_related` implementation).
- https://github.com/timberpile/Boorusama/blob/e306ff5338a2255a89731c61bd0672336a933344/packages/booru_clients/lib/src/pixiv/pixiv_client.dart
- https://www.pixiv.help/hc/en-us/articles/54499251340825-What-are-Access-Analytics (official help identifies Other Works and Related Works as distinct traffic sources).

### Recommended UI and loading contract

Show `More by This Artist` and `Related Works` as separate sections below the current Work's actual details, using the existing Danbooru-style related-content card/section components. Avoid a redundant Uploader section for Pixiv when creator and uploader refer to the same account.

Load a bounded first related page when that section becomes relevant, not for every timeline card or every image page in the same Work. Cache by Work plus appropriate profile/policy context; deduplicate in-flight requests across its pages. Exclude the currently viewed Work, preserve source order, and apply existing visibility filters.

Related results are Work recommendations, not members of the current Work or a canonical Danbooru family. Opening one creates a new navigation occurrence and Back restores the previous Work and detail scroll position. A failure in this optional section must not fail the primary Work viewer. Additional requests use validated endpoint-specific continuations; never forward credentials to arbitrary next URLs.

A later authenticated acceptance test must confirm response shape, pagination, unavailable/restricted works and request budgets. No such live call has been performed in this task.

## 8. Architecture and UI visual deliverables

The requested visual package separates:

- Conceptual classification from actual proposed inheritance/composition.
- Data/reference/member types from provider sessions and Widgets.
- Remote content groups from local Bookmark Groups.
- Work membership from recommendations.
- Resource identity from access context and repeated occurrence.
- Shared reusable components from different resource-specific compositions.

Proposed type names remain editable. The diagrams should not make `Post` inherit a newly mandatory `ContentItem`. Use an optional narrow listing sum/wrapper only where a consumer needs to display both media and group summaries.

UI variants should show a media-first Pixiv Work, shared artist/action/details sections below, Related Works at the bottom, normal Pool layout, nhentai Gallery composition, and Series -> Work -> Page navigation. A single-image Work must not require a pointless extra gallery step. Ugoira remains one animation; the demo must not offer an impossible Ugoira page sequence. Native Manga Series examples must use Manga Works, not ordinary Illustration membership.

## 9. Publication and acceptance

This branch is a durable design workspace, not an additional task tracker. GitHub Issues remain the only task tracker. Publish meaningful documentation/mockup increments; no PR, develop merge, issue closure or runtime implementation is implied.

Preserve the previous research, list later corrections explicitly, and keep an entry-point document linking the diagrams and standalone HTML files. The HTML must work locally without a build, server or external assets. Record actual browser checks and remaining Android/runtime verification separately.
