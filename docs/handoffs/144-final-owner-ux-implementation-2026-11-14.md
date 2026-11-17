# #144 — Final owner UX implementation handoff (2026-11-14)

> Naming normalization (2026-11-17): Historical paths and symbol references below use current MiteMite names. Recorded commit IDs and verification results are unchanged; consult the original commits for exact historical commands and artifact locations. These reference edits do not requalify earlier evidence.

## Owner device-layout correction (2026-11-15)

This later decision supersedes the former compact device/status presentation:
use localized relative dates in Activity and device timing; keep the existing
exact-date tooltip. **This Device** remains a fixed heading with editable
**Device Alias** as a property. Put both **Last Updated** (success) and
**Last Attempt** inside **Device Details**, with **Never** if absent. Move
**Update Now** and its progress to the MiteMite header. Omit Ready/Updating text
from the device identity section and retain failures/repair controls separately.
Timestamp refresh must not trigger synchronization, library reload or data writes.


> **Purpose:** Implement all currently approved owner QA/UI corrections, including the **final read-state clarification and top-right Unseen marker**. This document supersedes the contradictory unread/arrival and Pixiv/notification wording in [the earlier owner QA note](144-owner-ux-feedback-2026-11-14.md), the [v5 spec](../designs/2026-11-03-folder-based-collection-sync.md), and the illustrative mockup wherever they differ. Keep the rest of the approved architecture and the [current implementation handoff](144-interrupted-web-remediation-2026-11-14.md).

**Work on:** existing `feature/144-folder-based-collection-sync` worktree, never `develop`.
**Source inspected:** `c583df07621981973be2e4cd1ac5b31f1909ab42` (one documentation-only commit after tested Following integration `ee124f356`). Recheck HEAD before editing.
**Issue:** #144 remains open. Do not merge, open a PR, close the issue, reset test-device data, or touch protected physical phones without approval.
**Scope:** Product-language/UI behavior, correct Group/Post read state, native device notification delivery, Pixiv timeline standard selection, and regressions. This is **not** permission to redesign the unrelated Collection viewer or rename protocol/storage identifiers for branding. The visible MiteMite name is approved in decision 8.

## Non-negotiable owner decisions

## Additional owner QA corrections (2026-11-14, later than the earlier UX review)

These four corrections supersede any earlier contradictory guidance and apply on the **actual latest runtime branch**; the implementation agent must recheck HEAD because commits are arriving concurrently.

1. **No `Local` heading in Bookmark Home.** The Local Bookmark/Group cards remain the ordinary first content. The per-device sections still have their own device-name divider. In `lib/core/bookmarks/src/pages/bookmark_group_browser_page.dart`, remove the conditional root `SliverToBoxAdapter(Text(context.t.mitemite.local))` that is currently displayed when received mirrors exist. Do not remove `All Bookmarks`, local Groups, device section headings or their spacing. The UI should look the same whether or not a remote subscription is present, until the first device divider.

