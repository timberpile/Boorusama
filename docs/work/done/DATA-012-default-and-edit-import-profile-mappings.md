# Share import profile mappings by website and engine

Priority: Normal
Affected feature: Shared import review mappings for bookmarks, pinned searches, and following feeds

## Problem

Importing pinned searches requires manually selecting a target profile even when exactly one valid candidate exists. After selection, the mapping control disappears, preventing correction before import.

## Expected behavior and acceptance criteria

- Build one global mapping per canonical website and engine across all selected bookmark, search, and feed dependencies. Display that site once, without repeating its hostname and full URL, and apply its chosen profile to every matching dependent entry.
- Automatically select exactly one valid same-site, same-engine target even when its UUID differs from an exported reference. Hide the target selection control for that sole target.
- With multiple valid profiles, keep one shared target control visible and editable. Preserve exact-UUID identity safety and conflict validation; do not silently merge incompatible identities or broaden matching to another website.
- With no valid target, block Apply and show an actionable warning naming the website, directing the user to create a profile through the regular profile flow or skip affected items. Remove inline automatic profile creation from import review.
- Changing a shared target replans affected bookmarks/searches/feeds, replaces previous preflight, and applies only the newly reviewed mapping. Preview interactions must not write application data.
- Deselected or skipped dependents do not create irrelevant mappings. One selection applies consistently across categories; multiple accounts remain explicitly selectable.
- Cover cross-category shared mapping, canonical site equivalence, zero/single/multiple profiles, UUID conflicts, changing a target and dependent ownership in focused tests. Verify visible shared review UI.

## Context and scope

Approved by the user on 2026-10-05. Relevant code: `lib/core/backups/export_import/import/profile_mapping.dart`, the dependency planner, and `import_flow_page.dart`. The page currently omits resolved mappings unless they create a profile.

Related documentation: [unified import design](../../superpowers/specs/2026-10-01-unified-export-import-design.md), [IDEA-002](../done/IDEA-002-replace-profile-ids-with-uuids.md), [development workflow](../../development_workflow.md), and [engineering guidelines](../../engineering_guidelines.md).

The revised scope includes the shared site/engine grouping pipeline, target control, and one actionable shared-site issue. Preserve approved responsive layout and distinct-source issue coverage. Implementation uses its dedicated branch/worktree and an implementer subagent.

## Claim and progress

- Claimed 2026-10-05 by coordinator `/root/import_coordinator`; session rooted at `/root`.
- Branch: `fix/data-007-import-profile-mappings`.
- Worktree: `/home/timber/code/Boorusama/.worktrees/data-007-import-profile-mappings`.
- Implementer: `/root/import_coordinator/data007` (assigned).
- Status: implementation and verification complete; ready for coordinator review. No integration or publication authorized.

## Implementation and verification progress (2026-10-05)

- `ProfileMapper` automatically selects exactly one planner-valid candidate, including a different exported UUID. Same-site candidate priority and engine-only fallback remain unchanged. Exact UUID remains the default while same-site alternatives are available to edit; the dependency planner still blocks UUID/engine/site conflicts.
- Import review keeps non-import-supplied mapping cards visible after both automatic and manual selection. The existing Create profile action remains available.
- Existing notifier logic recalculates dependency mappings and replaces preflight on target edits; a real ZIP-load/apply regression verifies replaced preflight and validated-plan objects, changed pinned-search projection, unchanged repository during preview, and final pin/feed/internal-search ownership.
- Red-to-green evidence: four mapper/planner regressions and the resolved-card widget regression failed before the production fix. The initial 34 focused tests passed afterwards; the real notifier ownership regression also passed. The first full suite exposed three superseded explicit-single-candidate assertions in the planner and AnimeBoxes review; those were updated to the approved automatic contract, and all 14 tests in their focused follow-up passed.
- Android Dev APK built successfully (`fvm flutter build apk --debug --flavor dev -t lib/main.dart`, 237.4 seconds). Installed only on exclusively leased `emulator-5560`; every device/Maestro operation was preceded by renewal, and the lease was released after verification.
- Maestro opened a credential-free differing-UUID pinned-search fixture. Review automatically displayed Default profile, All checks passed, and Create profile. Opening the target dropdown and manually selecting Default profile preserved the mapping card and Create profile action. The 9-command assertion flow passed; screenshot: `/tmp/data007-reviewed-mapping.png`. The fixture was left unapplied in review. UI changes to a different existing target are covered by the widget and real notifier regressions; that alternative was not available in the emulator fixture.
- Final full Flutter suite: all 2,155 tests passed in 1 minute 59 seconds (`/tmp/data007-suite-final.log`). Targeted analysis of all changed Dart files has no errors or warnings; three pre-existing informational lints remain (`/tmp/data007-analyze-final.log`). `git diff --check` passed. Ticket remains in-progress for coordinator review.

