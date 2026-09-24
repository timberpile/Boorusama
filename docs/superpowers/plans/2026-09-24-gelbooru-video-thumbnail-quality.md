# Gelbooru Video Thumbnail Quality Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Display high-resolution static posters for Gelbooru-family videos at Automatic and higher quality while keeping the small thumbnail visible during loading and after failure.

**Architecture:** Add an explicit error-fallback URL to grid thumbnail media and the shared image widget. Resolve Gelbooru video posters from a static sample first, then from the video path, and select them through Gelbooru-specific grid mappers. Preserve Realbooru's thumbnail-only data semantics with a separate video-preview marker parsed from its HTML list rows.

**Tech Stack:** Dart, Flutter widgets, Riverpod repository providers, Dio-backed ExtendedImage, Flutter test.

**Spec:** `docs/superpowers/specs/2026-09-24-gelbooru-video-thumbnail-quality-design.md`

## Global Constraints

- Never use a video URL as an image candidate or download video media during thumbnail loading.
- Low quality keeps the existing small thumbnail.
- Automatic, High, Highest, and Original use the best static poster for Gelbooru videos.
- Non-Gelbooru engines, non-video posts, and GIF behavior remain unchanged.
- Do not add warning logs for a failed high-resolution poster.
- Use `fvm` for Flutter and Dart commands and format every changed Dart file.
- Do not commit, push, or create a pull request without separate user authorization.

## Review Focus

- A sample URL whose query contains `.mp4` but whose path ends in `.jpg` must remain a valid static poster; cover in Task 2 URL tests.
- A video URL with query and fragment data must preserve both when deriving `.jpg`; cover in Task 2 URL tests.
- A sample URL that is itself MP4/WebM must never be selected; cover in Task 2 URL tests.
- A failed poster and failed thumbnail must still end at the normal image error placeholder; cover in Task 1 widget tests.
- A Realbooru non-video row must remain thumbnail-only; cover in Task 3 parser and mapper tests.

---

### Task 1: Persistent thumbnail fallback

**Files:**
- Modify: `lib/core/posts/listing/src/types/grid_thumbnail_url_generator.dart`
- Modify: `lib/core/posts/listing/src/widgets/default_image_grid_item.dart`
- Modify: `lib/core/images/booru_image.dart`
- Create: `test/core/images/booru_image_fallback_test.dart`

**Interfaces:**
- Produces: `GridThumbnailMedia.fallbackUrl`, `BooruImage.fallbackUrl`, and `BooruRawImage.fallbackUrl`.
- Consumes: the existing `placeholderUrl` as the first visible network image.

- [x] **Step 1: Write the failing widget tests**

Add tests proving that a failed primary image exposes the configured fallback
network image and that a failed fallback still exposes `ErrorPlaceholder`.
Use an `ExtendedImageController` to drive the primary load state and a
controlled Dio adapter for the fallback response.

- [x] **Step 2: Run the focused test and verify RED**

Run: `fvm flutter test test/core/images/booru_image_fallback_test.dart`

Expected: compilation or assertion failure because the fallback URL contract
does not exist and primary failure currently renders `ErrorPlaceholder`.

- [x] **Step 3: Implement the minimal fallback contract**

Add nullable `fallbackUrl` fields through `GridThumbnailMedia`, `_Image`,
`BooruImage`, and `BooruRawImage`. When the primary image fails, render the
fallback with the same Dio, headers, sizing, fit, border radius, platform, and
cache manager. Its own failure renders the existing `ErrorPlaceholder`.

- [x] **Step 4: Format and verify GREEN**

Run: `fvm dart format lib/core/posts/listing/src/types/grid_thumbnail_url_generator.dart lib/core/posts/listing/src/widgets/default_image_grid_item.dart lib/core/images/booru_image.dart test/core/images/booru_image_fallback_test.dart`

Run: `fvm flutter test test/core/images/booru_image_fallback_test.dart`

Expected: all fallback tests pass with no warnings.

- [x] **Step 5: Record task verification without committing**

Record the focused test command and result in the execution ledger. Leave the
changes uncommitted because Git mutations require separate authorization.

### Task 2: Gelbooru static poster resolution and quality mapping

**Files:**
- Create: `lib/boorus/gelbooru/common/video_thumbnail.dart`
- Create: `lib/boorus/gelbooru/common/grid_thumbnail_url.dart`
- Modify: `lib/boorus/gelbooru/posts/types.dart`
- Modify: `lib/boorus/gelbooru/gelbooru_repository.dart`
- Modify: `lib/boorus/gelbooru_v2/posts/types.dart`
- Modify: `lib/boorus/gelbooru_v2/gelbooru_v2_repository.dart`
- Create: `test/boorus/gelbooru/video_thumbnail_test.dart`
- Create: `test/boorus/gelbooru/grid_thumbnail_url_test.dart`

**Interfaces:**
- Consumes: `GridThumbnailMedia.fallbackUrl` from Task 1.
- Produces: `resolveGelbooruVideoPosterUrl(...)` and `gelbooruGridThumbnailMedia(...)` for both Gelbooru engines.