2. **The missing `...` is the *Timeline toolbar* More button, NOT the Group AppBar menu.** The owner means the control inside an opened received Bookmark Group's **post/media Timeline toolbar**, where the regular **View Options** and other applicable timeline operations live. The existing source chain is `BookmarkScrollView` → `TimelineHeaderSliver` → `BookmarkListControls(gridConfig: PostGridConfigIconButton(...))`. In `lib/core/posts/listing/src/widgets/post_grid_config_icon_button.dart`, that button currently depends on `postController.itemsNotifier` being nonempty and the selection mode being inactive. **Check the actual received Group timeline UI and its controller/entry conditions** (including a Group containing Posts vs typed Pool/native-Group content, loading, toolbar layout and selection) to establish why the timeline control is missing; reproduce on the real app route, compare with an ordinary local Group, then restore the normal Timeline More/View Options behavior where applicable. This conditional is a source-level investigation lead, **not a proven root cause**. Keep the existing ordinary timeline menu contents (e.g. Select, View Options and contextually available Statistics/Blacklist), respecting the existing selection/empty-state rules wherever applicable. **Never add Create Local Copy, Unsubscribe, Publish, Rename, or any other Group action to this Timeline menu.** `BookmarkGroupBrowserPage` has a completely separate AppBar `KurumiPopupMenuButton` that calls `_syncActions` for Group-level commands. That AppBar menu was **not** the reported missing `...` and must not be treated as the fix or mixed into Timeline options. No duplicate AppBar action requested.
3. **Improve the received-Group glyph; no sync+lock/folder symbol.** `bookmark_group_browser_page.dart` currently uses `Icons.sync_lock` on the card via `syncIndicator` and beside the opened Group title. A lock reads as privacy/access restriction, while a generic circular sync suggests two-way editing. Prefer a single compact **incoming/mirror** indicator, such as an outlined arrow entering a small tray (receive/inbox metaphor), rather than a folder/lock or double-arrow refresh. Use the same clear glyph in Group cards and opened Group titles, and keep it visually subordinate to the Group's image/title. Tooltip/accessibility can read **Received from <device name>** or **Received Group**; no need to repeat a long read-only explanation on every item. This is icon-design direction; choose and inspect an existing consistent glyph instead of inventing multiple inconsistent icon variants. Verify 16–20dp readability, dark/light theme, small screens and overlap with the persistent numeric Unseen badge.

4. **Unseen thumbnail indicator may use the full height of the other overlay icons.** The previous 8–10dp marker was unnecessarily small. Match the existing `ThumbnailOverlayDimensions.extent = 20dp` (or the corresponding current overlay height): show a **20dp-tall, top-right, high-contrast accent indicator**, with a compact filled circular badge and contrasting border/backplate rather than a barely noticeable pinpoint. Preserve the existing top-left site/type icon row and bottom-right quick actions. `KurumiSelectableItem` uses a top-right Preview/Zoom control in selection mode: **hide the Unseen badge during selection**; never intercept gestures or compete with the Preview button. Continue deriving state from the authoritative Group-specific persistent `unreadMembers`; Seen items have no marker, Group badge remains plain `N` and never disappears on Group open. Verify the 20dp overlay geometry at grid sizes, 320dp and high text scale.

5. **Device-section divider action is an Edit pencil, not an ellipsis.** The trailing `Icons.more_vert` in `_deviceSlivers` currently **navigates to MiteMite's Devices screen**, not an overflow/context menu. The owner explicitly rejects that misleading ellipsis. Replace with an **Edit** pencil, and ensure its behavior matches its affordance: **open the receiver-local alias editor for that publisher directly**, reusing the existing MiteMite **Edit** flow and `setDeviceAlias` service command. Editing the alias must never modify source-owned publisher identity, signing key, trust or shared catalog names. Keep broader device management accessible from **MiteMite → Devices**, and if the device name/header itself navigates there, label that separately and consistently. Header layout remains **device title left, expanding divider, pencil at extreme right**, with responsive truncation, 48dp accessible tap target and `Edit` semantics (English Title Case). Test edit/cancel/blank-alias fallback, scoped publisher identity, live update of the header, persistence after reload and offline alias editing.

**Implementation checks:** Focused real-provider/widget tests should cover a local-only Home and a Home with received device sections; **the Timeline-toolbar `...` / View Options** in local versus received root/nested Group timelines, including typed content and selection, with **no Group actions in that menu**; pencil alias editing; and the native/persisted Unseen rendering at the new 20dp footprint. Verify the actual route on Android at 320dp/large text. The Group AppBar menu is distinct and should remain independent. Do not claim these tests are complete from an earlier runtime checkpoint.

