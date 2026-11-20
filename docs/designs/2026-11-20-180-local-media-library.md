# Local Media Library — #180

Status: **Design draft for owner review; not implemented.**
Issue: https://github.com/timberpile/Boorusama/issues/180
Starting point: `develop` at `5b17615346d2a162ebe287e400e97c60aa666798` (2026-11-20). Recheck current code before implementation.

## Purpose and scope

Local Media is the single managed home for user-created and received images, GIFs, and supported videos. It is an intrinsic, always-available **local source/engine**, not an online booru account. Its main purpose is small, personally curated media, not monitoring a huge existing filesystem gallery.

- Exactly one automatically initialized library per installation, in durable app-private storage. No configurable library folder or additional Local Media profiles in V1.
- No server URL, credentials, login, background filesystem watch, or special sharing identity required.
- Import a selected file, several files, or a selected folder (recursive, bounded, cancellable) as a **one-time copy**. A selected import folder is only an input, not an adopted library or ongoing sync source.
- Expose local posts through the standard grid, viewer and local tagging/search where supported. Reuse compatible bookmark/group actions, preserving the origin of other posts in mixed views. Source selection shows one Local Media entry without creating an ordinary authenticated profile.

## Repository boundaries / verified code facts

- `lib/core/posts/post/src/types/post.dart` defines the common `Post` consumed by shared viewers; `Post.id` is currently numeric, not a content hash.
- `lib/core/posts/post/src/types/post_origin.dart` carries origin/host/profile hints. `lib/core/posts/post/src/types/booru_post_data.dart` defines engine-specific payload and `StableBookmarkPostKeyData`; `booru_post_capability.dart` provides engine-owned codec/presentation.
- `lib/core/content/content_reference.dart` currently requires a validated HTTP(S) source for portable references. Do **not** invent a localhost or fake HTTPS installation for local posts. If content navigation/bookmarks require a stable address, add a narrowly scoped local-reference representation while preserving existing remote link grammars.
- `lib/core/posts/cross_profile_lookup/README.md` documents existing MD5-based remote lookup, which is related but separately scoped under #184.
- Current media URL/cache and profile authorization assumptions are network-oriented. Adapt local-byte resolving explicitly; do not feed fake network URLs into authenticated HTTP clients.

## On-disk identity and metadata

Suggested layout (inside the private library root):

```text
library.db
media/
  ab/
    ab<remaining-62-hex-digits>.png
  7c/
    7c<remaining-62-hex-digits>.mp4
```

- **SHA-256 of the complete original bytes is the canonical, portable file identity**, encoded in lowercase 64-character hex. Directory is the first two hex digits; filename uses the complete hash plus validated actual media extension.
- Compute optional **MD5** during the **same streaming read** for compatible booru lookups and the optional `sourceMd5` provenance field. MD5 is **not** used to deduplicate stored files.
- Store all durable media metadata in a **SQLite database at the library root**; no per-item JSON files or secondary permanent data cache. Use a schema/user version, indexes for SHA-256, MD5, import date, and tag associations; preserve media byte identity separate from local numeric row IDs.
- Minimum metadata: SHA-256, optional MD5, MIME/real format, relative file location, byte size, dimensions/duration where known, import/create timestamps, tags and categories, rating if known, meaningful origin/source data, optional original filename, optional `sourceMd5` and an editor-made marker if useful.
- Local post identity and bookmark transfer must use the **full SHA-256**, not a transient SQLite row ID or a synthesized numeric server ID. The local record may still use an internal integer `Post.id` for compatibility, but it must not become the stable saved identity.
- Derived images are **new files** with new SHA-256. Do not add a generalized parent graph or remote `derivedFrom` object. A simple optional source MD5 is sufficient for V1.

## Import and lifecycle

1. Copy supported image/GIF/video bytes into app-owned staging; discover format from actual bytes (never trust filename extension alone), enforce file-size and decoder limits.
2. Stream SHA-256 and MD5 as bytes are read/copied; do not reread all files just to compute the second hash. Check SQLite for the SHA-256; do not create a duplicate if already imported.
3. Atomically publish validated file bytes in a hash-sharded location and commit indexed metadata. Recover/clean staging after interrupted imports; never claim success for a partial file. Report skipped or unsupported files.
4. Do not rehash the whole library at startup. Missing/corrupt files must yield a recoverable state, not automatic deletion of media records or bookmarks. Provide an explicit repair/recheck route if needed.
5. Importing from outside does not rename/delete source files. Deleting an item from a bookmark group must not imply deleting the underlying local media; distinguish remove-from-group versus delete-from-library.
6. Metadata edits must not change file SHA-256. A byte-level media edit creates a separate local item.

## Boundary and UX rules

- Local media remain available offline. When the user picks source files/folders, ordinary system selection permissions are allowed **for import inputs**; no permission to manage an arbitrary persistent library folder is needed.
- Preserve existing Kurumi patterns, compact labels, localization and accessibility. Label an already contextualized import action **Import**, not "Import to Local Library".
- Existing normal settings/bookmark backups should retain stable local references, but must not silently include media bytes. Missing referenced files after a settings-only restore should remain placeholders until media are restored (#181).
- Supported native platforms may vary in file-picker APIs; avoid promising browser filesystem persistence in the first delivery.

## Verification / acceptance

- Verify deterministic SHA-based filename/layout, 256-shard distribution, exact dedupe, MIME mismatch rejection, duplicate metadata behavior and same-stream MD5 computation.
- Test cancellation/crashes at staging, publish and DB commit boundaries, low storage, permissions, corrupt database, unsupported media, very long imported filenames and restart/rebuild of local listing.
- Exercise local and mixed-origin viewers, tagging/search, bookmarks across app restart, backup reference preservation, thumbnail loading, and missing-file recovery.
- Test narrow width, large text and Android input/import flows; run scoped tests, then the full integration gate according to `AGENTS.md`. Code/device behavior is **not yet tested**.

## Related tasks

#181 complete backup/restore; #182 single media package; #183 image text editor; #184 optional metadata lookup; #185 deferred multi-media packages.

## Proposed defaults to review

Library-only file deletion should be explicit and irreversible only after confirmation; no automatic online hash queries (see #184). The only supported V1 library location is app-managed persistent storage; restoring an existing library is handled by #181 rather than mounting arbitrary directories.
