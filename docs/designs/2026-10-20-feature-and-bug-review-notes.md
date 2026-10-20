# Feature and Bug Review — Working Notes (2026-10-20)

> **Status: discussion archive / provisional research, NOT an approved design or implementation plan.**
>
> This file is deliberately kept on the isolated branch `maintenance/feature-review-notes-2026-10-20`. Do **not** merge it into `develop` or create GitHub issues from it automatically. Work through the 23 items with the user in the original order; create an issue for an item **only after explicit user instruction**. The user's follow-up observations below are tentative, not final product decisions.

## Provenance and reading guide

- Source: the 23-item feature/bug list discussed on 2026-10-20 and the subsequent review and user clarifications.
- Inspected repository baseline: `develop` at commit `7d58c7d86786fe3f891cb2810f615fc9adef07d5` (2026-10-20). Some related changes may exist only on feature branches.
- Confidence varies: **Observed in source** means directly supported by inspected code; **suspected** means plausible but not reproduced; **proposal** is a design candidate rather than an agreement.
- No device-level reproduction, profiling, or complete runtime test suite was performed for these notes. Effort estimates (S/M/L) are only rough relative sizes.
- The user calls pinned searches/topics and topic feeds by several names; the implementation currently uses `following_topics`/`FollowingTopic` in several places.
- The final wording, interaction behavior, priorities, and ticket boundaries are to be decided in the individual discussions.
- Repository convention: issue descriptions, design notes, and implementation documentation must be in English.

## Quick index

| # | Topic | Estimated effort | Present confidence / status |
|---|---|---|---|
| 1 | App-wide action labels, icons, and Title Case | M | Style principles agreed; UI audit still needed |
| 2 | Non-shrinking image-to-details scrolling in existing viewer | M | Focused dock/scroll idea under review |
| 3 | Customize URL/engine when duplicating a profile | M | Scope narrowed by user |
| 4 | Local custom profile icons and export | M | Deprioritized; PNG sufficient |
| 5 | Bookmark pools/series and mixed timeline entries | L | Product model unresolved |
| 6 | Pretty, category-colored pinned-query display | S–M | Raw query display confirmed |
| 7 | Pinned searches on Realbooru | S–M | Needs reproduction |
| 8 | Video badge on Realbooru | S | Likely classification issue |
| 9 | Viewer media and metadata prefetch | M | Media prefetch already exists |
| 10 | Find Pixiv post via Android Share | M | Share target already registered |
| 11 | Replace suitable confirmations with Undo | M | Undo exists for some bookmarks |
| 12 | Bookmark-style filtering in topic feeds | M | Snapshot-only scope proposed |
| 13 | Progressive loading up to Original quality | M | Original enum already exists |
| 14 | Recognize/persist the historical end of topics | M | Per-session `hasMore` exists |
| 15 | Mark Pixiv engine experimental | S–M | Supported as a code/UI policy |
| 16 | Reuse full query editor for topics | M | Current dialog uses raw text |
| 17 | Android 11+ custom download directories | M–L | SAF possible; needs URI-aware pipeline |
| 18 | One cancellable bulk-download notification | M | Partial notification infrastructure exists |
| 19 | Bookmark download quality/naming/duplicates | M | Inconsistent code paths confirmed |
| 20 | Scroll-to-top button remains visible at top | S | Plausible shared-component defect |
| 21 | Artist page information architecture | M | Current Danbooru composition inspected |
| 22 | Four previews without new-post tracking | S–M | Tracking/preview coupling confirmed |
| 23 | Resume a pinned topic from a chosen position | M | Needs separate reading cursor |

## 1. Audit action wording, icons, and capitalization throughout the app

**Original request.** Prefer concise labels that use meaningful icons instead of redundant verbs: “Add to global blacklist” → “+ Global blacklist”; “Add to account favorite group” → “+ Account favorite group”; “+ Create new group” → “+ Group”.

