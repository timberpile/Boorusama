# Pinned-search updates sorting

- Priority: Normal
- Affected feature/branch: Pinned Searches / `feature/pinned-search-unseen-sort`
- Agent/session: Codex implementation agent / assigned worktree
- Problem: Separate Unseen first and Newest post first modes force users to choose between NEW status and recent activity.
- Expected behavior: Replace both modes with Updates first. NEW searches precede read searches; within each group, the newest cached last-post time comes first.
- Acceptance criteria:
  - The menu has exactly Manual order, Updates first, and Oldest post first, in that order.
  - Dated searches precede undated searches within both NEW and read groups. Manual/input order breaks equal or missing-time ties.
  - Home and folder cards use the same session-only selection.
  - Sorting reads cached state without network requests or changes to persisted organization order.
  - Oldest post first and Manual order retain their behavior.
- Relevant context: `PinnedSearchSort`, `visiblePinnedSearchesProvider`, and `PinnedSearchesPage` drive both views. Task 24 will persist the final sort selection after this branch is reviewed.
- Dependencies: None.

## Completion evidence

- Original Unseen first work was completed and verified on this branch before the Updates first refinement.
- The refinement's tests failed against the old comparator and menu before the implementation changed.
- Focused sorter and Home/folder widget tests verify NEW priority, recency within both groups, undated entries, manual ties, menu choices, unchanged stored order, and no requests.
- The source labels were updated in all 23 locale catalogs and regenerated with `./gen.sh`.
- Full validation results are recorded in the implementation handoff.
