# Unify thumbnail overlays and reduce the favorite icon size

Priority: Normal
Affected feature: Post thumbnails / profile icons, status badges, and Quick Favorite

## Problem and goal

Thumbnail overlays use independently configured sizes: loaded profile/website icons are 32, bundled logos are 28, and status badges are 24 logical pixels. The fallback globe icon has a reference size of 26 within a 32-pixel outer area. Icons should obscure less of the image and appear consistently sized; the favorite icon should also be smaller.

## Agreed target dimensions and acceptance criteria

- Profile images, website logos, error/loading placeholders, and square status badges on thumbnails share an outer size of 20 × 20 logical pixels. Image content must not be distorted.
- Symbols inside status badges generally use 16 logical pixels. The GIF label may be slightly larger if necessary, but must remain readable within the same outer area.
- Video duration with a sound icon and the AI label have the same height of 20; their width follows the readable content. Do not force text into a fixed square width.
- The Quick Favorite heart has an explicit size of 20 and a smaller visible background with suitable padding. Its touch target remains sufficiently large; animation, loading state, and favorite functionality remain usable.
- Apply the sizing rule consistently to the relevant thumbnail overlays, including mixed bookmark grids and other consumers of this presentation. Website logos and icons outside thumbnails retain their existing dimensions.
- Manage these dimensions through a shared rule limited to thumbnail overlays. Do not change global website-logo constants to solve a thumbnail use case.
- Visually check custom profile images, bundled logos, network logos, error/loading states, GIF, video with/without duration, comments, translation, image series, AI, and favorite states. Small tiles and longer duration labels must not cause overflow or unreadable content.

## Feasibility and review

The user approved these target dimensions subject to a clean implementation. Before making changes, inspect the existing constraints and LikeButton behavior. If a target dimension impairs readability, layout, or usability, show and justify the specific deviation during review; do not silently change global sizes. Before/after views serve as visual acceptance evidence.

## Context

[Post architecture](../../post_architecture.md). Relevant entry points: `lib/core/config_widgets/website_logo.dart`, `lib/core/widgets/website_logo.dart`, `lib/core/bookmarks/src/widgets/bookmark_scroll_view.dart`, `lib/core/posts/post/src/widgets/image_overlay_icon.dart`, `lib/core/posts/post/src/widgets/image_grid_item.dart`, `lib/core/videos/player/src/widgets/video_play_duration_icon.dart`, and `lib/core/posts/favorites/src/widgets/quick_favorite_button.dart`.

Follow the [development workflow](../../development_workflow.md) and [engineering guidelines](../../engineering_guidelines.md) before implementation. Implementation requires its own branch/worktree and an implementer under the queue rules; the claim and completion evidence are recorded below.

## Decision

2026-10-05: Confirmed by the user after individual discussion, subject to a clean implementation. Work item created; implementation had not been requested or performed at that time.

## Implementation claim

2026-10-07: Implementation requested by the user. Implementer: Codex, current session.
Branch: `agent/post-010-overlay-sizes`.
Worktree: `/home/timber/code/Boorusama/.worktrees/post-010-overlay-sizes`.
Ticket translated into English before implementation.

## Implementation and verification

2026-10-07: Implemented and verified locally in the claimed task worktree.

- Added a shared thumbnail-only sizing rule and fitted outer box. All leading thumbnail icons, including mixed-bookmark profile/source logos and their loading/error states, render within 20 × 20 logical pixels. Bundled and network logo content can use `BoxFit.contain`; global logo sizes and default fit remain unchanged.
- Square status badges use a 20-pixel outer area and 16-pixel symbols. The GIF symbol uses 20 pixels for a readable label. Duration and AI badges retain content-based widths at height 20. Duration text fits the available space while its sound symbol remains 16 pixels, including at enlarged text sizes.
- Quick Favorite uses a 20-pixel heart, a 24-pixel circular background (2-pixel visual padding), and a 48 × 48 transparent touch target. LikeButton retains ownership of taps, animation, and async completion. Pending and interrupted actions preserve the existing favorite state until a successful completion.
- No deviation from the agreed target dimensions was necessary. The fixed-height informational labels scale their text down as needed; the normal duration label remains 14 pixels and the AI label uses 12 pixels.

