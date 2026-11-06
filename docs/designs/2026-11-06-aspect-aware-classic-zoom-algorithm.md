# Aspect-Aware Classic Double-Tap: Concrete Algorithm Candidate

**Status:** Experimental, **not** an approved runtime implementation. Current reference: `develop` `e306ff533`. The user wants Classic's **one-in / next-out** interaction and image-footprint goals for extreme aspect ratios, without fitting the model to Snap/Auto Comic internals. A separate opt-in [Zoom Study branch](https://github.com/timberpile/Boorusama/tree/maintenance/zoom-study-diagnostics) has the agreed ±10% Snap setting but is not merged.

## User preference update: conservative normal zoom (2026-11-06)

The user clarified that **slightly too little magnification is preferable to too much**. For ordinary image formats, most preferred first-double-tap results are **2.0–2.5×**; 3× or more was occasionally selected during manual sampling, but those cases would generally still have been acceptable at 2.2–2.5×. **Do not optimize the median measurements as if overshoot and undershoot had equal subjective cost.**

This supersedes the former 2.90× square-image peak and the unrestricted normal-image landscape other-fit. Use a **2.25× normal-image base**, a **small maximum 2.45× boost near square in portrait**, and **2.5× as the provisional upper bound for ordinary images**, including a normal-image landscape other-fit. These are only initial comparison values, not approved constants. **Never apply the 2.5× normal-image bound to extreme media readability targets**, such as square-footprint panoramas or tall comics, which can legitimately need higher magnification.

The earlier in-sample error `~0.29×` documented below was measured for the stronger candidate, **not** this new conservative one. It is retained only as historical evidence and must not be quoted as this version's predictive accuracy. For validation, compare over-zoom frequency and subjective comfort, not only mean absolute error.

## Product goal, not a universal fixed multiplier

A first double tap can mean two different things:

- **Readability:** a very tall or very wide image must show a conveniently sized readable **image band/column** so panning becomes practical. The *image footprint* should be chosen relative to the actual media viewport, not multiplied blindly by 3×.
- **Inspect detail:** an already legible, ordinary-shaped image needs a comfortable enlargement of the tapped area.

The actual screen viewport remains portrait/landscape; a "square-ish visible image footprint" refers to the **visible image area**, with empty side/top gutters where appropriate. It does *not* replace the viewport with a square.

## Inputs

```text
a = imageWidth / imageHeight         // decoded media dimensions, fallback validated metadata
v = mediaViewportWidth / mediaViewportHeight   // measured usable viewer rectangle
q = max(a / v, v / a)               // exact fit of the other image dimension
z = absolute scale relative to initial full Contain Fit
```

Guard zero, nonfinite and unknown dimensions. Fallback to the old safe Classic behavior when geometry is unavailable; do not guess from the device's nominal aspect ratio. The user measured on approximately `v=0.4543` portrait and `v=2.0904` landscape, but runtime must use the **actual** viewport.

## Candidate target geometry

| Image | Portrait target | Landscape target |
| --- | --- | --- |
| **Extremely tall** (`a <= 0.30`) | Fit displayed image **width** to viewport width: `z = v/a`. This matches Comic reading. | A square-ish **image column** with displayed width about viewport height: `z = 1/a`. Side margins remain visible. |
| **Ordinary shape** | Moderate detail scale, with an additional smooth boost near square images. | Fit the other dimension, `z = max(a/v, v/a)`, with a small minimum perceptible scale. |
| **Extremely wide** (`a >= 2.40`) | A square-ish, slightly portrait **image band** with displayed height `1.10 * viewportWidth`: `z = 1.10*a`. Horizontal panning. | Fit displayed image **height** to viewport height: `z = a/v` on a typical landscape viewport where `a >= v`. |

`z` is the relative contain-fit scale. For tall media in landscape, a narrower media viewport may need special casing: `1/a` assumes the image initially fits by height, which is true whenever `a < v`. Likewise `1.10*a` for wide media in portrait assumes its initial contain-fit is width-limited. Use the general calculated `fittedWidth`/`fittedHeight` if these assumptions do not hold.

## Smooth transitions instead of hard jumps

The four extreme geometries should be **fully in effect** only at clear extremes. In between, smoothly blend toward a detail-zoom rule. Sample-driven, editable candidate thresholds:

- Tall fully active when `a <= 0.30`; blend to normal by `a = 0.55`.
- Wide fully active when `a >= 2.40`; blend from normal starting at `a = 1.75`.
- In the middle, portrait detail zoom has a moderate **2.25×** base, plus a conservative **0.20×** bump narrowly centered on square images (peak **2.45×**). The user explicitly prefers less zoom over excessive zoom; higher manually selected samples should not force the default above 2.5×.
- Landscape normal zoom starts from the exact other-dimension fit `q`, with a tentative **1.15× minimum** and **2.50× maximum for ordinary images**. Extreme tall/wide readability targets remain exempt; this rule still has much less data behind it than portrait preferences.
- For extreme portrait-wide images, `1.10` is the displayed-image-height-to-viewport-width ratio. Treat it as adjustable, approximately 1.0–1.2, not an image zoom constant.

### Pure target-scale pseudocode (Dart-like)

