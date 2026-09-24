# Gelbooru video thumbnail quality design

## Goal

Show a high-resolution static poster for Gelbooru-family videos at Automatic
and higher image-quality settings without downloading video media.

## Quality behavior

- Low uses only `thumbnailImageUrl`.
- Automatic, High, Highest, and Original use a static video poster.
- GIF behavior remains unchanged.
- Other booru engines remain unchanged.

## Poster resolution

For a Gelbooru video post:

1. Use the API-provided sample URL when it has a supported static-image
   extension.
2. Otherwise replace a final `.mp4` or `.webm` extension in the video URL with
   `.jpg`, preserving query parameters and fragments.
3. If neither produces a static-image URL, keep the small thumbnail.

Using the explicit sample first preserves site-specific image hosts such as
`img.xbooru.com` and `wimg.rule34.xxx`. Derivation covers Gelbooru.com and
compatible sites that omit a sample but store the poster beside the video.

## Loading and failure behavior

The small thumbnail is both the initial network placeholder and the error
fallback for a high-resolution poster. The poster replaces it only after a
successful decode. If the poster fails after the existing retry policy, the
small thumbnail remains visible. No warning is logged.

Neither the primary candidate nor the fallback may be a video URL.

## Realbooru

Realbooru search is HTML-backed and marked `thumbnailOnly` because list rows do
not reliably provide complete original-media data. That capability remains in
place for refresh and post-detail behavior.

The list parser records separately whether a row's tags identify it as a
video. The grid may then attempt the parser's derived static JPG only for those
video rows at Automatic and higher qualities. This marker does not change the
post's media format or cause the derived JPG to be treated as the playable
video.

## Validation

Unit tests cover static sample selection, URL derivation, quality mapping,
Realbooru video-row detection, and non-video preservation. A widget test covers
the visible thumbnail fallback after a poster load failure. The full Flutter
test suite and analyzer run before completion.
