# Local-agent handoff: approved content architecture rollout

## Mission and authorization

Timber approved the reviewed architecture and asked for sequential implementation plans, sensible lower-cost subagent delegation and an independent Sol High or Astra High final review for every feature/stage. Execute the already decided work; do not restart the Post/Group, Bookmark membership, offline-metadata, Related UI/order or Pixiv navigation design discussion.

Repository: `timberpile/Boorusama`. Runtime baseline used for preparation: `develop` at `e306ff5338a2255a89731c61bd0672336a933344`.
Planning branch: `maintenance/content-architecture-design`; starting design baseline was `5c8f6171d40877db4d23d16554f20c454af3648a`.

This handoff authorizes the requested local implementation in isolated issue worktrees and scoped commits. It does **not** authorize PR creation, merging/cherry-picking task branches into develop or another existing task, pushing develop/master, releases, deleting branches/worktrees owned by others or closing implementation issues before shared publication. Continue through local dependent branches without requiring a develop merge between every stage. Request integration authorization only when actually needed; never treat passing tests as that authorization.

Current AGENTS.md and repository workflows are authoritative. Read them again at each new base/rebase. Use only the ordinary current working mode; do not propose another ChatGPT product/mode.

## Required reading order

1. `AGENTS.md`, `.agents/skills/execute-plan/SKILL.md`, relevant parts of `docs/development_workflow.md`, `docs/issue_workflow.md` and `docs/engineering_guidelines.md`.
2. `docs/plans/content-architecture/README.md`: audit, sequence, branch names and stage reviewer choices.
3. `docs/plans/content-architecture/approved-contract.md`: approved fields, invariants, source boundaries, storage and UI behavior. This supersedes conflicting earlier alternatives.
4. `docs/plans/content-architecture/review-protocol.md`: delegation and independent final-review gate.
5. Read plans 00 through 08 once to understand boundaries; then execute them one at a time in their prescribed order.
6. Read each live GitHub issue, latest comments and relevant existing code/tests immediately before working on it. Do not overwrite another agent's changes or take over an active claim just because its timestamp is old.

The approved review originally supplied downloadable HTML/Markdown/Dart sketches in chat. This repository contract and the detailed plans contain the implementation requirements, so execution does not depend on ChatGPT sandbox links. Declaration sketches are not compiled app code. Use real existing signatures/types and prove the implementation with tests.

## Prepared changes versus work still to do

### Prepared prerequisite #132

Branch: `feature/132-preserve-favorites-sync-group-contents`.
Published head with its own handoff: `2d468355406b92448d52f1b2a4914d058c6d5a1b`.
Runtime/test candidate: `b4995fd3248b9431730378772f82329d7e9c6ba2`.
Base: `e306ff5338a2255a89731c61bd0672336a933344`.
Read `docs/handoffs/132-preserve-favorites-sync-group-contents.md` on that branch.

The code removes first-binding clearing, destructive confirmation, clearing helper and obsolete runtime error dispatch. Tests were updated/added for non-destructive global/profile/editor assignments, mixed Post/Pool/Related membership/date preservation, settings failure, no automatic fetch and additive explicit fetch. #133's dialog redesign is excluded.

The preparation environment had no FVM/Flutter/Dart and could not clone GitHub via container DNS. Source and GitHub diffs were inspected, but **no formatter, analyzer, Flutter tests, full regression, device acceptance or independent model review ran**. These are mandatory local stage-00 tasks. Do not report this prerequisite as verified, merged or complete yet.

### Architecture runtime

No new ContentReference/Group/Bookmark runtime refactor was implemented in the preparation session. The architecture branch changes are documentation/plans only. New GitHub issues #154-#157 exist; #142/#143/#140/#141 are reused. All runtime implementation remains yours after stage 00.

## Worktree and base procedure

Start from a clean view of the repository without switching/stashing/resetting the user's primary checkout:

```bash
git fetch origin
git worktree list --porcelain
git status --short
DESIGN_SHA="$(git rev-parse origin/maintenance/content-architecture-design)"
git show "$DESIGN_SHA:docs/plans/content-architecture/README.md"
```

