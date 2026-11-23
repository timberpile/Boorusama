# Pixiv Browse and Explore Bottom Navigation Autohide — Implementation Handoff

Issue: [#175](https://github.com/timberpile/Boorusama/issues/175)
Source originally inspected: [`develop` at `fa40038f8a07`](https://github.com/timberpile/Boorusama/tree/fa40038f8a073a1fa74482c9a75b139a5e0a06c4), 2026-11-17. Revalidate against the branch actually used for implementation.

This is source-backed routing guidance, **not a device-reproduced root cause**; no code patch or live test was performed during research.

## Precisely observed behavior

- **Fails:** Pixiv **Browse** Work timeline: downward scrolling does not hide the bottom app navigation.
- **Fails:** Pixiv **Explore** Work timeline: the same missing autohide.
- **Works:** Pixiv **Search** once a search has been started: normal downward hide / upward reveal.
- **Works:** Ordinary non-Pixiv Browse profiles.

The working Pixiv Search path is a **critical negative control**. An unconditional missing hook inside `NativeContentGrid` cannot by itself explain why Search works and Browse/Explore fail, if all three really use the same native grid at runtime. Confirm the actually selected widget tree and scroll-notification ownership before choosing a fix.

## Code paths to compare

- `lib/boorus/pixiv/works/search_page.dart`: Pixiv Browse home uses `PixivWorkHomePage` / `MobileHomePageScaffold`, including the `nativeResultBuilder` path.
- `lib/boorus/pixiv/explore/widgets.dart`: Pixiv Explore uses `PixivWorkGrid` in its Explore-specific route/shell.
- `lib/boorus/pixiv/works/work_listing.dart`: shared `PixivWorkGrid` delegates to `NativeContentGrid`.
- `lib/core/content/widgets/native_content_grid.dart`: native listing owns a `ScrollController`, `RefreshIndicator`, and `CustomScrollView`.
- `lib/core/home/src/pages/mobile_home_page_scaffold.dart`: compare native-grid and ordinary PostGrid branches and route wrappers.
- Locate the **actual Pixiv Search results route** and its scroll listener/notification bridge; compare its route shell with Browse and Explore. The exact Search route builder should be confirmed from current source, not assumed.
- `lib/core/navigation/navigation_chrome_controller.dart`: `NavigationChromeController.userScroll(delta, pixels, outOfRange)`, `endScroll(pixels)`, `barHiddenFraction`, and exemptions.

## Investigation and minimal implementation

1. Use widget-tree inspection or a focused widget test to trace a single vertical `ScrollUpdateNotification` and `ScrollEndNotification` from each route: Pixiv Browse, Explore, and Search; also compare ordinary Browse.
2. Determine **which layer** forwards primary vertical scroll deltas to `navigationChromeProvider`. Search may already do so in a route wrapper, while Browse and Explore do not; verify rather than guess.
3. Reuse the existing shared scroll-to-chrome forwarding at a suitable **route boundary**, or extract a small adapter if two route shells need it. Respect `notification.depth == 0` (or the verified primary scroll identity), the active route, notification phase, and correct upward/downward sign.
4. If a common-grid listener is needed, ensure Search or its wrapper is not forwarding the same event a second time. Never globally double-call `userScroll` or `endScroll`.
5. Do not alter Work/Page identity, pagination, source filtering, refresh-state handling (tracked separately by #169), selected mode, search semantics, or the navigation animation curve.

Illustrative bridge **only when the equivalent call is absent**, not a drop-in patch:

```dart
if (notification.depth == 0) {
  final chrome = ref.read(navigationChromeProvider.notifier);
  if (notification is ScrollUpdateNotification) {
    chrome.userScroll(
      delta: notification.scrollDelta ?? 0,
      pixels: notification.metrics.pixels,
      outOfRange: notification.metrics.outOfRange,
    );
  } else if (notification is ScrollEndNotification) {
    chrome.endScroll(pixels: notification.metrics.pixels);
  }
}
return false; // Let ordinary scroll, refresh, and prefetch notifications continue.
```

## Focused regression checks

- **Browse:** down-scroll hides the bottom nav; partial up-scroll reveals it; near top the nav is visible.
- **Explore:** identical behavior and no interference with Explore's native Work layout.
- **Search:** already working behavior stays **unchanged**; one gesture must not double-advance `barHiddenFraction`.
- **Other profile:** ordinary PostGrid Browse remains unchanged.
- Scroll/refresh/pagination and rapid route/profile switching do not leak stale notification state.
- Selection mode, open menus, viewer open/Back and route-exit restoration preserve current exceptions (#85).
- Prefer small widget/provider tests with controlled scroll notifications. Do **not** require an emulator or live-service suite for this issue; owner will perform final device acceptance.

Record the proven root cause and the branch/commit tested. If the observed Search behavior contradicts the suspected architecture, re-check the concrete route variants before implementing a broad grid refactor.