- [x] **Step 1: Write failing resolver and grid-selection tests**

Cover static sample preference, MP4/WebM-to-JPG derivation, query/fragment
preservation, rejection of video samples and unsupported paths, Low selection,
Automatic-and-higher selection, fallback assignment, and unchanged non-video
and GIF behavior. Expectations use literal URLs.

- [x] **Step 2: Run the focused tests and verify RED**

Run: `fvm flutter test test/boorus/gelbooru/video_thumbnail_test.dart test/boorus/gelbooru/grid_thumbnail_url_test.dart`

Expected: compilation failure because the resolver and Gelbooru mapper do not
exist.

- [x] **Step 3: Implement the resolver and Gelbooru mapper**

Accept static image extensions from a parsed URL path. Otherwise derive `.jpg`
only from final `.mp4` or `.webm` video path extensions. Update both Gelbooru
post types to retain their raw sample for the resolver, and register the shared
mapper from both repositories. The mapper sets the small thumbnail as loading
placeholder and error fallback.

- [x] **Step 4: Format and verify GREEN**

Run: `fvm dart format lib/boorus/gelbooru/common/video_thumbnail.dart lib/boorus/gelbooru/common/grid_thumbnail_url.dart lib/boorus/gelbooru/posts/types.dart lib/boorus/gelbooru/gelbooru_repository.dart lib/boorus/gelbooru_v2/posts/types.dart lib/boorus/gelbooru_v2/gelbooru_v2_repository.dart test/boorus/gelbooru/video_thumbnail_test.dart test/boorus/gelbooru/grid_thumbnail_url_test.dart`

Run: `fvm flutter test test/boorus/gelbooru/video_thumbnail_test.dart test/boorus/gelbooru/grid_thumbnail_url_test.dart`

Expected: all resolver and quality-selection tests pass.

- [x] **Step 5: Record task verification without committing**

Record the focused test command and result in the execution ledger. Leave the
changes uncommitted because Git mutations require separate authorization.

### Task 3: Realbooru video preview marker

**Files:**
- Modify: `packages/booru_clients/lib/src/gelbooru_v2/post_v2_dto.dart`
- Modify: `packages/booru_clients/lib/src/gelbooru_v2/parsers/rb_parsers.dart`
- Modify: `lib/boorus/gelbooru_v2/posts/parser.dart`
- Modify: `lib/boorus/gelbooru_v2/posts/types.dart`
- Create: `lib/boorus/gelbooru_v2/posts/grid_thumbnail_url.dart`
- Modify: `lib/boorus/gelbooru_v2/gelbooru_v2_repository.dart`
- Create: `test/boorus/gelbooru_v2/realbooru_video_thumbnail_test.dart`

**Interfaces:**
- Consumes: the poster resolver, Gelbooru mapper, and fallback contract from Tasks 1 and 2.
- Produces: `PostV2Dto.isVideoPreview` and `GelbooruV2Post.isVideoPreview` without changing `Post.isVideo`.

- [x] **Step 1: Write failing parser and mapper tests**

Parse representative Realbooru HTML rows with and without the exact `video`
tag. Assert that only the video row carries the preview marker and that the
thumbnail-only grid mapper uses its static JPG at Automatic while keeping Low
and non-video rows on the small thumbnail.

- [x] **Step 2: Run the focused test and verify RED**

Run: `fvm flutter test test/boorus/gelbooru_v2/realbooru_video_thumbnail_test.dart`

Expected: compilation or assertion failure because no separate video-preview
marker or Realbooru mapper exists.

- [x] **Step 3: Implement the marker and thumbnail-only mapper**

Detect the exact comma-separated `video` tag in `parseRbPostsHtml`, carry the
optional marker through `PostV2Dto` and the app parser, and add a V2 mapper that
uses the static sample only when `isVideoPreview` is true. Keep the existing
`thumbnailOnly` capability and post-detail transition behavior unchanged.

- [x] **Step 4: Format and verify GREEN**

Run: `fvm dart format packages/booru_clients/lib/src/gelbooru_v2/post_v2_dto.dart packages/booru_clients/lib/src/gelbooru_v2/parsers/rb_parsers.dart lib/boorus/gelbooru_v2/posts/parser.dart lib/boorus/gelbooru_v2/posts/types.dart lib/boorus/gelbooru_v2/gelbooru_v2_repository.dart test/boorus/gelbooru_v2/realbooru_video_thumbnail_test.dart`

Run: `fvm flutter test test/boorus/gelbooru_v2/realbooru_video_thumbnail_test.dart`

Expected: all Realbooru parser and quality-selection tests pass.

- [x] **Step 5: Run cross-feature and full verification**

Run the three focused test files together, then `fvm flutter analyze`, then
`fvm flutter test`. Record all outputs and update the queue task with completion
evidence only if every acceptance criterion is verified.

- [x] **Step 6: Record task verification without committing**

Record the final commands and results in the execution ledger. Leave the full
change uncommitted for user review and delivery authorization.
