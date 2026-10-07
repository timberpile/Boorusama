# Development workflow

Follow [AGENTS.md](../AGENTS.md) for ordinary implementation. This file covers
integration, publication, and branch history. These actions require explicit
user authorization; implementation approval does not authorize a push or cleanup.

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
  size. Otherwise prepare the result for approved local integration.
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
- Before authorized cleanup, verify the integrated result and that no needed
  work remains. Never force-remove a dirty worktree or discard unmerged work.
  Squash merging does not make task commits ancestors of `develop`; force-delete
  only the exact verified branch when normal deletion refuses.

## Issue descriptions

Describe the problem, relevant reproduction context, and expected behavior
concisely; omit validation reports, logs, and development history.

## Exclusive Android emulator procedure

For device operations, follow [Android emulator coordination](android_emulator.md).
