# Pixiv Browse Bottom Navigation Autohide — Implementation Handoff

Issue: [#175](https://github.com/timberpile/Boorusama/issues/175)
Source reviewed: [`develop` at `fa40038f8a07`](https://github.com/timberpile/Boorusama/tree/fa40038f8a073a1fa74482c9a75b139a5e0a06c4), 2026-11-17.
These are source-backed integration clues, **not a confirmed runtime root cause**. No device test or patch has been run.

## Evidence and suspected boundary

User reports that scrolling down in Browse hides the app's bottom navigation for ordinary booru profiles but **not Pixiv**.

- `lib/boorus/pixiv/works/search_page.dart`: `PixivWorkHomePage` passes `nativeResultBuilder` to `MobileHomePageScaffold`.
- `lib/core/home/src/pages/mobile_home_page_scaffold.dart`: the native builder path uses a `KeyedSubtree` and a supplied native result; ordinary profiles use `PostGrid`.
- `lib/boorus/pixiv/works/work_listing.dart`: `PixivWorkGrid` delegates to `NativeContentGrid`.
- `lib/core/content/widgets/native_content_grid.dart`: owns its own `ScrollController`, `RefreshIndicator`, and `CustomScrollView`; it does not directly invoke the navigation chrome controller.
- `lib/core/navigation/navigation_chrome_controller.dart`: `userScroll(delta, pixels, outOfRange)` and `endScroll(pixels)` drive `barHiddenFraction`, with explicit menu/selection/viewer exceptions.

**Hypothesis:** the native Work-grid scrolling path is not reaching the same chrome scroll-event bridge as the ordinary `PostGrid` path. Locate the actual existing listener/caller first; `PostGrid` itself need not own that bridge.

## Proposed narrow fix

Trace scroll notification propagation from both Browse variants into `NavigationChromeController.userScroll/endScroll`. Verify primary vertical scroll identity (`notification.depth == 0`), delta direction, route ownership and end-of-scroll snapping. Reuse the **existing shared scroll-to-chrome adapter** for the native route or at the common route boundary; do not add a second listener that double-counts scroll deltas.

Conceptual adapter, **only** if an equivalent hook is truly missing:

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
return false; // Preserve normal refresh/prefetch scroll notifications.
```

Do not modify grid pagination, selection, Work/Page identity, insets, or the navigation bar animation just to mask the missing event.

## Focused regression checks

- With enough loaded Pixiv Works, down-scroll hides bottom navigation and up-scroll reveals it; at the top it is visible.
- Compare an ordinary PostGrid profile in the **same** navigation shell and ensure a single user scroll changes the chrome fraction only once.
- Profile switching, selection mode, open menu, viewer/Back, active pull-to-refresh, and route-exit restoration keep their intentional exceptions (#85).
- Check compact devices, keyboard/system safe areas and real-device gestures. Unit/widget tests should inspect `navigationChromeProvider` state, not only navigation pixels.