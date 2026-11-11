# Viewer overlay visibility lifecycle

Source baseline: `22348b2fb20049088705ce38f5b261e191b148af` (2026-11-11).
This is a source investigation and proposed correction, not an implemented fix or device reproduction.

## Finding

The report is supported directly by `_PostDetailsPageViewState._onPageChanged()` in [post_details_page_view.dart](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/posts/details_pageview/src/post_details_page_view.dart#L185-L205). After updating the current page, every ordinary Post transition in Immersive mode executes `hideAllUI()` when `initialHideOverlay` is true. A user who reveals controls therefore loses that choice on the next swipe. Keyboard, button and slideshow navigation also share this path; this is not specific to touch swipes.

The [controller](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/posts/details_pageview/src/post_details_page_view_controller.dart) already initializes `overlay` and `bottomSheet` from `initialHideOverlay`. Reapplying the preference at page change is unnecessary.

## Proposed correction

Treat the preference as an initial route-session value. Remove its ordinary-Post page-change reset and preserve the user's current overlay visibility while moving between Posts. Do not introduce a persisted setting or a per-Post visibility map.

Keep non-Post Back navigation available independently: the existing non-Post branch calls `showOverlay()`, while `PostDetailsOverlay(detailsEnabled: false)` bypasses media hiding. Avoid letting that forced group navigation mutate the remembered Immersive preference. Prefer rendering required group navigation independently of the Post overlay state; otherwise save and restore the session's Post-overlay choice at the Post/Group boundary.

Animation-controller attachment currently reads `initialHideOverlay` too. Preserve initial entry animation, but when reattaching to an existing controller synchronize from the live overlay/bottom-sheet state rather than resetting to the original preference. Check slideshow stop, which also consults the initial preference, and explicitly preserve slideshow-specific hiding without making an unrelated redesign.

Do not change #164's Details mode persistence, tap behavior, zoom or horizontal navigation.

## Focused verification for implementation

- Start hidden, tap to show, swipe forward/back: both top controls and quick actions remain shown.
- Start shown, tap to hide, navigate by swipe, keyboard and buttons: they remain hidden.
- Close and reopen the Viewer: the configured initial state is applied again.
- Post -> Group -> Post: group Back stays reachable and the previous Post-overlay choice returns.
- Details remains open during horizontal navigation; returning to Immersive has a deliberate consistent overlay state.
- Repeat with animation disabled and controller reattachment; verify slideshow start/stop separately.

Use controller/widget tests first, then a short Android interaction check. No runtime tests were executed for this documentation-only investigation. Related: #164; no change to #112 toolbar customization.