**Agreed direction (2026-10-20).** Widen this to an **app-wide audit** of headings, buttons, menu labels, and other short UI copy. Use English **Title Case** (also called headline-style capitalization) for short interface labels, with important words capitalized. This is the agreed style direction, not approval of every individual rewrite.

**Interpretation/examples.**

| Sentence case / verbose | Possible new presentation |
|---|---|
| Add to global blacklist | `[plus icon] Global Blacklist` |
| Add to account favorite group | `[plus icon] Account Favorite Group` |
| Create new group | `[plus icon] Group` |
| Download settings | Download Settings |
| Find in another profile | Find in Another Profile |
| Recently viewed posts | Recently Viewed Posts |

**Agreed capitalization rule:** Title Case for short English headings, labels, buttons, and menu actions; sentence case for explanations, notifications, error sentences, and body text. Apply locale-specific grammar outside English; do not mechanically Title-Case German. Distinguish add, remove-from-list, and permanent delete. Icon buttons still need semantic labels/tooltips. Favor actual icon widgets rather than embedding `+`/`-` characters in localized strings.

**Agreed terminology rule:** Capitalize the official names of app features consistently **even inside otherwise sentence-case prose**: e.g. "The post is hidden by your Global Blacklist." and "Open Topics to manage your saved searches." Apply this only when referring to a named UI feature or destination, not to generic words ("This feed has no posts"). Maintain a small canonical glossary for names such as "Global Blacklist", "Topics", and "Feeds"; verify the final names against real navigation labels. In localized languages follow natural grammar, while preserving intentionally named features. **Agreed emphasis principle:** Plain Title Case is the default. Use **bold feature names selectively** when it improves comprehension in explanatory text, hints, or dialogs; do **not** bold every mention or routinely bold labels, dense menus, and notifications. The exact placement remains subject to UI review and examples; validate readability, accessibility, and localization before adopting rich-text resources widely.

**Assessment.** A coherent microcopy/style pass is useful but larger than the initial examples. Audit all existing screens, avoid changing actions or accessibility, and compare consistent Kurumi components. **Effort M; UX value high.** Style direction agreed; remaining implementation decisions include the canonical feature-name glossary, the exact UI copy inventory, icon semantics, exceptions for clarity, and which explanatory passages benefit from selective bold. No GitHub issue or implementation is authorized yet.

## 2. Retain the Existing Viewer; Make Image-to-Details Scrolling Continuous

**Original intention.** Achieve the sense that the details page is physically attached to the image. Do not make users switch abruptly between an image view and a details view; preserve existing zoom/pan, horizontal post navigation, and the rest of the viewer's strengths.

**Latest user proposal (2026-10-20, still provisional; supersedes the earlier much larger redesign).** The current upward swipe initially moves the image toward the top of the screen and slides the details panel toward the bottom edge of the visible image; this animation already feels good. Keep it. The objection is that **after the image's empty top/bottom margins disappear, continued dragging reduces the displayed image size**, followed by a hard snap into the details sheet. Instead:

1. Keep the current media size while the existing top/bottom gaps close, until the details region physically **docks immediately below** the image.
2. If the gesture ends **before docking**, spring/snap back to the initial image view.
3. Once docked, **do not snap into another details mode** and do not shrink the image. Continued scrolling moves the full-size (fitted) image *up and off screen* while the attached details follow naturally, as one vertically moving layout.
4. Scrolling back up reveals the image in reverse, without a mode-switch jump. Once the image view is reached, the existing resting state can resume.
5. It is acceptable that the post image is **not visible while reading further down the details**.