- Queue ID corrected from DATA-007 to DATA-012 on 2026-10-05 because the old ID already existed in done/. Branch/worktree retained as the same ticket workspace.

- Independent review: no issues found; reviewer reran 44 focused tests successfully. Coordinator reviewed the scoped diff; pending root/user review, remains in-progress.

## Coordinated review status (2026-10-05)

Implementation: `9b6ff5ab4 + ed174c313`. Independent review approved; editable/default mapping regressions and UI check passed.

Combined verification is isolated in `.worktrees/nine-release-fixes-review` on `review/nine-release-fixes`. The final combined serial Flutter suite passed all 2,206 tests (exit 0); the unchanged current CLI implementation passed all 239 tests. The final Dev APK built successfully. Analysis of 29 changed Dart files found no errors or warnings; two unchanged baseline const-style informational lints remain. Development integration, publication, and cleanup have not been performed. Keep this ticket in progress pending final combined checks and its remaining acceptance evidence.

## Revised user feedback (2026-10-05)

The initial implementation is superseded by the acceptance criteria above: duplicate category mappings and repeated site labels were rejected. DATA-012 owns shared page, mapper UI, and dependency planner/notifier grouping changes. DATA-010 owns bookmark dependency/application tests and the Realbooru regular-versus-import-created investigation. Root will provide the integrated develop base before rebase; no integration or publication is authorized for this revision. Implementer `/root/import_coordinator/data007` resumes in the existing same-ticket branch/worktree.

### Shared identity decision

When active references for one canonical site/engine exactly match different local accounts, require an explicit shared target instead of choosing between them automatically. Auto-default may use a sole valid candidate or one exact target agreed by the references. Any exported UUID already bound to a different engine/site remains a blocking conflict regardless of a shared selection.

## Shared mapping revision progress (2026-10-05)

- Rebased the original ticket commits onto approved develop `8ce1984ccd6f4413c66fd4927ba9085f3d7827f6`; reread current agent/workflow instructions. Rebased original commits are `0e080badf` and `1d061cdd2`. DATA-010 bookmark prerequisite source/tests are isolated in `404b49f7e`; delegated shared-API test adaptation comes from test-only patch/commit `86778b14b`, carried separately as `323b0a71e`. These inherited changes are distinct from DATA-012's revision.
- Planner now groups active references by canonical website plus engine, retaining original references for applying the shared choice across bookmarks, pins, feeds, and feed-owned searches. Default HTTP/HTTPS ports, host case and trailing slashes normalize together; paths and nondefault ports remain distinct. Empty invalid sites never group or select unknown-site profiles. Same-engine profiles from another website cannot satisfy a dependency.
- Sole compatible target defaults without a selection control. Multiple compatible targets keep one editable selector, including explicitly imported projected profiles with readable account names. One agreed exact account defaults; competing exact accounts require an explicit shared selection. Wrong-site/wrong-engine reused UUIDs block every shared choice.
- Removed synthetic profile creation, the inline button, and public planner/notifier creation APIs. Missing-site issue names the website and directs regular profile management/import again or skipping. Ambiguous mappings show one website heading and an actionable picker hint; unrelated errors are preserved.
- Replanning expands one shared target back to each original reference, replaces preflight, and uses only the newly reviewed target on apply. Delegated real ZIP regressions cover bookmarks/pins/feeds with different exported UUIDs, zero preview writes, changed ownership, final profile hint and feed-owned searches, normal profile creation/reload, and rollback.
- Test-first canonical/account/cross-category/UUID cases failed against the previous behavior and passed after revision. Focused shared/UI/planner/notifier group passed 58 tests, additional invalid-site/port/path/wrong-engine cases passed, DATA-010's owned bookmark group passed 14, and migrated AnimeBoxes contracts passed 6. Approved narrow/large-text/long-target cases remain in DATA-013's standalone suite; distinct-site/source wording and resolution remain in DATA-009's suites. The duplicate copy of those tests in the inherited shared-page file was removed.
- Complete Flutter verification passed all 2,216 tests after migrating the remaining old reference-key contract. Final settled wording also passed all 2,216 tests in 2 minutes 46 seconds (`/tmp/data012-suite-delivery.log`). Analysis of all 17 changed Dart files is clean; formatting made no changes and diff check is clean. Logs: `/tmp/data012-full-final.log`, `/tmp/data012-analysis-delivery.log`, `/tmp/data012-contract.log`, `/tmp/data012-edge-tests.log`.
- Final Dev APK built successfully in 28.6 seconds. Exclusively leased `emulator-5556`; bounded non-streaming install succeeded after stopping an unusually slow streaming install. Renewal preceded every device/Maestro operation; automatic review briefly rejected calls because it did not recognize an immediately preceding batched renewal, and explicit separate successful renewals resolved this.
- Maestro opened credential-free preview fixtures: sole same-site differing UUID automatically passed checks with no mapping control; `missing.example` showed regular profile-management guidance, no create button, and disabled Import; two projected imported accounts appeared by name in one shared `review.example` picker and account 2 selection succeeded. No fixture was applied. The final hint assertion flow passed, and an 11-command flow selected account 2, reopened the same shared picker, selected account 1, and confirmed continued editability/no create action. Screenshots: `/tmp/data012-shared-unresolved.png` and `/tmp/data012-shared-selected.png`.
- Ticket remains in-progress for root review; no develop integration, publication, or cleanup performed.

