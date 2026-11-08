# Decision 5 — Bookmark/Snapshot Migration and Unknown Future Records

**Status:** Research recommendation. No migration implemented. Current data safety is the primary constraint.

## What already exists on develop

- **Bookmark backup format v9** retains local Post snapshots and `addedAt` per local group. The parser recognizes **v4–v9**, validates groups, IDs and dates, and rejects unsupported versions before applying an import.
- **CollectionBookmark** is presently a Pool/Related-only record: `kind: 'pool' | 'related'`, with typed ID/anchor and local memberships. Its parser rejects unknown kinds.
- The Post snapshot decoder has a useful *partial* forward-compatibility mechanism: `UnknownPostData` preserves custom engine payload when the engine-specific codec is unavailable/newer/incompatible. However, an unsupported **common** schema version or corrupted common fields still fails safely.
- Local Bookmark Groups and CollectionBookmarks both maintain per-membership UTC `addedAt` values, with legacy date fallback from the saved Bookmark's existing `createdAt`. Current export/import/Undo and duplicate-group flows depend on those dates.
- [Independent profile import (#142)](https://github.com/timberpile/Boorusama/issues/142), [anonymous read-only display (#143)](https://github.com/timberpile/Boorusama/issues/143) and [verified host alias identities (#43)](https://github.com/timberpile/Boorusama/issues/43) are still separate tracked tasks.

## The problem in an example

A future export contains:
- Old Danbooru Post 100 saved in group `Art` on Monday.
- Existing Danbooru Pool 42 saved in group `Manga` on Tuesday.
- New Pixiv Work 120 saved in group `Art` on Wednesday.
- A `Content Group` kind a later version of Boorusama knows, but the current app does not.

A downgrade/older import must **never quietly discard** the Work or unknown Group and then export a reduced, seemingly valid backup. It must also never convert an individually saved Pixiv Page 0 into a Work bookmark without permission.

## Recommended representation for new remote Group references

- A versioned typed **Group reference**, with validated source namespace, resource kind, stable key and source-owned summary metadata. The same stable reference format is used for local bookmarks, the viewer and lightweight `.bslink`.
- Keep **membership data separate**: local group ID and per-membership dates remain local, never become part of source identity or serialized access tokens.
- Never serialize credentials, current account choice or transient viewer occurrence/scroll state into a Group bookmark.
- Keep legacy Pool/Related identity and `localId`/added dates when converting old records. Do not alter retained Post IDs, snapshots or page index conventions.
- Treat mutable title, category, cover URL and tag counts as updateable metadata. They must not alter canonical reference identity or make an offline item impossible to export.

## Should we make a new backup version?

**Recommend v10 when first adding new typed Group records.** Existing v9 archives must stay readable exactly as before. Do not put a `work` or `gallery` kind into a document stamped `v9` if v9 readers cannot understand it.

A new reader may decode v9 records and project `pool/related` into the common group-reference contract *in memory*, while preserving the original stable key. A v10 writer emits validated v10 records once that format is approved. Keep any old v9 exporter only if backward-compatible export semantics can be guaranteed; do not fake compatibility by dropping unsupported groups.

Old apps that reject v10 explicitly are safer than old apps claiming to import it but silently losing unknown groups.

## Two distinct unknown-data cases

| Case | Current behavior | Recommended future policy |
| --- | --- | --- |
| Unknown **engine-specific Post custom data**, known common snapshot schema | `UnknownPostData` retains opaque custom payload | Preserve exact raw data and the existing local membership/identity |
| Unknown **Group kind** inside a supported v10 structural envelope | Currently rejected by Pool/Related parser | Prefer a bounded **opaque unresolved group record** only if it can be safely imported, stored, re-exported and deleted without losing bytes or changing its identity |
| Unknown **structural backup version** (e.g., v11 with unrecognized invariants) | Explicit unsupported-version failure | **Reject the entire import before mutation**; don't guess fields or import part of the file |
| Invalid/mismatched references, dates, scope or duplicate identities | Rejected | Reject or quarantine preflight, without partial destructive updates |

**Important contract:** If an unknown group cannot be retained *end-to-end* (import, persistence, duplicate/merge/Undo, export and rollback), reject the input transparently rather than claiming 'best effort' and losing information.

An opaque record may appear as a compact unavailable/recoverable entry, but it must not be interpreted as a Post, issued as a network request to an unknown host, or selected for source-account actions. Avoid showing unsanitized remote covers. Ensure bounded sizes and serialization tests so opaque records cannot become a hidden deserialization hazard.

## Import/export safety rules

1. Preflight backup version, record kinds, stable source keys, IDs, dated memberships, folder references and source constraints **before destructive writes**.
2. Apply the whole validated import transactionally. Preserve prior data on failure; ensure rollback restores memberships and updated metadata.
3. Match known Posts and Group references by source/engine/kind/key, not mutable title/category, and only apply verified aliases. Two different source installations under the same domain may not share identities.
4. Resolve matching local profiles only for **access**. Missing profiles do not make otherwise valid saved data disappear; use #142/#143 architecture for stored/unavailable records.
5. Do not collapse a saved Pixiv Page into a Work; individual page bookmarks and whole Work bookmarks are intentionally independent.
6. Export exactly what is retained, including opaque unknown payload when its round-trip safety has been validated. Never silently omit records, dates or group memberships.
7. Reject unrecognized active auth in portable archives. Explicitly prohibit private account data in saved reference payloads.
8. Restrict remote URLs and media/covers to safe policies on display, even when the backup record itself can be preserved.
9. New `.bslink` kinds retain the v1 envelope but require strict new URI validators. Older versions may reject those kinds safely, independently of bookmark backup format.

## Test matrix before integration

- Read old v4/v5/v6/v7/v8/v9 backups, including legacy Pool/Related formats and membership date fallbacks.
- Write/read new v10 with independent Posts, Works, Pools, Related Families and Gallery references in the same Bookmark Group.
- Import then export an unknown-but-structurally-valid v10 group kind **byte/semantic round-trip**, or clearly reject it preflight if opaque preservation is not implemented.
- Reject version 11 before any writes and preserve the existing full library.
- Reject malformed source keys, embedded credentials, oversized opaque values, invalid UTC dates, duplicate group IDs and missing memberships.
- Re-import and re-export idempotently; preserve Undo, removal, group duplication, moving between groups and deletion.
- Add/remove existing profiles after import without duplicating or changing content identities; exercise confirmed host aliases when available.
- Downgrade scenario: an older app must not silently remove unknown groups and then overwrite newer backups.

## Proposed decision

Adopt **v10 typed Group references** when the generalized architecture begins writing them, preserving all v9 data. **Fail closed on unknown structural versions.** Within a known v10 envelope, prefer safe opaque Group retention, but only with demonstrated end-to-end round-trip tests; otherwise explicit rejection is better than partial data loss.

**Still discuss:** Is opaque retention of future Group kinds a requirement for the first v10 implementation, or may the initial release safely reject unsupported kinds while preserving the user's original source archive? This is a compatibility/product decision, not only a parser detail.

### Code evidence

- [Bookmark Backup Codec](https://github.com/timberpile/Boorusama/blob/e306ff533/lib/core/backups/sources/bookmark_backup_codec.dart)
- [CollectionBookmark Pool/Related parser](https://github.com/timberpile/Boorusama/blob/e306ff533/lib/core/bookmarks/src/types/pool_bookmark.dart)
- [StoredPostCodec and UnknownPostData fallback](https://github.com/timberpile/Boorusama/blob/e306ff533/lib/core/posts/post/src/data/stored_post_codec.dart)
- [Bookmark Library Service](https://github.com/timberpile/Boorusama/blob/e306ff533/lib/core/bookmarks/src/services/bookmark_library_service.dart)
