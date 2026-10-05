# Realbooru original images

Priority: Normal

Affected feature: Realbooru post parsing and mixed post viewer

Work branch: `fix/realbooru-original-images`

Agent: `/root/implement_11`

## Problem

Realbooru search HTML exposes only a JPEG thumbnail. The current listing parser
changes that thumbnail path into an `/images/` path and keeps the thumbnail's
`.jpg` suffix. Original uploads can instead be `.jpeg`, `.png`, or `.gif`, so
the resulting original URL does not exist. The mixed viewer then receives the
fabricated URL from the search result and cannot load the full-resolution
media.

A public post observed during investigation used a `.jpg` thumbnail while its
post page exposed a `.jpeg` original. Header-only requests confirmed that the
fabricated `.jpg` original returns 404 and the post-page `.jpeg` URL returns an
image when sent with the site's required Referer. The fixture must contain only
sanitized, minimal markup and no account data.

## Expected behavior

Opening a Realbooru search result resolves the media URL from that post's HTML
before the viewer attempts to display the original. Absolute, protocol-relative,
root-relative, and path-relative media URLs are resolved against the configured
site. Empty or malformed media attributes are treated as unavailable rather
than producing a fabricated URL.

## Acceptance criteria

- A sanitized Realbooru listing/post-page fixture reproduces the mismatched
  thumbnail and original extensions.
- The listing parser does not claim that the thumbnail-derived `.jpg` path is
  the original upload.
- Opening an unresolved Realbooru result fetches that one post and replaces it
  in place without reordering the viewer.
- The post-page parser returns a valid absolute original URL for supported
  absolute and relative HTML attributes.
- Missing or malformed media markup returns no post rather than throwing.
- Focused regression tests, the full test suite, analyzer parity, and an
  exact-device Android check are recorded before this task moves to `done/`.

## Dependencies and constraints

- Preserve the shared mixed-viewer architecture and per-post origin/profile
  resolution.
- Do not fetch every search result to discover its extension; resolve only the
  post opened by the user.
- Realbooru media requires the existing profile-specific Referer header.
- No credentials or unsanitized adult-page content may enter fixtures, logs, or
  reports.

## Progress

- Claimed on 2026-10-02.
- Reproduced the extension mismatch using public markup and header-only media
  requests.
- Root cause traced from `parseRbPostsHtml` into the mixed viewer: search HTML
  has no original extension, while the legacy thumbnail-only details fetch is
  bypassed by the shared mixed-viewer route.
- Added sanitized listing and detail-page fixtures covering the observed `.jpg`
  thumbnail and `.jpeg` original mismatch.
- Changed listing parsing to retain the thumbnail as provisional media and
  detail parsing to safely resolve HTTP(S) absolute, protocol-relative,
  root-relative, and path-relative media attributes.
- Added a Gelbooru V2 presentation wrapper that resolves only an opened
  thumbnail-only listing post, replaces it in place, skips already-resolved
  posts, retains the listing thumbnail when detail data omits it, and retains
  the provisional post after a failed fetch.

## Verification evidence

- Focused parser, viewer, video-poster, and presentation contract suites passed
  on 2026-10-02: 33 tests.
- The isolated full `fvm flutter test` suite passed on 2026-10-02: 1,495
  tests.
- `fvm flutter analyze` completed with the existing 227 informational findings
  and no findings in changed files.
- `git diff --check 46558a4d0..54d41391b` completed without findings.
- A fresh Android x64 Dev APK was built from application commit
  `54d41391b1c63b5cfc3448660124bc3efc3a129e`, installed successfully on
  `emulator-5564`, and recorded with SHA-256
  `0e559f587a09979fd44c18e9fbe4c76dbbb4a98384fe729fa7404a57629f0e4d`.
- The exact-device Maestro check reached Realbooru anonymously, returned one
  result for public post `1009954`, opened it without an image error, and
  displayed `File format jpeg` in the expanded file details. This confirms the
  viewer used the post detail data instead of the listing-derived `.jpg`
  assumption. The focused production-path tests separately cover failed detail
  lookup and thumbnail fallback.
- Validation made no remote or account mutations. The original Danbooru
  profile was restored as active and the app was force-stopped. No device
  system settings were changed. A temporary anonymous local Realbooru profile
  may remain because its cleanup action was not safely reachable within the
  bounded live-site attempt.
- Independent review approved the implementation without findings before the
  final gate.