1. **Group badge = number of Posts still Unseen, NOT newly arrived Posts.** Display **`N`**, never `+N`. The Group badge **does not clear on opening a Group**. It decreases only when the relevant saved member is actually displayed in the active full Viewer or explicitly marked Seen. Hide at zero; no standalone membership-change dot substitutes for an Unseen count. This *replaces* the prior “opening acknowledges arrivals” visual contract.
2. **Unseen thumbnail marker belongs at the TOP-RIGHT corner** of the thumbnail, **not** beside the site icon at top-left. Owner now permits a **20dp-tall accent badge matching other thumbnail overlay elements**, rather than the earlier 8–10dp dot. Keep it high contrast with an outline/backplate, unobtrusive, and hidden during selection when top-right Preview is present. No `NEW` text, image dimming or full-card border. Seen items have no marker.
3. **Seen filter:** `All / Unseen / Seen` in received Group listings. Show it **only when the complete unfiltered Group contains both Seen and Unseen members**, or while a non-`All` choice is active to keep reset reachable. Group badge count is independent of the filter/search/viewport.
4. **Pixiv Work timeline long press:** Enter the existing app's **normal multi-selection mode**; do **not** open the `Entire Work` context menu. In that standard selection toolbar/menu, expose the **ordinary existing Work Bookmark action** with the established Group picker semantics and actual Work identities. This must work for selecting multiple Works; do not silently convert selected Works into Page bookmarks. Reuse normal selection appearance/behavior, not a new Pixiv-only interaction.
5. **Subscription success toast is unnecessary and must be removed.** The updated `Subscribed` label provides sufficient feedback. Normal error feedback remains. **New-device alerts are Android system notifications, not foreground toasts.**
6. The owner's other corrections in [the earlier QA note](144-owner-ux-feedback-2026-11-14.md) are **approved**: compact This device, simplified Publish management, `Device alias` action label -> `Edit`, Bookmark Home device heading left + expanding divider + menu right, and concise `Subscribed` text.
7. **No Folder glyph on Group cards.** There is no separate Folder category in Bookmark organization; do not infer a folder graphic from `hasChildren`. Avoid a generic folder+sync icon. Use the device section for origin and a subtle share/received status cue only where genuinely useful.
8. **Approved product/UI naming (2026-11-14): `MiteMite` is the feature name.** The owner explicitly rejected `Share` as the publication action because the app already uses Share for ordinary Posts/files/links. The complete approved label map and app-wide Title Case rule are in the section below. **Do not rename storage/protocol/cache keys, MethodChannels or internal source identifiers** for branding. An independent anime/fandom iOS app already uses the exact name `MiteMite`; naming collision review may be appropriate before public release, but the owner has selected this feature name.

## Approved MiteMite terminology, Title Case and Storage Location (2026-11-14)

**Owner approval:** These English UI labels are settled. **Do not reintroduce `My Shares`, `Shared with Me`, `Share` for publication, or `Stop Sharing`.** Reserve the ordinary **Share** command for the app's existing Post/link/file sharing flow. The MiteMite action is persistent one-way publication, not public internet posting or two-way edits.

| UI context | Final English label |
| --- | --- |
| Feature entry, page and navigation heading | **MiteMite** |
| Own active publication list page | **Published** |
| Group contextual command | **Publish to MiteMite** |
| Destructive action in published-root overflow | **Stop Publishing** |
| Source/Group publication state | **Published** |
| Receiver subscriptions management page | **Subscriptions** |
| Start / remove a subscription | **Subscribe** / **Unsubscribe** |
| Current subscription state | **Subscribed** |
| Trusted identity management | **Devices** |
| Device trust, removal | **Trust Device** / **Forget Device** |
| Receiver/device display name action | **Edit** (dialog can say **Device Alias**) |
| Current device panel | **This Device**; optional **Device Details** |
| Activity/history page | **Activity** |
| Chosen transport directory setting | **Storage Location** |
| Manual reconciliation control | **Update Now** |
| Reconciliation progress | **Updating…** |
| Timestamp of latest completed reconciliation | **Last Updated** |
| Explicit independence of a received copy | **Create Local Copy** |

