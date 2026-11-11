# Unified Post Viewer — approved Immersive / Details UX (#164)

**Status:** User-approved UX direction and HTML reference (2026-11-10). Implementation is in progress on the isolated #164 branch; integration and device acceptance remain separate.
**Issue:** [#164](https://github.com/timberpile/Boorusama/issues/164). Pixiv Works/Pages are a *later* dependency ([#140](https://github.com/timberpile/Boorusama/issues/140), [#141](https://github.com/timberpile/Boorusama/issues/141)).
**Canonical interactive prototype:** [2026-11-10-unified-viewer.html](mockups/2026-11-10-unified-viewer.html), version 2, SHA-256 `c34b5f4b3c41807cf19ae95b86c13ecd2e3375906c2c313afd88cf3821788034`. This is the exact standalone HTML reviewed and approved by the user, not a freshly reinterpreted reproduction.
**Visual baseline:** the user's four current-viewer screenshots (Immersive, Quick Action overlay, expanded Details, scrolled Details) supplied during the design discussion. The HTML recreates their real artwork, spacing intent, dark surfaces, familiar action order, top Back/Info chrome, content sections and mobile navigation. Do not copy the desktop-only prototype control panel into the app.

## Goal and precedence

Refactor the **existing shared Post Viewer**, not a separate full-screen Pixiv/Gallery viewer. The new UI should look like the existing Boorusama/Kurumi viewer while replacing the old draggable details-sheet displacement/expansion with a natural, scrollable Details page. Preserve established Post, video, user-configured gestures, shortcuts, actions, source/profile binding, and media-quality behavior unless explicitly changed below.

For #164, the **approved HTML** is the reference for appearance, gesture intent, mode transitions and visible layout. This document provides enforceable behavior and scope boundaries. The app's existing Kurumi components, theme roles and real production rendering are authoritative for platform-specific implementation details. If these sources genuinely conflict, do not silently invent a third interaction: document the discrepancy for user review before changing the approved UX.

Older designs such as the 2026-11-04 viewer lab and the experimental Combined-branch MediaGroupViewer are historical references, not authoritative viewer UI. The prototype's **Multi-page demo** is only a demonstration of future #140 behavior and is not part of #164.

## State model: two presentation modes, not four layouts

1. **Immersive:** One media viewport fills the available viewer area (normal contain/zoom behavior). Existing status/top chrome and the bottom title/quick-action preview are temporary **overlay visibility**, not a separate presentation mode.
2. **Details:** The same selected media appears at the start of a single vertically scrolling page; the normal title, quick actions, artist, tags, file info and other existing details follow it. No separate draggable sheet or secondary viewer route.

Immersive overlay visibility is controlled independently from media geometry. Returning from Details starts Immersive with its overlay hidden. Opening or closing quick controls must **not** change media geometry, reset zoom or scroll the content. The default entry state is Immersive with the UI hidden; an explicitly saved overlay preference remains supported. Retain normal system inset and back-navigation ownership.

### Gesture contract

| Starting state / hit region | Gesture | Required result |
| --- | --- | --- |
| Immersive, image at any zoom, overlay hidden | Single tap | Toggle the existing UI overlay only; keep media size/position unchanged |
| Immersive, unzoomed image, overlay hidden | Upward swipe | Enter Details, including when the bottom overlay was initially hidden |
| Immersive, visible bottom title/action overlay | Upward swipe | Enter Details; allow it even if media underneath is zoomed |
| Immersive, visible bottom toolbar/title preview | Horizontal drag | Move **media AND corresponding overlay** together, continuously under the finger; switch to adjacent Post only on a completed page gesture |
| Immersive, bottom toolbar button | Short tap / hold | Trigger existing action semantics; a recognized swipe must not accidentally activate a button |
| Immersive, zoomed media | Drag/pinch | Respect image pan/zoom ownership, not an accidental Details or adjacent-Post swipe; overlay provides an always-available Details entry gesture |
| Immersive, still image | Double tap | Existing zoom behavior takes precedence; must not also toggle overlay or Details |
| Details, media region | Single tap | Return to Immersive; restore the saved Immersive transform rather than resetting to a new image |
| Details, media region | Pinch/double tap/drag | No image zoom or panning; vertical scrolling scrolls the **whole page** |
| Details, anywhere scrollable | Vertical drag | Scroll the entire page; image scrolls completely away above the viewport; no sticky/resizing/floating image |
| Details, ordinary single-Post media or metadata region | Horizontal drag | Move **entire current Details page**, including image and all metadata, with the finger as the next/previous Post appears |
| Details, horizontal drag cancelled / insufficient | Release | Return smoothly to the original Post and retain its content/scroll state |
| Details, horizontal swipe completed | Release | Settle the neighbor in **Details**, without closing/collapsing it |
| Either mode | System Back / viewer Back | Exit the viewer to the originating screen; do **not** treat Back as a Details-to-Immersive toggle |
| Details, scrolled far below image | Scroll to top | Reveal the normal full Details media region; reaching the top in this drag does not switch modes |
| Details, already at scroll offset zero | Downward pull | Follow the finger toward Immersive; release snaps according to the travelled threshold |

Preserve nested control ownership: scrollable horizontal widgets, popup menus, selectable text, accessibility and configured gesture handlers should not be indiscriminately intercepted by a broad gesture detector. Work/Page gesture routing is deliberately deferred to #140.

### Details media layout

- At scroll offset zero, begin with an **uncropped contain-fit image**, followed immediately by the existing header/title/subtitle, Quick Actions, metadata and later content in their normal visual hierarchy.
- **Adaptive is the approved default.** Treat **60% of the usable viewer height as a ceiling, not a fixed reserved spacer**. Use the image aspect ratio and available width to size the media block. Wide/square images should not produce unnecessary vertical black empty space.
- Retain a reasonably sized **minimum media gesture target** for very wide panoramas; bottom-align especially wide media within that minimum target, as in the HTML. The top Back control may overlay the image in Details; Info is hidden there; do not reserve a separate top spacer for them. The prototype demonstrates approximately 158–188 px minimum depending on screen height; this is illustrative CSS geometry, not a mandatory Flutter dp constant.
- Keep Details media and its entire scroll surface clipped between the physical system-bar insets. Immersive media remains edge-to-edge, while UI controls respect all safe insets. Keep the actual image fully visible within this block, without cropping. Portrait/tall media can use nearly the full 60%; wide media uses less height. Recompute safely on rotation, insets and viewport/text-scale changes.
- The media block is the **first child of the same scroll surface** as all the details. Scrolling down moves the media offscreen. No handle, sticky header image, expanding background image, details-only overlay route, or bottom sheet.
- No zoom/pan on the media while Details is active. Scrolling and horizontal Post navigation must continue to work. Returning to Immersive restores the previously captured media transform/reading position.
- Retain original compact app density, top navigation/icon hierarchy, existing details action order and Kurumi styling. **No new persistent Fullscreen button, dedicated mode-switch row, second action toolbar, or decorative handle.** The existing Info control appears only in the visible Immersive overlay; do not introduce an extra button just to implement this transition.

### Transitions

A mode change should feel like the **same media element** smoothly moving/resizing between the two layouts, with detail content appearing below. Avoid rebuilding a duplicate media tree, abrupt image snap, an overlay that first covers the image, or independent animations fighting over transforms. Preserve loaded media, selected Post, and access/actor scope.

Manual vertical transitions must follow the finger continuously in both directions,
including reversals and holds. Commit the mode only on pointer release; a short
pull settles back to its starting mode and a qualifying pull snaps to its target.
Only the remaining snap or an explicit button/tap transition uses an animation.
Use a short visible settle even near an endpoint, rather than shrinking its
whole duration in proportion to the small remaining distance. During a mode
change, slide the bottom toolbar downward over the first half of the
Immersive-to-Details travel; any visible return runs over the last half. Its
position follows gesture progress. A regular Immersive UI toggle slides the
top and bottom chrome from opposite edges with matching motion. The Info
control also fades. Video quick actions use the same opaque surface as images.
An additional pointer cancels the mode gesture and retains native pinch ownership.
Zoom and return-to-fit updates preserve the chosen overlay and system-bar state;
a single tap while zoomed toggles the overlay normally and keeps that choice.

Prioritize rapid repeated interactions. The HTML reference uses roughly **165 ms** for the main transition; an initial Flutter target around **150–180 ms** is appropriate, adjusted against actual device frames and Kurumi motion conventions rather than enforcing an arbitrary hard timing test. Respect reduced-motion preferences.

A normal horizontal swipe is a **real page drag**, not a delayed fade or threshold-triggered content replacement. The neighbor and current page both follow the drag. Keep the same presentation mode during the gesture and after settling. Preserve the existing ordinary Post viewer's intuitive horizontal behavior.

### Pager, preloading, and checkpoints

- Reuse/extend the shared outer viewer's existing page sequence. Keep the **previous/current/next** Post/Work entry ready for interactive page movement, with bounded preloading of visible/display media. Never eagerly decode or download all originals or all remote Work Pages.
- The immediate neighbor may show an existing cached preview while its display image resolves; its **gesture animation must not wait on network requests**.
- Keep local checkpoints for each visited viewer occurrence: Details vertical scroll offset and, for Immersive, the last usable zoom/pan transform. Returning to an adjacent entry should not randomly jump to another scroll position or inherit a neighbor's media/metadata.
- Respect profile/source isolation, refresh generations, Back/restoration, missing media, long feeds, repeated occurrences, cancellation and memory limits. Drop heavy widget/media state outside the narrow active window while retaining lightweight checkpoints.
- This requirement does **not** authorize a new global media cache, a second pager framework or persistent serialized UI state unless a concrete existing limitation requires it.

## Owner clarification (2026-11-11)

The owner confirmed that Immersive starts with the UI hidden, a single tap shows
an overlay that may cover the image, and top controls in Details may also cover
the image. This resolves the earlier written no-overlap wording in favor of the
approved HTML. The HTML reference itself remains unchanged.

Subsequent device review on the same date supersedes the prototype's fixed
vertical transition and earlier no-pullback wording: manual transitions follow
the finger until release, a new downward pull at the top returns to Immersive,
Info is hidden in Details, and Details content stays between system bars.
Later feedback requires a visible release snap, toolbar translation completed
halfway into Details, matching upper/lower overlay motion, and hidden UI after
returning to Immersive. Bound inherited navigation padding to physical system
insets so a transient app-navigation obstruction cannot leave a black strip.
Single-tap overlay toggling also works while zoomed; zoom itself must not toggle
UI or briefly reveal Android bars. These requirements are reflected above.

## Future #140 extension — explicitly not part of #164

After the shared viewer design is accepted and implemented, Pixiv Work/Gallery support extends an outer Post/Work viewer entry with **inner Page navigation**:

- Horizontal swipe on the *image region* changes the current Work's Page, stopping at Work boundaries.
- Horizontal swipe over *Details metadata/actions* changes the outer Work with the entire Details page moving under the finger.
- There is no requirement for a fast Work-skip gesture in Immersive; entering Details remains the discoverable path.
- The selected Page and reading checkpoints should be kept per Work; action targets must refer to the selected, genuine Page.
- Independent local Work/Page bookmarks and Pixiv-specific source contracts remain #140/#141 responsibilities. The prototype's page toggle is not a mandate to implement them in #164.

Do not reintroduce a separate experimental media-first viewer when implementing #140.

## Required design-to-code acceptance

The Flutter agent must first inspect real existing viewer/Kurumi code, the **approved HTML at the linked commit**, and current screenshots, then extend the existing implementation rather than imitating the prototype's browser structure. Preserve the same action ordering, visible chrome, content hierarchy, title typography/overflow, spacing, themes and system-bar behavior wherever they are present today.

Use this checklist as a concrete acceptance gate (tests and capture comparisons, not simply a subjective "looks similar" claim):

| ID | Verify on actual Flutter UI |
| --- | --- |
| V01 | Baseline Immersive art/image framing stays unchanged when the overlay toggles |
| V02 | Both upward-swipe paths enter Details (image without overlay, bottom overlay with overlay); a zoomed image pans, while its overlay still works |
| V03 | Quick-action taps work; a **horizontal toolbar drag** pulls artwork and footer together, with no accidental action |
| V04 | Details image block uses adaptive contain-fit height **at most 60%** of usable height; wide, square, portrait, panorama and tall comic cases show no large avoidable gaps; top Back may overlay the image inside safe insets; Info is absent in Details |
| V05 | Vertical Details scroll removes the image naturally; no pinned media, expanding sheet or handle; a new downward pull at offset zero returns to Immersive |
| V06 | Horizontal Details drag continuously moves the **whole** image+metadata page with neighboring content, including cancel/settle; Details stays open |
| V07 | Returning to visited Posts restores per-occurrence Details scroll and Immersive zoom; no stale media, actions or metadata on rapid navigation |
| V08 | Tap Details image returns to Immersive; Back always exits viewer; popup/keyboard Back remains owned by the open child UI first |
| V09 | Manual vertical movement and reversal follow the finger 1:1; only release snaps; explicit transitions remain short with no media flash/rebuild; reduced motion works |
| V10 | Existing video, configured gestures, single-Post actions, source isolation, navigation, Pool/Related viewer, zoom/Comic and media quality remain correct |

For visual review, capture real Flutter frames at approximately **320 dp / enlarged text**, **390–414 dp**, and **landscape** with representative portrait, square and panorama media; include Immersive, overlay, Details at top and Details scrolled. Compare them directly to the HTML prototype and supplied baseline rather than trusting unit tests or accepting a new interpretation of the design. Controlled widget tests should cover gesture and state transitions; use an exclusive Android emulator lease and Maestro where device verification is needed.

Do not treat the HTML's desktop test panel, mock status indicators, fake source metadata, placeholder artwork variations, or demo Multi-page selector as UI requirements. Any necessary deviation from the approved interaction or visual layout must be **explicitly reviewed**, not silently changed during implementation.

## Delivery and integration boundary

This document and its HTML reference record the agreed target for the local coding agent. #164 should be implemented and independently reviewed before the #140 production viewer cutover. The design branch does not modify Flutter runtime, complete #164, approve a PR, or authorize a merge to develop. Apply repository verification/issue workflow rules to the eventual implementation separately.
