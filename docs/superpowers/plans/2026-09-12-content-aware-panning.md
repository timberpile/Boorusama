# Content-Aware Post Panning Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Constrain post-image panning independently on each axis so images remain centered while they fit and expose no blank space while they overflow.

**Architecture:** Kurumi owns opt-in transformation normalization because it owns the `TransformationController`, viewport size, and gesture lifecycle. Boorusama forwards the option through `InteractiveViewerExtended` and enables it only for the normal post viewer. The original-image page and every unrelated interactive viewer retain existing behavior.

**Tech Stack:** Flutter 3.47.2, Dart, `InteractiveViewer`, `TransformationController`, `Matrix4`, Flutter widget tests

**Spec:** `docs/superpowers/specs/2026-09-12-content-aware-panning-design.md`

## Global Constraints

- Implement only issue #3's axis-aware panning checkpoint.
- Do not implement fit-to-width, scroll-to-top, comic-strip-start, threshold selection, or automatic tall-image positioning.
- Apply the behavior only to the normal post viewer; do not change the original-image page.
- Keep the shared Kurumi behavior opt-in with `constrainPanToContent` defaulting to `false`.
- Preserve existing tap, long-press, double-tap, pinch-to-zoom, page-navigation, and video behavior.
- Use FVM for every Flutter and Dart command.
- Stop after opening a draft pull request for user review; do not merge it.

---

### Task 1: Constrain Kurumi transformations to rendered content bounds

**Files:**
- Modify: `packages/kurumi/lib/src/components/interactive_viewer.dart`
- Create: `packages/kurumi/test/interactive_viewer_test.dart`

**Interfaces:**
- Consumes: Flutter `Size`, `Matrix4`, `TransformationController`, and the existing optional intrinsic `contentSize`.
- Produces: `KurumiInteractiveViewer({bool constrainPanToContent = false})` and `KurumiRawInteractiveViewer({bool constrainPanToContent = false})`.
- Behavior: normalize only matrix translation; retain the incoming uniform scale and every other matrix component.

- [ ] **Step 1: Create focused widget-test setup**

Create `packages/kurumi/test/interactive_viewer_test.dart`. Use a real `TransformationController`, a `1000 x 1000` logical-pixel test viewport, and a `KurumiInteractiveViewer` with a viewport-filling child. Build matrices with literal scale and translation values rather than calculating expected values through production helpers.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';

Matrix4 transformation({
  required double scale,
  required double x,
  required double y,
}) => Matrix4.diagonal3Values(scale, scale, 1)
  ..setTranslationRaw(x, y, 0);