The source of truth is **the UI context**, not a one-to-one replacement of `mitemite.publish` everywhere: the *management page* says **Published**, the *action* says **Publish to MiteMite**, and a *status* says **Published**. Split localization keys as needed; preserve existing identifiers unless refactoring UI strings requires an additive key. Internal section discriminators such as `'publish'`/`'receive'` and classes like `MiteMiteService` may stay stable. The setup can still mention the technical **shared directory** in explanatory text; `Storage Location` is its concise row label.

**Title Case is an app-wide UI convention**, not just for MiteMite. Use it for page headings, navigation destinations, section headings, tab names, buttons and menu actions (e.g. **Update Now**, **Stop Publishing**, **Trust Device**, **Device Details**, **Create Local Copy**, **Storage Location**). Audit nearby existing screens for consistency, while keeping unrelated runtime changes scoped and reporting broader inconsistencies rather than mass-rewriting the entire app as part of #144. Do **not** mechanically title-case sentences, notifications' descriptive body text, error explanations, user-provided Group/device names, URLs, paths, brands or acronyms. Preserve existing i18n generation and all locale translations.

### Storage Location: use the existing Auto Backup display-path implementation

**Verified source behavior:** `lib/core/backups/mitemite/page.dart` currently displays `service.location` directly as its subtitle, exposing an Android SAF `content://...` tree URI. Auto Backup already handles this correctly: `lib/core/backups/auto/widgets.dart` watches `autoBackupDirectoryDisplayPathProvider(location)` from `lib/core/backups/auto/providers.dart`, which calls `AutoBackupRepositoryAndroid.directoryDisplayPath(location)` from `lib/core/backups/auto/repo_android.dart`. For Android's external-storage documents provider, it renders the decoded volume-relative folder path (for example `Documents/MiteMite`, or `<volume>/Documents/MiteMite`). For other SAF providers, it requests `directoryDisplayName` on the existing `boorusama/auto_backup` MethodChannel; `AutoBackupChannel.kt` reads the DocumentProvider's `COLUMN_DISPLAY_NAME` without creating backup folders. For ordinary non-SAF paths it returns the filesystem path.

**Implement:** Reuse this *display-only* facility for the **Storage Location** subtitle, or factor it into a shared named utility/provider if necessary; do not implement a second unsafe URI decoder or a duplicate Android channel. The persisted `service.location` must remain the **original opaque SAF tree URI** for read/write permission checks, sync storage and folder relocation. The formatted string is for display only and must never replace the actual location in preferences, path comparison, transport operations or validation.

- When location is absent, show an appropriate translated `Not Configured`/choose-folder prompt; while resolving, show the existing loading treatment.
- On failure/revoked permission/opaque provider with no display name, show a **localized, user-friendly unavailable-location message** and an actionable location-selection/permission-repair path; **never fall back to exposing the raw `content://` URI**.
- Use 1–2 lines with ellipsis for normal narrow layouts and a way to inspect/copy the **human-readable** location if appropriate; respect text scaling and accessibility. Actual path capitalization is untouched by Title Case.
- Do not add an extra `/v1` or internal device/catalog path: show the **user-selected transport root**, not Boorusama's internal publication directory.
- Preserve the ability to reconfigure a relocated shared directory without resetting publisher identity, subscriptions, received mirrors, anti-rollback history or local read state.

**Tests (unit/widget + authorized Android SAF):** `primary:Documents/MiteMite` displays `Documents/MiteMite`; non-primary volume path; different provider returns its real display name; absent/invalid/revoked grant does not show a raw URI; UI refresh after changing folder; offline and restored permission; non-Android path unchanged; nested mobile/desktop layout and large font. Do not claim arbitrary provider opaque IDs are physical filesystem paths.

## Source audit / existing integration boundaries

