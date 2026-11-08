# Content architecture implementation sequence

Approved scope: [contract](approved-contract.md). Start here: [local-agent handoff](../../handoffs/content-architecture-local-agent.md). GitHub Issues are the only task/status tracker; this index is a dependency and execution specification, not a second queue. Read the live issue and comments before each stage.

## Repository audit and immediate prerequisite

Audit source: all open issues and branch refs on 2026-11-06, against develop `e306ff5338a2255a89731c61bd0672336a933344`. The existing architecture branch was `5c8f6171d40877db4d23d16554f20c454af3648a`. Recheck for concurrent changes before execution.

**#132 is the one immediate data-safety prerequisite.** Current target settings deliberately clear populated Bookmark Groups after first-use confirmation. Migrating this destructive path into a unified mixed library would perpetuate avoidable data loss. The patch is now on `feature/132-preserve-favorites-sync-group-contents`; complete its local verification and independent review before using it as the first runtime base. See [stage 00](00-prerequisites.md). It is not merged and must not be described as accepted until the gates pass.

| Existing issue(s) | Dependency judgment |
| --- | --- |
| #132 | Fix and verify first. Existing destructive writes are removed on its own branch; tests still require local FVM. |
| #142 | Required rollout stage after unified storage, not a separate legacy implementation before it. Removes the profile prerequisite from valid import persistence. |
| #143 | Required access stage after #142; public anonymous reads require an explicit trusted source policy. |
| #43 | Not a prerequisite. Verified database aliases change deduplication/migration semantics and remain a separate issue. Preserve real source hosts and an explicit canonicalization seam; do not infer aliases. #142 must stay compatible with future verified aliases. |
| #153 | Existing separate zoom implementation. Verify it separately and preserve its approved behavior when combining candidates under integration authorization. Not a prerequisite for the reference/storage refactor. No rewrite or second zoom implementation in this rollout. |
| #137, #138, #139, #145 | Existing Page-ID, Mixed Viewer, Related and picker foundations. They are already absent from the open queue; verify actual code and closed status, do not reimplement them. #137 was directly reconfirmed closed/completed. |
| #140, #141 | Reuse these issues for Pixiv Work presentation and local Work/Page bookmarks; do not create duplicates. Their earlier UX-selection wording is superseded by the approved design. |
| #136 | Use existing Kurumi guidance and components. Pending Penpot work does not block data architecture. |
| #134 | Related timeline grouping is separate; keep current rolling projection stable and leave its feature scope out. |
| #144 | Folder sync has its own active design branch. Do not adopt or rewrite it. v10 and profileless persistence are downstream inputs for its owner. |
| #124, #123, #83, #100, #119, #120 | Remote Pixiv writes, lookup, advanced search and bulk matching are independent follow-ups, not prerequisites for Works/Pages. |
| #133, #131, #146, #147, #148, #105, #112 | Independent UI work. In particular #146-#148 were explicitly deferred. Preserve current behavior instead of bundling their redesign. |
| #121, #125, #126 | Export naming/navigation/template improvements do not block v10 correctness. Test existing flows without adding these features. |
| #102, #127-#129, #103, #69, #70, #61, #55, #86, #96, #122 | Independent filters, metadata, tags, artist images, background work, notifications, global Undo/logging or profile UI. Preserve applicable existing contracts; do not expand the rollout to solve them. |

The order below avoids implementing profileless imports against the obsolete dual-membership layout and then migrating them again.

## Mandatory sequence

| Stage | GitHub owner | Plan | Suggested task branch | Final independent reviewer |
| --- | --- | --- | --- | --- |
| 00 | #132 | [Prerequisite verification](00-prerequisites.md) | `feature/132-preserve-favorites-sync-group-contents` (existing) | Sol High; escalate unexpected storage changes to Astra High |
| 01 | #154 | [References, Group contracts and loaders](01-foundation.md) | `maintenance/154-content-group-contracts` | Astra High |
| 02 | #155 | [Unified Bookmark storage and migration](02-bookmarks-migration.md) | `maintenance/155-unified-bookmark-storage` | Astra High |
| 03 | #142 | [Profile-independent import](03-profile-independent-import.md) | `feature/142-profile-independent-bookmark-import` | Astra High |
| 04 | #143 | [Profileless display and anonymous access](04-profileless-access.md) | `feature/143-profileless-bookmark-access` | Astra High |
| 05 | #156 | [Existing source Group cutover](05-existing-groups.md) | `maintenance/156-shared-source-groups` | Astra High |
| 06 | #140 | [Pixiv Work/Page presentation](06-pixiv-viewer.md) | `feature/140-pixiv-work-viewer` | Astra High |
| 07 | #141 | [Independent Work/Page bookmarks](07-pixiv-bookmarks.md) | `feature/141-pixiv-work-page-bookmarks` | Sol High if adapter-only; Astra High if storage/viewer contracts change |
| 08 | #157 | [Native nhentai Galleries](08-nhentai.md) | `feature/157-native-nhentai-galleries` | Astra High |