```dart
double smoothstep(double start, double end, double x) {
  final t = ((x - start) / (end - start)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

double targetZoom(double imageAspect, double viewportAspect) {
  final a = imageAspect;
  final v = viewportAspect;
  final q = max(a / v, v / a);

  if (v >= 1) { // landscape
    final normal = q.clamp(1.15, 2.50).toDouble();
    if (a >= 0.55) return normal;
    final t = smoothstep(0.30, 0.55, a);
    final tallSquareFootprint = 1.0 / a;
    return lerpDouble(tallSquareFootprint, normal, t)!;
  }

  // portrait: ordinary images get a detail zoom;
  // approximately square images get a little more.
  final squareDistance = log(a) / 0.13;
  final detail = 2.25 + 0.20 * exp(-0.5 * squareDistance * squareDistance);

  if (a < 0.55) {
    final t = smoothstep(0.30, 0.55, a);
    return lerpDouble(v / a, detail, t)!;   // tall -> detail
  }
  if (a > 1.75) {
    final t = smoothstep(1.75, 2.40, a);
    return lerpDouble(detail, 1.10 * a, t)!; // detail -> wide
  }
  return detail;
}
```

`lerpDouble` here is illustrative, not a request for an extra dependency. Implement with `x + (y-x)*t` if appropriate. Above functions require valid finite positive input sizes and should be bounded by the existing **physical** media max scale, not a universal new 4× cap. Neither dimension fit nor image-band targets should suddenly become impossible for legitimate long comics.

## Illustrative target zooms on the measured 2.2:1 phone

| Image aspect `a` | Portrait `v=0.454` | Landscape `v=2.090` | Intent |
| --- | ---: | ---: | --- |
| Very tall Comic 1:4 | **1.82×** | **4.00×** | Portrait width fit; landscape square-ish column |
| Ordinary portrait 2:3 | **2.25×** | **2.50×** | Conservative detail portrait / capped normal landscape |
| Square 1:1 | **2.45×** | **2.09×** | Small square detail boost, no 3× default |
| Ordinary landscape 3:2 | **2.25×** | **1.39×** | Detail portrait / other-fit landscape |
| Wide 2.4:1 | **2.64×** | **1.15×** | Slightly portrait band / height fit |
| Panorama 4.4:1 | **4.84×** | **2.11×** | Readable band / full-height landscape |

These are **algorithm calculations**, not separate source observations.

## Check against the user's first JSON

- Input: **76 manual preferences**, 65 portrait and 11 landscape, all with decoded media dimensions. Some images appear in both orientations; one image has two different manual portrait preferences.
- The **older, more aggressive variant** had mean absolute scale difference about **0.29×**, median about **0.17×**, and 70/76 within ±25% of the selected preferences. These scores **do not apply to the conservative 2.45×-peak variant**. The current Classic's geometry/3× behavior was about **1.41×** mean absolute difference on these observations. Because the user prefers under-zooming, optimizing symmetric absolute error alone is inappropriate.
- These coefficients were **chosen after inspecting this dataset**. This is descriptive in-sample fit, **not independent predictive validation** or evidence that every image should match the algorithm.
- High-residual choices exist. In particular one ordinary portrait image of ratio 0.75 was set to about 4.28× and another of ratio 1.41 to about 4.11×, beyond the ordinary-size prediction. A ratio-only first-double-tap algorithm cannot infer the desired semantic subject-level magnification for every picture. Pinch remains available.

Only aggregate statistics are recorded here. **Do not commit the raw JSON or individual source post IDs**, which could reveal viewing activity.

## Snap and Classic state transition

**The manually recorded preferred values are authoritative subjective targets**, even though the diagnostic build had Snap/Auto Comic enabled. Those settings should **not** be used to discard or reweight observations.

For the eventual runtime behavior:
1. Compute the absolute target relative to **Contain Fit**, using decoded media dimensions and the current viewport. Keep the tapped point steady as the existing Kurumi viewer does.
2. When computed zoom is within **10% relative scale** of a **nontrivial** exact fit-to-width or fit-to-height target, use that canonical fit. Never snap a purposeful double-tap zoom back to contain scale ~1× merely because it is near.
3. Distinguish the actual **viewer baseline transformation** (Contain or previously applied Comic width-fit, including reading position) from an explicit **double-tap-zoom-active** state. Next double tap restores the previous meaningful baseline instead of unconditionally `Matrix4.identity()`.
4. If a tall Comic is already auto-fitted to width, the readability target may equal its starting baseline. Then a first double tap must not silently do nothing. A **separate detail increment** from that reading baseline is a reasonable candidate, while the next resets; choose this exact increment only after UX/device review.
5. Preserve page transitions, reset after orientation change without stale pixel coordinates, and source-configured gestures and video seek semantics.

## Tests needed on the future implementation

- Pure target function: threshold continuity, negative/zero/NaN inputs, computed geometries and both 2.2:1 device orientations.
- Normal and near-square portrait, extremely tall/wide, aspect matching, arbitrary viewport insets, and images with metadata dimensions 0 but decoded dimensions available.
- Double taps at different image points, pinch between taps, tap when already at non-identity Comic baseline, reading-position restoration, pagination, orientation changes and animated transitions.
- Verify fit snapping with 10% boundary and without forcing a no-op. Run Kurumi widget tests and Android device/gesture checks.
- Measure whether a **fresh** set of preferences, including more ordinary landscape images, supports the same thresholds. Prefer readability over a marginally lower in-sample error.

## Proposed next decision

Accept the **geometry/transition structure with a conservative ordinary-image zoom** as a test candidate, but do **not** finalize its numeric constants yet. The most important remaining user questions are (a) whether landscape-normal images should always use other-fit, including when the zoom is almost 1×; (b) the first double-tap action when a Comic already starts width-fitted; and (c) whether the portrait square boost feels too strong on genuinely low-resolution imagery.

Related: [Zoom Decision 6](2026-11-05-decision-06-zoom-geometry-and-data.md).