- `lib/core/backups/mitemite/reading_state.dart`: `SyncGroupReadingState.unreadMembers = members - readMembers` already provides a persistent, Group-specific, portable-identity Unseen set. `markRead` persists seen content independently from `arrivals` / `acknowledgeArrival`. Retain source-specific read states and durable journal compatibility.
- `lib/core/bookmarks/src/pages/bookmark_group_browser_page.dart`: `_arrivalSummary()` currently unions `reading.arrivals` and `hasUnseenChange` across a subtree; the card displays that count as `+N`. `_acknowledge()` runs when a Group opens/renders and clears that arrival notification. **Both are the wrong UI semantics now.**
- `lib/core/bookmarks/src/widgets/bookmark_local_group_card.dart`: renders `arrivals > 0 ? '+$arrivals' : '•'` at bottom-right, and renders `Icons.folder` when `hasChildren`. Replace these *presentation* behaviors without accidentally changing underlying ownership or the selection checkmark slot.
- `lib/core/bookmarks/src/widgets/bookmark_scroll_view.dart`: already computes selected unread keys via `SyncGroupReadingState.unreadMembers` for conditional Mark Read. It renders mixed `BookmarkPostEntry`, `BookmarkPoolEntry` and `BookmarkNativeGroupEntry` and currently has no Unseen overlay/filter. Viewer entries must carry the correct originating received Group.
- `lib/core/posts/post/src/widgets/image_grid_item.dart` puts ordinary source/type indicators **top-left**, score **bottom-left** and quick actions **bottom-right**. Use a separate top-right overlay for Unseen. `lib/core/posts/listing/src/widgets/default_selectable_item.dart` composes `KurumiSelectableItem`, whose **top-right is a Preview/Zoom button during selection** (and bottom-right is the selection checkmark). Therefore, **hide the top-right Unseen dot while selection mode is active** rather than obstructing Preview; the group's Seen/Unseen filter and conditional Mark Read continue to reflect read state. This deliberate collision rule supersedes the earlier “dot beside site icon” proposal.
- `lib/core/content/widgets/native_content_grid.dart`: native Group cards are `PoolGridItem` wrapped by `BooruMediaGroupBookmarkPresentation.wrapBookmarkMenu`. There is currently no normal native Group selection controller; `lib/boorus/pixiv/works/work_presentation.dart` wraps them in `PixivWorkBookmarkContextMenu` (`bookmark_actions.dart`) exposing only `Entire Work`. This is a **pre-existing code path also on develop**, not a regression introduced by the reviewed #144 documentation commit, but the owner explicitly requests its correction.
- `lib/core/backups/mitemite/notifications.dart`: device discovery uses `Kurumi.showSuccessToast`. `local_events.dart` persists discovery receipts. The app already depends on `flutter_local_notifications` and has native integration patterns in `lib/core/downloads/background/notification.dart`; Android declares `POST_NOTIFICATIONS`.
- `lib/core/backups/mitemite/page.dart`: This device uses a large raw identity tile; Publish rows use leading upload icons, unhelpful `Direct/All children` descriptions and prominent Stop icons; device alias action is `t.alias`; Subscribe success explicitly calls `Kurumi.showSuccessToast`. `bookmarks/src/pages/bookmark_group_browser_page.dart::_deviceSlivers` places divider before the device title.
- Latest local handoff reports **Following service/UI connected** at `ee124f356` with 1,249 scoped tests. Do not incorrectly label Following as unimplemented based on older handoffs. The broader #144 fault/SAF/retention/release work remains separate.

## Implementation tasks

### Task A — Make the unread Group badge authoritative

**Files:** `reading_state.dart` if a pure projection helper is helpful; `bookmark_group_browser_page.dart`; `bookmark_local_group_card.dart`; existing real-provider/group UI tests.

