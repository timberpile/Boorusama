# Feature Review Follow-up — 2026-10-21

**Discussion and issue-preview revisions only. No runtime fixes, GitHub issue changes, PRs, or merges.**

This supplements [the original 23-item archive](2026-10-20-feature-and-bug-review-notes.md). Where they differ, the user clarifications below are newer. Keep this archive branch out of `develop`.

Source baseline inspected: `develop` at `fd7ae8e63b9ecd1472167e6b9f95542f22efe170`. Runtime observations are user reports; the agent performed source inspection, not an Android reproduction or Flutter test run.

## Issue draft changes

- **#1 — Unify UI Labels and Icons:** also update localization keys and UI-text identifiers when changed wording makes their existing names misleading. Update consumers and translations together. Do not rename identifiers for capitalization alone. Keep the agreed short-label Title Case, feature names in prose, restrained bold, and accessible icon semantics.
- **#8 — Show Realbooru Video Badges:** the user live-confirmed an MP4 with the `video` tag that is unmarked in listings; the symptom affects every video listing they tested. Keep static poster display and actual video playback distinct.
- **#9 — Fix Realbooru Image Prefetch:** narrow the old general verification issue. Danbooru and Gelbooru already feel good to the user. Realbooru shows a thumbnail first and only then loads the display image. Preserve the existing directional preloader and the High limit; no video prebuffering.
- **#13 — Add Post Original Quality:** rename from Progressive Original Quality because progressive loading already exists. Add the Original setting while extending the existing progressive pipeline; neighboring prefetch stays at most High.
- **#15 — Mark Pixiv as Experimental**.
- **#20 — Fix Scroll-to-Top Button Visibility**.
- **#22 — Also Show Previews for Topics without Tracking**.
- **#21 — Refine Artist Page:** the revised direction is now concrete enough for an issue preview: Follow; no Browse Posts; Newest/Popular plus Search; clearer links/wiki/related tags.
- **New review #24 — Speed Up Profile Icons** and **#25 — Fix View Options Bottom Spacing**. These are review identifiers, not GitHub issue numbers.

The downloadable revision contains 19 new issue previews plus the revision preview for existing GitHub #49. Nothing has been posted as an issue. The #49 exact-file lookup and #10 Pixiv-source lookup should share a result interface without conflating match types or changing the selected-target behavior of #49.

## Labels and issue-writing conventions

The existing three type labels remain sufficient. `feature` includes improvements to user-facing behavior, wording, and UX; `bug` corrects incorrect behavior; `maintenance` covers primarily internal upkeep. Branch naming follows the type; it is not a reason to assign the type. #1 remains `feature` + `area:ui` + `ux`.

**Proposed:** a cross-cutting `performance` label for measurable latency/startup improvements, CPU/memory work, cache efficiency, and avoided redundant requests. Suggested initial candidates are #9, #14, and #24. Do not apply it to every visual cleanup. It has not been added to the live labels or `.github/labels.json`; this remains a review proposal.

`docs/issue_workflow.md` was sharpened on this archive branch: compact scope-specific titles, short Problem/Expected behavior, one main outcome per bullet, minimal reproduction, no padding, and no invented runtime verification. Authorization/status rules remain unchanged. These documentation edits are not integrated into `develop`.

## Profile icons: caching exists, startup can still block it

**Confirmed code:**

- `lib/core/posts/sources/src/source.dart` maps `donmai` to the bundled `assets/images/danbooru-logo.png`. Most other sites use remote favicons.
- `ConfigAwareWebsiteLogo` passes `defaultImageCacheManagerProvider` to `WebsiteLogo`.
- `packages/extended_image/lib/src/extended_image.dart` enables network-image caching by default. `DioExtendedNetworkImageProvider._fetchImageBytes` checks the cache before network fetch and returns nonempty cached bytes without revalidation.
- All these network icons use the same image cache as post media. Native `DefaultImageCacheManager._run` awaits initialization; the first initialization loads the index, lists cache files, checks entries, reconciles storage, and checkpoints before completing.

