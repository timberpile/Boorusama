# Decision 6 — Aspect-Aware Double-Tap Zoom After Real-Device Measurements

**Status:** Research and candidate algorithms. **No default algorithm or constants approved yet.** A separate user-test branch exists, but is not integrated into `develop`.

## One-minute explanation

Keep the **Classic interaction** (first double tap zooms in, next returns), but replace the crude normal-image 3× target with a useful amount based on **the visible media area and the actual image aspect ratio**. Extremely tall comics have their own readable fit-width baseline, which must not be accidentally lost.

## Current behavior and independent experiment

On `develop`, Kurumi `DoubleTapZoomMode.classic`:
1. If an existing transformation is non-identity, double tap resets to identity (not necessarily the prior **Comic reading** baseline).
2. Otherwise, for an image whose ratio differs greatly from the viewport, zoom to the **other dimension fit**.
3. Otherwise, zoom by a **fixed factor 3×**.
4. `fitCycle` may add a second detail zoom stage before returning. This extra step is the user's primary complaint.
5. Pinch **Snap Zoom to Fit** is separate from double-tap behavior.

The user-test branch [Zoom Study Diagnostics](https://github.com/timberpile/Boorusama/tree/maintenance/zoom-study-diagnostics) changes the Snap-to-Fit tolerance from ±5% to **±10%**, adds a developer-only live meter and records preferred zoom levels for individual images, with real image dimensions and viewport orientation in a JSON file in Downloads. **That branch has not passed Flutter/Android verification in this session and is not merged.** Do not describe 10% as the current `develop` value.

## Geometry independent of device pixels

Let `imageAspect = imageWidth / imageHeight` and `mediaAspect = usableViewportWidth / usableViewportHeight`. The zoom multiplier to fill the **other** dimension from an initial Contain Fit is:

```text
q = max(imageAspect / mediaAspect, mediaAspect / imageAspect)
```

Important: use the actual **usable media viewport** (subtract chrome/sheets/insets), not the physical screen ratio alone. The user's phone is about **1:2.2 in portrait, 2.2:1 in landscape**. These are reference geometries; the runtime must record the actual measured viewport.

| Example image ratio | Portrait viewport 1:2.2: other fit | Landscape viewport 2.2:1: other fit |
| --- | ---: | ---: |
| Square 1:1 | 2.20× | 2.20× |
| Typical portrait 2:3 | 1.47× | 3.30× |
| Landscape 16:9 | 3.91× | 1.24× |
| Wide panorama 4:1 | 8.80× | 1.82× |
| Very tall comic 1:6 | 2.73× | 13.20× |

All values are geometric targets **before** runtime max scale, media quality and Comic baseline. They are **not** user-approved desired zoom values.

This explains why any orientation-independent fixed zoom is unsatisfactory. The same panorama can need much more magnification in portrait than in landscape.

## Candidate algorithms worth measuring

1. **Exact Other Fit**: use `q` directly. Simple, matches the user's square-image expectation and respects actual geometry. May barely zoom at near-matching ratios; very wide content may jump too far.
2. **Bounded Other Fit**: clamp `q` to a minimum perceptible target and maximum double-tap target, **not the global pinch maximum**. Explore small floors near 1.2–1.35 and caps near 4, but no constant is final. A floor creates intentional clipping where an image almost fits perfectly.
3. **Soft Cap for Extreme Ratios**: use exact `q` over ordinary images and smoothly compress only large values (e.g. beyond a configurable aspect mismatch). More faithful for wide images but harder to predict and explain; only adopt if user measurements require it.

**Preferred initial hypothesis:** measure exact and bounded fit on the real phone; select the simplest bounded rule consistent with recorded preferences. Avoid a complex learned mapping on few subjective samples.

## Comic and baseline behavior

- `autoAdjustComicStrips` intentionally fits very tall images to width and allows vertical reading. This baseline is not necessarily the identity/Contain Fit transformation.
- The user wants the second double-tap to return to the **meaningful starting reading state**. Preserve the correct prior baseline transform/anchor when zooming from Comic mode.
- Rotating a phone changes the viewport aspect; a raw old pixel translation cannot be reapplied blindly. Keep a normalized image focal point/reading progress where possible.
- A manual pinch that changes scale or pan may differ from a double-tap state; decide whether double-tapping should restore baseline immediately or only reset when a double-tap zoom was performed. Preserve configured gesture overrides and video seek behavior.

## What to record and how to analyze it

From the developer Zoom Study JSON:
- Exact **decoded media** dimensions where available, plus metadata fallback/source flag.
- Usable viewport width/height, orientation, image ratio and optional source/Work/Page identity.
- Relative transformation scale and whether Auto Comic/Zoom Snap is enabled.
- Double-tap mode, time, ideally an explicitly selected **preferred** zoom after manual pinch.

**Recommended analysis:**
1. Separate portrait and landscape and group by `q`, not just image `width/height`.
2. Divide into near-screen-match, normal portrait, square, normal landscape, panorama, tall Comic. Exclude invalid dimensions and videos.
3. Compare each preferred zoom to `q`, fixed Classic 3×, bounded and soft-capped predictions. Plot per-sample errors and representative image examples.
4. Recognize repeated observations from the same image/person as preference tests, **not independent statistical proof**. Favor understandable piecewise/clip rules over a large fitting model.
5. Explicitly inspect Comic baseline values and zoom after rotation before approving reset transitions.

Privacy: exported JSON should not contain image bytes, URLs, account tokens or file paths. A numeric Post ID may still identify personal viewing activity, so share it deliberately.

## Test matrix for eventual implementation

- 1:2.2 portrait and 2.2:1 landscape, plus actual media viewport insets.
- Square, 2:3 portrait, screen-matched, 16:9 landscape, 4:1 panorama, very tall Comic, low-res image, video and unknown dimensions.
- First/second double tap; pinch between taps; image changed; screen rotated; sheet expanded/collapsed; original-quality image loaded mid-zoom; tap near edges.
- Already-set Auto Comic reading baseline, user-scroll position, reset back to baseline.
- Existing configured double-tap gestures and disabled Snap Zoom to Fit must not silently change meaning.
- Run package-level Kurumi tests, related Viewer tests, actual Android device/gesture tests, and full integration-candidate regression.

## Proposed decision

**Defer final zoom factor constants until the user's exported real-device JSON is reviewed.** Prepare a Classic one-in/next-out implementation with a geometry-aware target and a meaningful reset baseline. The separate ±10% Snap-to-Fit change is a scoped test feature, not approval of an entirely new zoom algorithm.

**Still discuss:** preferred floor/cap or gentle cap behavior, near-match minimum zoom, Comic reset baseline, and what a manually pinched image does on subsequent double tap.

### Code sources

- [Current Kurumi Interactive Viewer](https://github.com/timberpile/Boorusama/blob/e306ff533/packages/kurumi/lib/src/components/interactive_viewer.dart)
- [Current Auto Comic transform controller](https://github.com/timberpile/Boorusama/blob/e306ff533/lib/core/posts/details/src/types/post_viewer_transformation_controller.dart)
- [Zoom Study test branch](https://github.com/timberpile/Boorusama/tree/maintenance/zoom-study-diagnostics)
