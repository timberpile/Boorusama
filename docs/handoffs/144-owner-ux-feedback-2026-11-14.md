# #144 — Owner UX feedback on Android QA checkpoint

> Naming normalization (2026-11-17): Historical paths and symbol references below use current MiteMite names. Recorded commit IDs and verification results are unchanged; consult the original commits for exact historical commands and artifact locations. These reference edits do not requalify earlier evidence.

**Status:** Requirements and implementation guidance, **not a runtime change**. Recorded 2026-11-14 against branch commit `78adbb7927a7e973c13acb2be54b51246739bf46`. Continue the existing task worktree; never merge, PR, close #144 or operate protected physical phones without approval.

The owner's exact observations take priority over this note. The existing [v5 spec](../designs/2026-11-03-folder-based-collection-sync.md) still defines source-owned one-way mirrors and separate arrival vs Post viewing states.

> **Superseded read-state/notification/selection wording, 2026-11-14:** The [final owner UX contract](144-final-owner-ux-implementation-2026-11-14.md) replaces sections 6–8 where they conflict. Group badges are persistent Unseen member counts `N`, never arrivals `+N`; opening a Group does not clear them. The thumbnail dot is top-right and hidden during selection. Pixiv uses standard Work multi-selection and its ordinary Work Bookmark action. New-device notices are native notifications; Subscribe has no success toast. The observations below are historical, not acceptance of the new behavior.

## Feature identity: proposal, not a naming decision

The owner proposed **MiteMite** (`見て見て`, colloquial “Look, look!” / “Check this out!”), or shorter **Mite**, for the media/social-facing feature. The app is English-language. **Superseded naming decision:** MiteMite was approved for the product surface on 2026-11-14 and for all code, native and persistence identifiers on 2026-11-17. The owner confirmed the feature is unshipped and requested no naming migration or compatibility aliases.