**Inference, not measured proof:** an icon can already be persisted and still wait for unrelated media-cache startup work. This matches the bundled-logo/remote-logo difference, but does not prove that it explains every observed delay. Genuine misses can also follow eviction, cleared temporary storage, changed URLs, or cache errors. A spinner alone does not prove another HTTP request.

First distinguish cold cache initialization, actual cache miss/network fetch, and decode delay. A small independently initialized persistent icon cache is a reasonable candidate if the shared initialization proves responsible. Preserve custom-icon behavior, valid cached display during refresh, error fallback, bounded storage, and disabled automatic-media-loading semantics.

The web image-cache implementation is memory-only; a browser reload has different persistence behavior and may rely separately on browser HTTP caching. The user's term Browse/Browser does not establish that they are using the web build.

## View Options: hidden app bar still contributes its inset

**Confirmed code path:** `PostGridConfigIconButton._showViewOptions` opens the common Kurumi modal sheet. `KurumiBottomSheet` uses a bottom `SafeArea`. `AppNavigationShell` supplies `padding.bottom` and `viewPadding.bottom` equal to the full navigation extent unless wide layout, keyboard, selection, or viewer conditions apply. Those inset conditions do not include `barVisible` or `barHiddenFraction`, although `_NavigationBarSlide` translates the bar out of sight using that fraction.

This is a concrete explanation for the reported blank band. It is source-confirmed, not a completed device reproduction.

Correct the modal's effective overlap, not merely its background color. Distinguish a deliberately stable scroll-content inset from the currently visible app-navigation overlap. Preserve actual system gesture/keyboard safe areas and avoid timeline jumps during bar movement. Test visible, hidden, partially moving, keyboard, and viewer-return states. No runtime fix applied.

## Realbooru badge and prefetch findings

### Video preview badge

`packages/booru_clients/lib/src/gelbooru_v2/parsers/rb_parsers.dart` stores an `isVideoPreview` marker from the listing title's exact `video` token. It keeps a static poster URL in the listing representation. The existing thumbnail tests explicitly assert that such a poster row has `post.isVideo == false`; they do not establish that the listing renderer draws a badge.

The fix must connect recognized video-preview information to the shared Play badge without turning a JPG poster into a playable video URL. Also cover the real listing payload and a resolved MP4. Do not mistake `video_game` for a video, require a duration, or assume a tokenization issue without an actual payload.

### Adjacent display-image prefetch

Realbooru's listing parser has thumbnail/poster-level information. `GelbooruV2FullPostLoader` resolves the full post as its viewer widget is built; neighbor prefetch uses the information already in the list. Resolve only a bounded upcoming/previous window, then preload the correct display rendition with source-profile authentication and cancellation. Reuse fetched metadata and prioritize the visible post.

**High-versus-Original constraint:** the current full-post parser assigns the same `fileUrl` to `sampleUrl`. The preloader also deliberately reduces original-URL targets to thumbnail-only. Resolving metadata alone therefore does not guarantee a distinct High rendition. Verify actual site variants; do not silently download an original-only file by renaming it High. If no intermediate is available, this needs an explicit product decision. Danbooru/Gelbooru behavior and video startup are not optimization targets for this issue.

## Artist Page — revised B

Keep the compact artist information layout, **Follow**, wiki access, external profiles, related tags, and the post grid. Retain **Newest / Popular**.

Add a labeled **Search** action beside the Posts heading. It opens the normal Search as a separate app view, seeded with this artist tag and the same profile. Changes there must not rewrite the Artist Page's Follow query, sort, or scroll. Back restores the Artist Page.

Do not add a second filter sheet, settings icon for filtering, inline query field, or Browse Posts button to Artist View. A standalone revised HTML mockup demonstrates this handoff and independent search state with fictional content. Its mobile/desktop, light/dark, tag input, empty state, Back, Follow, and Wiki interactions were checked in headless Chromium. This validates the mockup, not the Flutter application.

