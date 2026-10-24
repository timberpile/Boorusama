# GitHub issue workflow

GitHub Issues are the sole source of task identity and status for tracked work in
`timberpile/Boorusama`. Ordinary scoped changes still need no issue, and PRs
remain explicitly requested, not mandatory. Do not mirror tasks in repository
Markdown files or allocate local ticket numbers.

## Issue writing

Write in English. Use a short, specific task label, not a narrative sentence.
Prefer a compact action plus its subject, or a clear problem name; roughly
3-7 words usually suffice. Omit ticket numbers, `FEAT:` / `BUG:` prefixes,
introductory filler, and a trailing period. Name the actual scope rather than
implying that an existing feature is entirely missing. For example:
**Fix Realbooru Image Prefetch**, **Add Post Original Quality**, or
**Fix Scroll-to-Top Button Visibility**.

The body normally contains **Problem** (one or two short sentences) and
**Expected behavior** (a few concrete, observable outcomes). Prefer 3-5 short
bullets with one main outcome each. Keep necessary exceptions beside the behavior
they qualify; avoid long sentences that combine several unrelated requirements.
Roughly 80-180 words is a guideline, not a target to fill. A smaller issue may
need less; essential scope and safety matter more than a word count.

Bugs include minimal reproduction steps and the relevant app version/platform
when known. Distinguish user-confirmed behavior, source findings, and a suspected
cause. Do not invent a build number or claim a device reproduction that was not
performed. Add a dependency or specification link only when useful. Describe
observable results rather than a file-by-file implementation plan.

Keep essential scope, compatibility, safety, and data-loss constraints visible.
Do not paste implementation instructions, blanket test requirements, logs, or agent
history into the issue. Short clarifications, decisions, blockers, and handoffs
may be comments; the description should reflect the current agreed outcome.
Move detailed designs and plans to repository documentation rather than simply
moving an implementation diary into issue comments. Never publish credentials,
private payloads, or machine-local paths as supposed shared documentation.

Example title: **Filter Bookmark Groups**

> **Problem**
>
> Finding a Bookmark Group becomes difficult when many groups exist.
>
> **Expected behavior**
>
> - Filter groups by name, ignoring case.
> - Show a clear no-match state with an easy way to clear the filter.
> - Keep group creation and existing group actions available.

## Labels

The [label catalog](../.github/labels.json) defines the supported names, colors,
and descriptions. Use exactly one type: `bug`, `feature`, or `maintenance`.
Use `priority:high` or `priority:low` only when appropriate; no priority label
means normal. Usually choose one area, and a second only for a meaningful boundary.
Areas are optional; do not add speculative labels or label every UI task `area:ui`.

Choose the type from the intended outcome: `bug` corrects incorrect behavior;
`feature` includes improvements to existing user-facing behavior, wording, and UX,
not only entirely new functions; `maintenance` covers primarily internal
engineering or upkeep without a user-facing behavior change. Choose the branch
prefix from that classification, not the classification to justify a branch name.
Related identifier cleanup can remain in a user-facing issue when needed to keep
its wording and code consistent; it does not require a second tracker.

`ux` is an optional cross-cutting label for user experience, interaction design,
and usability improvements. It may accompany any issue type or area. Unlike
`area:ui`, it does not imply a shared UI component or app-wide navigation.

`performance` is a cross-cutting label for meaningful latency, resource-use,
cache-efficiency, or redundant-request improvements. Use it alongside the task
label and owning area; do not apply it to purely visual UI polish.

`area:backups` covers backups, retention, restore, and all import/export formats
and flows. `area:boorus` covers site/engine support. Following uses
`area:following-topics`, not separate pinned-search or feed labels. There is no
`area:data`, `area:storage`, or `area:import-export`; storage changes use their
owning feature. `area:viewer` includes viewer preloading; `area:cache` covers
cache storage and eviction. `area:ui` is for shared components or app-wide UX.

| State | Meaning |
| --- | --- |
| Open, no status label | Backlog; not actively being worked on, not implicit approval |
| `in-progress` | Active implementation or required technical verification |
| `blocked` | A concrete obstacle prevents the next necessary step |
| `review` | Prepared for acceptance or authorized integration |
| Closed | Completed or deliberately not planned; use the appropriate close reason |

Status labels are mutually exclusive. Change only the relevant status labels;
retain unrelated labels, assignees, and issue content. Do not replace the complete
label array with only the new status. Remove workflow-status labels on closure.
The `review` label does not waive the full integration-verification gate.

To preview the catalog without network access or credentials:

```bash
python3 scripts/setup_issue_labels.py
```

With authorization and an authenticated GitHub CLI, apply it using `--apply`.
The script targets `github.com/timberpile/Boorusama` explicitly, creates or updates
only catalog labels, and never deletes unrelated labels or edits issue memberships.
It is safe to rerun after a partial failure. No continuous label synchronizer or
issue-migration automation is required.

## Starting and coordinating work

Search open and closed GitHub issues, relevant subsystem documentation and
existing task branches before creating a new issue. Reuse the actual GitHub number; never allocate one locally. Creating
an issue records a task, not permission to implement it. Follow the user's scope.

