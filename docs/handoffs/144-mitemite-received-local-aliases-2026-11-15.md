# #144 — Receiver-local aliases for MiteMite Groups and Following folders

> Naming normalization (2026-11-17): Historical paths and symbol references below use current MiteMite names. Recorded commit IDs and verification results are unchanged; consult the original commits for exact historical commands and artifact locations. These reference edits do not requalify earlier evidence.

**Owner-approved follow-up — 2026-11-15; implemented and verified 2026-11-16 on `d8ee9a269e50183d52c3052a48b84e4d3b82e35a`.** Continue existing `feature/144-folder-based-collection-sync`; follow `AGENTS.md`, the canonical [v5 design](../designs/2026-11-03-folder-based-collection-sync.md), and the [primary #144 handoff](144-interrupted-web-remediation-2026-11-14.md). Do **not** merge/PR/close #144 without owner approval.

Implementation uses private `mitemite.v1.collection_aliases` preferences, independent of canonical mirror records and signed data. The service validates current trusted source ownership under the mutation coordinator. Cleanup follows recovered committed ownership; a failed preference cleanup is retried by the next update without repeating a completed unsubscribe. See the [current primary handoff](144-interrupted-web-remediation-2026-11-14.md) for exact candidate results and limitations. Earlier source reconnaissance below records the pre-implementation state.

## Product behavior

Restore **receiver-local display aliases** for:
1. **Received Bookmark Groups**, both subscribed roots and nested received Groups.
2. **Received Following folders**, including the same folder's Feed header where applicable. Following **Topics** are deliberately outside this requested scope; do not add Topic aliases by inference.

These are **aliases, not source renames**. The publisher continues to own and synchronize the canonical names, hierarchy, membership/queries, order and Feed definitions; the receiver must still block direct edits to those. Locally writable Groups/folders retain their existing normal Rename/Edit actions and are not modified by this task.

- A receiver may **Set Alias / Edit Alias** on a received Group or Following folder. An empty/cleared alias restores the latest original publisher name; offer an obvious **Remove Alias** option when set.
- The alias is stored **only on this receiving installation**, not in signed catalogs, shared-folder payloads, outgoing publications, source-owned Group/TopicFolder records or definition digests. Other devices and the publisher never see it.
- Key the alias to a stable **canonical source identity** (publisher ID + collection kind + source UUID, or an equally stable mapping), not to a display name, hierarchy path, list index or a virtual subscription entry. A Group reachable through both a direct and inherited subscription is **one** item and displays one alias throughout.
- A publisher rename/reparent/reorder, a normal receive revision, offline interval, restart and overlap of subscriptions must **not erase or overwrite the local alias**. The latest verified source name still updates underneath; clearing the alias immediately reveals it. Aliases alone never count as received definition changes/new Posts, never affect NEW/Unseen/read or alter an outgoing semantic hash.
- Aliases must not bypass received read-only checks. In particular, do **not** implement an alias by calling `renameGroup`, `renameSharedFolder` or editing the mirrored `BookmarkGroup.name` / `TopicFolder.name`; those values are checked against signed source definitions.
- Keep local aliases while an existing subscription/mirror remains covered, including source temporarily unavailable. Clean up associated local aliases when a Group/Folder is **actually** removed by a confirmed uncovered Unsubscribe/verified withdrawal or the publisher is explicitly Forgotten, without deleting anything while the source is merely offline.
- Present the alias consistently in Group/Folder cards, opened-page titles, paths/breadcrumbs and the owning Following Feed header. Surface the original source name in the alias editor for clarity, not as a permanent extra badge/row. Keep signed/offered names authoritative in MiteMite subscription discovery; never leak untrusted labels before trust.
- In the received item overflow / opened item management menu, expose **Set Alias / Edit Alias** and, when set, **Remove Alias** alongside existing Create Local Copy and permissible Unsubscribe. Do **not** re-enable ordinary source Rename/Edit/Move/Delete/Publish. Keep menus concise, keyboard/a11y labels localized, and Kurumi layout consistent.
- Do not expand aliases to other types (Following Topics, device aliases already supported, local-only collections, other sync services). Do not change Create Local Copy naming semantics in this scoped task unless needed for a demonstrated bug.

## Source reconnaissance (verified on feature HEAD `4ef0cdd4ba22d9f95a4c14b67f8d6e508dbb180d` before this handoff)

- `lib/core/bookmarks/src/pages/bookmark_group_browser_page.dart` currently displays `group.displayName(context)` and gates received Group rename behind `!state.mirrors.isReceived(...)`; `_syncActions` currently exposes Copy / explicit-root Unsubscribe. Existing `BookmarkMirrorState.aliases` (`lib/core/bookmarks/src/types/bookmark_mirror_state.dart`) is **publisher/device aliases only**, not Group aliases.
- `lib/core/search/following_topics/src/pages/following_topics_page.dart` displays `folder.name`, suppresses editable folder actions for received folders and renders a separate folder-card/menu path. `lib/core/backups/mitemite/following_actions.dart` exposes received actions; `lib/core/search/following_topics/src/types/following_mirror_state.dart` has owner/source identity but **no per-folder alias map**.
- `lib/core/backups/mitemite/bookmark_mirror_engine.dart` and `following_mirror_engine.dart` apply signed source names to mirrored definitions and perform authoritative integrity checks. Use a receiver-local presentation/preferences API with durable storage and narrow edit authority, not a general-purpose mirror write grant. Avoid changing shared protocol/schema; if any **local** metadata format must evolve, use backwards-compatible reads/migration and keep active subscriptions/trust intact.

## Verification and handoff

1. Unit/persistence tests: alias set/edit/remove; empty/whitespace normalization; source identity binding; restart; verified remote rename/reparent; a failed/offline scan; no accidental payload, definition digest, subscription, read/NEW or signed metadata mutation.
2. Overlap test: direct child + inherited/root subscription shows **one alias** on both routes; another publisher's same-named Group/Folder is independent. Cleanup occurs only when coverage is truly gone. Forget removes that publisher's local aliases but not local copies.
3. UI/widget tests: Bookmark nested/root card and opened title; Following folder card, opened folder and owning Feed header; source name visible in dialog; received menu has alias actions but no writable source rename/edit; local collections still have their original actions. Validate aliases at 320dp and enlarged text.
4. Run focused + repository-appropriate validation, commit/push scope with `Refs #144`, and update primary handoff with **actual** final SHA/tests/limitations. The separate owner-approved [notification copy task](144-mitemite-notifications-ui-brand-2026-11-15.md#owner-approved-follow-up-task--mitemite-notification-copy-implemented-2026-11-16) is independent; preserve it.

**Important:** The source-owning read-only model is still the security boundary. This task restores only a *local presentation preference*. No general mirrored collection editing or bidirectional synchronization is authorized.
