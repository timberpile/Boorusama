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
| 2 | Smooth existing viewer-to-details transition | M | Provisional direction agreed; revisit later |
| 3 | Editable target URL while duplicating a profile | — | Not planned; existing duplication + filter editing sufficient |
| 4 | Local custom profile icons and export | M | Deprioritized; PNG sufficient |
| 5 | Bookmark pools/series and mixed timeline entries | L | Explicitly deferred to larger-issue discussion |
| 6 | Pretty, category-colored pinned-query display | S–M | UX direction accepted; not implemented |
| 7 | Pinned searches on Realbooru | — | No bug: following works; tracking deliberately unsupported |
| 8 | Video badge on Realbooru | S | Proposed fix accepted; not implemented |
| 9 | Viewer media and metadata prefetch | S–M | Image behavior investigation accepted; video prebuffer deferred |
| 10 | Find Pixiv post via Android Share | M | Share target already registered |
| 11 | Replace suitable confirmations with Undo | M | App-wide reversible-action audit accepted; not implemented |
| 12 | Bookmark-style filtering in topic feeds | M | Snapshot-only scope proposed |
| 13 | Progressive loading up to Original quality | M | Original viewer quality accepted; prefetch capped at High |
| 14 | Recognize/persist the historical end of topics | M | Per-session `hasMore` exists |
| 15 | Mark Pixiv engine experimental | S–M | Proposed scope accepted; not implemented |
| 16 | Reuse full query editor for topics | M | Current dialog uses raw text |
| 17 | Android 11+ custom download directories | M–L | SAF possible; needs URI-aware pipeline |
| 18 | One cancellable bulk-download notification | M | Proposed aggregate notification accepted; not implemented |
| 19 | Bookmark download quality/naming/duplicates | M | Proposed unified download behavior accepted; not implemented |
| 20 | Scroll-to-top button remains visible at top | S | Proposed fix accepted; not implemented |
| 21 | Artist page information architecture | M | Current Danbooru composition inspected |
| 22 | Four previews without new-post tracking | S–M | Proposed decoupling accepted; not implemented |
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

**Decision to carry forward (user confirmation, 2026-10-20).** Keep the **smaller transition/snap experiment** above as the provisional implementation direction; do **not** commit to the larger continuous-layout redesign. Defer the viewer topic for later discussion and possible prototype. Stable image size, no abrupt transition, sensible snap and wide-image behavior are the current priorities. This is a direction to retain in these notes, **not** an instruction to create an issue or implement it.

**Assessment.** This is **smaller in architectural scope** than a new continuous document viewer, but it is not just an animation constant: displacement geometry, `DraggableScrollableSheet` snap policy, nested scroll handoff, and zoom gestures interact. Treat as a **focused existing-viewer UX modification**, probably **M** rather than L after a targeted prototype. No implementation, GitHub issue, or final design approval yet.

## 3. Allow Editing the Target URL While Duplicating a Profile

**Original request.** Consider changing profile URL/engine. **Clarified desired scope:** The user primarily wants to duplicate an existing known profile while entering a **different site URL during duplication**. In-place editing of an existing profile URL or engine is **not** required. Switching the engine while duplicating is optional/unsettled, not an initial requirement.

**Observed in source (2026-10-20 `develop`).** The **Duplicate** action already exists in the profile management context menu (`lib/core/navigation/profile_management_page.dart`, around lines 53–61), but it **immediately invokes** `booruConfigProvider.notifier.duplicate(config: profile)` without opening an editor. `lib/core/configs/manage/src/providers/booru_config_provider.dart` (around lines 66–77) copies the entire profile with the default name `<name> copy`, passes its data straight into the add operation, and flags `isCopy: true`. The persistent repository already assigns a **fresh canonical profile ID** when `add` is called (`lib/core/configs/config/src/data/booru_config_repository_hive.dart`, around lines 38–46). Thus **the primary missing feature is an editing step before creating the duplicate**, rather than migration of existing identities.

