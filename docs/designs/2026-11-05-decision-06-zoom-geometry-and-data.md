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

## Updated user intent and actual preferred image footprint (2026-11-06)

**The objective is the visible *image footprint*, not a generic zoom multiplier.** The user describes two reasons for zoom: **readability** (very narrow/tall or wide media needs enough screen area to pan through) and **detail inspection** (normally readable images should enlarge the selected area). These are distinct intents. Normal images should not be forced into the same square-ish crop rule as extreme formats.

The user explicitly clarified: **all recorded values were manually chosen as preferred results**. Do not discount or reweight them just because Auto Comic or Snap-to-Fit was enabled. Existing Snap behavior should still be preserved in the eventual algorithm.

### Four extreme-image target geometries

Let `a = imageWidth/imageHeight`, `v = viewportWidth/viewportHeight`, and `z` be magnification relative to initial full Contain Fit.

| Image + orientation | Desired visible picture geometry | Candidate target `z` | Why |
| --- | --- | --- | --- |
| **Very tall + portrait** | Image fills **viewport width**, vertically pannable | `z = v/a` | Comic-style readable column |
| **Very tall + landscape** | Rendered image is about **one viewport height wide**, with deliberate side gutters and vertical pan | `z = kTall/a`, where `kTall≈1.0–1.1` is image displayed width / viewport height | Square-ish or slightly landscape window without forcing full landscape width |
| **Very wide + portrait** | Rendered image has a height around **1.0–1.2 viewport widths**; horizontal pan and top/bottom gutters | `z = kWide*a`, where `kWide≈1.1–1.2` is displayed image height / viewport width | Square-ish or slightly portrait window, not full portrait height |
| **Very wide + landscape** | Image fills **viewport height**, horizontally pannable | `z = a/v` | Natural horizontal panorama reading |

The usual *viewport rectangle itself* always keeps the phone's aspect ratio. A **square visible image area** in these cases means the displayed image fills a smaller, centered square-ish band/column with side or top/bottom gutters. It does **not** mean making the screen viewport square.

### Evidence from the user's 76 real-device choices

Dataset: 76 records, 65 portrait and 11 landscape, with **decoded** image dimensions. Do not commit raw Post IDs or private source links. The following medians include all samples in the specified categories, including those near a Snap value.

| Category | Count | Measured median **image footprint** | Inference |
| --- | ---: | ---: | --- |
| Tall `a<0.30`, portrait | 4 | Displayed width = **1.000 × viewport width** | Exact width fit in each sample |
| Tall `a<0.30`, landscape | 4 | Displayed width = **0.983 × viewport height** | Nearly square; individual values ~0.86–1.09 |
| Wide `a>2`, portrait | 6 | Displayed height = **1.125 × viewport width** | Square-ish, slightly portrait image band |
| Wide `a>2`, landscape | 6 | Displayed height = **1.000 × viewport height** | Exact height fit in each sample |
| Ordinary `0.5<=a<=1.9`, portrait | 55 | Chosen zoom **2.30×** | Detail examination more important than basic fit |
| Near-square `0.9<=a<=1.2`, portrait | 9 | Chosen zoom **2.86×** | Square detail zoom may deserve a higher target |

Viewport examples from the JSON: portrait ~363.43×800 (v=0.4543), landscape ~759.71×363.43 (v=2.0904). A very wide `a=4.4` image predicts about `4.4×1.1=4.84×` in portrait (observed 4.76×) and `4.4/2.09=2.11×` in landscape (observed 2.10×). A very tall `a=0.25` image predicts `0.4543/0.25=1.82×` in portrait (observed 1.82×) and `1/0.25=4×` in landscape (observed ~3.98× for this image).

**Do not overfit** the 4/6-sample extreme categories into hard exact thresholds. The observed range of `kTall` and `kWide` is genuine per-image subjectivity; the user allows a slightly non-square target.

### Transition to ordinary images (still open)

The four rules should apply when the content is **genuinely extreme**, not to normal portrait images that happen to mismatch a landscape screen. Use an explicit aspect category or a smoothly blended transition to the **detail zoom** regime. A normal 2:3 portrait in a portrait phone is comfortably readable at Contain Fit; its first zoom should target detail inspection, not a barely visible other-dimension fit. Likewise, a square portrait image favored ~2.86× rather than a mandatory 2.20×.

Candidates to test:
- **Readability regime:** choose the picture-footprint targets above.
- **Detail regime:** roughly 2.2–2.5× for common formats, investigate ~2.7–2.9× near square. This is a candidate based on the user's measured medians, **not** a published default.
- **Smooth transition:** ease between the two regimes so crossing an aspect threshold doesn't abruptly change zoom, and keep the double-tap focus point/pan stable.
- **Snap canonical fits:** if a computed target is sufficiently close to exact contain/width/height fit, snap to that canonical target (test ~10% in the user-study branch), but never overwrite the meaning of the chosen values in the measurements.

**Preserve Classic's fast one-in/next-out interaction**. Reset should return to a meaningful viewer starting state (including reading position if relevant), not blindly to identity when the initial display already had fit-width or another transform.

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
