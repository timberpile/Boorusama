# Recovered issue batch: local continuation handoff

Date: 2026-10-24. Repository: `timberpile/Boorusama`.

This is a handoff snapshot, not an additional task tracker. GitHub Issues remain authoritative. Read the current issue descriptions, latest comments and `AGENTS.md` before continuing.

## Recovery outcome and authorization

Six task branches with commits survived an interrupted chat session. Recovery inspected their actual diffs, restored the numeric favorite-ID contract on #76, and published an additional implementation branch for #73. The user explicitly requested real remote branches and commits, not patch files, with local continuation, testing, review and final integration.

The original batch includes eleven issues, in this order: #84, #75, #62, #76, #53, #79, #73, #74, #81, #57, #58. Only the first seven have published implementation work in this handoff. **#74, #81, #57 and #58 are not implemented and have no batch branch here.** Do not mistake this recovery for completion of the whole request.

All seven implementation branches start independently from shared `develop` commit `6875e0ce778aecfb2b83780c2185ce9273a9b2cc`, tree `db264f567eedf873dc5038131cb56deb0ad65a96`. They are not stacked. `develop` and `master` were not changed during recovery. No pull request was opened and no issue was closed.

## Published source states

The commits below identify source-review points, **not tested candidates**. The #73 branch also contains the documentation-only commit that introduces this handoff. Always inspect the fetched branch tip and preserve subsequent changes.

| Issue | Remote branch | Implementation source reviewed | Per-issue handoff on that branch |
| --- | --- | --- | --- |
| #84 | `bug/84-android-backup-creation` | `0d7fe0bad0a3658ad406305bc11d4b504e44dc79` | `docs/handoffs/issue-batch-2026-10-24/84.md` |
| #75 | `bug/75-bookmark-preview-autoplay` | `3d512acdf9320ca9cb38749114b83dc300013cf2` | `docs/handoffs/issue-batch-2026-10-24/75.md` |
| #62 | `bug/62-bookmark-download-policy` | `8a8c85d3f806ae91dc55359596d7403ab4d74e3f` | `docs/handoffs/issue-batch-2026-10-24/62.md` |
| #76 | `bug/76-realbooru-original-metadata` | `28eff8b0e826921d5de14dbba36a2fac882464aa` | `docs/handoffs/issue-batch-2026-10-24/76.md` |
| #53 | `bug/53-realbooru-prefetch-refresh` | `88edc010ec5928b865f02b881bfec03b875927bc` | `docs/handoffs/issue-batch-2026-10-24/53.md` |
| #79 | `feature/79-remove-search-tag-import` | `80401a1b50abf1a449730cad68a413c8a68964bc` | `docs/handoffs/issue-batch-2026-10-24/79.md` |
| #73 | `feature/73-bookmark-bulk-group-actions` | `b2dc517384b2c30c10ac9d8d128cde91229a2765` | `docs/handoffs/issue-batch-2026-10-24/73.md` |

Read each handoff from its own branch. The other branches' handoff files are not all present on #73 because the branches are independent. For example:

```sh
git fetch origin
git show origin/bug/84-android-backup-creation:docs/handoffs/issue-batch-2026-10-24/84.md
git show origin/feature/73-bookmark-bulk-group-actions:docs/handoffs/issue-batch-2026-10-24/README.md
```

## What is implemented and what is not

### #84: Android backup creation

**Diagnostic preparation, not a confirmed fix.** Native errors now retain a bounded operation stage and exception type without logging private paths, payloads or exception messages. Failed cleanup no longer masks the original write/verification error. The reported Android 16 creation failure still needs reproduction, diagnosis and a demonstrated fix. Do not close #84 or integrate these diagnostics as its completed solution.

Compare native backup stages with the working ordinary export flow. Preserve backup verification, existing files, manifest history and retention ordering. Use disposable fixtures for destructive failure scenarios, never reset the user's physical phone. The per-issue handoff gives the precise investigation and test boundaries.