**Relevant existing UI architecture.** The shared profile-creation scaffold already has a name field, configuration sections, a URL data field and add/save operations. `CreateBooruSiteUrlField` supports editable text when given an `onChanged` callback; the generic new-profile URL flow validates/normalizes HTTP(S) URLs. However, `EditBooruConfigNotifier.build` initializes *new* profiles from defaults based on `EditBooruConfigId`, so simply navigating to the add route **will not** preserve source profile settings: introduce a duplicate-specific initial-data path. Known-engine create pages currently use an engine-specific builder; a changed endpoint should be verified compatible with the inherited engine. Generic engine selection is already available for *unknown-site setup* but does not imply safe arbitrary engine changes in duplicate mode. Some engines are single-site and should not offer misleading URL customization.

**Recommended compact UX (not yet approved).** From **Profiles → long-press or context menu → Duplicate**, open a **Duplicate Profile** editor, seeded with a copy of the selected profile and:
- Profile Name: `<name> Copy` (editable).
- Site URL: existing URL (editable with normalization and inline validation; validate engine compatibility before saving).
- Engine: copied from source, initially displayed as a read-only engine label; consider advanced editing only if there is a concrete use case and compatible supported multi-site engines.
- Configuration: retain ordinary appearance, filters, gesture, viewer, and download preferences.
- Credentials: **retain them for recognized same-service URL pairs** (notably Danbooru and its `safebooru.donmai.us` safe-mode host), subject to verifying the destination. On arbitrary unknown host changes, clear site-bound secrets or require explicit informed approval for the destination; do not rely on matching booru engine alone.
- Do **not** duplicate bookmarks, topics, feed checkpoints, or post identities; the current `duplicate` operation only clones configuration data. Keep the source profile unchanged and use the existing add path so a new ID is created only on confirmation.
- **Cancel** should not leave a partial duplicate. Avoid surprising side effects such as changing the active profile; show validation failures without creating the profile.

**Scope/effort.** Narrow implementation; probably **S–M**, rather than a broader URL/engine migration. Add targeted tests for menu → prefilled editor → save/cancel, modified target URL, incompatible engine/URL, a new profile ID, unchanged source profile, inherited settings and cleared credentials on host change. No implementation or GitHub issue authorized.

**Remaining implementation question:** Decide an explicit allowlist/identity check for same-service hosts and exact credential-copy wording, without inventing generic cross-domain trust. The motivating Danbooru→Safebooru case should preserve credentials.

**Clarified motivating use case (user, 2026-10-20).** Duplicate a **Danbooru** profile to a **Safebooru** profile, retaining its familiar appearance/search/viewer preferences and **the same account credentials**, but using the safe-domain endpoint and/or different default filters. This is not an arbitrary cross-service migration. Official Danbooru configuration lists `safebooru.donmai.us` as a safe-mode hostname, i.e. a host of the same service: https://github.com/danbooru/danbooru/blob/master/config/danbooru_default_config.rb . Danbooru documents its API-key login at https://safebooru.donmai.us/wiki_pages/help%3Aapi . If only different application-level filters are desired while keeping exactly the same endpoint, the existing immediate `Duplicate` operation can already create a separate copy whose filters can then be edited; changing to the safe-mode hostname is the missing URL editing step.

**Revised credentials rule.** **Do not automatically wipe authentication solely because the host string changes.** Preserve credentials for an explicitly trusted, verified same-service pair such as `danbooru.donmai.us` ↔ `safebooru.donmai.us`, subject to verifying login against the target before sending any credentials. For unknown or unrelated endpoints, do not silently send secrets: clear credentials by default or obtain explicit informed consent that identifies the destination. Do not infer account/credential equivalence merely from matching engine type or a similar hostname. The requested duplication flow should feel like editing the copy *before creation*, not editing/migrating the original.


**Latest disposition (user, 2026-10-20): NOT PLANNED.** After reconsidering the actual use case, the user concluded that a new function or specialized duplication editor is probably **not worth introducing**. Existing Duplicate + editing independent default filters covers the core need. Keep the Danbooru/Safebooru host/credentials findings above for reference only. **Do not file an issue or implement the proposed URL-editing workflow unless requested again.**

**User confirmation (2026-10-20).** Agreed not to add a specialized profile-duplication function. Maintain disposition: not planned.

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