For authorized issue work, read its current description, linked requirements,
and latest comments. Check active branches/worktrees and existing ownership.
Assign the acting account where appropriate, set `in-progress`, and record one
short claim comment with the session identifier and intended branch, for example:
`Working on feature/42-bookmark-search (session workflow-20261018).`
Keep local paths and detailed progress in the task workspace.

Assignees and labels are not locks, especially when agents share an account.
A user or coordinating agent must allocate parallel queue work explicitly. Do
not take over an existing claim because its timestamp is old; coordinate the
handoff. On release of a claim, document the handoff and actual next state rather
than leaving a task falsely active. No distributed lock service is implied.

If GitHub is unavailable, do not claim new queue work, invent IDs, or create a
fallback local ticket. Already assigned work may continue from the known scope;
record pending metadata changes for later reconciliation. Explicitly requested
issue-free small changes remain possible.

## Branches and authorization

New issue branches use `<bug|feature|maintenance>/<issue-id>-<short-title>`.
Issue-free changes use `<bug|feature|maintenance>/<short-title>`. Use the actual
GitHub number and lowercase kebab-case; branch syntax alone cannot prove an issue
exists. Keep branch names stable after work starts. Legacy numbers are not GitHub
numbers, and existing branches are not renamed merely for this transition.

Use the [worktree helper and isolation rules](development_workflow.md#isolation-and-small-changes).
The helper remains local: it never creates issues, changes labels, fetches, or
pushes. Existing release, upstream, and Dependabot exceptions remain unchanged.

An explicit request to create or work on an issue permits its necessary scoped
metadata changes: description, labels, ownership, short coordination comments,
and its completion state when justified. It does not authorize unrelated issues,
code publication, merges, releases, or deletion. Those retain the separate
permissions in the [development workflow](development_workflow.md).

## Verification and completion

Perform scope-appropriate task verification under [AGENTS.md](../AGENTS.md).
Record detailed checks, the tested source state, limitations, and handoff context
in the normal task report, not the issue body. For a blocker, explain what must
change to proceed; for `review`, identify the outstanding acceptance/integration
step briefly. Required failing or unrun task checks are not a ready handoff.

For implementation tasks, close as completed only when agreed acceptance criteria
are satisfied and the solution is available in shared `origin/develop`. A release
is not required. Work that is only prepared or integrated locally remains open;
note that publication is pending when it is not authorized. Approval to merge a
task branch includes publication, issue closure, and completed remote-branch
cleanup under the [development workflow](development_workflow.md#integration).
Carry those steps through without asking again, unless the user explicitly limits
the scope. Verify the result is in `origin/develop` before closing the issue and
remove obsolete workflow-status labels. Non-code tasks may close when their agreed
outcome is complete and accessible. Cancelled or
superseded work uses the appropriate not-planned/duplicate reason, not completion.

Use `Refs #123` in a PR or commit while required acceptance remains outstanding.
Use `Closes #123` only when integrating that change completes the issue. GitHub
can close issues from a PR or commit reaching the default branch (`develop`);
preserve the closing reference in the final squash commit. Verify the actual
integration and issue state afterward, including removing obsolete status labels.
Never use a closing keyword simply because an implementation branch is finished.

## Documentation and handoffs

Keep three responsibilities separate:

| Content | Location and lifetime |
| --- | --- |
| Task outcome, priority, ownership, current status | GitHub issue |
| Detailed requirements and durable decisions | Relevant subsystem docs or `docs/designs/` |
| Optional implementation plans and temporary work | `docs/plans/` when worth versioning; otherwise the task workspace |

No extra document is required for a simple change. Specs and optional plans may
be detailed, but do not become a second status tracker. A completed plan is
historical context, not authoritative documentation of current runtime behavior.
Resolve contradictions between issue and specification rather than silently
choosing one. Update both when an agreed scope change requires it.

A specification needed before implementation must be accessible from a shared
commit/branch; prefer stable commit links for agreed requirements and explain any
pending publication. A local-only branch or `/tmp` path is not a cross-machine
handoff. Before handing work over, ensure the receiving agent can access the
actual source, requirements, remaining steps, and verification limits.

Before the task worktree is removed, preserve needed handoffs and move durable
knowledge into appropriate documentation. Do not commit raw logs simply to keep
them alive, but do not delete the only copy of information needed to continue.
Existing automatic cleanup and authorization rules still apply.

## Retired local task queue

The previous repository-local work-item queue is retired. GitHub Issues now
track every future queued task, while durable requirements and engineering
decisions live in relevant subsystem documentation or `docs/designs/`.
Historical completion evidence is accessible in the repository's Git
history (the final pre-removal tree is
[`1d2cc36`](https://github.com/timberpile/Boorusama/tree/1d2cc367a5e5691c7005cf9d438930f3c6c5ed8b/docs/work)).
This history is not a live queue. Do not restore old folders, local
status transitions, ticket allocation, or a second issue mirror.

Templates become visible in GitHub's issue chooser when their files reach
the default branch. Preparing labels alone does not activate branch-local
templates.
