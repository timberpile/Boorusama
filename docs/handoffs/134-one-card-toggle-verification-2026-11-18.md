# #134 One-card Related grouping and temporary toggle verification

Branch: `feature/134-related-timeline-groups`. Refs #134; Android acceptance remains
with the owner. Checked source: the follow-up commit containing this report, based
on `408a8f5ac` (the original feature replayed over documentation-only develop updates).

This implements the [approved revised handoff](134-related-one-card-group-posts-toggle-2026-11-18.md).
The [initial verification report](134-related-timeline-verification.md) is historical
evidence for the superseded two-member/five-result Related behavior and is unchanged.

## Implementation

- The Related pass uses a temporary source/account-scoped family map seeded from
  frozen entries. One verified member creates a card; later members extend its
  raw-index mapping without adding tiles, regardless of distance or appended page.
- Series retains its existing algorithm and priority for unfrozen entries. Frozen
  ordinary, Related, and Series entries cannot be stolen by delayed metadata.
- Related counts use only existing access-valid authoritative metadata. Unknown
  counts pass neither a total nor a displayed count, producing an icon-only badge.
- Group Posts is one localized Kurumi switch in existing View Options. A small
  controller-owned presentation preference defaults ON per query/config/controller,
  controls both group types, and is never serialized. Raw Posts remain unchanged.
  Selection and explicit family searches stay raw; viewer/Back retains the choice.
- Toggle changes discard frozen presentation entries and preserve a visible raw
  member using existing scroll tags, accounting for pinned headers. Deferred anchor
  restoration checks that the source list, session, and toggle choice are current.

## Short automated verification

`fvm flutter test --no-pub --concurrency=6 --reporter expanded` passed **72 tests**
across these complete targeted files:

- `test/core/posts/listing/neighboring_timeline_groups_test.dart`
- `test/core/posts/listing/neighboring_series_test.dart`
- `test/core/posts/listing/related_timeline_grid_test.dart`
- `test/core/posts/listing/related_timeline_grouping_toggle_test.dart`
- `test/core/posts/listing/search_series_index_test.dart`
- `test/core/posts/listing/post_grid_prefetch_test.dart`
- `test/core/posts/listing/post_grid_prefetch_wiring_test.dart`
- `test/core/bookmarks/related_family_test.dart`
- `test/application/view_options_insets_test.dart`

With the same flags, `test/boorus/danbooru_artist_page_test.dart --plain-name Series`
passed **two additional tests** for Newest/Popular grouping and obsolete metadata.

Coverage includes singleton parents/children, distant and appended siblings/parents,
direct nested families, frozen/delayed Series priority, source/account isolation,
every raw index represented exactly once, real card routes, cached/icon-only counts,
no count requests, both toggle directions without fetches/settings writes, query
reset, raw selection, viewer/Back, and 320px/200% text mid-scroll anchoring. Duplicate-only
pages stop after three automatic continuations; manual Load More starts another
bounded cycle. Existing cancellation/error/refresh and View Options layout checks pass.

`./gen.sh i18n` passed translation validation and generation. All 23 locale diffs
contain only the Group Posts label; the i18n package has no test directory.
All changed Dart files were formatted. Focused `fvm dart analyze` on the eleven
changed/new Dart files plus `packages/i18n` reported **zero errors, zero warnings,
and eight informational findings**, all on unchanged lines. `git diff --check` and
changed-document relative-link checks passed.

Durable logs: `.worktrees/_artifacts/134-one-card-toggle-20261118/` in the primary workspace.
Initial test fixture import/theme issues were corrected before the final pass.

## Limits

No emulator, device, live API, APK build, exhaustive repository suite, or develop
integration was performed. Final Android acceptance belongs to the owner. This
branch is pushed for review only; the issue stays open, and #176 remains separate.
