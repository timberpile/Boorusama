# Replace local profile IDs with UUIDs end-to-end

Priority: Normal
Affected feature: Profiles, settings, cached posts, Pinned Searches, Following Feeds, import/export

## Problem

The locally assigned integer profile ID is used as portable identity. It cannot reliably identify the same profile across independently created installations or future selective imports, especially with multiple profiles for one site. The ID audit is complete; this ticket covers implementation.

## Expected behavior

Creating a profile assigns one canonical lowercase UUID. Editing keeps it; duplicating or independently creating a profile assigns a new UUID, even on the same site. Profile selection, ordering, navigation, pins, feeds, and cached post origin continue to behave normally. New exports preserve identity; unsupported integer-profile archives fail clearly before writes.

## Decisions and edge cases

- Replace `BooruConfig.id` and its Hive key; do not add a second permanent ID. Update current selection/order, profile settings, pin/feed ownership, `PostOrigin.profileIdHint`, routes/deep links, import/export, deletion, cleanup, and rollback.
- Treat current `develop` as having no old installed data or exports to preserve. Do not add a dual-ID bridge, local migration, converter, or legacy integer-profile reader.
- Export/import UUID with engine/site metadata. Equal UUID with incompatible engine/site is a preflight conflict; an unmatched UUID must not silently match a same-site profile. Credentials and display name do not define identity.
- Keep upstream post/user IDs, engine/category constants, and internal row keys numeric. Bookmark identity follows IDEA-004, not profile UUID or a random bookmark UUID.
- Coordinate format and preflight with the ongoing export rewrite.

## Acceptance criteria

- All persisted and in-memory profile references use one UUID with no integer alias. Tests cover create/edit/duplicate, selection/order/deletion, navigation, pins, feeds, and cached post resolution.
- Export/import round-trips UUIDs and dependent records. Repeat import is idempotent; unmatched references require explicit mapping where needed; UUID/site conflicts fail preflight without partial writes.
- Old integer-profile archives fail clearly before mutation. No backwards-compatibility layer is introduced.
- Tests verify unrelated numeric IDs remain numeric and bookmarks still use IDEA-004's site-aware post identity.
- Measure serialized size and load time of a representative full 500-post feed cache before/after; report results and remove redundant repeated hints only if cost warrants it.

## Context and dependencies

The completed audit estimated a small storage increase for repeated UUID hints but did not benchmark runtime cost. This ticket is independent of IDEA-004 and must agree with the in-progress export rewrite. Two independently created same-site profiles are not assumed to be the same account.