Future<TransformationController> pumpViewer(
  WidgetTester tester, {
  required Size? contentSize,
  bool constrainPanToContent = true,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1000, 1000);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  final controller = TransformationController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: KurumiInteractiveViewer(
        controller: controller,
        contentSize: contentSize,
        constrainPanToContent: constrainPanToContent,
        child: const SizedBox.expand(),
      ),
    ),
  );
  return controller;
}
```

- [ ] **Step 2: Write failing tall- and wide-image tests**

For a `500 x 3000` image at scale `2`, assign translation `(100, -200)` and assert that horizontal translation becomes `-500` while vertical translation remains `-200`. For a `3000 x 500` image, assign `(-200, 100)` and assert that horizontal translation remains `-200` while vertical translation becomes `-500`.

Name the tests as observable outcomes:

```dart
testWidgets('centers a fitting width while preserving vertical movement', ...);
testWidgets('centers a fitting height while preserving horizontal movement', ...);
```

- [ ] **Step 3: Run the two tests and verify RED**

Run:

```bash
cd packages/kurumi
fvm flutter test test/interactive_viewer_test.dart
```

Expected: compilation fails because `constrainPanToContent` does not exist. This proves the tests require the new API.

- [ ] **Step 4: Add the opt-in API and transformation normalizer**

Add `constrainPanToContent` with a default of `false` to `KurumiInteractiveViewer` and `KurumiRawInteractiveViewer`, and forward it between them.

In `_KurumiRawInteractiveViewerState`, derive the pre-transform contained image size:

```dart
final containScale = min(
  viewport.width / content.width,
  viewport.height / content.height,
);
final fittedSize = Size(
  content.width * containScale,
  content.height * containScale,
);
final fittedOffset = Offset(
  (viewport.width - fittedSize.width) / 2,
  (viewport.height - fittedSize.height) / 2,
);
```

For each axis, compute `transformedLength = fittedLength * scale`. When it fits, return the centered translation:

```dart
viewportLength / 2 - scale * (fittedOffset + fittedLength / 2)
```

When it overflows, clamp the current translation between:

```dart
viewportLength - scale * (fittedOffset + fittedLength)
-scale * fittedOffset
```

Use a `0.5` logical-pixel tolerance for fit and translation comparisons. Return the original matrix for missing or invalid sizes. Clone the matrix and replace only its translation when a correction is necessary.

- [ ] **Step 5: Normalize before publishing transformation details**

At the start of `_onChanged`, normalize the controller value when the option is enabled. Use a boolean recursion guard. If correction assigns a new controller value, let the synchronous guarded notification publish the corrected `KurumiTransformationDetails`, then return from the outer notification.

When `_containerSize`, `widget.contentSize`, or `widget.constrainPanToContent` changes, schedule one post-frame normalization. Track whether a correction is already scheduled and verify `mounted` before applying it.

- [ ] **Step 6: Run the focused tests and verify GREEN**

Run the Kurumi test command from Step 3.

Expected: both tests pass, with the tall and wide images constrained on only their fitting axes.

- [ ] **Step 7: Add boundary, opt-out, and invalid-input tests**

Add cases that independently protect the remaining contract:

- a square `1000 x 1000` image at scale `2` preserves valid translation `(-250, -750)` on both axes;
- a tall `500 x 3000` image at scale `2` clamps vertical translation above `0` to `0` and below `-1000` to `-1000`;
- `constrainPanToContent: false` preserves programmatic translation `(100, -200)`;
- `contentSize: null` and `Size.zero` preserve translation without throwing.
- resizing the viewport from `1000 x 1000` to `1200 x 1000` recenters a fitting image width on the next frame;
- rebuilding the same controller with changed intrinsic content dimensions reapplies both axis bounds on the next frame.

For resize tests, retain the same controller across `pumpWidget` calls and use literal expected translations. Use one test per behavior.

- [ ] **Step 8: Run all Kurumi tests**

Run:

```bash
cd packages/kurumi
fvm flutter test
```

Expected: every Kurumi test passes.

- [ ] **Step 9: Format and commit the Kurumi implementation**

Run:

```bash
fvm dart format \
  packages/kurumi/lib/src/components/interactive_viewer.dart \
  packages/kurumi/test/interactive_viewer_test.dart
git diff --check
git add \
  packages/kurumi/lib/src/components/interactive_viewer.dart \
  packages/kurumi/test/interactive_viewer_test.dart
git commit -m "feat(viewer): constrain panning to image bounds"
```

---

### Task 2: Enable content-aware panning in the normal post viewer

**Files:**
- Modify: `lib/core/widgets/interactive_viewer_extended.dart`
- Modify: `lib/core/posts/details/src/widgets/post_details_item.dart`
- Create: `test/core/widgets/interactive_viewer_extended_test.dart`

**Interfaces:**
- Consumes: Task 1's `KurumiInteractiveViewer.constrainPanToContent` parameter.
- Produces: `InteractiveViewerExtended({bool constrainPanToContent = false})`, forwarding the value unchanged.
- Integration: `PostDetailsItem` passes `constrainPanToContent: true`; all other callers use the default `false`.

- [ ] **Step 1: Write a failing wrapper-propagation test**

Create `test/core/widgets/interactive_viewer_extended_test.dart`. Pump `InteractiveViewerExtended` inside `ProviderScope` and `MaterialApp` with a real controller, a `1000 x 1000` viewport, `contentSize: Size(500, 3000)`, and `constrainPanToContent: true`. Override `hapticFeedbackLevelProvider` with `HapticFeedbackLevel.none` so the test uses no settings persistence. Assign scale `2` and translation `(100, -200)`, then assert the observable controller translation is `(-500, -200)`.

This test fails if the wrapper omits or incorrectly forwards the option while relying on the already-tested Kurumi behavior for the geometry.

- [ ] **Step 2: Run the wrapper test and verify RED**

Run:

```bash
fvm flutter test test/core/widgets/interactive_viewer_extended_test.dart
```

Expected: compilation fails because `InteractiveViewerExtended` does not yet expose `constrainPanToContent`.

- [ ] **Step 3: Forward the wrapper option and enable it for posts**

Add the default-false parameter and field to `InteractiveViewerExtended`, then pass it to `KurumiInteractiveViewer`:

```dart
final bool constrainPanToContent;