Record DESIGN_SHA in the first handoff so the requirements are reproducible. Read planning files through git show or a separate detached read-only reference worktree. If creating that worktree, inspect the proposed path first; never overwrite an existing directory or attach an already checked-out branch.

For #132, use the repository worktree helper to inspect the matching slug/branch, then reuse its isolated task worktree. If the branch exists locally without a worktree, attach it deliberately with `git worktree add <isolated-path> <existing-branch>`. If only the remote branch exists, create its matching local tracking branch first after checking for conflicts. No reset or force recreation.

For each new issue after its predecessor passes the tests/review gate, create its own isolated local task branch at the verified predecessor SHA (or current develop if that exact predecessor is already integrated). This creates a dependency stack by ancestry, not a merge into develop and not modification of the predecessor. Record the predecessor SHA as the issue delta base. Use the exact names in the execution index. Compare issue changes with `git diff <ISSUE_BASE>..<ISSUE_HEAD>`, not the entire cumulative stack.

Do not inherit the planning branch's historical mockup commits into runtime branches merely to make the plans visible. Keep reading them from the pinned design reference. Do not cherry-pick unrelated branches into the stack. If a base changes after review, re-evaluate the combined candidate and run required checks again; preserve shared history and any foreign work.

## Sequential execution and branch ownership

| Order | Issue | Plan | Key deliverable |
| --- | --- | --- | --- |
| 00 | #132 | `00-prerequisites.md` | Verify/fix the prepared non-destructive Favorites Sync patch |
| 01 | #154 | `01-foundation.md` | Validated Post/Group references, metadata, members, scoped loaders |
| 02 | #155 | `02-bookmarks-migration.md` | Shared IDs/membership, restart-safe migration, v10, Related-only order |
| 03 | #142 | `03-profile-independent-import.md` | Valid imports without a matching profile, retained snapshots |
| 04 | #143 | `04-profileless-access.md` | Trusted public read contexts and compact unavailable indicator |
| 05 | #156 | `05-existing-groups.md` | Existing Pools/Related/Szurubooru on shared contracts, same UI |
| 06 | #140 | `06-pixiv-viewer.md` | Native Work listings and approved Image View/Overview |
| 07 | #141 | `07-pixiv-bookmarks.md` | Independent local Work/Page targets and portable sharing |
| 08 | #157 | `08-nhentai.md` | Native-verified public Gallery/Page source and bounded tags |

Only claim the stage you are actually implementing. Preserve unrelated labels/assignees; GitHub is the sole status tracker. Issue bodies stay compact, detailed evidence goes in the appropriate handoff. Do not create a duplicate issue for an existing stage or a Markdown status queue.

#43 verified aliases, #134 Related timeline grouping, #144 folder sync, #124 remote Pixiv writes, #83 search and deferred UI work are not prerequisites to solve first. Their boundaries are documented in the audit. #153 zoom already has a separate implementation/handoff; do not reimplement or silently integrate it. Its combination with viewer work needs authorization and its own final verification.

## How to implement each stage

- Inspect the named files and actual consumers before editing. Plans label new file paths as proposals; if an equivalent abstraction exists, extend it and document the substitution rather than adding a competing layer.
- Apply the task's red/green behavioral tests, then minimal implementation and regression. Use FVM, pinned dependencies and manual Riverpod providers. No speculative framework, provider codegen or dependency upgrade.
- Commit coherent scoped changes regularly with `Refs #<issue>`. Do not wait until the whole rollout to save work. Do not commit partial broken migrations as a release candidate; the stage gate applies to the coherent final cutover.
- Keep blockers/evidence in a durable ignored `.worktrees/_artifacts/content-architecture/<issue>/` directory. Never use /tmp as the only copy of logs, recovery plans or handoffs.
- Before each independent review, inspect the whole issue diff yourself and verify the actual runtime candidate. Do not conflate source review, automatic tests, CI, browser mockups and Android acceptance.

## Lower-cost subagents and final reviewers

Use lower-cost agents for bounded caller inventories, synthetic fixtures, mechanical renames, localization and simple UI/test adapters once interfaces are fixed. Give exact file ownership, signatures and test assertions. Prefer isolated patches/worktrees; no concurrent shared-file edits, no worker staging/pushing on behalf of another. The lead validates every worker diff and the combined result.