**Scheduling note (user, 2026-10-20).** Explicitly **skip #5 for now**; return to it with the other larger architecture/UX issues after the smaller items have been discussed. No pool-bookmark design has been approved.

## 6. Pretty, colored query when used as pinned-search title

**Original request.** Query-as-name should replace underscores with readable spaces.

**Observed in source.** `FollowingTopic.displayName` falls back to the raw `query` when `name` is null (`lib/core/search/following_topics/src/types/following_topic.dart`).

**Updated user direction (provisional).** **Not just plain white text.** Show the default query title in the same colored/tag-style presentation used for ordinary search terms, with category colors and readable names.

**Proposal.** Build a view-only token/chip representation from the structured query when available, with fallback parsing for old raw queries. Replace underscores **only in display text**, preserve the canonical stored query and any operators/metatags/negations. Unknown categories use neutral styling. Respect tight card widths, text scaling, overflow, and no unnecessary metadata/network lookup per card. User-defined custom names remain user-defined names. **Effort S–M; likely best coordinated with query-editor work #16 and tag-color consistency Issue #48.**

**Implementation detail from source.** `lib/core/search/search/src/widgets/selected_tag_chip.dart` already formats ordinary search chips using a rich label with colored operator/metatag spans and underscores rendered as spaces. Rendering this widget unmodified may unexpectedly open a tag-edit dialog on tap; a **dedicated read-only / inert presentation wrapper** or a view-only mode is preferable for Following Topic cards. Category colors require category data: `SearchQueryStructure.typedTags` saves strings, not category IDs, so use cached/available type metadata with a neutral fallback. Long title wrapping/truncation and named-topic query subtitles require design review.

**Discussion outcome (user, 2026-10-20): proposal accepted.** Use compact readable, search-style **colored tag presentation** for query-based Topic titles. No issue has been filed, and implementation details such as read-only chips still need development-level review.

## 7. Are pinned searches unavailable on Realbooru?

**Original request.** Investigate why following/pinning appears unavailable for Realbooru.

**Observed in source.** `FollowTopicButton` is not intrinsically dependent on a supported new-post refresh adapter; the shared UI can display a follow action for a nonblank query. Tracking support and storing a following topic are distinct concepts (`topic_follow_control.dart`, `search_refresh_query_adapter.dart`).

**User clarification (2026-10-20).** The Follow/Pin functionality **does work**. The initial impression was caused by the lack of **automatic new-post tracking**, which the repository intentionally disables on Realbooru. There is **no confirmed defect to fix in following itself**. Keep #22 separate for the independent four-thumbnail preview request.

**Stronger code finding.** `packages/booru_clients/boorus.yaml` explicitly configures **Realbooru** under `gelbooru_v2`, with HTML/thumbnail-only post listings and offset pagination (not Gelbooru V1). `GelbooruV2Repository.searchRefreshQueryAdapter` maps `thumbnailOnly: true` to `UnsupportedSearchRefreshQueryAdapter`, so **automatic new-post tracking is intentionally disabled** on Realbooru. However, the `FollowTopicButton` still permits local/manual Following even if tracking is unavailable, as covered by `test/core/search/following_topics/search_page_follow_action_test.dart`. Verify the user's exact UI route if the pin button truly disappears; avoid presenting automatic tracking as a prerequisite for pinning. This overlaps #22, which should provide a preview independently.