## Pool/Series bookmarks — corrected intent and alternatives

The user rejected **separate Posts and Series views inside a group**, not first-class Pool bookmark records. One mixed grid is the requirement. The earlier grouping-only document's categorical rejection of a SeriesBookmark must be reconsidered, not treated as a permanent architectural constraint. The active grouping branch was not edited.

### Meaningful options

| Model | Strength | Main limitation |
| --- | --- | --- |
| Adjacent display grouping only | Existing Post storage and actions remain intact | Not a durable Pool bookmark; grouping changes with order/filter |
| Save every member as Posts, then group | Existing local Post behavior; explicit capture | Many entries; no future members; stacks can split |
| Generic link tile | Simple navigation shortcut | Weak collection identity and limited offline/actions |
| **Typed Pool reference + cached card metadata** | Durable mixed-grid entry, bounded updates | Needs typed entry/membership/export support |
| Reference + cached ordered member manifest | Last-known contents and faster reopening | Must represent partial/stale coverage; no implicit offline media |
| Frozen collection snapshot | Stable archival membership/order | Versioning, retained data, partial capture, larger export |
| Automatic collection sync | Future members can appear automatically | Scheduling, limits, and removal/ownership complexity |
| Nested local group/bundle | User-defined cross-site albums | New hierarchy/cycle/recursive action semantics |
| Saved query tile | Reuses search execution | Still needs Pool identity; overlaps Topics and may lose order |
| User-selectable live/snapshot/sync modes | Maximum flexibility | Combines all complexity in a basic bookmark action |

**Recommendation, not yet approved:** typed Pool references with cached title/category/cover/count in the same grid as Posts, optionally cache already-fetched ordered membership, and keep **Bookmark Posts** as a distinct explicit operation. No automatic member import, background sync, or downloads. Visual grouping can remain an independent display feature.

For Danbooru, Series and Collection are categories of Pool. Store one Pool resource identity; do not change identity when category or title changes. Reference the verified source/database and Pool ID, not the cover Post ID or a globally ambiguous engine+ID pair.

**Required semantics:**

- One Pool tile is one saved/selected entry. Its count means known remote members, not individually saved images.
- Tap opens the Pool/Series in collection order. Back restores the Bookmark Group.
- Removing a reference never removes independently saved member Posts or downloaded files.
- A Pool reference and an individually saved favorite member may coexist; neither is a duplicate of the other.
- Group moves/removals/Undo must work for mixed entries. Do not run Post actions on a collection's cover or expand downloads silently.
- Cached metadata is not an offline media archive. Keep unavailable/deleted references with an honest recoverable state.
- Do not infer collection tags from the cover. Initial local filtering can match entry-owned metadata; searching cached members is a separate explicit scope and cannot imply complete remote coverage.
- Bookmark-added sorting is well-defined across types. Pool upload-date ordering needs a documented fallback, not a fabricated date from the cover.
- Version exports/imports and preserve all existing Post identities/memberships. Older importers must not silently drop new entry types.

`Bookmark` currently contains a `Post`/`StoredPostSnapshot`, and `BookmarkEntry` is only an alias. Mixed entries require an explicit type boundary across storage, actions, selectors, navigation, and backup. Do not disguise Pools as fake Posts. The complete change is medium-to-large despite a small tile UI.

The detailed options document supplied with the conversation expands these alternatives, filtering semantics, coexistence with grouping, and the recommended first-release boundary. No final model approval or implementation is implied.

## Verification and authorization

Source inspection used the pinned develop commit above. No emulator, live authenticated Booru query, FVM/Flutter tests, or application profiling was performed. User live reports are recorded as such. The HTML mockup was tested separately in Chromium and checked for script syntax and narrow-width overflow.

All repository writes from this review are documentation-only on `maintenance/feature-review-notes-2026-10-20`. New issue drafts, proposed labels, and the #49 revision remain pending explicit publication approval. No application files, active feature branches, `develop`, or live issue metadata were changed.