The lead retains identity, auth/host trust, allocation/migration, import conflict and active-viewer/gesture decisions. Follow the detailed prompts and rules in review-protocol.md.

At each stage end, use a **fresh independent** reviewer who did not author that code/tests/fixes:
- Sol High for #132 and narrow adapter-only #141.
- Astra High for #154/#155/#142/#143/#156/#140/#157, and any #141 work expanding into shared core behavior.
- Fresh independent Astra High again for the whole rollout at the end.

Record the actual model identifier/High setting, reviewed SHA, findings and verdict. Self-review or a renamed weaker agent does not satisfy the requirement. If the required reviewer is unavailable, report the review gate blocked and leave a ready reviewer prompt rather than pretending it happened. After remediation, retest and independently review the revised final candidate. No minimum hours; use complete review/remediation/re-review cycles as needed.

## Verification and device protocol

Use the per-stage test matrix and current engineering guide. Shared models, storage, access and viewer infrastructure require the full local suite. Every develop integration candidate needs a complete pass on its exact runtime/test/dependency combination:

```bash
test_workers="$(python3 scripts/physical_core_count.py)"
fvm flutter test --no-pub "--concurrency=$test_workers" <affected-test-paths>
./scripts/run_regression_tests.sh
git diff --check
```

Format only changed Dart files with `fvm dart format`; analyze the affected code or whole app as required. Generate outputs only for changed inputs or missing required output, following gen.sh prerequisites. A full pass on the unchanged candidate is reusable across handoff/documentation changes; do not rerun all Flutter tests solely to publish a report.

Read `docs/android_emulator.md` before any emulator operation and obtain its exclusive lease. Use Maestro and real services for required native scenarios. Never create multiple device drivers for one leased emulator. Use disposable upgrade fixtures; do not wipe the user's actual app/library. Do not commit credentials, private API payloads or private/adult screenshots. Desktop E2E is not a rollout priority, but compilation/existing tests and supported non-touch semantics must remain intact.

nhentai has a real native feasibility gate: WSL API/HEAD success does not prove Android GET/decode, search or stable pagination. Keep the source disabled and report evidence if required native reads fail; do not introduce a bypass/proxy or falsely mark support complete.

## Per-issue handoff format

Create/update one handoff on each issue branch under `docs/handoffs/<issue>-<short-name>.md` before moving on. Include:

```text
Issue and branch:
Requirements design SHA:
Issue delta base and final head:
Inherited verified prerequisites:
Behavior actually implemented:
Files/contract changes and justified deviations:
Tests and analysis actually run (commands, result, skips):
Android/live-service scenarios actually performed:
Independent reviewer (actual model/effort, SHA, verdict):
Findings, fixes and final re-review:
Open checks/blockers and integration/publication limits:
Next-stage base SHA:
```

Do not claim `review` readiness with failing/unrun required checks; keep accurate issue state. Do not use Closes until acceptance is actually satisfied and the authorized change is published to origin/develop. Local-only work stays open. Preserve every relevant issue ID in eventual integration commits.

## Final cross-stage acceptance

The final independent Astra High reviewer receives the full candidate and every stage handoff, not only nhentai. Check v9 -> local migration -> v10 -> cold restart; failed/ambiguous writes; two accounts/anonymous scope; offline saved metadata; all Bookmark kinds and independent Work/Page memberships; missing/repeated members; mixed-viewer action ownership; lazy request bounds; source revocation; and unchanged ordinary Posts/Following/Favorites.

Run the complete final regression and required Android scenarios against that exact combined candidate. Stage passes do not prove an untested later combination. Preserve approved zoom behavior if #153 is separately combined under authorization. Report completed local stages, verified evidence and remaining publication/acceptance work concisely to Timber. No release, PR, develop merge, issue closure or branch cleanup is automatic without its authorization.

## Escalation policy

Make simple implementation choices yourself and document them. Ask only for missing authorization or an actual uncovered product/safety decision, such as unavoidable data loss, contradictory source identity, unsafe access or a required source API that does not work. Do not stop to ask about already approved model fields, Related's current UI, Work/Page gestures, local versus remote bookmarks, offline Details retention or reviewer quality.
