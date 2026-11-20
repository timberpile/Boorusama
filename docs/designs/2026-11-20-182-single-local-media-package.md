# Single Local Media Package — #182

Status: **Design draft for owner review; not implemented.**
Issue: https://github.com/timberpile/Boorusama/issues/182
Depends on: #180.

## Goal

Let a user send a **single local media file with its selected metadata** to another Boorusama user, independently of the original site. The receiver can view it immediately and choose whether to keep it.

## Existing behavior / constraints

- `docs/bslink-mvp.md` and `docs/post_architecture.md` define `.bslink` as a strict **remote reference** without media bytes. The media package is a **different format**, parser, MIME type and share action; do not extend the link parser to import ZIPs.
- `lib/core/posts/shares/src/unified_post_share_sheet.dart`, `share_media_preparation.dart` and platform handoff code already prepare single-file share operations with transient file ownership.
- Messenger behavior differs: standalone link attachments were reported working in Signal while WhatsApp's association could fail. Do not claim reliable opening in all messengers without actual tests, or fall back to broad "open every file" intent filters.

## V1 format (proposed)

One versioned, self-contained attachment (candidate extension `.bsmedia`, subject to cross-platform MIME/association test). A constrained archive with:
- A small manifest: format/version, declared SHA-256, MIME/extension, size and portable metadata schema.
- Exactly **one** media payload; only safe package-relative paths and expected formats.
- Allowlisted portable metadata: tags/categories, rating, meaningful source context, optional source MD5 and other source-neutral post fields. Never serialize credentials, local absolute paths, profile IDs, hidden drafts, unrelated originals, or library internals.
- Media stored with ZIP `STORE`, not pointlessly recompressed; restrict archive size, item count and resource use.

Filename SHA-256 identifies exact file bytes, not a user or a semantic image. Importer verifies SHA-256 while staging bytes; metadata is untrusted data and is validated independently.

## User workflow

**Send:** from a local item in the established Share dialog, choose one Boorusama media-file action and hand off one complete attachment. Never rely on mixed text-plus-media delivery. Do not silently upload media to a remote site.

**Receive:** opening the attachment through Open with / Share to Boorusama validates the package, creates a **temporary preview**, and displays it in the existing viewer with a prominent, simple **Import** action. Merely opening is not import. On Import, save to the managed library using #180's atomic copy/dedupe; preserve existing local metadata if already present. Make already-imported state understandable without creating a duplicate. Keep temporary files owned and cleanup-safe on cancellation/restart.

Do not add message surveillance, background automatic import, arbitrary links/downloads, or profile imports.

## Failure boundaries

Reject unsupported versions, forged filenames/MIME, duplicate archive entries, archive traversal, ZIP bombs, corrupt payload bytes/hash, oversize files, invalid metadata and unexpected extra content. No side effects on failed preview/import. Share should retain file ownership long enough for the platform handoff but cannot guarantee messenger delivery.

## Verification

- Single image/GIF/video file round trips with tags and rating; metadata missing/untrusted; same SHA repeated without duplicates; cancel preview; cancellation during staging; corrupt/oversized/malicious archive.
- Distinguish and preserve existing `.bslink` behavior and routing; test real Android share/open flows, including messenger associations where available, without assuming cross-app guarantees.
- Accessibility, narrow layout, localized **Import**, and temporary-file cleanup.

## Out of scope

Multiple media per package (#185), synchronization, automatic import simply because a message arrives, editing attachments during receive, and bulk sharing.
