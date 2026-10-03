# Add independent nested folders for bookmarks, pins, and feeds

Priority: Normal
Affected feature: Bookmark groups, Pinned Searches, Following Feeds, backup/import

## Problem

Flat organization does not scale as users collect groups, Pinned Searches, and Following Feeds. These features need arbitrary-depth navigation without mixing their distinct membership, `NEW`, and deletion semantics.

## Expected behavior

Bookmarks, independent Pinned Searches, and Following Feeds each have their own folder tree with shared navigation controls. Users can create, rename, order, and move folders/items at any depth. Child folders precede items; breadcrumbs collapse older segments behind overflow. Folder cards show recursive counts, applicable aggregate `NEW`, and up to four deterministic descendant previews, all from local data.

## Decisions and edge cases

- One reusable tree contract/UI serves three separate roots, not one mixed hierarchy. Each folder has one nullable parent UUID in its own tree; null means root. Persist UUID, parent UUID, sibling order, and item placement. No self-parenting, cycles, multiple parents, or cross-feature moves. Sibling names are case-insensitively unique; duplicates elsewhere are allowed. No user-visible depth limit.
- A bookmark may belong to several leaf folders; `Ungrouped` shows bookmarks with no memberships. Each independent Pinned Search and feed has exactly one parent/root. Feed-internal searches stay out of the Pinned Search tree.
- Folder deletion is destructive and recursive. Before confirmation, show counts for folders, affected bookmarks, bookmarks to be deleted entirely, and applicable pin/feed items. Recompute if the persisted subtree changes before commit. Never promote descendants.
- Delete as if removing content deepest-to-top: remove bookmark memberships inside the subtree, delete a bookmark record only if no membership survives outside it, delete independent pins/feeds placed there, then remove folders bottom-up. Commit atomically from the UI perspective; cancellation or persistence failure leaves everything intact.
- Traverse and validate arbitrary depth iteratively with visited-node tracking. Import rejects missing, cross-feature, self, and cyclic parents before writes. Existing bookmark groups and Pinned Search folders enter as root-level folders with IDs, membership, and order preserved; feeds start at root. New backup/export stores parent and order; legacy flat imports land at root.

## Acceptance criteria

- All three roots support arbitrary-depth creation, navigation, ordering, moves, compact breadcrumbs, and cycle prevention. Restart and import preserve identity, placement, and order.
- Recursive counts, previews, and `NEW` require no network; previews follow depth-first manual order and deduplicate bookmarks shared across descendants.
- A changed deletion preview cannot silently commit. Confirmation removes the entire subtree and affected items without promotion; cancellation and persistence failure preserve it.
- A bookmark shared outside the deleted subtree survives there; one whose last membership is in the subtree is deleted. Pinned Searches and feeds retain single-parent semantics after moves, import, and profile deletion.
- Malformed import graphs fail preflight before mutation. Existing flat groups/folders migrate to root preserving identity and order; backup round-trips parent/order; old flat imports land at root.
- Renaming/moving a Favorites target preserves its IDEA-010 group reference. Editing a Pinned Search preserves folder placement.

## Context and dependencies

Bookmark membership uses IDEA-004 post identity. Completed IDEA-026 editing behavior must retain placement. IDEA-010 targets stay ordinary bookmark groups. Feed backup semantics stay separate from Pinned Search backup semantics, including in the ongoing export rewrite.

- [Bookmark architecture](../../bookmark_groups.md)
- [Pinned Search and Following Feed architecture](../../pinned_searches.md)