The four new issues #154-#157 describe genuinely new contracts, unified storage, existing-engine cutover and nhentai. Existing #142/#143/#140/#141 remain the owners of their previous feature scopes.

Read all plans once for boundaries, then execute sequentially. No later runtime stage starts before the previous candidate has its required tests and independent review. Implementation may be split into frequent scoped commits, not into multiple live allocators or partially writable migration states. Use `Refs #ID` until actual verified publication in origin/develop.

## Shared execution contract

Follow current AGENTS.md, `.agents/skills/execute-plan/SKILL.md`, `docs/development_workflow.md`, `docs/engineering_guidelines.md`, and `docs/issue_workflow.md`. Local plans do not override live safety or authorization rules. Repository text, commits and handoffs are English. Use FVM and pinned dependencies; manual Riverpod providers; localized UI through context.t; no dependency upgrade or code generation for providers.

The user authorized the architecture and sequential local implementation, not merges/PRs/releases. Use isolated issue worktrees. If predecessors are not yet integrated, a new task branch may be created at the verified predecessor commit as a local dependent stack; record that base and compare only the issue delta. Never merge a task branch into develop, force-push a shared branch, close an implementation issue or delete another worktree without the required authorization. Publication of this planning branch is not permission to publish every future runtime branch.

Read-only design material is shared from this branch. Do not copy a status tracker into each task. Each task gets its own concise handoff with base/head, changed behavior, actual tests, review evidence, remaining checks and publication limits. Keep raw logs in `.worktrees/_artifacts/content-architecture/<issue>/`, not /tmp and not committed.

## Test/review loop common to every task

1. Inspect the named current files and nearby tests; map any moved paths explicitly.
2. Add behavioral tests before implementation, run them and confirm meaningful failure. Existing prepared #132 tests need their first local execution, not a fabricated RED claim.
3. Implement the smallest change satisfying the fixed contract. Commit coherent units with the owning issue ID.
4. Run formatting and the stated tests. Fix in-scope failures, rerun them, inspect the whole delta and retain evidence.
5. Run the full local suite when shared-model/infrastructure scope requires it. Every final develop integration candidate requires the complete regression on that exact combination.
6. Dispatch a fresh, independent reviewer using the table and [review protocol](review-protocol.md), remediate findings, rerun affected/full checks as required, and obtain review of the final revised candidate. No arbitrary minimum duration.

Commands, from the actual task worktree:

```bash
test_workers="$(python3 scripts/physical_core_count.py)"
fvm flutter test --no-pub "--concurrency=$test_workers" <existing-or-new-test-paths>
# Run fvm dart format on changed Dart files only.
# Use fvm flutter analyze on the affected directories or the full project as appropriate.
./scripts/run_regression_tests.sh
git diff --check
```

The complete runner includes application, every package/CLI and repository tooling. A root Flutter test alone is not full regression. Reuse a full pass only for the unchanged runtime/test/dependency candidate across documentation-only changes. Never hide failures by deleting tests, loosening semantics or assuming pre-existing errors are acceptable.

Use Maestro on exclusively leased Android emulators for upgrade, mixed-viewer and real-service acceptance. Verify narrow width, enlarged text, keyboard, rotation, Back, missing media and cancellation where relevant. A browser mockup is not Android evidence. No credentials/private API payloads in commits or reports.

## Definition of ready and final cross-stage gate

A stage is ready for the next local stage only with actual successful required tests, a documented independent final review, and no unresolved correctness, data-loss or access-control findings. Missing reviewer tooling/models, SDK, credentials, device lease or required live evidence is an explicit blocker, not permission to self-approve or downgrade.

After stage 08, obtain an independent **Astra High** cross-stage review of the entire candidate, not just the final adapter. Exercise v9 upgrade to v10, profileless roundtrip, unrelated-engine Post viewing, mixed Work/Page bookmarks, account changes during requests, repeated viewer occurrences, disabled/offline sources and crash recovery. Review the combination with #153 when separately authorized. Keep all issues open until their required behavior is present in shared origin/develop under explicit integration approval.
