# Issue #163: Masonry thumbnail aspect ratios

## State

- Issue: https://github.com/timberpile/Boorusama/issues/163
- Implementation branch: `bug/163-masonry-thumbnail-aspect-ratios` (based on `develop` at `266a14c0f87f29213d48696bda7c806dc1d05b6e`)
- Implementation candidate before this handoff: `4d20ed64f513d755e53a2abb3cba8f60708053bc`
- **Not verified or approved for integration.** No PR or merge was requested.
- The GitHub connector was used to commit changes directly to the isolated remote branch. This environment has neither a Flutter/FVM SDK nor a local Git checkout. No Flutter tests, analyzer, formatter, emulator, or device checks have run.
- An independent review agent is not exposed in this session. **Independent review remains required** before declaring the issue ready. Do not report a review as completed until a separate agent has actually performed it.

## Scope and implementation

The symptom reported on Realbooru is an incorrectly sized Masonry tile for a video poster. HTML listing records lack dimensions, so the grid initially uses its configured fallback aspect ratio even when the loaded poster is widescreen. Thumbnail-only image listings and other engines can have similar gaps.

The committed implementation keeps sizing in presentation state and does not alter post, bookmark, or snapshot models:

- `lib/core/posts/listing/src/widgets/post_grid_item.dart`: `_PostGridImage` maintains a decoded aspect ratio locally, updates only for Masonry, guards stale callbacks when media/config changes, and ignores delayed probe-placeholder ratios after a winning image has been decoded.
- `lib/core/images/booru_image.dart`: an optional ratio callback follows the existing `ExtendedImageController.imageInfo` for the primary image, cached image bytes, and fallback chain. Reporting is deferred until after the current frame.
- `lib/core/images/image_candidate_picker.dart` and `lib/core/images/booru_image_candidates.dart`: the format-probing picker reports the first successfully decoded candidate's real dimensions without resolving its image provider again.
- No animation, new network requests, thumbnail prefetch behavior changes, or persistence changes.

The local `packages/extended_image` fork **does not** expose upstream `loadStateChanged` or `enableLoadState`; this code intentionally uses its existing `ExtendedImageController.imageInfo`. Review against this repository's fork, not pub.dev examples.

## Checks to run

Before doing any further work, read the current `AGENTS.md`, the issue, `docs/issue_workflow.md`, and `.agents/skills/debug-issue/SKILL.md`. Reuse this branch in an isolated worktree. Format the touched Dart files with `fvm dart format`, then run the affected Flutter suites:

```bash
fvm dart format lib/core/images/booru_image.dart \
  lib/core/images/booru_image_candidates.dart \
  lib/core/images/image_candidate_picker.dart \
  lib/core/posts/listing/src/widgets/post_grid_item.dart \
  test/core/images/booru_image_fallback_test.dart \
  test/core/images/image_candidate_picker_test.dart

fvm flutter test --no-pub \
  test/core/images/booru_image_fallback_test.dart \
  test/core/images/image_candidate_picker_test.dart \
  test/core/images/image_candidate_handoff_test.dart \
  test/boorus/gelbooru_v2/realbooru_video_thumbnail_test.dart \
  test/core/posts/listing/grid_thumbnail_media_test.dart

fvm flutter analyze --no-pub
```

The new tests cover decoded in-memory image dimensions, decoded network fallback dimensions, and the winning candidate callback. They were written but **not executed** here. Investigate any compile, analyzer, formatting, or runtime errors and fix them on the same branch. Because this changes shared image presentation, run additional affected consumer tests when justified. The full local regression on the final integration candidate is mandatory before merging into `develop`.

## Independent review instructions

Use a fresh agent/context that was **not involved in implementing the change**. Have it inspect the diff from `develop`, the current repository code, and the new tests. Request actionable findings with severity, exact paths, failure conditions, and fixes. In particular:

1. Confirm that callbacks observe the actual decoded visible rendition, including Realbooru's poster probing, cached images and fallbacks, without triggering extra network requests or decoding.
2. Inspect lifecycle and race safety: post reuse, profile changes, image quality changes, failed probes, late placeholder callbacks, rapid scrolling, disposal, GIF frames and disabled media loading.
3. Confirm that Masonry relayouts safely when children change height and that Standard/Classic layouts, viewer navigation, selections, and bookmark/snapshot persistence remain unaffected.
4. Check that the tests use the repository's **local** ExtendedImage API and cover meaningful regression boundaries.
5. Keep the fix as simple as practical; avoid speculative caches or animated transitions. Only explore animation if actual device/UI review finds disruptive jumps.

The remediation pass must address every confirmed finding, rerun affected checks, and record exact commands, results and outstanding limitations. A manual Android/Maestro check is recommended for Realbooru video rows and other sites with missing dimensions, following `docs/android_emulator.md` lease rules. Do not claim manual validation without running it.

## Handoff constraints

Do not merge, close the issue, create a PR, or delete this branch without appropriate authorization. Keep the issue `in-progress` until the implementation, required independent review and scope-appropriate verification are complete.