**Feasibility assessment.** A heuristic poll of Realbooru's first HTML search page and a set of recent post IDs might detect *some* new matching posts. However, HTML listings use offset pagination and omit reliable per-post creation timestamps; many intervening posts, search/tag changes, deletions, and reordering can make this incomplete. The current tracker explicitly requires a stable baseline/verified ordered results. A third-party Dart Realbooru client also states that Realbooru's official API is disabled and HTML scraping is required (https://pub.dev/documentation/realbooru/latest/); this is not independent proof of the server's current configuration. **Recommendation: do not enable unreliable automatic new-post notifications as if they were authoritative.** Manual following and #22 previews remain useful. No new tracking issue proposed.

**User confirmation (2026-10-20).** Agreed to keep Realbooru's manual Following without unreliable automatic tracking. #22 independent previews are still desired; no standalone Issue #7.

## 8. Show video badge for Realbooru videos

**Observed in source.** Shared `ImageGridItem` already supports a play icon when `isAnimated` is true, including unknown duration. Realbooru is configured under **Gelbooru V2**, not Gelbooru V1, and its HTML listing parser stores an independent `isVideoPreview` flag. See the newer confirmed mapping findings below.

**Assessment.** Reuse the existing shared badge for Gelbooru V2 `isVideoPreview` rows, without changing the actual media type of a static poster. Test exact `video` tag detection, false positives, metadata-less entries, and the normal post media mapping. **Effort S; missing renderer bridge confirmed in source, device symptom not independently reproduced.**

**Stronger code finding.** The Realbooru HTML parser `packages/booru_clients/lib/src/gelbooru_v2/parsers/rb_parsers.dart` recognizes the exact word `video` in thumbnail title/tags and sets `PostV2Dto.isVideoPreview`. That flag survives into `GelbooruV2PostData.isVideoPreview` and powers the Realbooru **static poster/thumbnail selection**, covered by `test/boorus/gelbooru_v2/realbooru_video_thumbnail_test.dart`. But HTML preview rows are currently mapped to image-like `Post` values (`post.isVideo == false` is asserted by the test); the grid's general video badge checks `post.isAnimated`, computed from `format`. Thus **the stored preview marker is not used to render the play badge**. Add a video overlay for `isVideoPreview` through a Gelbooru V2/Realbooru-aware grid addition, or a properly typed presentation flag, without falsely marking the static poster as a playable original video. Distinguish `video` from `video_game`. A full post may later resolve to actual video format. **Effort S; high confidence in missing mapping.**

**Discussion outcome (user, 2026-10-20): proposal accepted.** Existing `isVideoPreview` detection should drive a Play overlay without changing the underlying static preview's media type. No issue created or code changed yet.

## 9. Prefetch up to three next posts and reverse-direction posts

**Original request.** Prefetch the next approximately three posts' media **and metadata**, and preceding posts when moving back.

**Observed in source.** Direction-based **media preloading already exists** under `lib/core/posts/media_preload/src/`, notably `preload_strategy.dart`. It begins conservatively, adjusts offsets based on direction/confidence, can extend to three posts in the active direction, and treats direct entry specially (thumbnails only). Backward direction is already modeled.

**Assessment.** First instrument/verify actual behavior rather than reimplementing it. Separate thumbnail, display-quality media, original quality, and **full post details**; the last category may still need prefetch. Bound concurrency/memory/data usage, cancel stale tasks, honor profile credentials, and prioritize visible media. Avoid eagerly prefetching three originals (see #13). **Effort M for extending/validating; potentially S for a focused fix.**

**Review priority note.** Preloading is substantially implemented; count this primarily as a **focused verification/improvement** until a concrete user-visible gap is found. The existing strategy can extend media offsets to three in the navigation direction; full details of neighboring posts are a separate resource category. It can be briefly checked with the smaller issues, while any broad metadata pipeline work belongs to the larger group.

**Further source investigation / user question (2026-10-20).** The user may have assumed prefetching was missing because it **feels different across Boorus**. Confirmed code-path differences:
- The same `DirectionBasedPreloadStrategy` is used in both `MixedPostDetailsImagePreloader` and `PostDetailsImagePreloader<T>` (`lib/core/posts/details/src/widgets/post_details_image_preloader.dart`). Mixed-source posts are grouped by their resolved origin/auth for the download manager; unresolved origin yields no prefetch item.
- At initial entry (`EntryPattern.direct`, no page movements recorded), the strategy **prefetches thumbnails only**. The default base distance is one; consistently moving in one direction can build confidence and extend that direction to three adjacent posts. Moving backwards is symmetric; the three-post range is **not guaranteed immediately**.
- **When the configured viewer resolution URL equals the original image URL**, the preloader currently creates `ImageMedia.fromUrl(thumbnail)` rather than fetching the original. Thus high/original-only configurations can look as if image prefetching is absent. Otherwise it queues thumbnail and resolved display-quality URL, subject to available links.
- **Videos currently preload only video thumbnail URLs, never video bytes.** A comment in the typed path explicitly notes that actual video preloading is future work.
- **Realbooru** is `thumbnailOnly`: its list parser returns thumbnail/poster metadata, then `GelbooruV2FullPostLoader` fetches richer single-post data **only on visiting that post**. This can produce delayed metadata/actual image even when thumbnails are cached.
- The manager's `DownloadConfiguration` defaults to **two concurrent media requests**. The feature also respects `automaticMediaLoadingEnabledProvider` and cancels tasks when viewer navigation becomes inactive.
**Current recommendation.** Preserve the common preloader and investigate per-engine **measured hit/miss behavior**, with test examples (a normal Danbooru query, Realbooru HTML results, a video, sample-quality setting, original-quality setting, mixed-profile bookmarks). A small regression/fix or separate bounded metadata prefetch might follow only if tests show value. User has not requested an issue or a rewrite of this mechanism.

**User confirmation / additional question (2026-10-20).** Preserve the existing direction-aware image prefetcher and investigate site-specific/quality-specific behavior; no new system by default. The user asks if we can preload **only the first few seconds of nearby videos** so playback starts without delay.

**Video startup prebuffering feasibility — technical research, not yet approved:**
- **Yes, streaming permits it** when source/server and player support incremental delivery. Android Media3's `DefaultPreloadManager` supports prebuffering a selected number of seconds from the next media item, with examples for three seconds ahead and one second behind (https://developer.android.com/media/media3/exoplayer/preloading-media/preloadmanager/create). This is an implementation pattern, **not** a plug-and-play solution across all Boorusama engines.
- MP4/WebM progressive HTTP delivery is generally based on **byte ranges**, not a fixed clock-time slice. MP4 startability depends on container index/`moov` access (faststart vs tail), server range/seek support, and enough initial decodable frames/keyframes. HLS/DASH streams can preload initialization data and initial segments. A naive `Range: bytes=0-N` download might be useless, or re-downloaded, unless the actual player can consume that cached range.
- **Existing Boorusama architecture:** `lib/core/posts/details/src/widgets/post_details_image_preloader.dart` preloads only video thumbnails, never video bytes. `BooruPlayer` wraps multiple engines (video_player/FVP/MDK, media_kit/mpv, WebView). `lib/core/videos/player/src/widgets/video_player.dart` initializes a player when viewing the video and sources from either a **fully cached file** or the original streaming URL. Current `VideoCacheManager` is used for **background whole-file caching after playback has begun**; it does not expose a shared partial prebuffer to all backends. Initializing a paused player may prepare media, but it must be validated whether it actually buffers usable seconds for each engine.
- To avoid duplicate transfers, implement startup buffering in the **player's own buffering/caching stack**, or explicitly share a partial cache/media source with the subsequent playback instance. Do **not** prefetch arbitrary byte ranges through the image cache and then let the video engine fetch the same bytes again.
- **Candidate UX/policy:** priorize the next probable video (optionally one behind after reverse navigation); aim for ~2–3 seconds of first playable data, subject to a **small byte cap and time/network budget**. No pre-play/audio; cancel stale work; do not compete with the visible post; optionally disable on metered mobile networks. Reuse correctly scoped headers, URL and original-profile auth.
- **Important Realbooru caveat:** its HTML listing has a static poster and often no playable video URL until `GelbooruV2FullPostLoader` fetches the full post on entering it. That resolution would need to happen *before* video prebuffering, and that should not be done for many posts without strict limits.
- **Effort/risk:** an incremental engine-specific warm player (one upcoming video) might be moderate; a seamless unified cross-engine seconds-based preloader with reusable partial bytes is larger. First measure `time-to-first-frame` across engines/sites and prove actual reuse and startup improvement. This is a **candidate subfeature of #9**, not an authorized separate ticket.

**Latest user decision (2026-10-20): DEFER VIDEO PREBUFFERING.** A first-few-seconds startup buffer is feasible in principle, but do **not** plan, implement, or open an issue for it unless real startup latency later justifies the complexity. Preserve only the image-prefetch verification/quality-limit scope of #9. The feasibility research above remains archival information rather than a commitment.

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

**Discussion outcome (user, 2026-10-20): accepted direction.** Perform a scoped app-wide audit, replace confirmation dialogs for reversible local removals with real Undo, preserve confirmations for irreversible/permanent and remote destructive actions. Implement only after explicit request/issue authorization.

## 12. Bookmark-style filtering inside topic feeds — cached snapshots only

**Original request.** Apply the same filter controls as bookmarks to topics feed.

**Observed in source.** Bookmark selectors support tag inclusion/exclusion, originating site selection, and sorting in the in-memory library (`lib/core/bookmarks/src/providers/bookmark_group_selectors.dart`). Topic feeds have a separate snapshot/history architecture.

**Updated user direction (provisional).** **Search/filter only the already stored snapshots**. While filtering is active, disable historical pagination / loading older remote posts. Resume normal history pagination when the filter is cleared. Avoid background-fetching arbitrary older pages to satisfy local filters; performance should remain bounded.

**Proposal.** Reuse the recognizable bookmark filtering UI, apply predicates only to cached feed post snapshots, clearly communicate “Filtering saved posts” and empty-match states, preserve the original feed query and data. Account for incomplete cache coverage and deterministic ordering. No network calls from the filter action. **Effort M; substantially more bounded than a remote cross-topic search.**

## 13. Progressive image loading ending in Original quality

**Original request.** Add “Original post quality” while still displaying/loading intermediate qualities first.

**Observed in source.** `ImageQuality.original` already exists (`lib/core/images/image_quality.dart`), and the details toolbar has a manual Load Original action in supported contexts. The unresolved requirement is **automatic progressive media display**.

**Proposal.** Resolve only actual distinct URLs, show thumbnail → sample/high-quality → original in order with seamless visual replacement and appropriate fallbacks. If a stage fails, do not block another valid stage. Avoid downloading redundant byte-identical variants and respect device memory, network policy, and viewer prefetch limits. Decide whether this is a separate viewer option rather than changing the existing explicit Original action. **Effort M.**

**Agreed constraint (user, 2026-10-20).** Allow **Original** as a viewer quality, with progressive on-screen transition from smaller preview through available higher quality to original. **Neighbor-media prefetch must stop at High, never proactively download Original files**, even when the user has chosen Original for the currently viewed post. The original for the current visible post may load normally. The existing global `PostQuality` selector exposes only `Medium`/`High` (`lib/core/settings/src/types/post_quality.dart`), while per-profile `GeneralPostQualityType` already includes `original` (`lib/core/posts/post/src/types/post_quality.dart`); ensure correct terminology and backward-compatible settings migration. `ProgressivePostImage` already loads a lower representation and target concurrently but may not be a strict three-stage thumbnail→sample→original pipeline: inspect whether an actual intermediate sample must be independently requested. Also fix the existing preloader's branch that maps `originalImageUrl == resolvedViewerUrl` to thumbnail-only so the proposed High cap can be honored using a resolvable intermediate/safe substitute. Respect site capability limits and unknown sample URLs.

## 14. Recognize when a topic/feed has reached its oldest post

**Observed in source.** `FeedHistorySession` has per-source pagination cursors and session-local `hasMore` state. The persisted `FollowingTopic` has a highest-seen ID/checkpoint for **new-post tracking**, not an explicit durable oldest-post/exhausted boundary.

**Proposal.** On a reliable end-of-history response, persist a per-source historical-end marker and avoid unnecessary retries. Distinguish true exhaustion from API caps, failures, zero visible results caused by filtering, and temporarily unavailable sources. Invalidate/re-evaluate markers for query/profile changes and other relevant events. Expose an intelligible end-of-topic/end-of-feed state. **Effort M.**

## 15. Make Pixiv engine explicitly experimental

**Original request and direction.** Label Pixiv as experimental in UI **and code/docs**, and avoid letting it determine core booru abstraction decisions. It is a limited curiosity rather than a priority full-featured engine.

**Observed in source.** Pixiv has its own booru adapter, routes, and navigation code under `lib/boorus/pixiv/`.

**Proposal.** Add an Experimental indicator with limitations in profile creation and settings; document intentionally unsupported behaviors, provide user-facing explanation, avoid speculative generic abstractions solely to accommodate Pixiv. This does **not** waive security, correctness, or data-integrity requirements. **Effort S–M.**

**Bounded implementation preference.** Add a consistent `Experimental` indicator to the Pixiv profile setup and other relevant profile information, plus a concise limitation note in its engine package and developer documentation. Avoid introducing an all-engine experimental flag unless existing UI/design needs reuse. Keep Pixiv engine registration intact so existing profiles still work.

**Discussion outcome (user, 2026-10-20): proposal accepted.** Keep the Experimental marking small, visible and documented. No issue or implementation yet.

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

**Discussion outcome (user, 2026-10-20): accepted direction.** One cumulative/cancellable notification per bulk session. No issue created or code changed.

## 19. Bookmark downloads use different names/quality; duplicate detection inconsistent

**Observed in source — directly confirmed.** Bookmark download path in `lib/core/bookmarks/src/providers/bookmark_provider.dart` uses `bookmark.originalUrl`, labels metadata quality as `original`, and calls `fallbackFileNameBuilder`. Normal search/viewer download in `lib/core/downloads/downloader/src/providers/download_notifier.dart` computes effective download quality from settings and uses a configured filename generator. This explains reported differences. Actual duplicate behavior still needs reproducing.

**Proposal.** Refactor bookmark and regular post download entry points to a shared policy for resolved originating profile, desired quality, URL selection, generated filename, and existing-file identity. Preserve credential isolation for mixed-profile bookmarks. Distinguish deliberate variant downloads from duplicate same-file downloads; ensure sidecars match the actual quality. Add tests for profile-specific filename patterns, settings, equal origins, cache/skips, and destination-path behavior. **Effort M; high-confidence/high-value fix.**

**Discussion outcome (user, 2026-10-20): accepted direction.** Unify bookmark/search download quality, path/filename generation, and meaningful duplicate handling via shared policy. No issue created or code changed.

## 20. Scroll-to-top button does not disappear at top after manual scroll

**Observed in source — plausible root cause.** `packages/kurumi/lib/src/components/scroll_visibility.dart` updates top-state within the scroll-direction-change branch and tests exact `offset == 0`. If the user continues scrolling in one direction until reaching the boundary, the component may not re-evaluate visibility at the moment it reaches the top.

**Proposal.** Update visibility on position/boundary changes, not only direction changes; use a sensible epsilon/extent guard rather than exact floating-point equality. Cover manual dragging, ballistic scrolling, content resizing, programmatic jump, controller replacement, and accessibility animations. **Effort S; runtime reproduction still necessary.**

**High-confidence specific defect.** `KurumiScrollToTop._onScroll()` updates `_isOnTop` **only on user scroll direction changes**, not every offset/boundary change; long uninterrupted upward scrolls can therefore reach the top without hiding the button. Its `isTop` extension also checks `offset == 0` exactly. Fix with offset/boundary-aware visibility and tolerances, while keeping show-on-upscroll semantics if desired. Regression widget tests should cover drag-to-top without changing direction, ballistic finish, and scroll-to-top button tap. Source: `packages/kurumi/lib/src/components/scroll_visibility.dart`.

**Discussion outcome (user, 2026-10-20): proposed bugfix accepted.** Fix offset-aware top detection in the shared Kurumi component, with regression coverage. No issue or implementation yet.

## 21. Overhaul the artist page

**Observed in source.** Danbooru artist page is built by combining tag details, alternative names, URL chips, and an artist tag cloud (`lib/boorus/danbooru/artists/artist/src/pages/artist_page.dart`). The distinction between primary social links, related tags, and wiki material is not very explicit.

**Proposal.** Introduce recognizable sections: artist identity/aliases, primary external/social links with platform icons, direct wiki link and summary/availability, related tags, and posts. Keep high-frequency navigation/actions easy to reach and preserve existing Follow Topic support. Check API availability for wiki and social link metadata before selecting UI. **Effort M; start with Danbooru rather than over-generalizing.**

## 22. Populate four previews even when tracking is unsupported

**Original request.** “New-post tracking is unsupported for this search.” should not prevent four search thumbnail previews.

**Observed in source.** `SearchRefreshService.refresh` handles `UnsupportedSearchRefreshQueryPlan` before its normal fetch, and the snapshot processing ties previews to post creation timestamps. That coupling is unnecessary for simply displaying recent matching thumbnails.

**Proposal.** Decouple “fetch up to four preview posts” from “calculate trustworthy new-post changes.” Fetch a bounded first page when the query is executable; preserve a distinct **tracking unsupported** status, without committing false new-post checkpoints. Do not repeatedly fetch on every repaint; respect cancellation, authentication, and network limits. **Effort S–M; closely connected to #7.**

**Additional source finding.** For Realbooru (configured `thumbnailOnly: true`), the *following action itself* skips refresh/preview fetching because `followingTopicTrackingSupportedProvider` is false (`topic_follow_control.dart`). If refresh is invoked later, `SearchRefreshService` rejects `UnsupportedSearchRefreshQueryPlan` before fetching any posts. Therefore #22 must implement a **separate, bounded snapshot/thumbnail fetch on save and/or as needed**, not merely bypass one error return inside the tracking scanner. Its preview data model also currently assumes `postCreatedAt`, which is often absent from HTML-only rows; permit preview-only identity/thumbnail information without manufacturing tracking timestamps. Cache four results with appropriate error states and never change the tracking unsupported status.

**Discussion outcome (user, 2026-10-20): proposal accepted.** Load four previews independently of the tracking scanner, including on manually followed/Realbooru topics. No issue or implementation yet.

## 23. Resume a pinned topic from a selected post/position (oldest → newest)

**Original request.** Progressively work through a pinned query such as `my_tag order:id` from old posts toward new posts; select a post and continue “from here.”

**Observed in source.** Current high-water checkpoint serves new-post refresh, not user's reading/workthrough progress.

**Proposal.** Add “Start / Resume from Here” on a post, persist a **separate browsing cursor** scoped to topic/profile/query/sort order, and provide a clear way to resume or reset. For Danbooru-like engines that support ID order and ID-range filters, compose a verified query (e.g. `order:id` with an ID bound) without silently overwriting the original followed query. Handle removed posts, updated search filters, and sites without stable ID ordering. Distinguish “read up to this post” from “start at this post” inclusive/exclusive semantics. **Effort M; depends partly on topic/history design.**

---

## Existing related work and proposed discussion order

- **Updated discussion priority (user, 2026-10-20):** cover all **small, bounded issues first**, combining related issues when helpful; leave the larger UX/architecture issues until the end. #2 is on hold, #5 is explicitly skipped for now, and #4 remains deprioritized. This overrides discussion *order* but not the original numbering of 23 items. No auto-created GitHub issues.
- Within each chosen group, proceed automatically from one item to the next. **Conversation workflow agreed 2026-10-20:** continue directly into the next issue after covering the current one; do not wait for permission merely to advance. Discuss smaller neighboring issues together where useful. Spend dedicated time on major issues (especially #2 post viewer). A design decision does **not** authorize creating a GitHub issue; an issue still requires an explicit instruction. Keep decisions separate from working hypotheses.
- Relevant tracked issue: [#49 — Find post in another profile](https://github.com/timberpile/Boorusama/issues/49), related to but narrower/different from external Pixiv Share (#10).
- Relevant **unmerged** feature branch: [`feature/group-neighboring-series`](https://github.com/timberpile/Boorusama/tree/feature/group-neighboring-series), including a provisional grouping specification. Any future pool/series-bookmark design (#5) must reconcile with it rather than accidentally treating an earlier preference as a final decision.
- Potential shared work: **#1** touches general UI copy; **#6 + #16** involve query presentation/editing; **#7 + #22** cover tracking versus previews; **#9 + #13** cover image fetching; **#18 + #19** cover download infrastructure; **#12 + #14 + #23** cover topic feed history and progress.
- Higher-confidence potential fixes: **#19**, **#20**, **#22**. Larger UX/architecture questions: **#2**, **#5**, and (if expanded) **#17**.
- **No new GitHub issues, PRs, code changes, or merges are authorized by this file.** Amend these notes or file issues only when requested in later discussion.
