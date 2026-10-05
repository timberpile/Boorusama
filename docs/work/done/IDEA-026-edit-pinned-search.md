# IDEA-026 — Edit a pinned search

Priority: Normal

Feature: Pinned Searches

Work branch: `feature/26-edit-pinned-search`

Claimed by: `/root/implement_26_edit_pinned_search` (2026-10-02)

## Problem and expected behavior

Before this work, pins exposed Rename but could not change their exact query or owning profile. Edit lets a user change name, query, and profile in one save while retaining the pin identity and placement.

## Acceptance criteria

- The card menu opens an editor with separate optional name, exact query, and owning profile inputs. Cancel writes nothing.
- Individual pin menus in Home and folders offer Edit without a separate Rename; folder Rename remains available.
- Saving all three fields updates the existing independent pin; its UUID, folder/Home membership, and relative manual order stay fixed.
- A name-only save preserves checkpoint, highest ID, recent identities, previews, NEW, attempt, error, and cached last-post data. A null name displays the current query; a custom name stays until changed.
- A changed query or profile advances runtime incarnation and clears checkpoint, highest ID, recent identities, previews, NEW, attempt, error, and cached last-post data before baseline I/O. A successful baseline creates no NEW; a failed baseline keeps the edited definition saved as Not checked with a retryable error.
- The repository's normalized profile/query lookup, excluding the edited UUID, blocks collisions before any write. The editor stays open with a warning and neither pin changes. An identical normalized query in another profile is allowed.
- Missing profile, unsupported tracking, persistence failure, and baseline failure each have distinct visible outcomes. Unsupported tracking warns clearly while allowing the query to open normally.
- Old in-flight refreshes cannot coalesce away the new baseline or commit stale results into the new runtime incarnation.
- Editing an independent pin never mutates a feed-internal source or Following Feed.
- Backup/export contains only the edited definition. Reimport of its UUID remains idempotent; an imported different UUID with colliding normalized profile/query follows existing duplicate handling.

## Dependencies and constraints

Use the existing runtime revision and stale-commit safeguards, item 15 organization contract, and item 07 refresh coordination. Portable profile IDs remain for item 02. Reuse creation/import uniqueness semantics. Approved product behavior: `/tmp/ready_ideas_review_checklist.md`, item 26.

## TDD implementation checklist

- [x] RED/GREEN: repository edit validation, atomic save, runtime reset, name-only retention, and feed isolation.
- [x] RED/GREEN: notifier edit coordination, changed-definition baseline, and stale in-flight refresh race.
- [x] RED/GREEN: editor cancel, duplicate/missing/unsupported/save/baseline outcomes and localized labels.
- [x] Verify backup/export and import behavior; update persistent documentation.
- [x] Run generation, formatting, focused tests, targeted analysis, and diff review; record evidence before moving to done.

## Progress

Claimed before product edits. The repository test first failed because `edit` did not exist; the notifier race test failed for the same reason; the widget test failed because the Edit action was absent. Each passed after implementation. The focused repository, notifier, widget, export, and import run passed 158 tests. The full Flutter suite passed 1,498 tests on the captured rerun. Targeted Dart analysis found no issues; `git diff --check` was clean. `./gen.sh` completed successfully.

Backup export was checked directly after an edit, and existing repeated-import and normalized-query tests passed.

After rebase onto `origin/develop` at `3d907c985`, a new RED/GREEN regression test verified that a profile-only edit retains typed-tag navigation while a query edit clears it. The rebased focused suites passed 175 tests and targeted analysis found no issues. An earlier full-suite run reached 1,751 passes and one failure: `Session Resume should mark dry run session as pending when interrupted` reported an asynchronous provider read after its test ended. A serial full-suite rerun reproduced the same failure and was stopped after confirmation. The bulk-download file passed all 33 tests in isolation, and the named test also passed alone. No bulk-download source was changed. The later full-suite run for the Rename-menu fix passed 1,756 tests.

Review round 1 fixed indistinguishable duplicate-named profiles in the editor by sharing the pinned-card name/URL caption logic. A widget test first failed because the disambiguated caption was absent, then passed and selected the intended owner profile. A gated-save widget test first showed barrier dismissal before save completion, then passed after disabling barrier dismissal and guarding system Back. The covering focused suites passed 177 tests; targeted analysis found no issues and diff checks were clean. The fix is committed as `073cb5dfa`.

The Dev APK from this worktree was installed over the existing app on emulator-5564 without clearing data. Maestro confirmed editor open/Cancel, a duplicate-query warning with no save, a successful exact-query and owner-profile edit, and the unsupported-tracking warning for an existing profile. The local test pin was restored to its original query and Danbooru owner, and the other pin remained unchanged. Missing-profile deletion and a full export/import file round trip were not exercised; live delayed-save barrier/Back and duplicate-named profile cases are covered by widget tests, not Maestro.

Review feedback (2026-10-03): Remove the redundant individual-pin Rename action now that Edit includes the name field. `/root/fix_26_remove_rename_action` verified Home and folder card menus, the separate folder Rename, and the search-page Manage Pinned Search path. Home and folder widget regressions first failed on the visible extra Rename entry.

The Home and folder regressions then passed with Edit present and pin Rename absent; the Home test also confirmed folder Rename remains. The migrated name-only Edit test preserved the query label fallback and NEW state. Focused page/folder/search-page widget suites passed 122 tests, targeted analysis found no issues, and the full Flutter suite passed 1,756 tests. `git diff --check` was clean. No new emulator run was performed for this menu refinement.

Independent review of `600bd1fe1` found no critical, important, or minor issues. The reviewer separately reran the three focused widget files (122 passed), targeted analysis (no issues), and the diff check (clean), and confirmed the Home and folder menu paths, search-page name flow, and folder Rename. All acceptance criteria are verified; this task is complete on `feature/26-edit-pinned-search`. The branch has not been pushed or merged.