**Code findings (observed on `develop` at `7d58c7d`).**
- `lib/core/posts/details_pageview/src/post_details_page_view.dart`: `_buildMain()` allocates `Expanded(_buildPageView())` followed by `_buildBottomDisplacement()`. The latter uses the sheet's pixel displacement as spacer height, thereby making the viewer viewport shrink as the panel rises. `_onSheetChanged()` stops following displacement above `maxSize`.
- `lib/core/posts/details_pageview/src/drag_sheet.dart`: uses a `DraggableScrollableSheet` with snap points at 0, `maxSize` (normally 0.7), and 0.9. The provided draggable scroll controller is used by the drag handle, whereas the details content currently uses a **separate** `_contentScrollController`. Both snap policy and scroll handoff need examination: simply disabling image scaling does not guarantee a seamless continuous gesture.
- `lib/core/posts/details_pageview/src/post_details_page_view_controller.dart`: sheet open/reset and drag-end logic currently snap toward a fixed `maxSize` or back to zero, and sheet expansion is a discrete state.
- `lib/core/posts/details/src/widgets/post_details_item.dart` and Kurumi `interactive_viewer.dart`: existing pinch/double-tap zoom and pan already work; zoom disables page/sheet swipes through the transformation callback. Preserve those behaviors instead of adding a forced tap-to-enter fullscreen zoom.
- `lib/core/posts/details/src/widgets/post_details_page_scaffold.dart` builds existing details slivers; do not replace their content or eager-load everything. Automatic comic-strip enlargement for unusually tall images remains a separate configurable behavior to verify.

**Scoped implementation direction to evaluate, not yet approved.** Keep the same `PageView`, media widgets, sheet contents, and zoom controls; change the **layout displacement and sheet scrolling behavior**. Let viewport height be `H`, fitted media height be `h` (with `h <= H`), and rising sheet displacement be `d`. While `H-d >= h`, preserve the existing shrinking *empty margins* and corresponding image translation (the media itself remains the same size). At the **dock point** `d = H-h`, the image fills the remaining upper area and the details meet its bottom edge. Beyond docking, keep the media size fixed; translate/clip its viewport upward in step with `d` rather than re-fitting to a smaller viewport. Continue moving the details upward with the same motion. Allow the docked view to occupy the full height, and hand scrolling over to details content without a hard intermediate snap. Use measured visible media geometry, respecting per-post aspect ratio, video, and safe areas.

**Gesture/snap contract to prototype.** Only the *pre-dock* phase is allowed to spring back on release. After reaching the dock point, release should stop naturally (with suitable momentum) rather than snap to the old 0.7/0.9 sheet points. Return gestures should scroll details to top, then pull the docked image back down; a deliberate Info button or Back action may explicitly navigate between positions, but should not introduce surprise snaps. Avoid competing scroll controllers and avoid requiring a separate zoom mode. Test quick flicks, slow drags, interruptions, orientation changes, post switches, overlay visibility, and movement while zoomed.

**Aspect-ratio edge case.** Very wide images can have large blank margins in the existing initial full-screen layout, making the distance `H-h` to dock unusually long. The earlier idea of showing details immediately beneath a short/wide image is **not a current decision**; test whether to shorten that gap or animate through it instead of forcing the user to make an enormous swipe. Extremely tall images should initially fit no larger than a viewport, except for the separately controlled comic-strip mode.

**Further UX refinement (user observation, 2026-10-20; not yet approved).** The user's main discomfort may be the **perceived jump** between viewing the image and reading details, not the sheet layout itself. They are happy with most existing viewer behavior and are uncertain whether the larger docking/continuous-scroll proposal is needed. In particular, very wide images make the docking distance long, and abandoning snap entirely would allow unattractive intermediate states with dark/empty space. Prefer testing a **minimal animation-and-snap improvement first**:
- Keep two stable resting destinations: the usual image view and a visually attached/usable details view. Intermediate geometry is permitted only *during* drag or animation, never as an idle resting state.
- Keep the image at a stable fitted scale instead of shrinking as the sheet takes more viewport height; animate its position and/or clip/occlude it behind the rising details surface. Do not create a visibly shrinking "post thumbnail" effect.
- Make the interactive drag, release, and animated finish form a continuous motion (velocity-aware with a bounded duration), without a sudden change in transform, brightness, scroll origin, or a second snap on completion.
- For short/wide images, avoid a required several-hundred-pixel drag before the layout docks: use a reasonable gesture threshold/velocity to **animate the remainder** into a stable attached destination. An adaptive normalized progress mapping and/or surface-backed gap during movement might help, but need direct visual comparison. Never leave black space as an unlocked stable position.
- When closing from the top of the details area, reverse the same transition rather than instantly resetting to a centered image. Preserve the existing background/overlay conventions, gesture configuration, zoom, and horizontal paging.
- **Decision still open:** whether smooth two-state sheet transition alone feels right, or whether continuous scrolling past dock is necessary. Prototype the smaller transition first and compare the exact perceived result to current behavior before committing to scroll-controller refactoring.