Checks performed:

- `fvm dart format` on all changed Dart files.
- `fvm flutter test --no-pub --dart-define=POST_010_CAPTURE_PATH=build/post-010-review/after.png test/core/posts/listing/thumbnail_overlays_test.dart test/core/config_widgets/website_logo_test.dart test/core/posts/listing/post_grid_item_test.dart test/core/posts/favorites/danbooru_favorite_interruption_test.dart`: 31 tests passed.
- Targeted cases cover 80- and 120-pixel tiles at normal and doubled text sizes; GIF, unknown video duration, sound/silent video, a 100-hour duration, comments, translation, image series, AI, bundled Danbooru/Hydrus logos, a non-square custom image, network loading/failure, retained global logo dimensions, taps in transparent favorite padding, successful add/remove, pending completion, interrupted removal, and independent post taps. Shared-card regression coverage includes search, favorites, bookmarks, and feeds.
- Static analysis of the nine changed production files and the new test file: no issues.
- `git diff --check`: passed.
- Missing generated outputs in this fresh worktree required `fvm dart pub get` in `packages/boorusama_cli` and `./gen.sh`; no generator inputs changed. Flutter emitted the existing native-hook warning documented in [build troubleshooting](../../build_troubleshooting.md); the test command exited successfully.

Visual evidence (local, ignored build artifacts retained for review):

- Before: `build/post-010-review/before.png`.
- After: `build/post-010-review/after.png`.
- Both sheets use the same widget fixtures, synthetic image data, real fonts, and thumbnail sizes. The baseline uses the original grid/status/duration/favorite widgets from `d1eb12c33`; shared logo fit configuration is the same for a sizing comparison. Baseline overflow diagnostics were intentionally retained in its 80-pixel/doubled-text example. All implementation files were restored after baseline capture.
- Both sheets were inspected. The updated sheet shows smaller, consistent badges, a readable GIF label and duration, undistorted portrait image content, loading/fallback states, and filled/unfilled hearts. The narrow enlarged-text example has no overflow.

Limitations: these are rendered widget fixtures, not emulator screenshots or live-site validation. No emulator or backend was used. Keyboard checks do not apply to the thumbnail grid interaction. The user authorized a commit on the task branch. Work remains local; integration and publication were not requested.

## Favorite corner-spacing follow-up

2026-10-07: The user reported excessive bottom/right spacing after the initial commit. A geometry regression reproduced a 16-pixel visible background inset: the 24-pixel background was centered inside the 48-pixel touch target, adding 12 pixels to the grid's intended 4-pixel corner margin.

Aligned the background to the bottom-right of the touch target and moved the extra transparent LikeButton padding to its top and left. The visible background now retains exactly 4 pixels from both thumbnail edges, and the 20-pixel heart stays centered in its 24-pixel background. The full 48 × 48 touch target remains active.

The regression checks both visible margins and heart/background alignment alongside taps in transparent padding, async add/remove, and independent post taps. The existing narrow-width/enlarged-text, image-state, and favorite-interruption checks were rerun. The updated `build/post-010-review/after.png` includes this alignment correction.

Follow-up verification: the new margin assertion failed before the correction (expected 4, actual 16). After the correction, `thumbnail_overlays_test.dart` and `danbooru_favorite_interruption_test.dart` passed all 18 tests. Analysis of the changed widget/test found no issues, Dart formatting and `git diff --check` passed, and the refreshed review sheet was inspected. No additional device/live validation was performed.

## Local integration

2026-10-07: The user authorized integration into local `develop`. The two verified task commits are combined into one squash commit. The staged task patch was checked for exact equivalence before this integration note; the combined application, test, and dependency tree matches the tested task tree. Unrelated queue updates on `develop` are preserved. No additional test run was needed for this documentation-only difference.

Visual review images were preserved with matching SHA-256 checksums outside the completed task worktree before its cleanup:

- `/home/timber/code/Boorusama/.worktrees/.artifacts/post-010-review/before.png`
- `/home/timber/code/Boorusama/.worktrees/.artifacts/post-010-review/after.png`

Task branch/worktree cleanup follows verified integration; remote publication was not requested.
