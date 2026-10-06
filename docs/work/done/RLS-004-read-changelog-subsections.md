# RLS-004: Read complete in-app changelog sections

Priority: Normal
Affected feature: In-app release notes dialog

## Problem

The v4.5.0-timberpile.3 notes appear empty in the app. The latest-changelog
reader stops at the first blank line, immediately after the version heading.
GitHub's published release notes contain the complete text.

## Acceptance criteria

- Reproduce empty latest notes with the current changelog structure.
- Read the complete latest release section, preserving blank lines and Markdown
  subheadings, and stop before the next top-level version heading.
- Preserve older flat-list format, version metadata and seen-state behavior.
- Add focused regression coverage and verify the scoped fix.

## Claim

- Coordinator: /root, 2026-10-06 changelog-markdown-sections
- Implementer: /root/changelog_sections
- Branch: fix/changelog-markdown-sections
- Worktree: /home/timber/code/Boorusama/.worktrees/changelog-markdown-sections
- Base: local develop 20b2b595c

Read AGENTS.md, development workflow, engineering guidelines, related RLS-003
and Timber identity design. Scope is the in-app reader and necessary regression
coverage/documentation. Keep release prose and remote release state unchanged.
Integration and publication require separate authorization.

## Progress

- Claimed before implementation. Source investigation identifies first-blank-line
  termination in `lib/core/changelogs/repo.dart`; regression proof pending.

## Completion evidence (2026-10-06)

- Reproduced with the real repository and bundled `CHANGELOG.md`: `.3` returned
  empty content. The dialog already uses `MarkdownBody`; headings are supported.
- The reader now stops at the next `# ` release heading and retains blank lines
  and `##`/`###` subsections. Release prose, version parsing and seen keys remain
  unchanged.
- Six focused repository regressions passed, including current bundled notes,
  legacy flat lists, adjacent release headings, EOF, previous-version metadata
  and persisted seen state using a real temporary Hive box. Before the fix, five
  content tests failed and the seen-state test passed (exit 1).
- Fresh worktree CLI dependency setup and `./gen.sh` passed. Final focused
  `fvm flutter test --no-pub test/core/changelogs/changelog_repository_test.dart`
  and analysis of the repository/test files passed (exit 0, no analyzer issues).
  Logs: `/tmp/changelog-markdown-sections-20261006-{red,green,analyze,gen}.log`.
- The test build emitted the documented libavif `File modified during build`
  message, but tests completed successfully. Full-suite and Android UI checks
  were not run for this scoped parser fix. No develop integration, push or
  release mutation was performed; delivery awaits review and approval.

## Approved local delivery (2026-10-06)

- User confirmed the fix works and approved merging into local develop.
- Rebased the single scoped commit onto develop `32b2b9257`, preserving the
  approved bookmark fix. Reread current AGENTS.md and development workflow.
- Combined Changelog and Bookmark regression suites passed all 19 tests,
  exit 0; evidence:
  `/tmp/changelog-markdown-sections-20261006-integration.log`.
- Coordinator and independent review found no issues. Integration uses one
  descriptive single-parent commit; publication and cleanup remain separate.
