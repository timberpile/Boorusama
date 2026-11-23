# Group Viewer and Timeline modes — issue #176

**Status:** proposal for discussion, not an approved Flutter implementation.\
**Date:** 2026-11-18. **Issue:** [#176](https://github.com/timberpile/Boorusama/issues/176).\
**Branch:** `feature/176-group-viewer-design`.\
**Inspected baseline:** `develop@a9ce9de09e4a9d8c994c24804d7c65ef8cefe270`.

[Interactive prototype](176-group-viewer/index.html) · [UX critique and independent-review brief](176-group-viewer/ux-review.md) · [Verification and limitations](176-group-viewer/verification.md)

Download `index.html` and open it in a browser. GitHub's file view displays source, not a running prototype. The HTML embeds its styling, behavior and original illustrative SVG fixtures; it needs no network or account. The surrounding design-study controls are not proposed app settings.

> **Latest correction, 2026-11-18:** Related Groups now default to **Single**. The earlier **Custom Related order** feature was an incorrect interpretation and is withdrawn. Only the existing **Oldest / Newest** selector is needed, accessible in both Single and Timeline and persisted using the existing Related Bookmark `preferredOrder`. This file retains historical exploration; the [current screenshot-aligned design](176-group-viewer/screenshot-alignment.md) and [updated HTML](176-group-viewer/index.html) are authoritative.

> **Updated 2026-11-18 after real app screenshots and architectural clarification:** the user selected **B+**, a direct one-tap switch between Single and Timeline in existing chrome, retaining one **shared** fullscreen viewer (not a Pixiv-specific viewer). Immersive and Detailed remain states of Single. The [screenshot-aligned design and verified code boundaries](176-group-viewer/screenshot-alignment.md) and [updated HTML](176-group-viewer/index.html) supersede the first study's A recommendation, global Single default, permanent group header, and outer navigation rail. [Archived initial mockup](176-group-viewer/original-study.html).

## Initial recommendation (superseded by screenshot-aligned B)

Use **A: a labelled `Single | Timeline` segmented control** within the existing group viewer, immediately below the compact Back/title/Info header. Keep **Order separate from presentation** and available in both modes. Reuse the existing media viewer, member timeline, source-bound actions and Details presentation rather than inventing another navigation stack.

Single means one member's media at a time. Timeline means the group's existing image-list/grid presentation, not the outer feed, a chronological sort, or a new social feed. The prototype includes one-, two- and three-column arrangements; one column also demonstrates a vertical image stream. Display density is independent of member order.

This recommendation is a design judgment, not a measured usability result. Flutter documents segmented controls for small, mutually exclusive sets including view switching; this supports the control category, not its superiority in Boorusama specifically. Implement the appearance through existing Kurumi components or an appropriately themed wrapper, not an unrelated default Material surface. [E1, R1]

### Three working variants

| Variant | Interaction | Benefit | Cost / recommendation |
| --- | --- | --- | --- |
| **A — labelled header-adjacent pair** | One tap to either visible mode | Explicit alternatives and selection; stable placement across group kinds | A dedicated row costs media height. Recommended starting point. |
| **B — compact header view menu** | Tap view icon, then choose labelled Single image or Timeline | Frees a row and preserves more media space | Alternative is hidden and needs another tap. Keep as the space-saving candidate, not the default. |
| **C — bottom segmented pair** | One tap above the existing action area | Easier to reach with one hand | Competes with member navigation, actions and system gesture area; resembles navigation tabs. Do not lead with this variant. |

The same state and member sequence drive all variants. Switching variants is a study operation, not a product feature. A Boolean switch and an unlabelled icon-only flip were rejected: they respectively suggest an on/off setting or conceal the two available presentations. Do not silently substitute B when text grows; wrapping must preserve the user's learned control and labels.

## What exists today

The following facts are from the pinned baseline, not inferred from screenshots:

- `GroupLayout` currently selects `memberGrid` or `mediaPager` through engine-owned presentation. Pixiv selects `mediaPager`. Unifying the experience therefore needs selected presentation state above that existing default; merely changing every adapter to return one enum value is insufficient. [R2, R3]
- `MediaGroupPage` owns the inner media region. The shared `PostDetailsPageView` owns outer occurrence paging, Details, system chrome and overlay. Keep this division. The existing code also preserves the cover until actual page media paints. [R4, R5]
- `MediaGroupCheckpoint` belongs to an **outer occurrence** and tracks `memberKey`, not just an index. `GroupMember` separately carries source position and availability. Its validation explicitly preserves occurrences and source positions instead of compacting missing members or deduplicating repeated posts. [R6, R7]
- Related currently offers oldest/newest using ID ascending/descending. **Custom manual ordering is new scope**, not an existing feature to expose. Pool order currently distinguishes Ordered, Latest and Oldest. [R8, R9]
- The overlay uses safe-area-aware circular Back and Info controls. Work-specific actions compose into the existing action toolbar; access context is retained only while authorization remains compatible. [R10, R11]

The mockup follows these structural cues: compact header, circular Back/Info, dark fitted-media canvas, image-dense timeline, source/profile subtitle and familiar action area. It does **not** establish exact runtime colors, font metrics, icons, or pixel-perfect fidelity. No current Android screenshot was visually compared. The inspected style guide itself distinguishes proposed baseline guidance from already accepted contracts. Production theme tokens and established widgets remain authoritative. [R1]

## Group-specific behavior

| Group | Initial order | Allowed ordering | Display language and scope |
| --- | --- | --- | --- |
| Related | Oldest first, unless a saved choice exists | Oldest first, Newest first, proposed Custom order | `Post 3 / 6`; posts retain individual identities and actions |
| Series | **Ordered** | Source sequence only in this proposal, as requested | `Post 3 / 6`; labels describe source sequence, not upload dates |
| Pixiv Work | **Page order** | Author page sequence only | `Page 3 / 6`; Work and Page actions remain distinct |
| Pool / Collection | Ordered | Retain supported Ordered / Oldest / Newest choices | `Post 3 / 6`; available options remain adapter-dependent |

Pools are included because #176 explicitly includes them, even though the user's examples emphasized the other three kinds. Do not flatten Series, Related and Pixiv into identical action capabilities merely because they share a viewer.

### Related ordering

The same text-labelled Order control opens the same editor from either presentation. Standard sort changes and custom edits are drafted; **Save** applies them to both views, **Cancel** discards them, and an **Undo** action restores the previous order while this context remains active.

Custom ordering is a local presentation overlay over stable **member occurrence keys**. It must not write remote parent/child relationships, rewrite source positions, or turn a Related group into a Series. Store it under the stable group identity plus site namespace and profile scope; the HTML demonstrates session state only. Device sync of this preference is outside this proposal. Selecting a standard sort must not destroy the saved custom sequence.

The editor provides explicit move-earlier/move-later buttons. A production drag handle may supplement them, not replace them. W3C's dragging criterion requires a non-drag pointer alternative; keyboard support alone does not provide that alternative. [E2] The HTML intentionally implements button reordering rather than claiming native drag behavior.

A partial manifest cannot be presented as a complete reorderable group. Block creating or modifying Custom until the membership manifest is complete; allow cancelling and selecting supported standard sorts. Existing custom state can remain stored while temporarily incomplete. Reconcile refreshed members by key: preserve surviving custom relative order, append newly discovered members in source order, and never retarget selection using its old index. Show an explicit notice when an authoritative manifest removes the selected occurrence. A tombstone must not disclose restricted metadata.

## Interaction contract

### Entry and mode preference

For a new installation/profile with no saved preference, **Single is the proposed default** for supported media groups. An explicit caller request to open Timeline takes precedence. A remembered occurrence restores its own mode and member before considering defaults. Otherwise use the device-local last selected mode for that profile and group kind, so opening many Related groups does not repeatedly undo the user's choice.

Only an explicit presentation choice should update that preference; a technical fallback, restriction, or empty result must not. The prototype demonstrates per-kind session preferences with fixed fixture profiles. Durable storage, migration and cross-device behavior are not implemented here. The default remains a product decision for this context, not an approved requirement.

### Switching and selection

Both views consume one effective ordered sequence. Switching changes neither source nor membership. Preserve selected `memberKey`, group occurrence, source/profile binding and order.

On the first switch to Timeline, reveal the selected member and mark it `Current`. **Passive Timeline scrolling does not select another image.** Tapping a member selects it and opens Single in the same viewer. Returning to Timeline with unchanged selection restores its previous scroll position; changing the selected member or reordering reveals that member in its new position. Maintain the Timeline's scroll anchor separately from selection. This avoids the reproduced bug where image 4 became image 3 merely because image 3 was first in the same grid row.

For production, use a member occurrence key plus within-item offset for Timeline restoration; a raw pixel offset alone is insufficient after width, density or ordering changes. The HTML uses pixels for its fixed fixture layout and therefore is not the persistence implementation.

Retain the selected member's zoom transform in the existing bounded checkpoint; do not apply it to another member or to the Timeline. The prototype does not implement zoom.

### Two navigation levels

Inner arrows and the member picker navigate **within the group**. `Next item` and its paired previous control navigate **outer feed occurrences**. The explicit outer rail in the prototype is proposed UI, not an existing toolbar claimed to be reproduced. It makes the separation testable and accessible without discovering a swipe.

**Proposed boundary change:** stop inner navigation at the first/last member; leaving the group requires a deliberate outer action. Current code can transfer edge navigation to the outer occurrence, so this is not a no-op implementation detail. [R5] It reduces accidental exits but adds effort when reading many short groups. Before implementation, decide whether to keep the permanent outer rail or retain established toolbar/edge shortcuts with an explicit boundary indication. Never make a normal member arrow unexpectedly mean "next group" without communicating that change.

When more members can load, reaching the loaded edge requests group continuation, not the next outer item. Show a lower-bound loaded count rather than a false final total. Failure offers Retry in place and preserves the reading checkpoint.

### Back and Details

Mode changes do not push routes. Back first dismisses an open transient dialog/Details surface; otherwise it returns to the originating feed and its position. Hidden chrome by itself does not create another Back step. Native zoom/dismissal precedence must remain compatible with the existing viewer, not be replaced by the HTML's keyboard model.

Info opens the existing shared Details presentation in production. The HTML uses a modal to compare content: group facts, source/profile, current member, effective position, original source position and availability. It is not a request to replace the current media-to-Details transition with a generic popup. The real transition, expanded Details state, cancelled predictive Back and system-bar restoration need native verification. Android guidance requires predictable destination previews and respect for gesture insets. [E3, E4]

### Actions and access

Retain the engine's normal favorite semantics. Page/Post download and sharing remain member-targeted. Work bookmark controls and group-wide actions are explicitly scoped. The mockup illustrates Work-level Pixiv favorite/bookmark state and Page-level download/share; it does not establish a new native favorite API contract. Existing engine adapters must remain the authority. [R11]

Never resolve a cached member with the currently selected global profile just because a view changed. Revalidate authorization before loading media or executing actions. When a member is unavailable, keep its occurrence/ordinal and disable member operations. When restriction is known from the access policy, use a neutral restricted placeholder with **no retained image, title, tag or accidental preview** in either mode or return surface. The current member enum does not itself encode every restriction reason; only show a specific reason when independently available. [R7, R11]

Group actions may remain available when one member is missing if their own capability and authorization allow them. Missing media is not proof that the group itself is inaccessible. Download-all must report incomplete/skipped results rather than claiming all members succeeded. [R11]

## Presentation and accessibility

Use semantic Kurumi colors and existing spacing; the HTML palette is illustrative. Keep tappable controls out of system insets and retain the established opaque Timeline header contract. The prototype keeps the header visible to compare switch placement; production must retain the accepted hide-on-scroll/reveal behavior rather than copying this simplification. [R1, E4]

Use the app's 48-logical-pixel interaction target convention, selected-state semantics, named icon buttons, predictable focus return and non-drag ordering. The 48-unit convention comes from the app guide, not a claim that WCAG requires that exact value. Accommodate narrow layouts and large text through wrapping, not smaller targets. Prefer selected text plus shape/color indication; do not rely on color alone. Reduced-motion behavior must not alter identity or navigation.

Timeline cells preserve row-major reading order in this prototype. Avoid a CSS-column or masonry reading order that contradicts Series/Pixiv ordinals. Production should use existing grid contracts without reintroducing the discarded dynamic aspect-ratio relayout work. Portrait, landscape, long images, video and ugoira need real-media follow-up; the SVG fixtures are deliberately simple.

## Shared implementation boundary — not a second viewer

Keep the engine source, member hydration, source order and access validation in their current layers. Introduce a viewer-owned presentation choice and effective-order adapter, with an occurrence-owned checkpoint for selection and Timeline position. The existing `GroupLayout` can remain the capability/default decision; it must not become a global mutable preference attached to cached source data. [R2–R7]

Conceptually separate:

1. **Access-scoped group data:** identity, source metadata, member occurrences and canonical positions.
2. **Local group presentation policy:** permitted order choices, optional custom occurrence-key order, default-mode preference.
3. **Outer-occurrence reading state:** chosen mode, selected member, Timeline anchor, existing media transform and Details state.

These are responsibilities, not a prescribed new class hierarchy. Extend the current checkpoint and shared composition where appropriate; do not replace them wholesale. Keep stable widget identity through transitions and preserve already decoded media. Inactive presentations must not both eagerly hydrate or preload the entire group. Reuse the existing bounded restoration, source-scoped preload and cancellation behavior. [R4, R6]

Validate refresh/reorder races by captured occurrence, access generation and member key. A modal opened for group A must not save into group B after an outer navigation or source switch. Persist custom order atomically; a failed save must leave the previous order selected and offer retry. These are production requirements; the mockup has no asynchronous storage layer.

## Decisions still open

**Presentation switch (resolved):** B+ was explicitly selected. One tap switches to the other group presentation. The displayed icon signifies the **destination** (grid in Single; single image in Timeline), with accessible localized labels; keep the existing viewer shell and do not add a new row. B remains a historical menu comparison, not an open choice.

**Boundary behavior:** explicit outer navigation is safer but costs space and can slow sequential reading. This departure from the existing edge behavior needs Timber's decision.

**Preference policy:** Single initially, then last explicit choice per profile/kind, is proposed. Per-group overrides and persistence across restarts should be agreed before migrations are written.

**Custom-order scope:** the prototype includes both ordinary sort selection and genuine custom rearrangement to cover "manual ordering." If the intended scope is only user-selectable oldest/newest sorting, omit new custom persistence without changing the two-mode contract.

The requested independent UX specialist review has **not** happened: no subagent runner is exposed in this conversation. The accompanying critique is explicitly an author self-review, with a brief ready for a genuinely independent reviewer. No PR, merge, issue closure, runtime implementation or native-test claim is implied.

## Research references

All repository paths below refer to the pinned baseline unless otherwise noted. External references were checked on 2026-11-18. Design recommendations are interpretations, not direct prescriptions from these sources.

- **R1:** [UI style guide](https://github.com/timberpile/Boorusama/blob/a9ce9de09e4a9d8c994c24804d7c65ef8cefe270/docs/ui_style_guide.md).
- **R2:** [Group presentation capability](https://github.com/timberpile/Boorusama/blob/a9ce9de09e4a9d8c994c24804d7c65ef8cefe270/lib/core/content/groups/group_capability.dart).
- **R3:** [Pixiv Work presentation](https://github.com/timberpile/Boorusama/blob/a9ce9de09e4a9d8c994c24804d7c65ef8cefe270/lib/boorus/pixiv/works/work_presentation.dart).
- **R4:** [Media group page](https://github.com/timberpile/Boorusama/blob/a9ce9de09e4a9d8c994c24804d7c65ef8cefe270/lib/core/posts/details/src/widgets/media_group_page.dart).
- **R5:** [Shared viewer and edge navigation](https://github.com/timberpile/Boorusama/blob/a9ce9de09e4a9d8c994c24804d7c65ef8cefe270/lib/core/posts/details_pageview/src/post_details_page_view.dart).
- **R6:** [Media group checkpoint](https://github.com/timberpile/Boorusama/blob/a9ce9de09e4a9d8c994c24804d7c65ef8cefe270/lib/core/posts/details/src/types/media_group_checkpoint.dart).
- **R7:** [Member occurrences, positions and validation](https://github.com/timberpile/Boorusama/blob/a9ce9de09e4a9d8c994c24804d7c65ef8cefe270/lib/core/content/groups/group_member.dart).
- **R8:** [Related order values](https://github.com/timberpile/Boorusama/blob/a9ce9de09e4a9d8c994c24804d7c65ef8cefe270/lib/core/posts/related/related_posts_order_value.dart).
- **R9:** [Pool order values](https://github.com/timberpile/Boorusama/blob/a9ce9de09e4a9d8c994c24804d7c65ef8cefe270/lib/core/posts/pools/src/types/pool_details_order.dart).
- **R10:** [Shared viewer overlay](https://github.com/timberpile/Boorusama/blob/a9ce9de09e4a9d8c994c24804d7c65ef8cefe270/lib/core/posts/details_pageview/src/post_details_overlay.dart).
- **R11:** [Group actions and authorization retention](https://github.com/timberpile/Boorusama/blob/a9ce9de09e4a9d8c994c24804d7c65ef8cefe270/lib/core/posts/details/src/widgets/media_group_actions.dart).
- **E1:** [Flutter SegmentedButton](https://api.flutter.dev/flutter/material/SegmentedButton-class.html): small sets of mutually exclusive choices and view switching.
- **E2:** [W3C WCAG 2.2, Understanding Dragging Movements](https://www.w3.org/WAI/WCAG22/Understanding/dragging-movements.html): provide a non-drag pointer alternative.
- **E3:** [Android predictive Back design](https://developer.android.com/design/ui/mobile/guides/patterns/predictive-back): destination previews, cancellation and system gesture areas.
- **E4:** [Android edge-to-edge design](https://developer.android.com/design/ui/mobile/guides/layout-and-content/edge-to-edge): system insets and scrolling top-bar behavior.
