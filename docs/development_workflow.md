# Development workflow

Follow [AGENTS.md](../AGENTS.md) for workflow selection and verification. This
file covers isolation, authorization, integration, publication, and branch history.

## Isolation and small changes

By default, create or reuse an isolated task branch/worktree before changing
repository files. Exception: an explicitly requested small, predictable change
that is not tracked by a GitHub Issue and for which no review is requested or warranted may be
implemented and verified directly on clean local `develop`, in one scoped commit,
without further approval. This permits direct edits and a local commit only,
not merging or integrating a task branch. If uncertainty arises or scope grows
beyond this exception, move the change into a task worktree before continuing.
GitHub Issues always require their own task branch/worktree. The full regression
gate for develop also applies to direct local develop commits; qualification of
the unchanged runtime candidate can be reused for documentation-only updates.

For work requiring isolation, run (based on current local `develop`):

```bash
python3 scripts/agent_worktree.py create 42-bookmark-search --branch feature/42-bookmark-search
```

For isolated work, perform implementation and verification in the reported worktree.
If the expected task worktree may already exist, inspect it first:

```bash
python3 scripts/agent_worktree.py status 42-bookmark-search --branch feature/42-bookmark-search
```

For an issue-free small task, use e.g. `--branch maintenance/update-agent-instructions`.
New branches use `<bug|feature|maintenance>/<issue-id>-<short-title>` when linked
to an issue, or `<bug|feature|maintenance>/<short-title>` otherwise. Use the actual
GitHub number, never a local allocation or a legacy ticket number. Verify the
issue association before work; the helper validates syntax and never contacts
GitHub. Titles are lowercase kebab-case. Once work starts, keep the branch name
stable even if the issue title or type label changes.

Pass the same slug and `--branch` to create, status, and remove. Without `--branch`,
status/remove support existing `agent/<slug>` worktrees only; create requires an
explicit new-style branch. Existing `agent/` and `fix/` branches may be inspected
and removed with `--branch`, but not newly created by this helper. Other legacy
branches remain usable through normal Git commands; do not rename running work.
For a branch that already exists without a worktree, inspect it and deliberately
attach it with `git worktree add <isolated-path> <existing-branch>`; the helper
never silently reuses, resets, or recreates existing state.

Continue an existing worktree for the same task; never reuse it for unrelated work.
Do not edit the user's primary checkout except under the small-change exception;
never switch, stash, or reset it.

Keep changes within the request; avoid unrelated cleanup. Local work and commits
on the agent's own isolated task branch/worktree are explicitly authorized as
part of the requested task; no separate approval is needed unless the user says
otherwise.

An authorized request to implement or work through GitHub Issues also authorizes
creating their local and remote task branches and pushing scoped commits to those
task branches in `timberpile/Boorusama`. Choose the conventional issue branch name
above without a separate naming or push approval, and continue an existing task
branch rather than creating a competing one. Preserve unrelated work; use normal
fast-forward pushes, never overwrite another agent's commits. Report incomplete
verification in the handoff; publishing a work-in-progress task branch does not
claim review or integration readiness. Explicit limits such as "local only" or
"do not push" take precedence. Creating an issue alone does not authorize its
implementation or code publication.

Merging or integrating a task branch always requires explicit user authorization.
Approval such as “this branch can be merged” authorizes the complete task workflow:
verified integration, publication of the approved change to `origin/develop`,
closure of the associated issue after verifying publication, and deletion of the
completed remote task branch and local branch/worktree. Complete these steps
without requesting permission again. Explicit narrower limits (for example,
“local only”, “do not push”, or “keep the branch”) take precedence. This approval
does not cover unrelated outgoing changes, releases, or creation of a PR.
Task-branch publication does not authorize merging, cherry-picking, replaying, or
otherwise integrating its changes into `develop`, pushing `develop`, creating a
PR, closing an implementation issue, publishing a release, or deleting branches.
Modifying `develop` or any other branch/worktree outside the permissions above
requires explicit user authorization.
Outside authorized issue task-branch publication or an approved integration
workflow, code publication, merges, releases, and unrelated remote changes still
require explicit authorization. An explicit issue-creation or issue-work request
also authorizes the scoped issue metadata updates in the
[issue workflow](issue_workflow.md). Use `gh` or the connected GitHub tools and
explicitly target `timberpile/Boorusama`; provide manual instructions for other
repositories.