- Final APK Maestro follow-ups passed: sole-target 8-command flow asserted All checks passed and absence of target/hint/create controls; missing-site 7-command flow asserted website/profile-management guidance and absence of target/create controls. Final screenshots `/tmp/data012-sole-hidden.png`, `/tmp/data012-missing-guidance.png`. Emulator lease released after the last screenshot. Implementation and all requested acceptance checks complete, ready for root review.

## Blocking review follow-up: canonical bookmark ports (2026-10-05)

- Independent review found that snapshot bookmarks synthesize HTTPS for `sourceUrl`. Turning canonical origin `site.example:443` from a nondefault HTTP port into `https://site.example:443` removed the port during dependency normalization and could select the wrong default-port account.
- Narrow fix builds the bookmark dependency from the stored canonical origin directly, without guessing a scheme. Existing origin rules, explicit ports, paths, and approved mapping UI remain unchanged.
- New real version-4 codec/package/notifier scenario uses `http://site.example:443/install/`: the wrong HTTPS default-port profile blocks Apply and preview leaves profiles/bookmarks/groups untouched; adding a regular matching HTTP-443 profile and reloading resolves the dependency. Applying preserves `site.example:443/install`, existing bookmark identity, and the correct saved profile hint. Before the fix this failed because the wrong profile was silently accepted (expected unresolved dependency, actual no errors).
- Related mapping/bookmark focused tests: all 23 passed (`/tmp/data012-port-green.log`); failing-before evidence `/tmp/data012-port-red.log`. Final analysis/full-suite results follow below. Root owns authorized integration and both ticket worktree/branch cleanup; implementer performs neither.

- Related IPv6 follow-up: canonical `[::1]:443/install` and `[::1]/install` failed in the old internal reference-key URL parser. `ProfileReferenceKey` now uses the same canonical site normalizer as origin/grouping, retaining UUID and engine identity. Two additional real codec/package/notifier cases verify canonical IPv6 keys, incorrect-site blocking, correct profile acceptance, preview snapshot isolation, and persisted hints. Both failed before the key fix with `FormatException` (`/tmp/data012-ipv6-red.log`).
- Derived bookmark references are runtime-only: the two production callers create mapping dependencies and look up the applied profile. Journal serialization records resolved source/item IDs and actions, not references. External search/feed reference serialization and parsing are unchanged.

- Final canonical port/IPv6 verification: all 246 export/import and AnimeBoxes migration tests passed in 1 minute 9 seconds (`/tmp/data012-canonical-green.log`); analysis of the three changed Dart files is clean (`/tmp/data012-canonical-analysis.log`); diff check clean. The previously running whole suite picked up the two IPv6 red regressions before the key fix: 2,217 passed and exactly those two failed (`/tmp/data012-port-suite.log`). Both are now green in the final focused run. As directed, root will rerun the integrated full suite on the final tree; no repeated implementer full run or emulator check is needed for this unchanged UI.

## Approved local delivery (2026-10-05)

User verified the combined flow and explicitly approved develop integration and removal of both ticket branches/worktrees. DATA010 and DATA012 share the final implementation and are delivered together in one descriptive single-parent local commit. Independent final review approved `8c0623b137dc46c584e59a3ed976073027c7e720` after canonical HTTP-port and IPv6 corrections. Final full suite passed all 2,219 Flutter tests (exit 0); all staged application/test/translation source files match that tested tree byte-for-byte. Changed-file analysis and whitespace checks passed. Sole/missing/multiple profile UI states and editing were verified with Maestro; the user confirmed the flow works well. Local wording edits in en-US.json were preserved and excluded from this integration. No remote publication is authorized.
