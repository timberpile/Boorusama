# Bottom navigation visibility and layout contract

Status: **Agreed user-facing behavior; design guidance for #177, not implemented or tested.**
Issue: https://github.com/timberpile/Boorusama/issues/177
Task branch: feature/177-bottom-navigation-visibility-layout
Source examined: develop at 96e026cc9b7db88bd8544166deacaa5a15a0867e (2026-11-18). Recheck the implementation branch before changing runtime code.

## Intent and limits

Make the compact bottom navigation predictable and reduce recurring route-specific visibility repairs and page-specific bottom-padding fixes. Extend the existing Flutter/GoRouter/Riverpod navigation infrastructure; do not build a second navigation system, independent scroll-history service, or new engine abstraction. This scope changes only navigation interaction/layout, not post data, group persistence, or route semantics.

## Approved product behavior

### Navigation and reset semantics

- On entering **or returning to** a different page, destination, or logical in-page view, start with the bottom bar **visible**, regardless of whether the previous view left it hidden. This explicitly includes Bookmark Group -> parent/overview via toolbar Back, system Back, ancestor selection, and returning from the Post Viewer.
- **Preserve the content's scroll position** and retained destination session when restoring bar visibility. Never force the scroll controller to jump to the top.
- Normal rebuilds, loading/refresh updates, and closing an ordinary popup/dialog **are not new views** and must not reset the bar. Reselecting an already-selected destination retains its existing no-op behavior.
- No restoration of the previous hidden/partial bar state after leaving a view. Do not persist a hidden-fraction map per route/group.
- Existing menu, selection-mode, keyboard, wide-layout, auto-hide preference, system-inset, and viewer visibility rules remain valid. A visible-on-navigation reset is a scroll-chrome intent, **not** permission to draw the bar over an active viewer, keyboard, or selection controls.

### Direct scrolling and release

- Only the **primary active vertical timeline** may control scroll-driven bottom navigation. Direct finger dragging moves the bar with scroll displacement, pixel-for-pixel over the panel's actual travel extent, clamped between fully visible and fully hidden. A direction reversal moves it immediately in the reverse direction.
- On **finger release**, finish with a short animation toward the endpoint indicated by the **last meaningful direct drag direction**: downward -> hidden, upward -> visible. Do not use the current 50%-visible threshold. A partial reverse drag should decide the endpoint regardless of how far the bar has traveled.
- A fling must not delay the snap until ballistic motion stops, nor let later inertial updates reverse the release decision. Programmatic scrolling, horizontal/nested scrolling, overscroll/bounce, and events from inactive destinations do not drive it. Preserve the established near-top reveal behavior.
- Once an animation settles, the resulting state persists at rest. **Never automatically reveal on scroll idle or after a timeout.** A hidden bar returns on upward direct scrolling, appropriate explicit chrome overrides, or navigation.
- When auto-hide is disabled, the bottom bar must remain available without requiring another scroll event. Reduced-motion settings must be respected for non-drag animations.
- Preserve the *existing Post Viewer entrance/exit synchronization* and its toolbar/overlay behavior; simplifying that animation is **not** part of #177. Returning from a completed viewer dismissal now resolves to visible underlying navigation, without a flash during the viewer's reverse transition.

### Layout and bottom obstructions

- A visible bottom bar must not obscure the final meaningful item or fixed actions of a normal page. Avoid screen-specific hard-coded navigation heights and ensure system safe area, keyboard, selection bar, attached footer, and viewer controls are accounted for **once**, not added repeatedly.
- **Ordinary non-timeline pages** use a shared safe content-layout contract. Their content and fixed actions are protected from the active bottom obstruction without each individual page having to implement its own bar padding. Existing pages that already consume the inset must not get an additional inset.
- **Timelines** keep a full-height, stable scroll viewport. The bar overlays the timeline and can move over its content; the viewport must not resize or jump on each animation frame. Provide enough **scrollable end clearance** to allow the final item and pagination controls to be entirely reached above a visible bar. End clearance is not a persistent outer gap that shrinks the viewport.
- **Floating controls, feedback, sheets, and popups** follow the *actual rendered obstruction* rather than the timeline's maximum scroll-end clearance. Keyboard/system geometry and route-owned attached footers are respected in the same calculation.
- Do not solve a covered final item by resetting scroll, adding repeated SafeAreas, hiding the item, making navigation transparent, or globally enlarging every page's bottom padding.

