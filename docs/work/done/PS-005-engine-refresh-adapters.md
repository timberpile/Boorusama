# Extend pinned-search refresh across engines

Priority: Normal
Affected feature: Pinned searches
Work branch: `feature/chronological-pinned-search-support`

## User decisions

Implement shared scanning with engine-specific adapters for every booru whose
existing APIs make timestamp-based new-upload tracking straightforward.
Continue using creation/upload times; metadata edits must not count as new.

Keep Pinned Searches in its current side-menu section and position. Keep both
the navigation entry and search-page pin button visible for unsupported
profiles. Opening the tab or pressing the pin button must explain that the
profile is not supported, without saving a new pin or starting refresh requests.
Do not change profile-scoped storage; displaying pins across profiles is a
possible future presentation change.

The user explicitly asked to record this work and prioritize bounded refreshes
in [PS-001](../done/PS-001-bounded-newest-post-refresh.md) first. That work is
now complete; this adapter task remains queued.

## Acceptance criteria

- [x] Unsupported engines default to an explicit unsupported capability.
- [x] Every readily supported engine opts in with upload-time, chronological
      ordering, stable identity, and a bounded newest-page fetch.
- [x] Supported adapters reuse the shared bounded scanner from PS-001.
- [x] Both unsupported entry points show a localized explanation.
- [x] Side-menu section placement and desktop tab indices remain unchanged.
- [x] Existing pins persist across unsupported-profile visits.
- [x] Tests and documentation distinguish implemented support from unverified
      authenticated endpoints.

## Investigation findings

Most integrations already supply upload timestamps. Gelbooru v1, Hydrus, and
Zerochan currently do not. Sankaku assigns a new synthetic integer on each fetch
for string-ID posts; persisted integer deduplication therefore cannot safely
support those posts without a stable identity design. Thumbnail-only Gelbooru
v2 sites cannot supply upload times.

Danbooru supports `order:created_at`; Szurubooru supports
`sort:creation-time`. Philomena exposes `sf=created_at&sd=desc`, which its
client does not currently pass. E-shuushuu's search notifier does not forward
`limit` as `perPage`. Hybooru returns effective page size and total metadata
that its post repository currently drops.

Rule34 and Safebooru.org XML parsing is already implemented and Safebooru's
existing pin was verified live in the emulator. The site-specific XML work
remains in the working tree; it is not a claim of support for all Gelbooru sites.

## Completion — 2026-09-17

Agent: Codex (/root). Branch: `feature/chronological-pinned-search-support`.
133 pinned-search tests passed and static analysis was clean. Tests verify
canonical upload ordering, rejection of unsafe order overrides, unsupported
tab/pin actions without writes/requests, and preserved existing pins.
Maestro verified the unchanged menu location and live Danbooru refresh.
Rule34 XML is covered by parser/scanner tests; authenticated live validation
remains unavailable. Safebooru was verified live in the preceding XML step.

Opted in Danbooru, e621, Gelbooru, non-thumbnail-only Gelbooru v2, Moebooru,
Philomena, Shimmie2, Szurubooru, AnimePictures, Hybooru, E-shuushuu, and Pixiv.
Philomena raw refresh sets created_at descending; E-shuushuu forwards the limit.
Nozomi is postponed in PS-012 because its complete index intersections violate
the bounded-work requirement. Timestamp-less integrations and unstable Sankaku
identity remain unsupported. Opt-in is not a claim that every authenticated
site was verified live; nullable/unsorted responses still fail explicitly.