### #75: Bookmark preview autoplay

Group/folder previews observe the existing GIF autoplay setting, select a static poster when disabled, and render a lightweight empty fallback when no suitable static preview is known. Normal image and video-preview selection are preserved. Unit tests were authored. Add/execute mounted-widget and network-request regressions and verify the actual overview before acceptance. This change is independent of #81.

### #62: Bookmark download policy

**Partial implementation.** Supported source-resolved listing selections and the fallback viewer toolbar reuse the ordinary download notifier rather than forcing the legacy original-only path. The stored-snapshot fallback remains; missing/ambiguous origins or unsupported mixed selections can still reach the legacy policy. Finish this without borrowing another profile's credentials or silently dropping selected posts. Also verify intentional different-quality downloads when custom filenames collide. No new download tests were run or authored on this branch.

### #76: Realbooru original metadata

The detail parser distinguishes explicit original references from the displayed sample and carries available original dimensions/exact bytes. It introduces no per-post grid fetches or full-image metadata downloads. The new fixtures are synthetic, not proof of actual current host markup. Capture representative safe live-host fixtures and verify parsing, Post conversion, details UI and snapshot compatibility.

Recovery found that the initial commit `35c294b7da10a8b3f8dc160db0c711fceb53d27f` had accidentally changed unrelated `PostFavoriteDto.id` from `int?` to `String?`. Follow-up `28eff8b0e826921d5de14dbba36a2fac882464aa` restores `int?`; do not cherry-pick only the initial commit. The final DTO diff against develop adds only the nullable file-size field/documentation and constructor parameter.

### #53: Realbooru prefetch

A bounded serial metadata queue and optional engine capability reuse the detail-provider cache, prioritize the visible post and nearby directional candidates, and feed resolved non-original renditions into the existing image preloader. Queue and rendition tests were authored. Verify actual provider scoping, origin matching, stale-result handling, request bounds and viewer lifecycle; this code has not compiled or run here. No original-only neighbor media may be fetched merely to conceal a missing intermediate rendition.

### #79: Search favorite-tag import

The redundant empty-favorites import insertion is removed from Search. The dedicated management-page import and import implementation remain. Check empty/populated/filtered favorites, Search submission and import through the management page. No new widget test is included.

### #73: Bookmark bulk group actions

**Partial implementation.** The existing Bookmarks selection popup gains a direct Remove entry only when the listing has a concrete group. It captures the actual view's group and selected posts and reuses source-aware group removal and Undo. All Bookmarks and the existing group pickers are preserved. A dispatch/error-boundary test was authored.

The requested shorter picker labels still need locale edits: `Add to` and `Remove from`, retaining chevrons. The direct entry temporarily reuses the existing localized `following_topics.remove_selection`; replace it with a suitable shared generic Remove key as part of that wording work. Generate localization using the project's FVM workflow, not by editing generated code. Add real-notifier success/Undo and narrow-popup regressions. See the per-issue handoff for the selection-action-bar overflow constraint that led to reusing the existing popup.

## Dependencies and integration boundaries

- Review and complete #76 before accepting #53 or implementing #57. Their branches share the common base rather than carrying each other's code.
- #62 and #73 both modify `bookmark_scroll_view.dart`. Keep #62's ordinary-download routing and #73's `currentGroupId` argument; never resolve by replacing the whole file with one side.
- Future #57 must preserve the High ceiling for neighboring prefetch, progressive replacement and failure retention. Do not replace #53's metadata/lifecycle work when combining the viewer changes.
- #75 and future #81 are distinct: respecting disabled autoplay is not the same as validating large cached GIF eligibility.
- Do not modify unrelated Maestro, engine-metadata-audit, Series exploration or review-note branches.

## Four remaining issues

Read fresh requirements and check for existing ownership/branches before beginning these. Create a separate issue branch/worktree for each only when starting real work. No implementation or passing-test claim exists for these four:

- **#74:** Global bookmark-count visibility, default disabled, persisted with existing settings patterns. Do not alter memberships, stored counts or picker membership indicators.
- **#81:** Autoplay eligibility for a large GIF only when the complete valid file is locally available, while always respecting the global switch. Cache checks must not initiate network requests or duplicate downloads. Review eviction/invalid-entry races.
- **#57:** Add Original to global Post Quality compatibly with saved values and per-profile settings. Coordinate with #76/#53; preserve the visible image, geometry and zoom during upgrades and keep download quality independent.
- **#58:** Persist proven history exhaustion per source with query/profile invalidation. Do not persist a filtered empty page, missing timestamps, transient errors, endpoint pagination limits or access restrictions as a confirmed end. Inspect the history/session and repository contracts before choosing persistence changes.

## Verification actually performed

The GitHub connector successfully read and wrote branches/commits. Recovery read the repository instructions, inspected source and commit patches, compared each published implementation against the common base, and checked that the #76 correction is limited to its intended file and the #73 listing change to one argument. These are source and publication checks only.

**No FVM formatter, Dart analyzer, Flutter/package tests, Android build, emulator/phone test or complete regression ran in this chat environment.** FVM/Dart/Flutter are not installed here, and the container cannot resolve GitHub for a local checkout. The remote connector's write access is independent of those local execution limitations. Authored tests are unexecuted tests, not passing tests. No branch is represented as integration-ready.

## Local execution and completion

1. Fetch origin, reread current `AGENTS.md`, `docs/issue_workflow.md`, relevant development/engineering guidance, issue descriptions and comments. Preserve unrelated work and reuse any existing task worktrees. Continue the exact remote branches above rather than creating duplicate replacements or applying patches.
2. For each issue, review the complete branch diff, finish remaining acceptance, add missing regressions, format with FVM, analyze the affected scope and run the scope-appropriate tests. Local-package changes require the complete package suite plus relevant app consumers. Record actual commands/results and the checked source commit in its handoff/report.
3. For Android UI/device validation, follow emulator leases and the project's Maestro procedure. Prefer actual service behavior and controlled disposable scenario data. Never expose credentials/private payloads or reset the user's physical-device data.
4. Prepare the final combined integration candidate on current develop. Run the complete local suite required by the engineering guide; the existing handoffs reference `./scripts/run_regression_tests.sh`, but verify the current entry point and FVM requirements before execution. Any subsequent runtime/test/dependency or combined-candidate change invalidates that pass. A full pass can be reused only for the same candidate or documentation/status-only changes.
5. The user requested final integration after successful local testing/review. Follow that authorization and the repository's squash/equivalent-replay workflow; do not create PRs unless separately requested. Preserve issue IDs in final commit subjects. Use `Refs #N` while acceptance remains open; `Closes #N` only when completion is justified.
6. Publish approved completed work to `origin/develop`, verify the actual remote result, then close only the completed issues and remove obsolete workflow-status labels. Clean up only their completed remote/local branches and disposable worktrees under the established rules. Do not close a partial issue merely because its preparation branch was merged. Preserve needed handoffs before cleanup.
7. Report implemented changes, automated results, manual/device results, and unresolved work separately. Do not infer correctness from a clean commit or branch existence.

## Start prompt

Continue the Boorusama issue batch from the published branches listed in `docs/handoffs/issue-batch-2026-10-24/README.md` on `origin/feature/73-bookmark-bulk-group-actions`. Read current AGENTS.md and each branch's own handoff. Review and complete partial work, implement the four remaining issues on separate branches, and run the required FVM, package, application and Android checks. Preserve #76 before #53/#57 and both changes in the shared #62/#73 file. Merge/publish only fully accepted, regression-tested candidates under the existing authorization, then verify publication, close the corresponding issues and clean up completed branches. No patch-file workflow or PR creation.