## Agreed simplification versus the previous behavior

Previously, a route-specific sync attempted to keep a hidden bar when a viewer/popup returned to the same route. It also snapped a partially moved bar according to a half-way threshold after scrolling ended. Those **scroll-chrome** rules are replaced by visible-on-navigation and last-drag-direction snapping. The existing viewer animation itself is retained.

These choices intentionally avoid storing/restoring a per-page bar state. They do **not** require replacing the existing single animation/geometry implementation.

## Implementation direction (engineering recommendation, not extra product requirements)

### 1. Reuse current navigation owners and existing panel geometry

- NavigationChromeController and NavigationChromeRouteSync currently hold the global hidden fraction and route-based restoration. DestinationRouterBinding, DestinationPageActivity, and NavigationActivity already identify selected/foreground/covered destinations. Extend that mechanism rather than adding another competing navigator observer or lifecycle registry.
- NavigationScrollBoundary already filters user-origin vertical scroll notifications for PostGrid and NativeContentGrid. Keep **one** effective bridge per primary scroller; do not forward events twice.
- NavigationOverlayInsetsScope currently owns a single rendered animation; NavigationPanelGeometry and NavigationPanelScope are shared by the bar, attached footers, and overlay insets. **This architecture exists on the examined develop commit**; preserve it. Do not recreate multiple independent animation controllers or reposition the bar/footer separately.
- NavigationFooterExtents leases belong to the active destination and must remain safe through changes in branch and route activity.

### 2. Model view transitions, not individual Back handlers

- Treat a genuine route/destination activation and a change of *logical content-view identity* as the reset boundary. A stable identity should be based on the active destination and route instance plus an optional in-page identity.
- BookmarkGroupBrowserPage changes groups with _open() and state updates, not always a Flutter route transition. Its existing per-view scope (group ID, BookmarkGroupViewMode) is a useful in-page identity. Register this identity at the owning page/view boundary **once**; do not call controller.show() from _open(), every Back action, menus, and unrelated widget events.
- A normal rebuild retaining that identity is inert. If a view-mode change actually replaces the content view, it should count as a new logical view. An ordinary filter/edit/refresh within the same view should not.
- Viewer enter/exit is a dedicated transition: suppress bar during the viewer, preserve its existing progress synchronization, and publish the agreed visible underlying state upon returning. Ordinary popup dismissal must not be mistaken for viewer return.
- For callbacks deferred to a later frame, reject obsolete view identities/generations so a previous view cannot reveal/hide the new one out of order. Dispose/suspend pending scroll gestures on deactivation; do not treat widget mount/dispose order as navigation history.

### 3. Change drag completion without losing finger tracking

- Keep the continuous scroll-delta-to-hidden-fraction mapping during a direct drag, including the actual panel extent provided by NavigationBarScrollScope.
- Record the last meaningful **direct drag** delta direction. Complete/snap when that drag is **released**, not only after ScrollEndNotification (which may arrive after a fling). A stationary tap or gesture with no valid drag delta must not arbitrarily choose an endpoint.
- Cancel/retarget a pending snap when the user starts a new drag; resume from the **rendered** current fraction, avoiding a one-frame jump.
- Ignore ballistic notifications after release for navigation purposes and clear stale gesture state across route/selection/keyboard/setting changes. Test a genuine fling and a drag that ends without inertia.
- The exact Flutter gesture hook is an implementation detail to verify against real widget behavior; avoid claiming ScrollEndNotification alone represents pointer release.

### 4. Apply existing insets correctly by layout class

