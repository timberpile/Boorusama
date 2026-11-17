# Improve Double-Tap Zoom Corner Focus — Technical Handoff

Issue: [#168](https://github.com/timberpile/Boorusama/issues/168)
Source reviewed: [`develop` at `55cec5ae2b69`](https://github.com/timberpile/Boorusama/tree/55cec5ae2b697612a68af40ed3a8bc4ba1caedbb) (2026-11-17).
Audience: local implementation agent. Code snippets are **unapplied proposals**, not verified patches.

## Evidence and likely cause

**Source-confirmed:** `packages/kurumi/lib/src/components/interactive_viewer.dart` passes `_doubleTapDetails!.localPosition` from `_handleDoubleTap` directly into `_calculateClassicDoubleTapMatrix`. That function feeds the same point to `_calcZoomMatrixForTargetScale`, which converts it via `TransformationController.toScene`. The scale selection from #153 is separate and should stay untouched. The exact UX effect is user-reported; it was not rechecked on Android.

## Suggested implementation

Introduce a pure focal-point remapper before building the **zoom-in** matrix. Compute the currently painted image rectangle in local viewer coordinates, including contain-fit letterboxing; for a cover-filled area this may equal the viewport. Start with a symmetric **12% inset** on each axis, mapping the inset's inner edge to the actual painted edge and the inner-center to center. Clamp outside taps. Do not resize or translate the image widget, change zoom scales, or remap the second tap that restores `_classicReturnMatrix`.

Illustrative helper (verify rect geometry and transform coordinates in the current widget before wiring):

```dart
double remapAxis(double tap, double origin, double extent) {
  if (!extent.isFinite || extent <= 0) return tap;
  final inset = extent * 0.12;
  final t = ((tap - origin - inset) / (extent - 2 * inset))
      .clamp(0.0, 1.0);
  return origin + t * extent;
}

Offset remapFocus(Offset tap, Rect imageRect) => Offset(
  remapAxis(tap.dx, imageRect.left, imageRect.width),
  remapAxis(tap.dy, imageRect.top, imageRect.height),
);
```

If a valid painted rect cannot be determined, fall back to the unmodified tap rather than guessing. Respect any already-transformed Auto Comic reading baseline.

## Focused verification

- Verify center, edge, and 12%-inside-corner taps on a square, very tall comic, landscape, and panorama; expected target approaches actual image corner before physical screen corner.
- Verify letterboxed margins, narrow images, rotation, invalid dimensions, and continuity near the inset boundary.
- Preserve second-double-tap matrix restoration, pinch, zoom-limit clamp, page swipe, video, and accessibility behavior; use Kurumi's existing viewer tests.
