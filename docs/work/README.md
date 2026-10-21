# Legacy work-item archive

**Historical records reconciled on 2026-10-21.** GitHub Issues are the only
tracker for new work. Do not claim, reopen or allocate tasks from these files.
A separately authorized later change will consolidate remaining material and
remove the old `docs/work/` structure.

- [`done/`](done/) holds **125** completed, integrated work items. Unchecked
  historical acceptance notes are not evidence of active work.
- [`archive/`](archive/) holds **seven historical dispositions**: two moved to
  GitHub Issues, two superseded by the unified Topics interface and three
  retained as documentation or accepted decisions. None is an active ticket.
- `ready/` and `in-progress/` intentionally contain only `.gitkeep`.
  `active/` and `blocked/` have no live legacy items.

**UX-002 (Unified post selection and actions)** is [done](done/UX-002-unified-post-selection-and-actions.md)
following integration at `fd7ae8e`. **POST-009 (Portable Boorusama post and
search links)** is [done](done/POST-009-share-links-that-open-posts-in-boorusama.md).
The duplicate GIF-001 and obsolete Rule34/Safebooru handoff were retired in
the preceding reconciliation; their relevant implementation history is in
[guided GIF refinement](done/0033-guided-loop-refinement.md),
[bounded refresh](done/PS-001-bounded-newest-post-refresh.md) and
[engine refresh adapters](done/PS-005-engine-refresh-adapters.md).

## Archive dispositions

| Legacy item | Subject | Outcome |
| --- | --- | --- |
| [ART-001](archive/ART-001-artist-profile-icons.md) | Artist profile images in post details | Moved to [#69](https://github.com/timberpile/Boorusama/issues/69) |
| [PS-020](archive/PS-020-os-background-search-refresh.md) | OS-scheduled Following Topics refresh | Moved to [#70](https://github.com/timberpile/Boorusama/issues/70) |
| [FEED-002](archive/FEED-002-filter-following-feeds.md) | Filter Following Feeds by name and profile | Superseded by unified Following Topics UI |
| [PS-032](archive/PS-032-filter-pinned-searches-and-folders.md) | Filter Pinned Searches and folders | Superseded by unified Following Topics UI |
| [PS-012](archive/PS-012-nozomi-bounded-refresh.md) | Bounded Nozomi automatic refresh | Documented feasibility constraint; no issue |
| [PS-019](archive/PS-019-independent-read-state-for-shared-searches.md) | Independent read state for shared feed sources | Existing shared behavior accepted; no issue |
| [PS-022](archive/PS-022-gelbooru-or-batched-feed-fetching.md) | Gelbooru OR/batched feed fetching | Conditional idea documented; no issue |

Nozomi, shared read state, Gelbooru OR and the scope of implemented filters
are recorded in [Following Topics](../following_topics.md).
This branch is a historical documentation/queue reconciliation only; it does
not change runtime code, existing issues or unrelated feature branches.
The entire legacy structure will be removed in a **separate future change**.