**Assessment.** This is **smaller in architectural scope** than a new continuous document viewer, but it is not just an animation constant: displacement geometry, `DraggableScrollableSheet` snap policy, nested scroll handoff, and zoom gestures interact. Treat as a **focused existing-viewer UX modification**, probably **M** rather than L after a targeted prototype. No implementation, GitHub issue, or final design approval yet.

## 3. Change profile URL/engine during *duplication*, not in place

**Original request.** Change existing profile URL/engine and consider dangerous side effects.

**Updated user direction (provisional and important scope reduction).** Primary need: **duplicate an existing known profile and edit the URL while duplicating it**. Editing URL or engine on an already-created profile is **not required**. Allowing an alternative engine when creating the duplicate is a possible extension, still to confirm.

**Assessment.** This avoids the main data-migration hazard of rewriting existing profile identity. New duplicate must receive a **new profile ID**, preserve the original unchanged, validate new URL/engine compatibility, and avoid silently copying secrets to a different host. Review which settings to copy (display prefs, filters, credentials, server-specific capabilities, pinned searches) and which to reset. Do not reuse source-profile tracking checkpoints or imply that post IDs identify the same database across hosts.

**Code boundary.** Profile create/manage/config data live under `lib/core/configs/`. **Effort M**, notably safer than retroactive URL mutation. Open: should engine selection be enabled, what is copied, and whether authentication defaults to cleared on changed host.

## 4. Select local custom profile icon; include it in exports

**Original request.** Choose own icon, resize to small dimensions, save as JXL if possible, and include it in exports.

**Observed in source.** An **icon URL field** and `ProfileIconConfigs.url` already exist (`lib/core/configs/appearance/src/widgets/profile_icon_url_field.dart`; `lib/core/configs/config/src/types/profile_icon_configs.dart`). This is not yet equivalent to importing a local binary icon.

**Updated user direction (provisional).** **Low priority / leave for later.** JXL is only a format experiment / nice-to-have; **PNG is fully acceptable**.

**Proposal.** File picker; decode/crop/resize to a small bounded square; store a local managed icon asset; include binary data with portable manifest/reference in backup/export; restore without relying on old device paths; permit removing/replacing the icon. Start with PNG; evaluate JXL only after verified encoding/decoding support across supported platforms. **Effort M, deferred.**

## 5. Bookmark whole pools or series; possibly use mixed timeline entries

**Original request.** Bookmark pools (including Danbooru series pools); possibly let pool/series entries appear alongside ordinary posts in one feed or bookmark timeline.

**Related ongoing work.** Branch `feature/group-neighboring-series` has a design/initial pure grouping primitive but is **not yet integrated**. That document explicitly prefers ordinary post bookmarks and display-only adjacency grouping; it **rejects** a separate `SeriesBookmark` entity. Relevant branch design: `docs/designs/2026-10-11-neighboring-series.md` on that feature branch, not on `develop`.

**Updated user direction (provisional).** **Revisit that design carefully**, rather than accepting an incomplete/half-functional pool solution. Nothing is finalized.

**Unresolved product models.**
1. **Save all members as individual bookmarks** (existing proposed model): existing data behavior, stable offline post list; updates to the remote series are not automatically tracked.
2. **Save a reference to a pool**: a compact durable entity that resolves potentially changing membership; requires cross-site identity, caching, offline behavior, deleted/renamed pools, and export rules.
3. **Both**: explicitly distinguish “Bookmark Pool” from “Bookmark All Posts”; complexity rises but semantics are clearer.