KurumiInteractiveViewer(
  constrainPanToContent: constrainPanToContent,
  // existing arguments remain unchanged
)
```

In `PostDetailsItem`, add only:

```dart
constrainPanToContent: true,
```

to its `InteractiveViewerExtended`. Do not change `OriginalImagePage` or any other caller.

- [ ] **Step 4: Run the wrapper test and verify GREEN**

Run the command from Step 2.

Expected: the wrapper test passes.

- [ ] **Step 5: Run related post-viewer regression tests**

Run:

```bash
fvm flutter test test/core/widgets/interactive_viewer_extended_test.dart
fvm flutter test test/core/posts/post_viewer_original_actions_test.dart
```

Expected: both focused suites pass; original-image loading action behavior remains unchanged.

- [ ] **Step 6: Format and commit the Boorusama integration**

Run:

```bash
fvm dart format \
  lib/core/widgets/interactive_viewer_extended.dart \
  lib/core/posts/details/src/widgets/post_details_item.dart \
  test/core/widgets/interactive_viewer_extended_test.dart
git diff --check
git add \
  lib/core/widgets/interactive_viewer_extended.dart \
  lib/core/posts/details/src/widgets/post_details_item.dart \
  test/core/widgets/interactive_viewer_extended_test.dart
git commit -m "feat(viewer): enable content-aware post panning"
```

---

### Task 3: Verify phase 1 and open the review checkpoint

**Files:**
- Verify: all changed files in `develop..feature/3-improve-tall-images`
- Remote: GitHub issue `#3` and a new draft pull request targeting `develop`

**Interfaces:**
- Consumes: Tasks 1 and 2 as one independently reviewable phase.
- Produces: a verified draft PR; no merge and no phase-2 code.

- [ ] **Step 1: Run code generation and confirm a clean generated diff**

Run:

```bash
./gen.sh
git status --short
```

Expected: generation succeeds and produces no unrelated tracked changes.

- [ ] **Step 2: Run static analysis**

Run:

```bash
fvm flutter analyze
```

Expected: no analyzer issues.

- [ ] **Step 3: Run the affected package and focused root suites**

Run:

```bash
cd packages/kurumi
fvm flutter test
cd ../..
fvm flutter test test/core/widgets/interactive_viewer_extended_test.dart
fvm flutter test test/core/posts/post_viewer_original_actions_test.dart
```

Expected: every test passes.

- [ ] **Step 4: Run the complete root suite**

Run:

```bash
fvm flutter test
```

Expected: all root tests pass with zero failures.

- [ ] **Step 5: Audit scope and working tree**

Run:

```bash
git diff --check develop..HEAD
git diff --stat develop..HEAD
git status --short --branch
```

Confirm the diff contains only the committed design and plan, Kurumi constraint and tests, wrapper forwarding, post-viewer opt-in, and root wrapper test. Confirm there are no fit-to-width actions, settings, translations, or original-image-page changes.

- [ ] **Step 6: Push and create the draft pull request**

Run:

```bash
git push -u origin feature/3-improve-tall-images
gh pr create \
  --draft \
  --base develop \
  --head feature/3-improve-tall-images \
  --title "Merge branch 'feature/3-improve-tall-images'" \
  --body "Closes #3

## Summary
- constrain panning independently against rendered image bounds
- enable content-aware constraints only in the normal post viewer
- preserve current behavior for the original-image page and unrelated viewers

## Verification
- ./gen.sh
- fvm flutter analyze
- Kurumi package tests
- focused post-viewer tests
- complete root Flutter test suite

## Review checkpoint
This draft contains only phase 1. Fit-to-width, scroll-to-top, comic-strip-start, and automatic tall-image handling remain intentionally excluded pending review."
```

- [ ] **Step 7: Verify GitHub policy and stop for review**

Run:

```bash
gh pr checks --watch
gh pr view --json number,title,isDraft,state,mergeable,statusCheckRollup,url
```

Expected: the `Pull request policy` check passes, the PR remains open and draft, and no merge occurs. Report the PR URL and verification results to the user, then stop before phase 2.
