# Local Media Backup and Restore — #181

Status: **Design draft for owner review; not implemented.**
Issue: https://github.com/timberpile/Boorusama/issues/181
Depends on: #180.

## Goal

Make the single app-private Local Media library portable and recoverable without forcing media bytes into existing settings/bookmark backups or automatic backup rotation.

## Existing code boundary

- `lib/core/backups/zip/bulk_backup_service.dart` currently assembles ordinary backup sources in a temporary directory, then ZIPs those staged files; it is not an appropriate as-is path for a multi-gigabyte media tree.
- `lib/core/backups/sources/sqlite_source.dart` handles ordinary SQLite backup sources; use SQLite's supported consistent backup/snapshot mechanism rather than blindly copying a live database with possible WAL state.
- `lib/core/backups/export_import/export_import_page.dart` and related settings provide existing export/import navigation. Reuse the relevant picker and feedback primitives, not necessarily the legacy archive implementation.

## UI contract

Add **Backup** and **Restore** in the Local Media area of Data & Storage (placement may reuse an existing settings entry). Archive destination/input uses the system file picker or save/share sheet; only the **live library directory** is restricted to app-private storage.

On Restore present **Merge** (default) and **Replace** with concise explanations and an explicit confirmation before Replace. Show summary of new/existing entries and progress when determinable, plus a completion/partial-failure report. Do not enable automatic Local Media backups in V1.

## Archive contract

- Versioned ZIP (proposed filename `boorusama_local_media_<date>.zip`) with a manifest identifying **local-media-library**, format version, hash algorithm, database schema, and media inventory. This archive is distinct from ordinary `.bsexport` / settings ZIP and from single-file media packages (#182).
- Include a **consistent SQLite snapshot** plus the exact stored media bytes; store each item at its safe canonical hash path. Use ZIP64 for archives/files exceeding classic ZIP limits.
- Prefer ZIP `STORE` (compression level 0) for compressed media; metadata/manifest can use a light compression level when supported. Keep the export **streaming** and bounded in memory; do not copy the entire library into an additional temporary directory.
- The current dependency choice (including `archive` package streaming, ZIP64 and STORE behavior) must be verified with real large-file tests before implementation; upgrading dependencies requires scope-appropriate checks.
- Never rehash the whole existing library on **backup export**: use recorded SHA-256/MD5 plus file metadata; flag unreadable or missing media instead of silently claiming a complete backup.

## Restore semantics

**Preflight:** inspect format/version, archive item count, names, paths, declared sizes and a consistent snapshot; reject traversal, duplicate ZIP entries, symlinks, unsafe absolute paths, decompression bombs, malformed metadata and incompatible DB versions. Cap resource use, surface insufficient free storage where feasible.

**Merge (default):**
- Read the snapshot's SHA-256 identities and compare with the active library's DB; do **not** rehash all existing files.
- For new hashes, stream-extract and calculate SHA-256 (and MD5 when required) **during extraction** to verify content. Publish atomically and insert the matching metadata.
- Existing valid SHA-256 entries are not copied, overwritten or deleted. Local tags/ratings/edits win; fill only unambiguously absent metadata, never silently resurrect explicitly removed tags. A DB reference whose backing file is missing may be repaired from the verified backup.
- If a hash filename collides with different bytes, reject as conflict; do not silently overwrite.
- Preserve metadata and file consistency after interruption, including crash recovery for staged changes.

**Replace:**
- Require explicit, destructive confirmation. Stage and validate a complete candidate library without touching the active one; stream-hash incoming new files once during extraction.
- Quiesce active DB readers/writers, safely publish the replacement and retain the existing library until success/recovery is guaranteed. Do not assume cross-volume renames are atomic; account for storage overhead and cancellation.
- On any failed preflight/extraction/commit, the current library must remain usable.

**Cross-backup compatibility:** Regular settings/bookmark backups continue without media payloads. Stable SHA-based bookmark references survive temporary absence of local media and resolve when the Local Media archive is restored. Do not silently drop missing references.

## Verification

- Merge no-op and partial overlap, local metadata precedence, missing-file repair, multiple imports of the same archive, invalid/checksum-mismatch archive, unsupported schema, interrupted merge/replace, insufficient space and process restart.
- Confirm WAL-consistent SQLite snapshots, ZIP64/large-file streaming, compressed/uncompressed entry handling, no export-side full rehash, no existing-library scan during merge, and readable output in standard ZIP tools.
- Ensure normal app backups remain small and excluded from Local Media bytes; run targeted tests and the complete integration gate before merging.

## Not in scope

Cloud synchronization, scheduled automatic Local Media backups, arbitrary live library folder selection, per-file version history, and preserving unsupported future database versions by guesswork.