Mixed `Post` / `Pool` / `Series` feed entries could be a general display abstraction without making them interchangeable storage objects. Define count semantics, selection/actions, navigation, filters, ordering, and partial visibility. **Effort L, architecture/product discussion required.**

## 6. Pretty, colored query when used as pinned-search title

**Original request.** Query-as-name should replace underscores with readable spaces.

**Observed in source.** `FollowingTopic.displayName` falls back to the raw `query` when `name` is null (`lib/core/search/following_topics/src/types/following_topic.dart`).

**Updated user direction (provisional).** **Not just plain white text.** Show the default query title in the same colored/tag-style presentation used for ordinary search terms, with category colors and readable names.

**Proposal.** Build a view-only token/chip representation from the structured query when available, with fallback parsing for old raw queries. Replace underscores **only in display text**, preserve the canonical stored query and any operators/metatags/negations. Unknown categories use neutral styling. Respect tight card widths, text scaling, overflow, and no unnecessary metadata/network lookup per card. User-defined custom names remain user-defined names. **Effort S–M; likely best coordinated with query-editor work #16 and tag-color consistency Issue #48.**

## 7. Are pinned searches unavailable on Realbooru?

**Original request.** Investigate why following/pinning appears unavailable for Realbooru.

**Observed in source.** `FollowTopicButton` is not intrinsically dependent on a supported new-post refresh adapter; the shared UI can display a follow action for a nonblank query. Tracking support and storing a following topic are distinct concepts (`topic_follow_control.dart`, `search_refresh_query_adapter.dart`).

**Assessment.** Cannot yet confirm the exact symptom. Reproduce from the actual Realbooru profile screen: absent action, disabled action, failed creation, or only warning about new-post tracking? Realbooru may use a Gelbooru-like engine with different API capabilities. Avoid conflating #7 with #22; one is entry/availability, one is preview behavior after following. **Effort S–M pending reproduction.**

## 8. Show video badge for Realbooru videos

**Observed in source.** Shared `ImageGridItem` already supports a play icon when `isAnimated` is true, including unknown duration. In the inspected Gelbooru V1 parser, `format` is derived from the file URL; exact Realbooru parsing/classification needs verification (`lib/boorus/gelbooru_v1/posts/parser.dart`).

**Assessment.** Check a real video post through the post DTO → mapped media type / `isAnimated` → grid overlay pipeline. Reuse the shared badge, not a Realbooru-only badge component. Test GIF versus true video, missing duration, audio indicators, and unavailable preview URLs. **Effort likely S; root cause not reproduced.**

## 9. Prefetch up to three next posts and reverse-direction posts

**Original request.** Prefetch the next approximately three posts' media **and metadata**, and preceding posts when moving back.

**Observed in source.** Direction-based **media preloading already exists** under `lib/core/posts/media_preload/src/`, notably `preload_strategy.dart`. It begins conservatively, adjusts offsets based on direction/confidence, can extend to three posts in the active direction, and treats direct entry specially (thumbnails only). Backward direction is already modeled.

