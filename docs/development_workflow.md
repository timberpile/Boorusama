# Development workflow

Follow [AGENTS.md](../AGENTS.md) for workflow selection and verification. This
file covers isolation, authorization, integration, publication, and branch history.

## Isolation and small changes

By default, create or reuse an isolated task branch/worktree before changing
repository files. Exception: an explicitly requested small, predictable change
that is not a work item and for which no review is requested or warranted may be
implemented and verified directly on clean local `develop`, in one scoped commit,
without further approval. This permits direct edits and a local commit only,
not merging or integrating a task branch. If uncertainty arises or scope grows
beyond this exception, move the change into a task worktree before continuing.
Work items always require their own task branch/worktree.

For work requiring isolation, run (based on current local `develop`):

```bash
python3 scripts/agent_worktree.py create <task-slug>
```

For isolated work, perform implementation and verification in the reported worktree.
If the expected task worktree may already exist, inspect it first:

```bash
python3 scripts/agent_worktree.py status <task-slug>
```

Continue an existing worktree for the same task; never reuse it for unrelated work.
Do not edit the user's primary checkout except under the small-change exception;
never switch, stash, or reset it.

Keep changes within the request; avoid unrelated cleanup. Local work and commits
on the agent's own isolated task branch/worktree are explicitly authorized as
part of the requested task; no separate approval is needed unless the user says
otherwise.

Merging or integrating a task branch always requires explicit user authorization.
Modifying `develop` or any other branch/worktree outside the permissions above
requires explicit user authorization.
Publication and remote changes always require explicit authorization. Use `gh`
and explicitly target `timberpile/Boorusama`; provide manual instructions for
other repositories.

## Integration

Use a clean checkout and preserve unrelated user changes. Review the approved
diff, stage only that change, verify the combined result, and confirm the
integrated tree and any queue status afterward.

| Change | Destination | Integration method |
| --- | --- | --- |
| Ordinary feature/fix or other task | Local `develop` | One descriptive Conventional Commit using squash or equivalent replay |
| Explicitly requested task PR | Remote `develop` | Manual squash merge with a descriptive Conventional Commit title |
| `upstream/master` synchronization | `develop` | Real merge preserving upstream ancestry |
| Release promotion from `develop` | `master` | Real merge titled `Merge branch 'develop'` |
| Release history from `origin/master` | `develop` | Fast-forward when possible; otherwise an explicitly approved real merge |

Commit bodies are optional; keep them short and include only useful rationale
or context beyond the title. Do not use `Merge branch ...` as an ordinary squash
commit title. Do not rebase or squash shared upstream/release history.

## Pull requests and publication

- Use a PR only when the user explicitly requests one, regardless of change
  size. Otherwise prepare the result for approved local integration, unless the
  small-change exception above permits a direct local `develop` commit.
- Before authorized publication, fetch current references and reconcile the
  task branch with latest `origin/develop`. After a rebase, reread current
  `AGENTS.md` and this workflow.
- Agree the publication branch name before pushing. The current PR policy
  accepts `feature/<description>` and `fix/<description>` (optionally prefixed
  with an issue number); other local prefixes may need renaming. Keep the same
  task worktree.
- Keep PR titles descriptive and bodies concise: explain the problem and
  resulting behavior. Include `Closes #<issue-id>` only when an issue exists.
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
and run the full Flutter suite before committing. Abort rather than commit an
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
prepare the exact reversal diff and resolve that additional scope first.
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

- Pushing `develop` needs explicit authorization. Force pushes and deletion
  are prohibited. Before pushing, inspect outgoing merges with
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
  Use the helper for matching `agent/<slug>` worktrees, or `git worktree remove`
  with the exact registered path for older task branches. Delete the exact local
  branch with `git branch -d`. Squash merging does not make task commits ancestors
  of `develop`; if normal deletion refuses, force-delete only after verifying
  patch/tree equivalence and that no unintegrated commits remain. Remote branch
  deletion and other cleanup still require explicit authorization.

## Issue descriptions

Describe the problem, relevant reproduction context, and expected behavior
concisely; omit validation reports, logs, and development history.

## Exclusive Android emulator procedure

For device operations, follow [Android emulator coordination](android_emulator.md).