- For each **received** Group use its authoritative `SyncGroupReadingState.unreadMembers`, **not `arrivals`**, to derive the bottom-right count. `unreadMembers` already excludes removed members. A newly received Group with five never-viewed members shows **`5` immediately**, even before the user opens it.
- Preserve the existing subtree aggregate concept: a parent card summarizes **unique portable member identities that are still Unseen in at least one received member Group in its own publisher subtree**. Deduplicate the same portable identity across sibling/parent entries and virtual direct-root links; do not merge read flags across independently owned source Groups. A Post seen in Group A but unseen in Group B remains unseen for B; a shared parent count includes that identity once if any covered Group still considers it unseen.
- Delete/disable the **Group-open acknowledgment effect from the visible badge**. Opening, scrolling or displaying the Group grid may not call anything that changes its Unseen count. If the historical `arrivals` / `hasUnseenChange` model remains for compatibility or activity metadata, it **must not drive the Group badge, event dot or Group-opening UI**. Do not delete historical private journal fields or reset checkpoint state without a separately tested migration.
- Rename misleading presentation variables/labels such as `arrivals` on Group cards to `unseenCount` where appropriate, show plain `N` with zero hidden, preserve bottom-right selection priority and accessible semantics `N unseen posts`.
- Remove the obsolete folder glyph on nested Group cards. A received mirror can retain a subtle distinct status marker but no combined folder/sync symbol.
- A Viewer display/explicit Mark Read must update the affected Group and any parent aggregate reactively; do not require a fresh transport scan. Unsubscribe/verified deletions/rearrival/source rename retain correct counts and independent read state.

**Required tests:** zero/five unread; opening Group never changes number; viewing one -> 4; marking selected two -> 2; reopen/restart retains 2; parent/child same identity but different read flags; two publishers; A and independently subscribed B virtual link; source rename/reorder; remove/reappear previously viewed identity; local Groups without received owner show no badge.

### Task B — Per-member top-right Unseen dot and Seen filter

**Files:** `bookmark_scroll_view.dart`, existing thumbnail/Grid components only where necessary, Bookmark native Group/Pool cards, read-only projection helpers and tests.

- For **received Group member cards only**, derive Seen/Unseen from the owning Group and `syncBookmarkMemberKey(record)`. Do not infer from all local Bookmark memberships, a thumbnail URL, global bookmarks or current appearance. Native saved Work/Pool references also need their typed member identity; no automatic “all Pages seen” on visiting a Work.
- **Placement:** **top-right** of the thumbnail image, inset about **4–6dp** as required by clipping/rounding. Match the other thumbnail overlay elements at approximately **20dp total height** (see `ThumbnailOverlayDimensions.extent`), using a filled theme-accent round badge with contrasting outline/backplate. No tiny 8–10dp-only pinpoint requirement. Noninteractive `IgnorePointer`; accessibility meaning `Unseen`. Do not move the site logo, source/type overlay or quick actions.
- **Selection collision rule:** the existing `KurumiSelectableItem` uses **top-right Preview/Zoom while selecting**. Hide the Unseen marker when selection mode is active (or use an equivalent non-overlapping existing convention with the exact same user-observable outcome). Do **not** obstruct selection, Preview, bottom-right checkmark, favorite/quick actions or long press. Seen items show no dot.
- Add compact **`All / Unseen / Seen`** control in the existing Group listing controls only if there is a mixture in the **complete, unfiltered owning Group membership**. If a non-`All` filter is active and the membership changes to all Seen/Unseen, keep the control visible until reset; an empty-filter state must have a clear way back to All.
- Compose state with current sorting, search, availability, projection and selection. **Never let a Post grid/controller index drift from the filtered `BookmarkGridEntry` identity.** Viewer opens the correct displayed occurrence; selected actions operate only on displayed/selected keys. Clear or reconcile selection when the filter hides entries. Count badge across the full Group, not only filtered/search-visible results. Update dot/filter after a real read commit without altering the publisher-owned structure.
- Accessibility: labels reflect current Seen/Unseen, not only color; high contrast and 320dp/150%-200% text checks.

**Required tests:** all Seen/all Unseen hide filter; mixed shows; filter currently active with no matching items remains resettable; search/sort/interleaved typed entries; per-Group identity independence; received-only and mixed-local records; unavailable content; viewer returns to the correct occurrence; selection/preview top-right collision; no dot or filter in ordinary Local Groups.

### Task C — Restore standard Pixiv Work timeline selection