A naming check found an existing iOS social app named **MiteMite** specifically serving anime/fandom communities (App Store listing: https://apps.apple.com/de/app/mitemite/id6778221764). Evaluate product-name confusion before adoption; no trademark clearance has been performed.

Bookmark organizational structure now consists of **Groups**, not a distinct Folder type. Do **not** put a folder glyph on Group cards just to denote hierarchy or one-way mirroring. Preserve group-cover identity, compact publishing/received affordances where useful and the existing arrival badge.

## Owner feedback and concrete acceptance contract

### 1. Android system notifications, not discovery toasts

**Current source:** `lib/core/backups/mitemite/notifications.dart` calls `Kurumi.showSuccessToast` for newly discovered devices. `local_events.dart` already persists discovery delivery receipts. Boorusama has `flutter_local_notifications: ^22.0.1`, `POST_NOTIFICATIONS` in AndroidManifest and an existing implementation in `lib/core/downloads/background/notification.dart`.

**Required:** New-device and other notification-worthy asynchronous sharing events should appear as real Android system notifications (notification shade), **not as foreground success toasts**. Tap should route to the correct device/Receive view via the existing navigation owner. Use a dedicated notification channel and shared/compatible plugin initialization; handle Android 13+ permission and denied permission without presenting a toast as a substitute. Keep event history visible in the feature. Preserve durable dedup across polls/restarts and do not send collection metadata about untrusted devices. Notifications occur when foreground/resume scans detect events; do not claim terminated-app push delivery. Ordinary **user-initiated action feedback** can remain a concise toast if it is not being presented as an event notification.

**Tests:** first device detected -> one native notification and correct tap target; repeat scans/restart -> no duplicate; permission denied -> no toast, event stays in activity; multiple devices/batch; trusted and untrusted privacy; background/foreground lifecycle, detached host, app startup and channel identity.

### 2. Simplify the “This device” section

**Current source:** `lib/core/backups/mitemite/page.dart:94-199` shows Shared folder, Device name, a raw multi-line UUID/fingerprint tile, status, and count-bearing navigation rows.

**Required:** Make this a compact scannable identity/status panel. Keep the device's editable display name prominent; place long ID and public-key fingerprint behind an explicit, accessible **Device details** action/disclosure with copy controls, while retaining their full availability for trust verification. Avoid repeated labels, giant text blocks and unnecessary row heights. Keep folder selection, Sync now, status and counts discoverable. Match Kurumi styling, 320dp, 150%-170% text and keyboard insets. Do not hide the security information irretrievably.

**Tests:** narrow/desktop, long device name, keyboard, copyable ID/fingerprint, permission/error status, return/Back semantics.

### 3. Simplify Publish management entries

**Current source:** `mitemite/page.dart:219-263`. Each published root renders a leading upload icon, `Direct`/`Direct + via parent` plus `All children` description, and a trailing large stop-circle button.

**Required:** Remove the **leading icon**. Avoid a prominent destructive “Stop publishing” icon on each row. Prefer a compact trailing `...` action menu containing **Stop publishing** (confirmed with overlap-safe removal implications), or a subdued textual action if no menu is warranted. Show the Group title as primary; suppress the always-true “All children” description. Show secondary info only when it materially disambiguates direct+inherited coverage, missing/offline status or a pending failure. The management page remains a list of *directly published roots only*. Do not change signed recursive publication semantics, and do not introduce an extra Folder entity.

**Tests:** normal single published root has no redundant subtitle/icon; direct+inherited displays correct reason only where needed; offline/stop confirmation; removing A retains direct B and vice versa; keyboard/menu/overflow focus and accessibility.

### 4. Rename the device alias action

**Current source:** `mitemite/page.dart:366-389` renders a text button labelled `Device alias`.

**Required:** Label the actionable button **Edit**, keeping the device name as visible context. Reuse the existing local alias edit flow. The “device alias” concept can remain in the editor's descriptive text where useful, but should not be the button label. Include English translations and localized equivalents without changing internal data keys.

**Tests:** button label, opens alias editor for the correct device, empty alias restores publisher name, persistence across restart.

### 5. Bookmark Home device section header

**Current source:** `bookmark_group_browser_page.dart:820-855` renders `Expanded(Divider)` *before* the name, then an ellipsis button.

**Required:** The device title must start **leftmost** inside the header's usual horizontal margins; the `...` button must be **rightmost**. Use the available intervening width for a subtle divider: `[device name] [expanding divider] [...] ` — not divider-name-menu. It should run across all the remaining horizontal space between the two anchor elements. Preserve text truncation, touch target, clickable device menu, RTL adaptation and group-tree alignment. Reuse the compact existing Home card geometry.

**Tests:** 320dp/390dp/desktop, extremely long alias, RTL where supported, ellipsis focus and tap, group card alignment, no clipped divider.

### 6. Per-Post unseen indicator and contextual filter

**Current source:** `SyncGroupReadingState.unreadMembers` in `mitemite/reading_state.dart`, `BookmarkScrollView` in `bookmarks/src/widgets/bookmark_scroll_view.dart`. A received Group's `+N` arrival badge is **not** a Post read-status indicator.

**Required:** In each received Bookmark Group, mark genuinely unviewed saved Post/typed collection occurrences in the grid with a **compact visual signal** (dot/outline/accent marker) that remains legible on varying thumbnails and accessible to screen readers. No card-size jumps or intrusive “NEW” labels. Use the Group's canonical owner/read-state and portable member identity; do not propagate one Group's seen state to another device/Group, and do not count mere thumbnails, adjacent preloads, failed media or opening the Group as a Post view.

Add a small filter with **All / Unseen / Seen** (or equivalent) to the existing listing controls. **Only show the control if the full, unfiltered received Group contains at least one Seen and at least one Unseen member**, or while a non-All filter is selected so the user is never trapped in a filtered view. Do not show this filter on ordinary local Groups that have no corresponding read-state model. Combine it correctly with existing search, sort, availability and selection; changing filters must not retain hidden selection/actions against unrelated entries. When a viewed Post changes state, update its marker/filter results reactively without mixing Groups or resetting arrival badges.

**Tests:** all seen -> hidden filter; all unseen -> hidden filter; mixed -> visible; selection then filter; change to seen while viewing and return; re-open/restart; same source identity in multiple Groups with independent read states; independently subscribed child/root virtual links share one canonical state; unavailable snapshots/typed Work/Page/Pool cases.

### 7. Preserve distinct arrival acknowledgements and actual Post reading

**Owner observation:** Simply entering a Group clears its Group unseen count, but selecting an unviewed Post still offers `Mark Read`/“Mark Seen” until that Post is actually viewed.

**Contract:** This is **intentional** under the approved v5 spec, not itself a persistence bug. Group open acknowledges only its own newly **arrived** membership `+N`/dot *after rendered content*; per-Post `unreadMembers` remains until the real full Viewer or explicit Mark Read/Seen action. Do not “fix” the report by marking all Posts viewed on Group open. Make the distinction understandable through the new Post indicator and filter, potentially with accessible labels “New additions” vs “Unseen post”.

**Tests:** Group arrival count clears after rendering, Post unseen marker and Mark Read remain; viewing exactly one Post clears only its read state; hidden/preloaded media do not; selection Mark Read only when selected contains unseen and never clears arrival count; parent and child arrivals independent.

### 8. Pixiv timeline long-press selection regression (cross-feature)

**Current source:** `lib/core/content/widgets/native_content_grid.dart:288-352` uses `GroupContentEntry` + `PoolGridItem`, then `BooruMediaGroupBookmarkPresentation.wrapBookmarkMenu`. Pixiv implements that in `lib/boorus/pixiv/works/work_presentation.dart:65-69` with `PixivWorkBookmarkContextMenu`; `lib/boorus/pixiv/works/bookmark_actions.dart:333-350` exposes `Entire Work` as a sole context action. The same files are byte-identical on `develop` at audit time; the behavior did not originate in the #144 commit, although the owner reports it now.

**Required:** Long-pressing a Pixiv *timeline* Work thumbnail should **enter the ordinary grid multi-selection mode**, as on other timelines, not show the lone “Entire Work” menu. Use the existing selection framework and maintain Work-level identity/selection semantics (each native card is a Work; do not silently select arbitrary Pages). Removing the context-menu wrapper by itself is not sufficient if long press remains inert: `NativeContentGrid` currently has no equivalent Group-card selection controller. Preserve Work bookmarking via the intentional primary/action/overflow path. Verify any standalone Post entries and grid/keyboard/context interactions. Do not alter the unrelated Pixiv Work/Page Viewer bookmark decisions still under separate UX discussion.

**Tests:** one-finger long press selects Work; long press does not show “Entire Work” context menu; normal tap opens viewer; further taps extend/cancel selection; selection toolbar actions target valid Works; other native Group engines remain unaffected; desktop right-click/keyboard behavior intentional. If this is owned by a separate Pixiv issue, cross-reference it without delaying the agreed Sync safety invariants.

### 9. Subscription status copy

**Current UI:** Some subscribed text explains `Subscribed; content is read-only ...`.

**Required:** Display simply **Subscribed** in the corresponding status/subtitle. Read-only ownership remains enforced at repository and menu level; do not repeatedly explain it in ordinary status labels. Optional accessible help can clarify semantics where genuinely necessary, but not in each row.

**Tests:** subscribed status exact label, Unsubscribe affordance, no source-edit actions, accessibility state and no pre-trust collection disclosure.

## Cross-cutting verification

- Execute the affected widget and real-provider tests first; use the real app router for navigation and Android system notifications for delivery tests. Verify actual UI with authorized leased emulators only.
- Run the final candidate's complete repository regression, analysis, Kotlin/build and real SAF/two-device checks per `AGENTS.md`. These QA items are **not** accepted by the documentation-only review.
- Preserve signing, anti-rollback, source-owned/read-only mirrors, receiver-local reading/aliases, stable IDs, overlap-safe Unsubscribe/Forget and local-only All Bookmarks.
- Do not rename protocol files/keys or invent two-way editing because the user wants more consumer-facing terminology.
- Report exact tested SHA and limitations. Do not merge or close #144 without owner approval.
