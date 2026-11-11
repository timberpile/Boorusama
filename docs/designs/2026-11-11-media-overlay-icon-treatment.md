# Media-overlay icon treatment

Baseline: `22348b2fb20049088705ce38f5b261e191b148af`. Proposed visual direction; no screenshot, mockup or device contrast review was performed. The user asks for shadows around the icon glyphs, not circular black button fills or a shadow around an invisible button box.

## Current components and concrete inventory

| Surface | Source evidence | Proposed treatment |
| --- | --- | --- |
| Viewer Back and Info | [PostDetailsOverlay](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/posts/details_pageview/src/post_details_overlay.dart) uses KurumiCircularIconButton | Initial change: transparent resting surface and a glyph shadow. Preserve action, position and hide/show lifecycle. |
| Optional top More menu | [DefaultFallbackBackupMoreButton](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/posts/details/src/widgets/post_details_actions.dart) adds its own circular Material overlay when the normal toolbar is absent | Apply the same top-overlay treatment to the trigger only, not its popup menu. |
| Viewer previous/next arrows | [PageNavButton](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/posts/details_pageview/src/page_nav_button.dart) uses a circular MaterialButton with surfaceContainerOverlay | Closest follow-up candidate for the same media-icon style; retain pointer/keyboard affordances and zoom-dependent visibility. |
| Video time/progress/control strip | [VideoControls](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/posts/details/src/widgets/video_controls.dart) has a theme surface at 0.8 opacity behind controls and text | Keep its coherent backing initially. A slider/time strip is not equivalent to a single floating icon; redesign separately only with visual evidence. |
| Transient video Play/Pause/Seek feedback | [VideoActionIcon](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/videos/player/src/widgets/video_action_icon.dart), used by [SeekAnimationOverlay](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/posts/details/src/widgets/seek_animation_overlay.dart), draws a black rounded fill at up to 0.6 opacity | Separate optional visual trial: it is short-lived feedback, not a persistent navigation button. Preserve its animation and visibility. |
| Thumbnail metadata and quick actions | [ImageGridItem](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/posts/post/src/widgets/image_grid_item.dart) contains metadata badges, an explicit AI overlay fill and separately positioned quick actions | Do not remove text-badge surfaces wholesale. Their density/readability and the independent Retry hit-test fix need separate evaluation. |
| Timeline Headers, Search and menus | [UI style guide](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/docs/ui_style_guide.md) records the accepted opaque-surface contract | Excluded. This request must not reverse #136/#148 or make ordinary application chrome transparent. |

This is a targeted inventory of inspected consumers, not a claim that every overlay in the repository has been exhaustively enumerated. Top actions injected by engine-specific builders must be checked during implementation so an otherwise consistent row does not retain one filled trigger.

## Implementation proposal

[KurumiCircularIconButton](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/packages/kurumi/lib/src/components/circular_icon_button.dart) already exposes backgroundColor, iconColor, constraints and semanticLabel. Its default is semanticColors.overlay/onOverlay with a minimum 40 dp constraint. Keep those defaults unchanged for other consumers. Compose an opt-in media-overlay presentation using the existing button, a transparent resting background and shared glyph-shadow parameters; add a narrowly scoped Kurumi visual option only where both normal and custom icons need it. Keep application actions/localization outside Kurumi.

Use the current media foreground semantics, with a tight dark contour-like shadow plus a softer diffuse shadow as the initial visual trial. Suggested starting values are a 1 dp low-blur near-zero-offset shadow and a softer 3 dp shadow; these are experiment values, not new approved project-wide tokens. Test white, black and busy image backgrounds before selecting final opacity/blur. Do not add a permanent circle, whole-row scrim or box shadow as a substitute for glyph shadows.

The Info icon needs explicit attention: [KurumiInfoCircleIcon](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/packages/kurumi/lib/src/components/info_circle.dart) uses CustomPaint and reads only its effective color. A normal IconTheme shadow will not affect that painter. Add opt-in shadow drawing for the same icon paths (or a proven small visual primitive that supports both renderers) while preserving the existing Info glyph. Avoid expensive full-screen filters, repeated offscreen layers or pixel sampling of the media merely to choose icon color.

Retain visible hover, pressed and keyboard-focus feedback even though the resting fill is transparent. Keep tooltips, localized semantics, enabled/selected states and useful hit targets. Use the established 48 dp touch-target precedent around compact glyphs where layout permits, without enlarging the visible icon or shifting the entire toolbar unnecessarily. Do not inherit new shadows into popup contents or opaque Details controls.

Preserve #164's current Immersive/Details composition, physical safe insets, gesture ownership, media motion and group Back behavior. The separate [overlay lifecycle correction](2026-11-11-viewer-overlay-lifecycle.md) should be verified independently; changing appearance is not a fix for repeated hiding.

## Decision and verification boundary

Recommend a small top-overlay trial first, then extend to side navigation only if the same treatment works. A blanket redesign of all translucent surfaces is not justified by this request. The style guide's current instruction to preserve backing overlays needs a narrowly documented media-icon exception if this direction is accepted, not an unannounced global token change.

Use visual fixtures for bright, dark, high-detail and video backgrounds in light/dark/AMOLED themes, narrow widths and enlarged text. Check the custom Info painter, injected top actions, focus rings, touch hit areas, RTL Back direction and animation-disabled mode. Screenshots/device review must establish readability; a semantic color name or an automated widget pass does not prove contrast. Retain a deliberate high-contrast fallback if the glyph-only trial is insufficient, subject to a separate visual decision rather than silently restoring the rejected black circles.

No production widget, theme default or layout was changed by this investigation.
