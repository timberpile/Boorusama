# #177 Bottom Navigation Visibility and Layout — Local Agent Handoff

Issue: https://github.com/timberpile/Boorusama/issues/177
Approved behavior and technical constraints: [Bottom navigation contract](../designs/2026-11-18-bottom-navigation-visibility-layout.md)
Task branch: feature/177-bottom-navigation-visibility-layout
Inspected: develop at 96e026cc9b7db88bd8544166deacaa5a15a0867e (2026-11-18).
Status: **research/specification only**. The branch contains documentation; no application implementation or tests have been performed here.

## Confirmed source observations versus reported behavior

**User report (not device-reproduced):** Open a Bookmark Group, scroll down to hide the main bottom navigation, then Back to the Groups overview. The bar stays hidden until a later scroll.

**Source-backed explanation:** BookmarkGroupBrowserPage navigates between groups through _open(), which updates the requested in-page group ID. NavigationChromeRouteSync, hosted by production_navigation_router.dart, only sees Flutter Route object changes; it therefore misses an internal group -> parent transition. Current route-sync tests explicitly preserve a hidden bar on viewer return, which conflicts with the newly approved visible-after-navigation behavior. Treat this as a documented mechanism, not proof of live reproduction.

**Other source findings:**
- NavigationScrollBoundary already sits above RawPostGrid and NativeContentGrid, filtering direct vertical scroll updates. It currently snaps in NavigationChromeController.endScroll() based on a 0.5 hidden-fraction threshold; the boundary's ScrollEndNotification can arrive after a fling. Both behaviors must change while retaining finger tracking.
- A single NavigationOverlayInsetsScope animation already publishes NavigationPanelGeometry for the bottom bar, attached footer, and overlays. This was changed after the earlier research; **do not introduce a second animation or geometry authority**.
- NativeContentGrid already consumes ViewportBottomInsetsScope for trailing clearance and scroll-to-top controls. RawPostGrid still uses a MediaQuery-based trailing sliver with pagination exceptions. Audit all consumers for double counting before changing layout.
- Ordinary page layouts use mixed SafeArea/MediaQuery conventions. #89, #67, #106, #147 and #175 contain previous targeted corrections; preserve them.

## Relevant source map

| Path | Focus |
| --- | --- |
| lib/core/navigation/navigation_chrome_controller.dart | Hidden fraction, drag/snap rules, viewer owner/progress, scroll-chrome resets |
| lib/core/navigation/navigation_interaction_scopes.dart | NavigationScrollBoundary; active vertical gesture filtering and release handling |
| lib/core/navigation/navigation_chrome_route_sync.dart | Route-level reset semantics; viewer versus popup behavior |
| lib/core/navigation/production_navigation_router.dart | Active destination, current route, viewer/route sync wiring |
| lib/core/navigation/destination_activity.dart | Existing route/branch foreground/covered activity ownership |
| lib/core/bookmarks/src/pages/bookmark_group_browser_page.dart | _open(), in-page view key (group ID, view mode), empty group scroll surface |
| lib/core/navigation/navigation_panel_geometry.dart | Shared visible obstruction and stable endClearance, attached footers |
| lib/core/navigation/navigation_overlay_insets.dart | Existing single rendered animation, Kurumi overlay insets |
| lib/core/widgets/viewport_bottom_insets.dart | Existing shared consumer contract |
| lib/core/navigation/app_navigation_shell.dart | Compact bar, page MediaQuery and footer coordination |
| lib/core/posts/listing/src/_internal/raw_post_grid.dart | Trailing clearance / bottom page selector / static viewport |
| lib/core/content/widgets/native_content_grid.dart | Already consumes shared viewport insets and scroll boundary |
| lib/core/settings/src/widgets/settings_navigation_pane.dart | Existing explicit bottom inset consumer; avoid adding it twice |

## Suggested implementation order

1. **Pin failing integration cases first.** Add a real production-router/headless-app test for hidden Bookmark Group -> Back to overview, plus nested group and system Back. Ensure the test actually scrolls the live primary content rather than calling controller.show() directly. Keep a distinct same-view popup round-trip and viewer-return case.
2. **Consolidate view activation.** Extend existing route/destination activity signals with one stable optional logical-view identity (Bookmark Group ID + view mode), registered at the content-owner boundary. Reset scroll-hidden state only for meaningful navigation/view transitions, including completed viewer return. Do not add show() to every Back/menu handler or treat a normal rebuild as navigation. Preserve retained scroll controllers.
3. **Correct drag completion.** Continue pixel-for-pixel movement during direct vertical dragging; on actual release, snap toward the last meaningful direct direction, independent of the 50% threshold. Ignore inertial updates for chrome after release. Handle interruption, new gestures, and stale notifications; follow current rendered fraction to prevent a one-frame jump. Do not make idle auto-reveal the bar.
4. **Apply the existing layout contract.** Preserve NavigationPanelGeometry and single bar/footer/overlay motion. Reconcile trailing insets of RawPostGrid, NativeContentGrid, Bookmark scrolling, pagination, fixed actions, and ordinary-page shared safe layout. Use maximum endClearance only for scrollable *content end* and current visible obstruction for floating/overlay controls. No double SafeArea, no hard-coded 64/88/104-pixel per-page fixes.
5. **Review compatibility.** Keep the viewer's existing transition synchronization and overlay/selection/keyboard behavior. Do not redo completed Pixiv #175 or footer #147 work, and do not change route navigation/history or post source semantics.

## Regression coverage to add or revise

- test/core/navigation/navigation_chrome_route_sync_test.dart: replace old hidden-on-viewer-return expectation; preserve same-page popup behavior and no-op rebuilds.
- test/core/navigation/navigation_scroll_boundary_test.dart: partial drag, last-direction reversal, actual release versus delayed fling-end, nested/horizontal/programmatic/overscroll, auto-hide preference, inactive branch.
- test/application/navigation_scroll_flow_test.dart: finger-follow motion and rendered bar geometry through release; update old 50%-threshold expectations.
- test/application/bookmark_hierarchy_screen_flow_test.dart and related Bookmark flow tests: real group navigation, Back via both paths, view switching, retained scroll anchor.
- NavigationOverlayInsetsScope/NavigationPanelGeometry, page inset, NativeContentGrid/RawPostGrid and footer tests: final row/pager/actions reachable, no viewport reflow, no double system/keyboard insets; test partial/final animation frames.
- At least narrow width, large text, wide layout, keyboard, selection, viewer and attached-footer scenarios where applicable.

## Guardrails and unknowns

This is an issue-linked **feature** branch for specification; do not merge, close the issue, or open a PR without authorization. Recheck the branch head and current develop before implementing; the code may have moved. Flutter/Android/Maestro runs were **not performed** during this remote documentation task.

The exact Flutter gesture hook to observe release before ballistic settling must be verified by targeted widget tests. The proposal to keep stable maximum scroll-end clearance when hidden is a technical tradeoff to validate, not a user-approved separate requirement. If an existing shared layout wrapper already fulfills a case, reuse it rather than create a parallel one.

The issue controls user-visible outcomes, and the linked design document controls the approved behavior. This handoff is source-specific implementation guidance, not a separate task tracker.