**Assessment.** First instrument/verify actual behavior rather than reimplementing it. Separate thumbnail, display-quality media, original quality, and **full post details**; the last category may still need prefetch. Bound concurrency/memory/data usage, cancel stale tasks, honor profile credentials, and prioritize visible media. Avoid eagerly prefetching three originals (see #13). **Effort M for extending/validating; potentially S for a focused fix.**

## 10. Pixiv Share → find the artwork on configured Booru profiles

**Original request.** User has an artwork in Pixiv and wants to find it inside Boorusama.

**Observed in source.** Android's main `AndroidManifest.xml` already declares an `ACTION_SEND` intent-filter for `text/*`, i.e. a text-sharing entry point. The actual Pixiv share payload/receiving flow must be tested. Existing **Issue #49 — Find post in another profile** uses exact original MD5 from a Boorusama post and does **not** fully cover starting from an external Pixiv link.

**Updated user direction (provisional).** Share from Pixiv to **Boorusama**, open the app, and either:
- choose one eligible destination profile, then search; or
- automatically search **every configured profile that can support the appropriate Pixiv-source filter**, group results by profile, and choose the result to open.

**Feasibility / proposed flow.** Extract and normalize Pixiv illustration URL/ID (including common share-link variations); derive profile-specific query only when that engine/site supports a verified lookup syntax (for instance Danbooru's Pixiv-ID metatag); launch scoped requests with each profile's own credentials, restrictions, and rate-limit handling. Parallelism must be bounded; support cancellation, explicit unsupported-profile/no-match states, multiple matches, and no silently inferred exact image identity. Do not depend on the experimental Pixiv engine for basic external-link lookup.

**Key UX question.** Default to **Search All Supported Profiles** for convenience, or require a chooser to avoid unexpected requests and potentially exposing the artwork ID to every configured host? Both are technically feasible. Also check what Pixiv actually shares on Android. **Effort M.**

## 11. Replace safe, frequent removal confirmations with Undo

**Observed in source.** Bookmark removal already has an Undo toast mechanism (`lib/core/bookmarks/src/providers/bookmark_provider.dart`, `showRemovalUndo`).

**Proposal.** Audit existing confirmation dialogs across the app and classify actions by frequency, reversibility, server-side impact, and data loss. Use immediate action + Undo for reversible local removals; keep confirmation for permanent file deletion, destructive reset, broad cleanup, or actions that cannot reliably be reversed. Preserve group membership, order, and other state on undo. Handle failures and concurrent undo requests. **Effort M; audit scope needs inventory.**

## 12. Bookmark-style filtering inside topic feeds — cached snapshots only

**Original request.** Apply the same filter controls as bookmarks to topics feed.

**Observed in source.** Bookmark selectors support tag inclusion/exclusion, originating site selection, and sorting in the in-memory library (`lib/core/bookmarks/src/providers/bookmark_group_selectors.dart`). Topic feeds have a separate snapshot/history architecture.

**Updated user direction (provisional).** **Search/filter only the already stored snapshots**. While filtering is active, disable historical pagination / loading older remote posts. Resume normal history pagination when the filter is cleared. Avoid background-fetching arbitrary older pages to satisfy local filters; performance should remain bounded.

**Proposal.** Reuse the recognizable bookmark filtering UI, apply predicates only to cached feed post snapshots, clearly communicate “Filtering saved posts” and empty-match states, preserve the original feed query and data. Account for incomplete cache coverage and deterministic ordering. No network calls from the filter action. **Effort M; substantially more bounded than a remote cross-topic search.**

## 13. Progressive image loading ending in Original quality

**Original request.** Add “Original post quality” while still displaying/loading intermediate qualities first.

**Observed in source.** `ImageQuality.original` already exists (`lib/core/images/image_quality.dart`), and the details toolbar has a manual Load Original action in supported contexts. The unresolved requirement is **automatic progressive media display**.

**Proposal.** Resolve only actual distinct URLs, show thumbnail → sample/high-quality → original in order with seamless visual replacement and appropriate fallbacks. If a stage fails, do not block another valid stage. Avoid downloading redundant byte-identical variants and respect device memory, network policy, and viewer prefetch limits. Decide whether this is a separate viewer option rather than changing the existing explicit Original action. **Effort M.**

## 14. Recognize when a topic/feed has reached its oldest post

**Observed in source.** `FeedHistorySession` has per-source pagination cursors and session-local `hasMore` state. The persisted `FollowingTopic` has a highest-seen ID/checkpoint for **new-post tracking**, not an explicit durable oldest-post/exhausted boundary.

**Proposal.** On a reliable end-of-history response, persist a per-source historical-end marker and avoid unnecessary retries. Distinguish true exhaustion from API caps, failures, zero visible results caused by filtering, and temporarily unavailable sources. Invalidate/re-evaluate markers for query/profile changes and other relevant events. Expose an intelligible end-of-topic/end-of-feed state. **Effort M.**

## 15. Make Pixiv engine explicitly experimental

**Original request and direction.** Label Pixiv as experimental in UI **and code/docs**, and avoid letting it determine core booru abstraction decisions. It is a limited curiosity rather than a priority full-featured engine.

**Observed in source.** Pixiv has its own booru adapter, routes, and navigation code under `lib/boorus/pixiv/`.

**Proposal.** Add an Experimental indicator with limitations in profile creation and settings; document intentionally unsupported behaviors, provide user-facing explanation, avoid speculative generic abstractions solely to accommodate Pixiv. This does **not** waive security, correctness, or data-integrity requirements. **Effort S–M.**

## 16. Rich query editing with suggestions for topics

**Original request.** Topic query editor should use real tags/suggestions rather than raw text; ideally reuse full search query editor.

**Observed in source.** `edit_following_topic_dialog.dart` has a plain `TextField` for query. `SearchQueryStructure` can already represent typed tags and validates correspondence to the canonical query.

**Proposal.** Integrate a shared query-editor component with colored tags, operators, site-specific suggestions, and raw-syntax editing. Use the edited topic's chosen profile to resolve capabilities. Do **not** accidentally execute/commit a remote refresh on each keypress within the edit dialog; save/validate atomically, preserving unsupported syntax losslessly. Coordinate with #6 and the separate search filtering UX work. **Effort M.**

## 17. Android 11+ download targets outside public directories

**Original request.** Check whether the warning that downloads must be in public directories is truly unavoidable.

**Observed in source.** `lib/core/downloads/background/downloader.dart` rejects Android paths lacking a recognized public directory on newer SDKs. That is a **current application/transport policy**, not proof that Android exposes no alternatives.

**Assessment.** Android's Storage Access Framework (SAF) can grant persistent user-picked URI access to supported folders, subject to Android restrictions. Merely disabling the guard will not make arbitrary paths writeable. A robust alternative needs a URI-aware file-writing implementation, persisted grants, handling of provider/SD-card disconnection, correct background task integration, duplicate detection, and sidecar files. Some restricted roots remain inaccessible. Relevant platform documentation: https://developer.android.com/training/data-storage/shared/documents-files . **Effort M–L; requires architecture/transport verification.**

## 18. One notification per bulk download operation, with total progress and Cancel

**Observed in source.** There is a bulk-progress notification abstraction (`lib/core/downloads/background/notification.dart`) as well as native individual task notifications. The paths may emit too many visible notifications during mass downloads.

**Proposal.** Give every bulk session an ID and one continuously updated summary notification (completed / total, bytes if reliable, failures, cancellation). Expose Cancel for **that operation**, not necessarily every download in the app. Suppress noisy per-file notifications during the session; summarize failures and final completion. Ensure cached/skipped tasks count correctly, and handle app restart, simultaneous sessions, and Android notification permission. **Effort M; related to #19.**

## 19. Bookmark downloads use different names/quality; duplicate detection inconsistent

**Observed in source — directly confirmed.** Bookmark download path in `lib/core/bookmarks/src/providers/bookmark_provider.dart` uses `bookmark.originalUrl`, labels metadata quality as `original`, and calls `fallbackFileNameBuilder`. Normal search/viewer download in `lib/core/downloads/downloader/src/providers/download_notifier.dart` computes effective download quality from settings and uses a configured filename generator. This explains reported differences. Actual duplicate behavior still needs reproducing.

**Proposal.** Refactor bookmark and regular post download entry points to a shared policy for resolved originating profile, desired quality, URL selection, generated filename, and existing-file identity. Preserve credential isolation for mixed-profile bookmarks. Distinguish deliberate variant downloads from duplicate same-file downloads; ensure sidecars match the actual quality. Add tests for profile-specific filename patterns, settings, equal origins, cache/skips, and destination-path behavior. **Effort M; high-confidence/high-value fix.**

## 20. Scroll-to-top button does not disappear at top after manual scroll

**Observed in source — plausible root cause.** `packages/kurumi/lib/src/components/scroll_visibility.dart` updates top-state within the scroll-direction-change branch and tests exact `offset == 0`. If the user continues scrolling in one direction until reaching the boundary, the component may not re-evaluate visibility at the moment it reaches the top.

**Proposal.** Update visibility on position/boundary changes, not only direction changes; use a sensible epsilon/extent guard rather than exact floating-point equality. Cover manual dragging, ballistic scrolling, content resizing, programmatic jump, controller replacement, and accessibility animations. **Effort S; runtime reproduction still necessary.**

## 21. Overhaul the artist page

**Observed in source.** Danbooru artist page is built by combining tag details, alternative names, URL chips, and an artist tag cloud (`lib/boorus/danbooru/artists/artist/src/pages/artist_page.dart`). The distinction between primary social links, related tags, and wiki material is not very explicit.

**Proposal.** Introduce recognizable sections: artist identity/aliases, primary external/social links with platform icons, direct wiki link and summary/availability, related tags, and posts. Keep high-frequency navigation/actions easy to reach and preserve existing Follow Topic support. Check API availability for wiki and social link metadata before selecting UI. **Effort M; start with Danbooru rather than over-generalizing.**

## 22. Populate four previews even when tracking is unsupported

**Original request.** “New-post tracking is unsupported for this search.” should not prevent four search thumbnail previews.

**Observed in source.** `SearchRefreshService.refresh` handles `UnsupportedSearchRefreshQueryPlan` before its normal fetch, and the snapshot processing ties previews to post creation timestamps. That coupling is unnecessary for simply displaying recent matching thumbnails.

**Proposal.** Decouple “fetch up to four preview posts” from “calculate trustworthy new-post changes.” Fetch a bounded first page when the query is executable; preserve a distinct **tracking unsupported** status, without committing false new-post checkpoints. Do not repeatedly fetch on every repaint; respect cancellation, authentication, and network limits. **Effort S–M; closely connected to #7.**

## 23. Resume a pinned topic from a selected post/position (oldest → newest)

**Original request.** Progressively work through a pinned query such as `my_tag order:id` from old posts toward new posts; select a post and continue “from here.”

**Observed in source.** Current high-water checkpoint serves new-post refresh, not user's reading/workthrough progress.

**Proposal.** Add “Start / Resume from Here” on a post, persist a **separate browsing cursor** scoped to topic/profile/query/sort order, and provide a clear way to resume or reset. For Danbooru-like engines that support ID order and ID-range filters, compose a verified query (e.g. `order:id` with an ID bound) without silently overwriting the original followed query. Handle removed posts, updated search filters, and sites without stable ID ordering. Distinguish “read up to this post” from “start at this post” inclusive/exclusive semantics. **Effort M; depends partly on topic/history design.**

---

## Existing related work and proposed discussion order

- Follow **#1 → #23** in the original order. **Conversation workflow agreed 2026-10-20:** continue directly into the next issue after covering the current one; do not wait for permission merely to advance. Discuss smaller neighboring issues together where useful. Spend dedicated time on major issues (especially #2 post viewer). A design decision does **not** authorize creating a GitHub issue; an issue still requires an explicit instruction. Keep decisions separate from working hypotheses.
- Relevant tracked issue: [#49 — Find post in another profile](https://github.com/timberpile/Boorusama/issues/49), related to but narrower/different from external Pixiv Share (#10).
- Relevant **unmerged** feature branch: [`feature/group-neighboring-series`](https://github.com/timberpile/Boorusama/tree/feature/group-neighboring-series), including a provisional grouping specification. Any future pool/series-bookmark design (#5) must reconcile with it rather than accidentally treating an earlier preference as a final decision.
- Potential shared work: **#1** touches general UI copy; **#6 + #16** involve query presentation/editing; **#7 + #22** cover tracking versus previews; **#9 + #13** cover image fetching; **#18 + #19** cover download infrastructure; **#12 + #14 + #23** cover topic feed history and progress.
- Higher-confidence potential fixes: **#19**, **#20**, **#22**. Larger UX/architecture questions: **#2**, **#5**, and (if expanded) **#17**.
- **No new GitHub issues, PRs, code changes, or merges are authorized by this file.** Amend these notes or file issues only when requested in later discussion.
