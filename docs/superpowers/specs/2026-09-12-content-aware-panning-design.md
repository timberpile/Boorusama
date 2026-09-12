# Content-Aware Post Panning Design

## Purpose

Implement the first review checkpoint of GitHub issue #3: prevent unintended
movement on any axis where the displayed post image still fits inside the post
viewer. This makes vertical navigation through tall images stable without
restricting legitimate two-axis panning after zooming far enough.

This checkpoint does not add fit-to-width, scroll-to-top, comic-strip-start, or
automatic tall-image positioning. Those behaviors will be designed only after
the content-aware constraint has been reviewed.

## Scope

The behavior applies to still images in the normal post-details viewer. It does
not change:

- the separate original-image page;
- tag-editing and upload viewers;
- video interactions;
- page navigation or the post-information sheet;
- existing pinch-to-zoom, double-tap, long-press, or tap callbacks.

The shared Kurumi viewer receives an opt-in capability so that existing callers
remain unchanged. Boorusama enables it only from `PostDetailsItem`, where the
intrinsic post dimensions are already available as `contentSize`.

## Interaction Behavior

At every transformation, calculate the rendered image bounds for the current
viewport and zoom scale independently on each axis.

- If the transformed image width is no greater than the viewport width, lock
  horizontal translation to the value that centers the image.
- If the transformed image height is no greater than the viewport height, lock
  vertical translation to the value that centers the image.
- If an axis overflows the viewport, allow movement on that axis but clamp it so
  neither image edge can move past the corresponding viewport edge and reveal
  empty space.
- Treat the axes independently. A tall image may scroll vertically while
  remaining horizontally centered; a wide image behaves symmetrically.
- Once zoom makes both dimensions exceed the viewport, normal two-dimensional
  panning remains available within both sets of bounds.

The correction applies after direct controller updates as well as user gestures.
It is also reapplied after viewport-size or intrinsic-content-size changes so
rotation and responsive layout cannot leave a previously valid translation out
of bounds.

## Geometry

Let intrinsic content size be `C`, viewport size be `V`, transformation scale be
`s`, and the current matrix translation be `t`.

The untransformed image is laid out with contain semantics:

```text
containScale = min(V.width / C.width, V.height / C.height)
B = C * containScale
o = (V - B) / 2
```

`B` is the rendered image size before the interactive transformation and `o`
is its centered offset in the viewport-sized child.

For each axis with viewport length `v`, base-image length `b`, base offset `o`,
and translation `t`:

```text
transformedLength = b * s
```

When `transformedLength <= v`, the centered translation is:

```text
t = v / 2 - s * (o + b / 2)
```

When the transformed image overflows, translation is clamped to:

```text
v - s * (o + b) <= t <= -s * o
```

The implementation uses a small floating-point tolerance when comparing bounds
to avoid oscillation around an exact fit.

## Kurumi API

Add `constrainPanToContent` to both `KurumiInteractiveViewer` and
`KurumiRawInteractiveViewer`, defaulting to `false`. The existing
`InteractiveViewerExtended` wrapper exposes and forwards the same property.

When enabled, valid `contentSize` and viewport dimensions are required for the
additional constraint. Missing, zero, infinite, or non-finite dimensions fall
back to the existing Flutter `InteractiveViewer` behavior instead of inventing
bounds.

The Kurumi state normalizes the `TransformationController` matrix before
publishing `KurumiTransformationDetails`. A recursion guard permits the
controller's corrected notification to publish the final state exactly once
without repeatedly assigning the same matrix.

The implementation assumes the existing uniform, non-rotating transformation
used by `KurumiRawInteractiveViewer`. No rotation support is added in this
checkpoint.

## Post Viewer Integration

`InteractiveViewerExtended` in `PostDetailsItem` sets
`constrainPanToContent: true`. The existing post width and height continue to
provide `contentSize`; no additional post metadata or provider state is added.

The original-image loading behavior remains compatible. When loading the
original changes only the media URL or aspect-ratio metadata, the current post
dimensions continue to describe the same underlying image and the constraint
remains valid.

## Testing

Kurumi widget tests use a real `TransformationController` in a fixed viewport
and assert the observable corrected matrix translation. They cover:

- a tall image retaining vertical movement while horizontal drift is centered;
- a wide image retaining horizontal movement while vertical drift is centered;
- a sufficiently zoomed image retaining valid movement on both axes;
- translations beyond overflowing image edges being clamped to the nearest
  valid boundary;
- disabled constraints preserving the current behavior;
- invalid or absent content dimensions falling back without exceptions.

The Boorusama wrapper test confirms that the opt-in value reaches Kurumi and
that the default leaves existing callers unchanged. The post viewer's explicit
one-line opt-in is verified by analyzer coverage and the phase scope audit;
constructing the complete post-details provider graph solely to inspect a
forwarded boolean would test implementation structure rather than behavior.

Verification runs:

1. `./gen.sh`
2. FVM-managed Dart formatting for changed Dart files
3. `fvm flutter analyze`
4. the Kurumi package test suite
5. focused root post-viewer tests
6. the complete root Flutter test suite

## Review Checkpoint

Commit the phase-1 implementation on `feature/3-improve-tall-images`, push it,
and open a draft pull request titled
`Merge branch 'feature/3-improve-tall-images'` with `Closes #3` in its body.
Stop after the draft PR and verification results are available. Fit-to-width,
scroll-to-top, comic-strip-start, threshold selection, and automatic behavior
remain excluded until the user reviews and approves this checkpoint.