**Files:** `lib/core/content/widgets/native_content_grid.dart`, `lib/boorus/pixiv/works/work_presentation.dart`, `bookmark_actions.dart` only for reuse of the existing Work Bookmark target/action, shared selection code and relevant tests.

- Introduce the app's **existing standard multi-selection controller/surface** for native Group content, using each **Work reference/occurrence** as the selection identity. Respect disabled interactions, normal tap, long press, selection tap, cancel, keyboard/desktop behavior, and the same standard selection chrome as other listings. Do not leave long press inert.
- **Long-press a Pixiv Work = begin selection**, never show a standalone `Entire Work` context menu. In selection mode, the toolbar/menu must offer the ordinary **Work Bookmark** operation/picker already used for entire Works, using captured Work access/source and accepted local Bookmark semantics. With multiple selected Works, use the project's normal bulk-bookmark flow or extend its existing typed action safely; no Page-target fallback and no new bespoke dialog. Preserve ordinary single-Work bookmarking outside selection via the existing viewer/action.
- Source identity and available actions must be validated for each selected Work; changing or losing a profile must not silently apply an action to another Work. Other native Group engines should not accidentally inherit Pixiv-specific actions.

**Required tests:** long-press -> selection with one Work selected; no `Entire Work` context popup; tap another Work adds it; existing Work Bookmark selection action opens correct picker/target for single and multiple Works; exit restores normal tap-to-viewer; source changes/unknown Work handled safely; no regression to normal Post selection.

### Task D — Android notification and concise subscription

**Files:** `mitemite/notifications.dart`, `local_events.dart` only if needed, app notification initialization/navigation, `mitemite/page.dart`, widget/native notification tests.

- Replace discovery **success toasts** with **Android OS local notifications** using the app's existing notification dependency. Use a distinct channel and correct tap/deep link into trusted-device management/Receive; do not publish untrusted collection titles/counts. Dedup per durable publisher+fingerprint across restarts/polls. Handle Android notification permission denial by retaining discoverability in the app Activity/Receive page **without a substitute toast**. Do not claim delivery while the app is terminated; detection currently runs during permitted foreground/resume scans.
- Remove the success toast in `MiteMitePage._subscription` entirely. Successful subscribe becomes visibly **`Subscribed`**; failure remains truthful with existing error feedback. Remove any redundant `Subscribed; content is read-only...` explanatory copy, without weakening write guards.

**Required tests:** native notification received once, channel and permission, denial, tap navigation, repeated scans/relaunch, unrelated pending events, privacy before trust, subscribe no success toast/accurate Subscribed state.

### Task E — Apply the already-approved clean UI adjustments

**Files:** `mitemite/page.dart`, Bookmark Group Home browser/card, English localization resources and accessible widget tests.

- **This device:** compact prominent device name and status, with ID/fingerprint behind accessible `Device details` disclosure and copy controls; keep location, Sync now and trust-verification details available. Follow existing Kurumi design, keyboard resize and 320dp/large-text behavior.
- **Publish:** direct published roots only. Row has **no leading upload icon**, **no redundant “All children” subtitle** and **no prominent stop-circle action**. Use a trailing `...` menu with **Stop publishing** + overlap-aware confirmation. Secondary text only when it clarifies inherited/direct overlap, missing source, pending error or similar exceptional status.
- **Device alias button:** label **`Edit`** (editor can still say device alias), retains current persisted alias semantics; empty alias restores publisher's name.
- **Bookmark Home device heading:** **name leftmost**, flexible full intervening divider, **Edit pencil rightmost**, with title truncation and accessible touch target. The pencil invokes the **device alias editor directly**, not a menu or generic navigation. Do not prepend a divider.
- **Group card icon:** remove `Icons.folder` from nested Group cards (there is no separate Folder entity). Replace received `Icons.sync_lock` with one compact incoming/mirror glyph shared with the opened Group title; do not create a folder+sync or lock-based icon.
- **Subscribed:** short status only; no redundant read-only explanation or toast.