## Integration

Use a clean checkout and preserve unrelated user changes. Review the approved
diff and stage only that change. Before integration, require the complete local
suite from [engineering guidelines](engineering_guidelines.md#complete-local-test-suite)
on the final combined candidate. An existing pass on that same candidate remains
valid across agent handoffs and documentation/status-only updates. Relevant
runtime/test/dependency changes or a changed develop combination require a new
full pass. Confirm the integrated tree and queue status afterward; record the
checked commit/state and commands in the normal task report.

| Change | Destination | Integration method |
| --- | --- | --- |
| Ordinary feature/fix or other task | `develop`, then `origin/develop` under merge approval | One descriptive Conventional Commit using squash or equivalent replay |
| Explicitly requested task PR | Remote `develop` | Manual squash merge with a descriptive Conventional Commit title |
| `upstream/master` synchronization | `develop` | Real merge preserving upstream ancestry |
| Release promotion from `develop` | `master` | Real merge titled `Merge branch 'develop'` |
| Release history from `origin/master` | `develop` | Fast-forward when possible; otherwise an explicitly approved real merge |

Commit bodies are optional; keep them short and include only useful rationale
or context beyond the title. Do not use `Merge branch ...` as an ordinary squash
commit title. Do not rebase or squash shared upstream/release history.

## Pull requests and publication

- Use a PR only when the user explicitly requests one, regardless of change
  size. Otherwise publish authorized issue work to its task branch and prepare
  the result for separately approved integration. The small-change exception
  above still permits only a direct local `develop` commit.
- Before publication, fetch current references and inspect the task branch
  against latest `origin/develop`. Reconcile relevant changes without overwriting
  shared task-branch history. After a rebase, reread current `AGENTS.md` and this
  workflow. Unresolved integration or verification work must be reported; it does
  not prevent publishing isolated work in progress for a local-agent handoff.
- Authorized issue work uses its conventional task branch name without a
  separate naming approval. For publication outside that authorization, agree
  the branch name before pushing. The current PR policy accepts `bug/`,
  `feature/`, and `maintenance/` with optional issue numbers.
  Legacy `fix/` PR branches remain accepted during the transition; do not create
  new ones. Upstream synchronization, Dependabot, and release-promotion exceptions
  remain unchanged. Keep the same task worktree.
  The validator is loaded from the PR base branch: the new policy must reach
  `develop` before a new-prefix PR can rely on it. Do not bypass that check.
- Keep PR titles descriptive and bodies concise: explain the problem and
  resulting behavior. Use `Refs #<issue-id>` while acceptance is pending;
  use `Closes #<issue-id>` only when the issue exists, all agreed acceptance
  criteria are met, and this integration completes it. Preserve the reference
  in the final squash commit when using commit-based closure.
  Do not include validation statements, test counts/results, tool logs, or
  development history. CI status supplies the validation evidence.
- Required CI checks must pass before marking a PR ready. Keep failing or
  incomplete work in draft and address review changes in the same worktree.
- Merge only after required checks and explicit merge approval. Do not enable
  auto-merge or use rebase merging. Verify the merge and remote branch deletion.
  Local synchronization and cleanup remain separately authorized.

## Upstream synchronization

With explicit authorization for the merge and push, fetch `origin` and
`upstream`, fast-forward local `develop` to `origin/develop`, then merge
`upstream/master` using `--no-ff --no-commit`. No separate task branch or PR is
needed for this authorized integration operation.

Resolve conflicts while preserving fork behavior, regenerate required outputs,
and run the complete local suite before committing. Abort rather than commit an
incomplete merge. Use `chore: merge upstream master`; verify that the upstream
tip remains an ancestor and the checkout is clean before the authorized push.

## Release promotion and history

Prepare the version/changelog on `develop`. A release PR must be explicitly
requested; only `develop` may target `master`. Require an up-to-date branch,
`Pull request policy`, `Release validation`, explicit merge approval, and the
real merge in the table above. Tag/build the approved commit on `master`;
release publication requires separate authorization.

An explicit request to complete a release through a GitHub draft (for example,
using `prepare-release`) authorizes its local preparation integration, pushing
the intended release contents to `develop`, creating the `develop` to `master`
release PR, merging it after the required checks, pushing the exact release tag,
building and uploading verified artifacts to a GitHub draft, and synchronizing
the release history back into `develop`. Honor narrower limits and requested
review checkpoints; do not ask again for these already authorized steps. A
generic preparation request remains local. The draft workflow never authorizes
public publication: the user publishes the draft manually. Existing release
scripts/services remain excluded by that skill. This authorization applies to
executing an explicitly requested draft release, not to editing the skill.

An explicit request to undo recorded release actions authorizes the scoped
recovery integration, normal pushes, and removal of an unchanged draft created
by that run. Preserve later/unrelated work and shared history. Any reversal on
`master` goes through `develop` and a checked release PR with a real merge.
Reverting the whole promotion may also remove pre-existing `develop` features;
prepare the exact reversal diff and resolve that additional scope before merge.
Inspect the full recovery PR diff so later unrelated `develop` work is not
silently promoted alongside the reversal; resolve that extra scope before merge.
Public releases, pushed-tag deletion, and changes outside recorded ownership
need a separately scoped decision. Recovery does not authorize public publishing.

Before new work on `develop`, bring the release merge back from `origin/master`
with authorization. Fast-forward when possible. If `develop` has advanced, merge
`origin/master` into it; never reset or rebase the shared branch. For a history-only
synchronization, the tree diff must be empty. Review and verify any actual file
changes/conflicts, then confirm `origin/master` is an ancestor before pushing.
A release PR behind `master` needs this synchronization before its checks rerun.

## Protected branches and cleanup

- Pushing `develop` needs explicit authorization; task merge approval includes
  publication of that approved task as described above. Force pushes and deletion
  of `develop` are prohibited. Before pushing, inspect outgoing merges with
  `git rev-list --min-parents=2 origin/develop..develop`; only approved upstream
  merges and release-history merges are allowed.
- Direct commits/pushes, force pushes, and deletion of `master` are prohibited,
  including for administrators. Promotion is through the approved release PR.
- After successful, verified integration of a completed task into local `develop`,
  automatically remove its local worktree and branch unless the user asks to
  retain them. Verify the integrated result, cleanliness (including untracked and
  ignored files), and that no pending work or needed artifacts remain. Preserve
  unfinished work and unrelated branches/worktrees. Remove only known disposable
  task-generated files; retain anything uncertain. Never force-remove a worktree.
  Before removal, preserve needed handoffs and durable technical knowledge as
  described in the [issue workflow](issue_workflow.md#documentation-and-handoffs).
  Use `python3 scripts/agent_worktree.py remove <slug> --branch <exact-branch>`
  for matching helper-managed worktrees; omission of `--branch` is for legacy
  `agent/<slug>` only. Otherwise use `git worktree remove` with the exact
  registered path. Delete the exact local
  branch with `git branch -d`. Squash merging does not make task commits ancestors
  of `develop`; if normal deletion refuses, force-delete only after verifying
  patch/tree equivalence and that no unintegrated commits remain.
- Under task merge approval, delete the completed remote task branch only after
  verifying the approved result is in `origin/develop` and that the remote branch
  contains no unintegrated work. Refresh and check the exact remote tip; use an
  expected-tip lease when deleting it so concurrent updates are preserved. Close
  the associated issue and remove workflow-status labels after publication.
  Remote deletion outside this approved task and other cleanup still require
  explicit authorization.

## Issue descriptions

Follow the [issue workflow](issue_workflow.md) for concise descriptions, labels,
claims, completion, and documentation. GitHub Issues are the only tracker for new tasks. Issues and PRs are not
mandatory for ordinary scoped changes. Historical repository work-item files
are available in Git history only; never recreate that queue or mirror issue
status in local Markdown tickets.

## Exclusive Android emulator procedure

For device operations, follow [Android emulator coordination](android_emulator.md).