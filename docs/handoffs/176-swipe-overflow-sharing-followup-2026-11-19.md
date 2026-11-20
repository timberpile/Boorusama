# #176 — Held-swipe galleries, persistent viewer presentation, functional overflow, and unified sharing

**Implementation handoff for the local agent — 2026-11-19**

- **Repository** `timberpile/Boorusama`
- **Task branch** `feature/176-group-viewer-design`
- **Source reviewed** `46df5cd9f6ee1da5ba0d79a913456caee288f273`
- **Issue** [#176](https://github.com/timberpile/Boorusama/issues/176)

**Status:** Owner-approved follow-up specification. See the implementation and verification notes below.

## 0. Instructions, scope, and precedence

Continue the existing task branch/worktree; preserve local uncommitted work and commits created after the reviewed SHA. Before editing, refresh remote refs and inspect the *current* file contents and nearby tests. Follow `AGENTS.md`, `docs/development_workflow.md`, and the relevant repository skills. Use FVM. Do not create a new task branch, issue, PR, or parallel tracker. Do **not** post technical handoffs or progress as comments on #176. Do not merge, close the issue, or publish to `develop` without the owner's approval.

This document is the governing specification for the *new* feedback below. It supplements the existing #176 design, accepted layout/canvas/order/cover work, and verification records; it does **not** authorize replacing or undoing unrelated #176 work. In particular, retain:
- The shared viewer, B+ Single/Timeline switch, independent Post/Page and Group/Work bookmark buttons, Timeline drill-in/Back, saved scroll/member identity, and no fake substitute gallery.
- Existing Danbooru Pool/Series Ordered/Latest/Oldest and Related Oldest/Newest controls **in their dedicated Single header and Timeline controls**. Newest is the Related label; Latest is the Pool label. Remove only their *duplicate member-Post More menu items* as instructed below. If old specs mention overflow sorting, this newer owner request supersedes that placement, not the capability.
- Nonblank ordering transitions, no Danbooru Series cover-as-member flash, the deliberate Pixiv cover handoff, and viewer canvas-attached counters. Keep the previously accepted image/source authorization contracts.
- Defaults from #176: Single for Pixiv Works, Danbooru Series, and Related; Timeline for ordinary Collections/Pools, subject to established explicit entry/restoration semantics. Do not silently force every linked Collection into Single.

The owner reported:
1. During a held horizontal swipe into a Collection **Timeline**, the actual timeline is blank until the destination becomes the selected page.
2. Horizontal swiping from a Post currently in Detailed presentation hides details / changes the user's Immersive–Detailed choice. That choice must persist throughout a viewer session.
3. Remove Ordered/Latest/Oldest from member Post More menus. Long More menus currently overflow vertically and must scroll.
4. Existing More entries displaced from toolbars (especially Share) must actually work.
5. Combine Post/Page and whole Group/Work file sharing into the normal Share dialog. Shorten displayed "Boorusama Link File" to **"Link File"**. A direct Post file opens the individual Post/Page; a Group file opens the entire Group from its first member. No new "Group with selected member" file format.
6. Offer Danbooru **Post vs Pool native web links** separately where a valid native Pool URL is supported. Keep normal Source Link and Image Link behaviors.
7. Compact Links tab: no long URL previews/descriptions beneath link rows, **Post ID and its numeric value remain visible**, smaller vertical spacing, and scope-badged actions. Move Media/Links toggles into the Share header row when there is room.
8. Fix Share bottom sheet being pushed upward by the visible viewer UI overlay and leaving a black/empty gap underneath.

Do not interpret those as unrelated rewrites or an invitation to change local Bookmarks, website Favorites, URL import grammar, or backups.

## 1. Held-swipe Collection Timeline: render the real destination before settlement

### Verified source path and likely cause

- `lib/core/posts/details/src/widgets/post_details_image_preloader.dart`: `MixedPostDetailsImagePreloader` populates adjacent `PreparedGroupWindow` slots only if `capability.presentation.layoutFor(entry.summary) == GroupLayout.memberGrid`. It independently classifies Work preparation using the **default** `mediaPager` layout.
- `lib/core/posts/details/src/widgets/mixed_post_details_page.dart`: `_layoutFor(entry, index)` can instead select Timeline/memberGrid from the active group's reading state or `_carriedGroupLayout`. It also accounts for Pixiv Work member-count eligibility and Pool state.
- `lib/core/posts/details/src/widgets/viewer_entry_content.dart`: when offscreen and the prepared slot is absent, it explicitly returns `SizedBox.expand()`. Thus an effective Timeline destination can be drawn blank even though the outer PageView already builds it.
- `lib/core/posts/details/src/widgets/content_group_page.dart`, `lib/core/posts/pools/group_post_scope.dart`, `lib/core/content/groups/prepared_group_reads.dart`: the real group presentation and prepared head/member read are already available; preserve their cache/source authorization.

**Required implementation:**

1. Introduce/route through **one authoritative effective presentation decision** for an occurrence (Group type, current user-selected/carried mode, source capability, current metadata, Pixiv single-member fallback, selected access). Both outer rendering and adjacent preloading must consume it. Do not copy subtly different `layoutFor` logic into a second preloader switch. A read-only resolver or small state projection is appropriate; avoid initiating hidden foreground requests merely to decide layout.
2. Keep preparable **exactly immediate previous and next outer occurrences**, plus the selected page; reuse the existing bounded window and direction policy. Do not preload every Group in a long viewer sequence. Respect automatic media loading, route visibility, cancellation, and access changes.
3. For any adjacent occurrence whose **effective** layout is Timeline, mount the **same real `ContentGroupPage`/engine Timeline subtree**, not `PreparedGroupPreview`, a hand-built proxy grid, thumbnail skeleton falsely presented as the real gallery, or a second route. The element, gallery controller, filter/ordering state, and scroll checkpoint must survive activation from passive → selected/settled. A destination may show its normal loading surface when data are cold, but not blank solely because it is offscreen.
4. Use the actual target Source/access, resolved applied order, target profile's `postsPerPage`/page mode, and refresh revision for first-page preparation. Do not accidentally use the currently displayed neighbor's settings. Reuse pending or completed shared reads using the same underlying cache identity (access, reference, applied order, limit, revision); merely toggling the preparation priority/foreground flag must **not issue a duplicate logical first-page fetch**.
5. Apply this equally to Danbooru Pool, Series, Related, and multi-page Pixiv Work when Timeline is chosen. Pixiv's default mediaPager alone is not enough to decide whether to prepare a Timeline. A single-image Pixiv Work must remain eligible only for its supported Single behavior; preserve established no-eligible-Timeline fallback.
6. **Separate passive painting from foreground effects.** Offscreen or held-drag pages can lay out real tiles and decode permitted thumbnails, but cannot acknowledge Group display/read, start playback, issue favorite/vote writes, launch extra pagination, handle taps/focus/semantics, or perform interactive-only metadata/cover side effects. Existing `ViewerEntryContent` `IgnorePointer`/`ExcludeFocus`/`ExcludeSemantics`, `NavigationActivity`, `GroupViewerScope.passive`, and gallery continuation guards should be reused and audited. Do not gate the *entire real Timeline widget's build* behind activity.
7. Activate interactive behavior only after the **outer page is selected and the horizontal motion settled**. A rounded page index/halfway crossing is insufficient. A drag from A toward B followed by release back to A must not produce B's display receipt or side effects.
8. Preserve prepared/on-screen widget keys, image provider/cached decoded images, PageStorage, selected `memberKey`, and mode when transitioning to foreground; never swap an offscreen "preview" tree for a different real tree at settlement. Prevent an intermediate blank or first-page reload. Page refresh/reorder can invalidate the correct keyed source explicitly; ordinary swiping may not.
9. Keep source/profile security behavior fail-closed. A revoked/changed authorization or policy must discard the previous cached visual where necessary; avoid showing content from another profile just to avoid a flicker. Preserve ordinary unread/seen/display acknowledgement contracts.

**Implementation check:** Record a held-swipe widget scenario between ordinary Post → Series/Pool/Related Timeline → Pixiv Work Timeline in both directions. Before release, assert real tiles and layout exist in the neighbor. Continue to settled page, assert the **same gallery/controller identity**, scroll checkpoint, no intermediate replacement, at most one shared first-page logical request, and active actions only after settlement. Include interrupted/cancelled swipe, missing access, cold network, delayed metadata, a one-page Pixiv Work, and target/source-specific ordering/limits. Check the exposed UI, not just provider data.

## 2. Persist Immersive/Detailed across outer and inner swipes

### Current reset paths to inspect

- `lib/core/posts/details_pageview/src/post_details_page_view.dart`: `PostDetailsPageView.didUpdateWidget` currently collapses `sheetState` when `detailsEnabled` flips from true to false. A Group Timeline, loading state, or new occurrence can therefore destroy the user's Detailed choice. `_commitPage` also explicitly forces the overlay visible for non-Post pages or reapplies initial Hide to later pages.
- `lib/core/posts/details/src/widgets/post_details_page_scaffold.dart` derives `detailsEnabled`, `overlayEnabled`, and `isPostPage` from the currently resolved Post/media-page identity, which can change transiently during preparation.
- `PostDetailsPageViewController` owns session-level sheet/overlay notifiers; `_ViewerPage` owns per-page Details rendering and saved offsets. These are different responsibilities.

**Required contract:**

1. Treat **Immersive vs Detailed as one viewer-session presentation preference**. Horizontal outer swipes across ordinary Posts and Groups, inner Pixiv/Pool member switches, metadata loading/error/availability changes, and temporary Timeline presentation must **not** modify that preference.
2. Timeline has no ordinary Post Details panel: it **temporarily does not display** the session's Detailed state, but must not reset it. When returning to eligible Single, restore Detailed if selected. Keep Timeline/Single reading mode separate from Immersive/Detailed; keep overlay shown/hidden independent of both.
3. Only **explicit user actions** (e.g. Details toggle/vertical transition and the previously accepted Timeline drill-in contract) may choose different presentation behavior. Do not reapply the viewer's initial Show/Hide setting to every swipe, or run `resetSheet` to make an adjacent Group view fit. The explicit Timeline-tile drill-in already applies the complete Show/Hide UI setting and should keep doing so; this is not an ordinary horizontal swipe.
4. Preserve each **individual member occurrence's** Details scroll position within the existing bounded retention window. A Group's outer occurrence key alone is insufficient if multiple inner members have separate Details. Do not create unbounded global scroll state. Keep zoom/video state properly scoped; no cross-member transform leak.
5. When a still-loading next Post becomes available, it must inherit the session choice without a flash to Immersive. If the user changes the choice while a swipe is in progress, commit the actual explicit preference once and apply it to the settled destination; protect against old animation/lifecycle completions resetting newer state.
6. Preserve overlay state across ordinary swipes and modal dismissal unless the user explicitly changed it. Showing the UI momentarily to access Share must not accidentally become a different persisted Detailed state.

**Tests:** Immersive → ordinary Post → Group Timeline → ordinary Post remains Immersive; Detailed → ordinary Post → Group Timeline → eligible Single remains Detailed; Detailed → Pixiv Work page 2 → page 3 retains Detailed and each page's own scroll; reverse swipes; reduced motion; no-Post/loading/error intermediate frames; toggle during held drag. Distinguish session presentation from opening a Timeline tile, which retains existing explicit drill-in behavior.

## 3. Remove duplicate sort menu items; fix *actual* More overflow and dead actions

### Sort placement

In `lib/core/posts/details/src/widgets/media_group_actions.dart`, `groupOrderMenuButtons(...)` currently adds the Ordered/Latest/Oldest or Related order choices to `PostActionToolbarScope.additionalButtons`. Remove only this redundant insertion from the **member Post More** menu. Preserve the dedicated `GroupOrderSelector` / `GroupViewToggle` in Single's upper header and the existing Timeline sort controls. No change to the actual ordering values, persisted Related preference, checked selection, or #176 icon choices. Test all Danbooru Pools **including Series**, and Related in both modes.

### Vertical overflow — wrong component pitfall

The real Post action overflow goes through:

`SimplePostActionToolbar` or `DanbooruPostActionToolbar` → `BooruMenuButtonRow` → `KurumiAdaptiveButtonRow.menu` → `_buildOverflowButton` in **`packages/kurumi/lib/src/components/adaptive_button_row.dart`**.

This is **not** the `KurumiPopupMenuButton` path in `packages/kurumi/lib/src/components/popup_menu.dart`. The latter already computes a viewport-bounded max height; the adaptive More currently uses a `SingleChildScrollView` without the required bounded-height/viewport constraints.

- Constrain the menu's **available height** using current viewport and native top/bottom safe areas, keyboard `viewInsets`, minimum margin, and anchor positioning; make the **menu content**, not the entire page, vertically scrollable. Reuse/shared helper with Kurumi popup if appropriate, but avoid unrelated visual redesign.
- Use `KurumiAnchor` viewport constraints/positioning correctly, including landscape, narrow/short screens, 1.5–2× text scale, keyboard visible, and desktop.
- All menu items must remain reachable with touch, wheel, keyboard and accessibility. Keep focus restoration and menu dismissal semantics.
- Do not reduce tap targets to squeeze items.

### Critical additional bug: callbacks disappear when buttons overflow

`KurumiAdaptiveButtonRow._buildOverflowButton` invokes `KurumiButtonData.onTap`, or else `onOverflow`. It does **not** invoke the `onPressed` of the original `IconButton` stored in `widget`. Current toolbar definitions have entries lacking `onTap` (notably Share, and depending on capability Download, Favorites/Votes, etc.). They can become **inert** when placed in More.

Required: audit **all** `ButtonData` and `SimpleButtonData` that can move into More in both general and Danbooru toolbars. Give toolbar and overflow a **single, canonical action callback with identical availability, permission, busy, and source binding checks**. Prefer refactoring the button to expose its action rather than inventing a separate simplified favorite, vote, or download implementation. Do not inspect widget types or synthesize taps on child `IconButton`. The action should run after the overflow closes, with a still-current source/access context; preserve correct dialog Navigator/ProviderScope/Route context.

Test on a narrow width forcing overflow: open More, scroll to the last item and **activate** Share; assert the normal unified Share dialog opens. Exercise Download, favorite/vote, comment/history, Work-specific actions according to their capabilities. Confirm disabled operations remain disabled. Test menu closing, focus return, item order, and no spurious navigation.

## 4. One unified share dialog and explicit Post versus Group targets

### Owner-approved semantics

- **Current Post/Page**: an individual Post identity, even when encountered inside Pool, Related, Series or Pixiv Work. A Post `.bslink` opens that individual Post/Page *directly* in its own viewer; it does **not** navigate to the surrounding Collection or carry a selected Group member. For Pixiv, preserve the stable Work+Page key (including a nonzero page number).
- **Entire Group/Collection/Work**: share only the source Group reference, **not** the currently selected member, Timeline scroll offset, sender's current sort, or sender's Immersive/Detailed state. On receiving the link, begin at the **first member of the recipient's effective/source order**, under the recipient's existing #176 per-kind/default mode: Single for Pixiv/Series/Related, Timeline for ordinary Pools/Collections unless an explicit existing entry preference takes precedence. Never resume the sender's page N. Do not introduce a new Group+selected-member URI/version or change `.bslink` grammar.
- Group scopes: use the **actual captured Viewer Group occurrence/source**. A Post can be in several Pools; the Group share action must refer to the Pool the user is viewing, not a random association inferred from Post ID, nor a different active profile.
- Outside any Group, there is only a Post target. From a Group Timeline/summary without a specific Post selected, offer Group target(s), not a fabricated Post 1 link.
- Avoid creating invalid choices: unresolvable Post stable key, unavailable/unsupported native web group URL, or revoked reader should yield disabled/absent appropriate actions, not a guessed URL or fallback to a different profile.

### Existing components and needed changes

Current code:
- `lib/core/posts/links/boorusama_post_link.dart`: `BoorusamaPostLink.fromPost` and stable Pixiv page keys.
- `lib/core/posts/links/boorusama_group_link.dart`: validated Group reference with no member.
- `lib/core/posts/links/boorusama_link_file.dart` / `boorusama_link_file_share.dart`: existing V1 document codec, filename, cleanup, system share; reuse unchanged document grammar. Post, Group, and Search filenames use the normalized source profile name. The engine name is the fallback.
- `lib/core/posts/links/boorusama_group_link_page.dart` and `boorusama_post_link_page.dart`: current receivers/entry flow. Do not rewrite them or bypass source/profile choice merely for sharing.
- `lib/core/posts/links/share_group_link_button.dart`: a separate direct Group file share, currently used from Group views.
- `lib/core/posts/shares/src/providers.dart`: `ShareService.sharePost` gathers Post/auth context and constructs `UnifiedPostShareSheet`. It currently lacks an explicit captured Group target.
- `lib/core/posts/shares/src/unified_post_share_sheet.dart`: `PostSharePayloads.build` is Post-centric and validates one Post URI. The existing `_perform` compares a `boorusamaLink` payload exclusively to `BoorusamaPostLink.fromPost(...)`; this check cannot simply be removed to add Group links.
- `lib/core/posts/shares/src/share_payloads.dart` and `share_payload_tile.dart`: payload/UI structure. Refactor for scoped link action(s) without duplicating entire dialogs.

Implement a small **typed share context** (names are suggestions, not existing APIs), containing an optional captured Post, optional **validated Group reference**, source binding/access/reader, and allowed capabilities. Resolve it **at the initial Share tap**, pass it to the dialog, and validate the captured source again before copy/OS share handoff. In the active Group member toolbar, take `GroupViewerScope` context before pushing a modal route; **do not try to find GroupViewerScope from the modal's new BuildContext**, as the captured group scope may no longer be above it. Reuse current auth access rather than silently borrowing the newly active account. Be aware that the same Post may appear in different groups and that Timeline summary lacks an `InheritedPost`.

A Group-only Share entry point should reuse the same **Links panel/actions** (opening on Links when media is not available), without requiring dummy Post fields, invoking media download code, or replacing the Group header with an unrelated modal design.

Keep the existing file share as **one attachment per action**, not mixed with image media. Maintain pre-handoff authorization/visibility validation, cancellation, cleanup/retry behavior, iOS/Android sharePositionOrigin, and correct handling of `ShareActionOutcome`. Do not persist credentials, receiver-private IDs, signed media URLs, bookmarks or source snapshots in portable document data. A share action cannot outlive source authorization simply because a file was staged.

For Group file attachment, validate `BoorusamaGroupLink.fromReference(capturedReference)` and current authorized binding, **not** the Post URI. For Post attachment validate `BoorusamaPostLink.fromPost(capturedPost, auth: capturedAuth)` and current Post visibility. Do not disable either validation to make a common payload function compile. Use distinct action IDs and widget keys; one generic `boorusamaLink` payload for both would invite incorrect retry, busy and validation behavior. The Group file should not call `context.postLinkFileMessage(...)` with a Group URI, because that method parses a Post URI; use a group-specific caption containing the group name and source profile name. Fall back to the group type and ID and the site host when that information is unavailable.

### External native website ("Booru") links

The existing normal `Booru Link` references the **Post** using `postLinkGeneratorProvider(auth).getLink(post)`. Within a supported Danbooru Pool/Series, also offer a separate **Pool Link** to the native Pool page, bound to the target Pool's authorized site and Pool ID. Use the existing Danbooru URL/link generator or a validated known engine-specific route; inspect the repository API before choosing the exact construction. Validate host/path/ID, including custom Danbooru site URLs. **Do not append `/pools/{id}` to an arbitrary base URL or invent routes for engines without a supported native Group web URL.** Related Group's canonical Boorusama Group file is not automatically a Pool website link; omit native Group website row unless a real supported external target exists. Pixiv Work external web link may use its established Work route if provided by the engine. Keep `Source Link` (author/provenance) separate from either Booru destination and retain `Image Link` (direct media) behavior.

Test that Post URL points to the Post and Pool URL points to that exact Pool, including a Post occurring in multiple Pools, custom source URLs, and an absent/unsupported Group web URL.

## 5. Exact Share UX and localization

### Header

Use the **existing Share title with the Media / Links selection in the same header line** with comfortable horizontal spacing. The title must remain readable, and the controls must not cover/destroy the close/back behavior. On small widths or doubled text use an adaptive `Wrap`/second line instead of overflow or scaling text below accessibility size. Keep the established Kurumi/Material styling and selection semantics. Remove the separate redundant 12dp vertical row gap where possible. Both tabs retain their current meaning; Media descriptions may remain.

### Links panel layout (no URL previews)

Keep link rows visibly compact, using the existing `SharePayloadTile` or a shared link-row variant:
- **Link File**: **one row** with the Boorusama app icon and, where available, up to **two trailing Share buttons**. The **image badge** means *Current post/page .bslink*, the **layers/collection badge** means *Entire Group .bslink*. Reuse the established icon badge language from the two #176 Bookmark scope buttons; use tooltips and semantics "Share current post link file" / "Share entire collection link file" (localized; exact English may be adjusted for consistency). Both are **share-only**; never expose the raw `boorusama://` text as a Copy action. For Group-only context show only Group action; standalone Post only Post action. Keep each target's enabled/busy/retry state separate and unambiguous.
- **Native Booru website links**: **two compact labelled rows** when both exist: **Post Link** with Copy + Share; **Pool Link** (or suitable engine-specific Collection/Work label) with Copy + Share. Both use the site icon. This intentionally avoids four almost identical icons in one row. When only one exists, show that row alone. Scope badges can reinforce the difference; do not rely on badges alone.
- Keep existing **Source Link** and **Image Link** with Copy/Share as applicable. Omit rows in pure Group summary where no Post information exists.
- **Post ID** must remain, with the numeric value displayed **on a second line beneath the label**, plus the existing supported actions. Do not hide or blank the ID while removing previews.
- Remove secondary long URL/value lines and link previews in the **Links tab** (not necessarily in Media). Do not reserve an empty subtitle line merely to align heights. URLs remain available through Copy/Share; accessibility and tooltips should explain what each action does.
- Reduce per-row and between-row vertical spacing (`SharePayloadTile` currently has 8dp vertical padding **plus** an extra 8dp after each tile). Keep icon buttons' effective tap areas approximately **48dp minimum**, readable typography, focus/semantics, and sufficient separation even at 320dp/large text. Do not make actions too small to gain density.
- Keep all other existing share media, video/GIF, original, and clipboard workflows. Media and Links should not lose their current permissions/capabilities because a new Group target exists.

### Label change: globally visible, localized

Change the English authoring string `post.action.boorusama_link` in `packages/i18n/translations/en-US.json` from **"Boorusama Link File"** to **"Link File"**. This is a general visible-label change, not just this dialog; reuse `context.linkFileLabel` across other link-file actions (Artist, Search, Group) where applicable. Keep the V1 document format compatible with existing files. New Group filenames use the resource type directly, as in `danbooru-pool-42.bslink`, `danbooru-related-42.bslink`, and `pixiv-work-42.bslink`. Add new English keys only where meaningful differentiated tooltips/labels are needed. Run normal i18n generation if inputs change; do not edit other translation sources or generated Dart by hand, and do not overwrite existing localized prose.

### No duplicate Group share action in Post More

Remove the separate `ButtonData(title: context.linkFileLabel, ... onTap: share)` from the Group member Post More menu in `media_group_actions.dart` once the normal Share dialog offers both file targets. Keep whole-Group sharing accessible from **Timeline and Group summary/header** through the unified Links workflow, not an uncategorized direct-file-share menu action. The Group header can retain a standard Share icon that opens the unified dialog (Group-only where appropriate). Avoid duplicate, competing file share entry points in a single menu.

## 6. BUG: Share modal pushed up by viewer overlay

### Source-derived mechanism to confirm with a reproduction

- `lib/core/navigation/navigation_chrome_controller.dart` tracks `viewerBottomObstruction` on the active viewer.
- `lib/core/navigation/navigation_overlay_insets.dart` `NavigationOverlayInsetsScope` sends that obstruction to `KurumiOverlayInsetsScope(bottomPadding / bottomViewPadding)`.
- `packages/kurumi/lib/src/components/media_query.dart` `KurumiOverlayMediaQuery` copies these values into overlay route `MediaQuery.padding.bottom` and `viewPadding.bottom`.
- `lib/core/posts/shares/src/providers.dart` opens `Kurumi.showModalBottomSheet` on small screens, which wraps its content in `KurumiOverlayMediaQuery`. `packages/kurumi/lib/src/components/bottom_sheet.dart` and `UnifiedPostShareSheet` use `SafeArea`. Consequently, the modal can reserve the **viewer controls behind the modal** as if they were system/keyboard insets. This is the likely mechanism for the observed raised share sheet with blank space below. Confirm actual geometry in a controlled test before declaring the cause proven at runtime.

**Expected behavior:** With the viewer in Immersive, tap to show the UI overlay and then Share. The modal is **anchored to the bottom usable system viewport** and has exactly the native safe-area/keyboard clearance. It must **not** float up by the height of the underlying UI overlay. Opening Share with the viewer overlay hidden yields the same modal bottom anchor/available height. Closing Share restores the viewer state and does not cause the canvas/counter/overlay to jump.

**Implementation guidance:** Correct the handling of **modal route insets at the overlay boundary**, distinguishing underlying app/viewer chrome obstruction from actual native system safe area and keyboard. Prefer a narrowly scoped modal inset policy in the existing Kurumi overlay adapter/shared dialog launcher. Do not globally set all viewer bottom obstructions to zero, remove all `SafeArea` widgets, or blindly change to `useRootNavigator: true` (which can lose local navigation/provider contexts). Keep non-modal toast, popup, page content and app navigation bar obstruction semantics unchanged. Avoid double counting system insets when Android bars are hidden/visible. Maintain proper scrolling and size constraints when the keyboard is open.

**Tests and diagnostics:**
1. Build real viewer → show overlay → open normal Post Share modal → measure modal's bottom edge and gap to native system safe area. Repeat with overlay hidden; geometry must match.
2. Repeat for Group member Share, Group-only summary Share, keyboard shown, landscape/short viewport, large text, and both reduced-motion settings. Confirm no cut-off and no empty black reserved area.
3. Cover navigation shell presence and ordinary standalone Share (not only a simplified bare `MaterialApp`). Test a second unrelated Kurumi modal after the fix to ensure system/keyboard insets still work.
4. Assert backdrop content is not unintentionally tapped during modal display; closing modal preserves underlying viewer presentation/overlay state.

## 7. Suggested implementation sequence and ownership

1. **Baseline/reproduction:** Record branch HEAD and uncommitted status, inspect actual runtime files and existing #176 tests. Add failing controlled widget tests for held Timeline swipe, Detailed persistence, inactive More callbacks, and overlay-shift geometry before modifying the implementation. If a test cannot exercise a platform-native placement, document that separately and run a necessary device test.
2. **Viewer state:** Consolidate effective Group layout/projection; prepare real adjacent galleries and preserve controllers; fix session Detailed state independently of transient eligibility. Reuse existing shared read/access gates; do not grow preloading beyond ±1.
3. **Menus:** Remove duplicate sort entries; constrain the **adaptive** More popup; centralize toolbar/overflow actions and test their actual invocation.
4. **Sharing model:** Capture typed optional Post + Group source once; integrate Group link into the existing Share dialog with separate validated payload/action and native website capability. Preserve old standalone and Group-only share flows.
5. **Share UI:** Compact Links rows, move header toggles, apply scope badges/semantics, rename global label, author new en-US strings and generate.
6. **Modal geometry:** Fix modal-specific overlay safe-area sourcing, test after the compact layout change. Do not patch viewer chrome layout to hide a modal bug.
7. **Hardening:** Format/analyze, run focused consumer + Kurumi + link-file tests. Before saying branch ready to integrate, run the full repository local regression suite on the final candidate per `AGENTS.md`; report skipped tests and any native behavior not exercised. Commit task-specific work and provide checked SHA and durable logs. No automatic merge, issue closure or issue comments.

### Main source/test locations (non-exhaustive)

| Concern | Runtime code | Tests to extend |
| --- | --- | --- |
| Effective Group mode/preparation | `lib/core/posts/details/src/widgets/mixed_post_details_page.dart`; `post_details_image_preloader.dart`; `viewer_entry_content.dart`; `adjacent_group_preparation.dart`; `content_group_page.dart` | `test/core/posts/details/mixed_post_details_page_test.dart`, `test/core/posts/pools/group_post_pager_test.dart`, Group native/Work widget flows |
| Session Detailed/overlay | `lib/core/posts/details_pageview/src/post_details_page_view.dart`; `post_details_page_view_controller.dart`; `lib/core/posts/details/src/widgets/post_details_page_scaffold.dart` | `test/core/posts/details_pageview/`; `test/core/posts/details/mixed_post_details_page_test.dart` |
| More and actions | `packages/kurumi/lib/src/components/adaptive_button_row.dart`; `lib/core/widgets/booru_menu_button_row.dart`; general/Danbooru Post toolbars; `media_group_actions.dart` | `packages/kurumi/test/` adaptive-menu focus/viewport tests; real Post toolbar widget tests |
| Link formats & Share | `lib/core/posts/links/boorusama_{post,group}_link.dart`; `share_group_link_button.dart`; `lib/core/posts/shares/src/{providers,share_payloads,share_payload_tile,unified_post_share_sheet}.dart` | `test/core/posts/shares/share_boorusama_link_test.dart`; `share_payloads_test.dart`; `share_payload_tile_test.dart`; `test/core/posts/links/{share_group_link_button,boorusama_group_link_page,boorusama_link_file}_test.dart` |
| Modal placement | `lib/core/navigation/navigation_overlay_insets.dart`; `packages/kurumi/lib/src/components/{media_query,bottom_sheet}.dart`; Share entry point | Navigation-shell overlay geometry widget tests + relevant Kurumi modal tests |

## 8. Acceptance matrix — must pass on final candidate

- **Held swipes:** Post ↔ Related/Series/Pool/Pixiv Timeline, both directions. Real target tiles visible *during* drag; settled state retains exact gallery/controller. No false display acknowledgement on cancelled drag, unauthorized thumbnail, fake preview substitution, spontaneous playback or pagination; first batch reused once.
- **Mode:** Immersive remains Immersive and Detailed remains Detailed across ordinary horizontal swaps. Timeline does not erase remembered Detailed state. Per-member Details scroll and Timeline scroll checkpoints are retained within existing bounds. Explicit drill-in still honors Show/Hide UI setting.
- **Sort:** no Ordered/Latest/Oldest in member Post More; upper Single and Timeline sort controls still work for Pool/Series/Related with correct labels/checkmarks/icons and no blank sorting transition.
- **More:** 320dp short viewport and 2× text + keyboard: scrolling reaches last action. Share, Download, favorites/votes and appropriate Work actions execute in both toolbar and overflow. No inert entries, clipped controls or wrong source actions.
- **Link File (member context):** one visible row with image and Group share badges, each distinct and correctly labelled. Decode attachments and verify Post vs Group exact URI. Pixiv page 3 Post link opens page 3 alone. Group link opens first Group member under recipient defaults, not sender's page 3 or sort/mode. No raw URI/copy action.
- **Link File (standalone and Group-only):** standalone Post has no fake Group share. Timeline/summary offers Group share without fake Post; old direct Group file action is no longer duplicated in member More.
- **Booru native links:** in a Danbooru Pool, Post Link and Pool Link both have working Copy and Share actions to distinct correct native web destinations; two different Pools containing same Post produce distinct Pool targets. No invented external link for Related or unsupported engines.
- **Compact Links:** no URL preview/subtitle lines; the numeric Post ID appears beneath its label; Share title and Media/Links controls align on common row with responsive wrap when needed; accessibility touch targets are maintained.
- **Overlay bug:** Share sheet bottom is **unchanged** by showing/hiding Immersive viewer controls, with no black padding gap; keyboard/native safe area still work; modal dismiss returns to the same viewer state.
- **Security/regression:** account/profile switch or access revocation cancels unfinished share and prevents wrong-profile file handoff; Link File V1 import/export and existing media/GIF/video/copy/share workflows remain intact; no persistence/backup schema change.
- **Verification:** passing focused suites and complete local suite on the final runtime commit; specify exact commands, counts, errors/warnings/skips, device/UI observations and remaining unverified cases. Do not claim tests passed based solely on older rebase verification.

## 9. Completion report required from local agent

Provide the final branch SHA and concise sections for: implemented behavior (by area); meaningful deviations and why; focused/complete tests actually executed with result; interactive/native reproduction evidence for held swipe, overflow and modal geometry; observed remaining limitations; and confirmation no unauthorized `develop` integration or Issue actions occurred. Commit only code/tests/docs belonging to this follow-up. Update stale design wording only where necessary to avoid conflict with the owner-approved newest behavior.

## Implementation notes

- The viewer decides the effective Group layout before staging adjacent pages. The
  passive Timeline uses the same gallery and first-page data as the settled page.
  A held or cancelled swipe leaves the destination's display receipt pending.
  When swiping out of a Timeline in Detailed mode, the incoming page uses its
  own source profile and configured section order before release.
- Immersive and Detailed are session choices. In Detailed mode, separate member
  scroll offsets fit within a bounded cache. Timeline tile drill-in still applies
  the configured overlay behavior.
- The post toolbar and More menu share their action callbacks. The adaptive
  popup uses the same viewport constraints as the standard Kurumi popup. Post
  More actions wait for dismissal. Sorting lives in the Single header
  and Timeline. Related retains the accepted Latest and Oldest labels from the
  [canvas and order review](176-canvas-order-verification.md).
- Share shows the current Post and an authorized Group when both targets exist.
  Danbooru Pool web links use the captured site's native Pool path. Group-only
  Share opens directly on Links. The mobile sheet uses the window's own
  bottom insets and gives the keyboard its available space.
- Pixiv Timeline sharing offers the native artwork URL and ID alongside the
  Work file. Post sharing uses the site-issued ID. Work file captions use
  the loaded title and author, and Danbooru Pool captions render underscores
  as spaces. Pixiv page files use the `work-page` filename suffix and retain
  their exact page target.
- Widget tests check creator captions for Pixiv page and Work files in
  Immersive and Detailed. They also check that the Share popup retains the
  selected avatar under its current profile authorization.
- The owner still observed a missing artist name when opening Share from
  Immersive on device and accepted this as a remaining limitation for #176.
- Widget tests exercise held swipes, gallery identity, member scroll offsets,
  actual overflow actions, authorization revocation, attachment destinations,
  and share sheet geometry with simulated native insets. Native share-sheet
  behavior and physical-device swipe smoothness are pending device review.