**Required tests:** before/after narrow and desktop geometry, 150%-200% text, RTL where applicable, long aliases, keyboard edit, focus/overflow popups, direct/inherited Publish stop scope, device header menu alignment and no clipped labels.

## Spec/test cleanup and acceptance

1. **Fix all contradictory documentation**: `docs/designs/2026-11-03-folder-based-collection-sync.md` sections **6.1–6.2 / 7** and its scenarios currently say `+N` means recent arrivals and Group opening acknowledges it. Replace with the owner's **persistent Unseen Post count `N`** and **no change on Group open**; update accessible labels, expected tests and v5 mockup explanations. Revise the earlier [QA note](144-owner-ux-feedback-2026-11-14.md) sections 6–7 and historical handoff text with a clear dated supersession, **without rewriting historical test evidence as though it tested the new behavior**.
2. Preserve the separate existing **Following Post NEW** and Following definition-change glyph semantics; the above Group badge behavior applies to **received Bookmark Groups**, not to Following.
3. Add model/projection unit tests and production-provider/widget tests that demonstrate durable read state, parent aggregation, filtering, index stability and no Group-open acknowledgement. Exercise actual full Viewer read gating for stills/video without claiming thumbnail/preload counts. Verify app behavior using authorized leased Android emulator(s), including notifications and selection gestures.
4. Follow `AGENTS.md`: focused tests/analysis and formatting for each scoped change, then the **complete repo regression** on the final source if shared Group/read models or common timeline selection are modified; Android build and actual two-device read/notification/SAF scenarios as appropriate. Keep complete logs under durable ignored `.worktrees/_artifacts/144-...`.
5. Preserve existing signed transport, replay floor, journal, received read-only ownership, overlap-safe cleanup, local-only All Bookmarks and publisher identity; no hidden deletion/reimport, no forced app data reset or new network service.
6. Commit and push scoped completed changes on the **existing feature branch**, independently review important read-state/selection changes, update the primary #144 handoff with **exact runtime SHA, executed test counts, Android evidence and residual risks**. No merge, PR or issue closure without explicit approval.

## Completion checklist for this UX pass

**Verification result (2026-11-15):** Initially qualified on runtime `99a3b71b2`; final runtime `86e221083` includes the later owner-approved combined-subtree reading and notification contracts. Checkmarks below combine the focused production-provider/widget tests, full repository regression and actual Android cases recorded in the [final handoff](144-interrupted-web-remediation-2026-11-14.md). They do not claim every variation was exercised manually on Android; that handoff distinguishes native, host and transport limits. No merge, PR or issue closure is authorized.

- [x] Received Group with five unseen members shows **`5`** before and **after** opening, without marking them Seen.
- [x] Viewing one saved member in its actual full Viewer shows **`4`** in the individual Group scenario. In a combined subtree view, that member becomes Seen in every covered canonical Group; unrelated Groups/publishers remain unchanged.
- [x] Group badges remain correct through restart, source update, parent/child overlap, Unsubscribe and reappearance.
- [x] Unseen marker is **top-right, approximately 20dp tall** like other overlays in normal grid view, and does **not collide** with top-right Preview in selection mode.
- [x] `All / Unseen / Seen` appears only for mixed read state or active filter; results and selection keys remain correct.
- [x] Pixiv Work timeline long press uses ordinary selection, with the usual Work Bookmark action; no `Entire Work` context popup.
- [x] Subscribe updates to **Subscribed** with **no success toast**.
- [x] New-device alert is an **Android notification**, with permission/privacy/dedup/tap behavior tested.
- [x] The received root and child Group **Timeline-toolbar `...`** shows normal View Options where the local equivalent does, and **never includes Group-level MiteMite actions**.
- [x] This device, Publish, alias Edit, device heading/divider/menu and no Folder glyph match the owner-approved UX.
- [x] Revised spec/tests reflect **persistent unread-count semantics**, not obsolete arrivals, and final checked SHA is reported.
