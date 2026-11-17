# Favorites Header Scroll Behavior — Implementation Handoff

Issue: [#131](https://github.com/timberpile/Boorusama/issues/131)
Source reviewed: [`develop` at `fa40038f8a07`](https://github.com/timberpile/Boorusama/tree/fa40038f8a073a1fa74482c9a75b139a5e0a06c4), 2026-11-17.
This is a source investigation and proposed fix; no Android reproduction or code patch is claimed.

## Corrected product contract

The owner confirms the current bug affects **Favorites for non-Pixiv profiles**, not Pixiv. The navigation Header (title/actions) must scroll off and return **only when the Favorites list is at the top**. On partial upward scroll away from the top, **only the Timeline Toolbar** may reveal. Pixiv Favorites already works as intended; Pixiv Browse/Explore have no reported Header bug.

The old #131 wording about a transparent Pixiv titlebar is explicitly superseded. #148 now records Favorites as an exception to its general floating Header rule.

## Evidence and code entry points

- `lib/boorus/pixiv/favorites/page.dart`: the correct Pixiv Favorites reference composes `KurumiSliverAppBar` and the privacy filter in `PixivWorkGrid.sliverHeaders`.
- `test/boorus/pixiv_favorites_page_lifetime_test.dart`: the test **“populated Favorites prefetch but title and privacy return only at the top”** scrolls away, reverses slightly and expects both title and privacy controls to remain offscreen; they return when the position reaches zero.
- Investigate the non-Pixiv Favorites destination via the shared `favoritesPageBuilder`/PostGrid route, its app-bar slivers, and any shared Header options. Compare the exact scroll ownership with Pixiv Favorites before changing a global Kurumi default.

## Proposed focused fix

Keep the Favorites navigation Header in the natural sliver scroll flow, without `floating` or `snap` behavior while the viewport remains below the beginning. If the relevant Kurumi wrapper exposes these parameters, use the existing non-floating configuration; otherwise provide a narrow Favorites-specific choice at the shared Header composition boundary. Keep the Timeline Toolbar's independent floating/reveal behavior intact. Avoid hiding the header via opacity while retaining an invisible hit target; preserve top insets and opaque Header background.

Do not alter Browse/Explore or generic timeline Header behavior globally, and do not move the Pixiv Public/Private controls into the floating Toolbar.

## Focused regression checks

1. Non-Pixiv Favorites: scroll far down, then slightly up while `pixels > 0`; navigation Header stays offscreen and only Timeline Toolbar appears.
2. Return to `pixels == 0`: title/actions become visible and reachable again, with normal surface.
3. Repeat for representative booru engines, profile switches, selection mode, narrow width and 200% text.
4. Pixiv Favorites reference test remains green; Pixiv Browse/Explore Header behavior remains unchanged.
5. Validate gesture frames on-device if the reported header travels downward with content rather than merely becoming visible early.