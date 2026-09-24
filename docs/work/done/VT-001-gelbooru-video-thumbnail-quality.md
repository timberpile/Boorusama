# Improve Gelbooru video thumbnail quality

Priority: Normal

Affected feature: Gelbooru and Gelbooru v2 post grids / `fix/gelbooru-video-thumbnail-quality`

Agent/session: Codex `/root`, 2026-09-24

## Problem

Gelbooru-family video posts use the small thumbnail at every image-quality
setting even when the site exposes a larger static JPG poster. The result is
noticeably blurrier than image thumbnails.

## Expected behavior

- Low quality displays only the small thumbnail.
- Automatic and higher qualities display the small thumbnail immediately and
  replace it with a larger static poster when that poster loads.
- A failed poster request leaves the small thumbnail visible without logging a
  warning or displaying an error.
- Thumbnail resolution never downloads the actual video.
- The behavior is scoped to Gelbooru and Gelbooru v2, including compatible
  configured sites such as Rule34.xxx.
- Realbooru retains its thumbnail-only data semantics while allowing a
  best-effort static poster for list entries identified as videos.

## Acceptance criteria

- [x] Static API sample images are preferred over derived poster URLs.
- [x] Missing static samples derive `.jpg` from `.mp4` or `.webm` paths while
  preserving URL query and fragment data.
- [x] Low quality selects the small thumbnail.
- [x] Automatic, High, Highest, and Original select the static poster for
  Gelbooru video posts.
- [x] Failed poster loads keep the small thumbnail visible.
- [x] Non-video posts and non-Gelbooru engines retain their existing behavior.
- [x] Realbooru video search results can opt into the poster without treating
  the scraped list item as a complete media post.

## Completion evidence

- Focused resolver, quality-selection, fallback, and Realbooru tests: 20 passed.
- `fvm flutter analyze`: no issues found.
- `fvm flutter test`: 1,286 tests passed.
- Android dev APK built and installed on `emulator-5554` without clearing app
  data. Maestro verified a live Gelbooru `video` result grid at Automatic
  quality with static posters and intact video indicators.
- `git diff --check`: passed.

## Relevant context

- Design: `docs/superpowers/specs/2026-09-24-gelbooru-video-thumbnail-quality-design.md`
- Implementation plan: `docs/superpowers/plans/2026-09-24-gelbooru-video-thumbnail-quality.md`

## Dependencies

None.