- ViewportBottomInsetsScope exposes **visible** (current obstruction) and **endClearance** (maximum trailing scroll clearance). NavigationPanelGeometry derives them from the actual navigation + attached-footer geometry. Prefer these existing APIs over a second navigation-height provider.
- Shared ordinary-page/scaffold layouts should consume the appropriate safe bottom inset **once**. Avoid globally wrapping every page with an additional SafeArea on top of its own SafeArea; migrate or reuse existing consumers and verify the effective inset at each boundary.
- Shared timeline hosts (RawPostGrid, NativeContentGrid, Bookmark timelines, paginated variants) should consume stable **endClearance** once at the content end; do not dynamically resize the scroll viewport based on the hidden fraction. NativeContentGrid already reads the shared scope; compare it with RawPostGrid's MediaQuery-based bottom sliver and pagination handling before editing.
- Stable maximum end clearance may leave trailing scroll space when the bar is hidden at the *absolute end* of a list. This is a **suggested stability tradeoff**, not an additional agreed requirement: prefer no visible scroll jump or obstructed last item. If it causes unacceptable blank space, validate a consistent alternative without changing viewport size.
- Floating actions and overlays use **visible**, not endClearance, and must not double count system gesture insets, page SafeArea, or the keyboard.
- A route-local attached footer may share the shell panel; preserve one consistent motion/obstruction for both. Do not accidentally reintroduce the navigation/footer misalignment fixed in #147.

### 5. Safe rollout and test boundaries

- Adapt shared infrastructure first, then connect the Bookmark in-page boundary and any uncovered layout hosts. Avoid a broad unreviewed rewrite of engine pages. Remove obsolete manual calls only after equivalent behavior is covered.
- Existing tests reflect old behavior: navigation_chrome_route_sync_test currently expects a hidden bar after viewer return; navigation_scroll_flow_test and navigation_scroll_boundary_test include half-way snapping and ballistic handling. Update those intentionally rather than treating them as product requirements.
- Prefer production-router headless widget tests for actual navigation/Bookmarked hierarchy and actual drag/release behavior. Pure controller tests alone cannot validate route observers, ScrollNotification ownership, overlay positioning, or visual geometry.

## Acceptance matrix

| Case | Required observation |
| --- | --- |
| Bookmark Group -> nested Group -> Back to parent/overview | Bar becomes visible; existing scroll positions persist; both toolbar and system Back work |
| Group ancestor jump and view-mode switch | View identity changes when content view changes; refresh/rebuild does not reset |
| Hidden Following feed -> Back; Browse -> other destination -> Back | Bar visible after navigation and no unrelated scroll needed |
| Hidden timeline -> Viewer -> Back, including partial viewer dismissal | Viewer controls/route animation remain correct; underlying bar visible on completed return, no flash |
| Modal/menu opened and closed on an unchanged timeline | No unintended scroll-chrome reset; menu's existing reveal policy remains |
| Short down drag, short up reversal, release at partial fractions on both sides of 50% | Finger tracking is continuous; final snap follows last direct direction, not half-way distance |
| Fling after user release | Snap starts at release and inertial updates cannot re-hide/re-reveal |
| Idle, programmatic jump, nested horizontal scroll, overscroll | No unsolicited visibility changes |
| Auto-hide disabled, keyboard open/close, selection, inactive branches | Correct chrome override; stale gesture notifications ignored |
| Compact ordinary page, last button/footer and multi-line text | Last action fully visible/tappable without double insets |
| PostGrid, NativeContentGrid, Bookmark scroll, pagination | Full-height stable viewport; final item reachable above bar; no scroll jump on hide/reveal |
| Attached footer, toast, sheet and floating control | Follow actual panel/keyboard/system geometry with one consistent rendered animation |
| Narrow/wide, enlarged text, safe-area variations and reduced-motion | No inaccessible actions, focus leaks, or layout regressions |

## Evidence, related work and open implementation details

- Source-level explanation for the reported Bookmark bug: BookmarkGroupBrowserPage._open() changes its in-page ID while NavigationChromeRouteSync only compares active Flutter route identity. User reproduction was reported; it was **not device-reproduced** in this research.
- Previous fixes: #85 (feed exit restore), #89 (page overlap), #67 (sheet spacing), #106 (toast inset handling), #147 (navigation/system-panel geometry), #175 (Pixiv native-grid auto-hide). Preserve their accepted behavior; avoid duplicating it.
- Exact gesture-release integration and the safest ordinary-page shared wrapper require implementation-time verification against the current source and widget tests. These are technical choices, **not additional questions about approved UX**.
- No runtime changes, Flutter test executions, Android device tests, or independent code-review agent runs are claimed by this document.
