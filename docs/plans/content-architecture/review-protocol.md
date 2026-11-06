# Delegation and independent review protocol

This protocol is required by Timber for the content-architecture rollout. It supplements current AGENTS.md; it does not waive tests or grant merge permission. Read [execution order](README.md) for each issue's minimum reviewer.

## 1. Lead and lower-cost implementers

The lead retains ownership of the approved contract, stage sequencing, integration decisions, security/migration risks and final verification. Use a lower-cost/weaker subagent only for a bounded task whose interface, files and acceptance assertions are already fixed.

Suitable delegated tasks:
- Read-only callsite/test inventory with concrete paths and no speculative refactor.
- Sanitized JSON/metadata fixture variants and simple parser mapping after contracts are fixed.
- Mechanical PostBookmark rename/import repairs in a declared disjoint file set.
- Localized static text, documentation/link updates and bounded layout tests.
- Straightforward regression tests whose expected behavior the lead has specified.

Do not delegate independent architectural authority over identity canonicalization, profile/credential/host trust, central allocation, migration activation/rollback, import conflict policy, active-media ownership or gesture arbitration to a weaker agent. It may propose evidence/tests, but the lead designs and reviews the actual implementation.

Default to one small worker when that saves effort. Parallelize only independent work with no shared writers or SDK/emulator state. Prefer isolated child worktrees/patches; never allow two agents to edit/stage the same files or alter the main user's checkout. Worker task descriptions are scoped implementation instructions, not another tracker. Use the owning GitHub issue and per-issue handoff.

Every worker receives: exact base commit; issue/plan/contract paths; allowed files; forbidden scope; consumes/produces signatures; expected tests; no merge/push/issue-closure authority; reporting requirements. Require changed-file list, actual commands/results and unresolved concerns. The lead inspects the diff and runs combined tests; a worker's assertion is not verification.

### Lower-cost worker prompt template

```text
Work only on issue #<ID>, task <N> of <PLAN>, based on commit <BASE>.
Read current AGENTS.md and the linked approved contract.
You may change only: <EXACT FILES>. Do not alter shared contracts, storage,
authorization, branches, dependencies or user-visible scope.
Implement: <SPECIFIC BEHAVIOR AND SIGNATURES>.
Prove: <NAMED TESTS AND ASSERTIONS>. Use FVM; no invented test results.
Do not merge, push, close issues, or edit another worker's files.
Return your patch/commit, changed files, commands/results and any discrepancy.
Stop and report a contract conflict instead of choosing new architecture.
```

## 2. Mandatory reviewer selection

- #132: **Sol High** for the narrow settings/delete-path removal. Use **Astra High** if unexpected persistence/recovery changes become necessary.
- #154, #155, #142, #143, #156, #140 and #157: **Astra High** because they cross core identity, storage, access or viewer-state boundaries.
- #141: **Sol High** only if it remains a consumer/adapter stage over the fixed shared APIs; otherwise **Astra High**.
- Final combined rollout: a fresh independent **Astra High** review across all stages.

These are explicit model/reasoning selections requested by the user. Record the actual available model identifier and effort setting used by the local tool. Do not merely write Sol High/Astra High in a report while running a weaker model. If the environment does not offer the required independent reviewer, mark the gate blocked and preserve an executable reviewer handoff. Do not silently substitute self-review or a lower tier. No claim that these reviewers have already run in the ChatGPT preparation session is made.

The final reviewer must not have authored the implementation, tests or fixes it reviews. Use a fresh context with read access to the repo/spec/tests; implementation history can be supplied as evidence, but not as conclusions the reviewer must accept. A previous independent reviewer can recheck fixes in a fresh pass; it must not become their implementer.

## 3. Gate timing and cycles

1. Lead completes the stage, inspects the whole delta, formats/analyzes it and obtains actual scope-required test results.
2. Freeze a candidate commit and record its baseline. Supply code, tests, contract and verification evidence to the independent reviewer.
3. Reviewer inspects all changed paths and relevant consumers and runs focused checks where useful. Existing full regression evidence for the identical candidate may be reused; do not waste time rerunning it solely because the reviewer session changed.
4. Lead addresses findings on the same issue branch. Update/add regressions and rerun affected checks; shared runtime/test/dependency changes require a complete final pass before integration.
5. Reviewer reviews the new final candidate, including the fixes and changed interactions. Repeat until correctness/data-loss/security findings are resolved or explicitly escalated to the user.
6. Only then may the next dependent local stage begin. A missing check/model, unverifiable live API or unresolved safety finding is a blocker, not a passing review.

There is no minimum review duration or arbitrary hour target. Each stage needs at least one complete independent final review pass; remediation requires a new review pass on the revised candidate. A later base/runtime change invalidates applicable evidence. Pure documentation/status updates do not force an application regression rerun.

## 4. Required reviewer input

- Repository and issue number, exact task branch/worktree.
- Base SHA and candidate SHA; list any stacked prerequisite commits.
- Approved contract, stage plan and live issue/comments.
- Whole issue delta (`git diff <BASE>..<HEAD>`), not only selected snippets.
- Relevant pre-existing consumers and tests, especially mutation/import/source/viewer entry points outside changed files.
- Actual verification commands/results, skipped tests, device/live-service limits.
- Scope exclusions and known risks, without hiding failures as pre-existing.

## 5. Independent final-review prompt

```text
Review issue #<ID> independently using <Sol High|Astra High> at High effort.
Repository: timberpile/Boorusama
Branch/worktree: <BRANCH AND PATH>
Base: <BASE SHA>
Candidate: <HEAD SHA>
Read AGENTS.md, docs/plans/content-architecture/approved-contract.md,
<STAGE PLAN>, the live issue/comments, and the complete candidate diff.
You did not implement this change. Do not accept the implementer's summary as
proof. Do not modify code; return actionable findings for the implementer.

Check specification compliance, actual callsites, source/engine/profile isolation,
identity versus occurrence, snapshot compatibility, lazy loading/request bounds,
unknown/filtered/missing data, races/disposal, UI semantics/accessibility, and
all persistence/import/Undo paths touched by this stage. For migration stages,
inspect every durable boundary, restart recovery, ID allocation and preservation
of memberships/dates. Check tests can fail for the old behavior rather than only
matching implementation internals. Do not reopen settled design choices without
concrete evidence of a correctness or feasibility problem.

Run focused checks as useful with FVM. Inspect existing full-suite evidence for
this exact candidate; never invent results or treat missing tests as passed.
Report each finding with severity, path/lines, triggering sequence, concrete
impact, required behavior and suggested regression coverage. Separate confirmed
bugs, unverified risks and nonblocking cleanup. State all review/verification limits.
Finish with APPROVE, CHANGES REQUIRED, or BLOCKED, identify the reviewed SHA,
and list conditions for the next stage. An approval cannot waive remaining
required tests or replace explicit develop integration authorization.
```

## 6. Persisting review evidence without a second tracker

The task handoff records reviewer model/effort, reviewed SHA, verdict, material findings/resolution commits and actual commands. A concise relevant issue comment can link it. Keep raw logs in durable ignored `.worktrees/_artifacts/content-architecture/<issue>/` storage. Do not commit huge transcripts, create local issue status boards or publish credentials/private payloads.

Self-review is still required from the implementer, but is never called independent review. CI, unit tests, source inspection, browser checks and Android acceptance are separate evidence categories. The final handoff reports them separately.
