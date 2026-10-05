# Development workflow

Small and medium features and fixes reach local `develop` as one descriptive
Conventional Commit after review and explicit approval. Pull requests are for
genuinely large branches that need GitHub review and test context; they use
squash merging with a descriptive commit title. GitHub issues are recommended
when useful, but repository queue tickets do not require them. The coordinating
agent delegates every queue ticket's implementation to a subagent, with one
dedicated worktree and branch per ticket. Intermediate commits on that branch
are allowed. Publication to a remote remains a separate authorized action.

In a fresh Git worktree, run `fvm dart pub get` from
`packages/boorusama_cli` before the first `./gen.sh`; the generator imports the
CLI package configuration from that directory.

The current `libavif` Rust native hook can repeatedly emit `File modified during
build. Build must be rerun.` even on an unchanged checkout. Cargo declares
`native/vendor/libavif` as a dependency directory; `native_toolchain_rust`
converts it to a file URI without a trailing slash. `hooks_runner` then treats
the directory as a missing file, records the current time, and invalidates its
cache on the next run. A verbose Flutter test log identifies this dependency.
Verify the test exit code and unchanged checkout before attributing this
message to concurrent source edits; repeating the build alone does not fix
the dependency URI classification.

## Exclusive Android emulator procedure

The host-wide, standard-library CLI is `python3 scripts/emulator_lease.py`.
Its `claim`, `renew`, `release`, and `status` commands use one lease file per
exact emulator serial in `/tmp/boorusama-emulator-leases-<uid>`. A claim records
an owner session/worktree label, a hash of a unique token, and a 30-minute
expiration. The raw token appears only in the successful claim output.
`status` and a busy claim report the owner and expiration without revealing the
token. The owner must retain the token returned by its claim.

1. Discover available serials with `adb devices -l`. Choose one exact
   `emulator-NNNN` serial; discovery does not reserve it.
2. Run `python3 scripts/emulator_lease.py claim emulator-NNNN --owner
   "<agent-session> <worktree-path>"`. Proceed only when the command succeeds.
   If it says `busy`, leave that serial alone. `python3 scripts/emulator_lease.py
   status emulator-NNNN` can inspect a lease without changing it.
3. Immediately before **every** device-affecting command or Maestro call, run
   `python3 scripts/emulator_lease.py renew emulator-NNNN --token <token>`.
   Stop using the emulator if renewal fails. Each individual operation must
   finish in less than 20 minutes; split longer Maestro flows into steps and
   renew between steps. A device-free APK build does not need a lease.
4. Set `device_id: "emulator-NNNN"` on every Maestro call. Use
   `adb -s emulator-NNNN ...` for every ADB device command and
   `fvm flutter ... -d emulator-NNNN` for Flutter device commands. Do not use a
   busy device as an implicit fallback.
5. After the final operation, run `python3 scripts/emulator_lease.py release
   emulator-NNNN --token <token>`.

The lease is a coordination mechanism among compliant sessions on the same
host and OS user. It does not lock the emulator itself. A short `flock` guards
each lease update, while expiration recovers abandoned reservations. Since no
heartbeat runs in the background, renew before each bounded operation.

## Issue descriptions

Keep issue descriptions short and proportional to the problem. Small issues
should use a few concise sentences or bullets describing the problem, relevant
reproduction context, and expected behavior. Include longer explanations or
implementation details only when necessary to understand the issue.

Do not include validation reports, test counts or results, static-analysis
results, testing tool logs, or development history in issue descriptions. Keep
verification details in work reports or review discussions instead.

## Single-commit integration on develop

- Small and medium features and fixes, including queue tickets, use one local
  commit on `develop` after verification and explicit user approval. A pull
  request is not required. Integrate an isolated ticket branch with a squash or
  equivalent replay, checking that unrelated changes are not staged.
- An authorized non-ticket change may omit the GitHub issue, work branch, and
  pull request. Authorization for a direct change does not carry over to later
  changes.
- Give every single-parent feature or fix commit a specific Conventional
  Commit summary, such as `feat(dev): reserve emulators across agent sessions`.
  Do not use `Merge branch '<branch-name>'` for a squash commit. Keep the
  summary only, without a commit description.
- Except for the explicitly documented `upstream/master` synchronization,
  every local commit added to `develop` must have one parent. Never merge a
  feature or fix branch into local `develop` with a merge commit; squash or
  replay its approved change onto current local `develop` instead.
- Before pushing local `develop`, verify that its outgoing range contains no
  merge commits:

  ```bash
  git rev-list --min-parents=2 origin/develop..develop
  ```

  The command must produce no output. If it prints a commit, rebuild the
  unpushed commits as a linear chain before pushing.
- Direct commits to `master` remain prohibited.

## Features and fixes

1. For a queue ticket, the coordinating agent selects an eligible task,
   claims it under `docs/work/in-progress/`, and assigns implementation to a
   subagent. Record the branch, dedicated worktree, and implementer in the
   ticket. The coordinator reviews the result; the implementer may work on
   its assigned ticket directly without delegating it again. Choose the local
   single-commit path for small or medium work. Use a pull request only when
   the branch is genuinely large enough to need GitHub review context.
2. Create a dedicated branch and worktree. Base local single-commit work on
   current local `develop`; fetch and base a large pull-request branch on
   latest `origin/develop`. Do not switch a shared or dirty primary checkout
   just to start ticket work, and do not reuse a worktree or branch across
   tickets. For local work, for example:

   ```bash
   git worktree add -b feature/<short-description> \
     .worktrees/<short-description> develop
   ```

   Use `feature/<issue-id>-<short-description>` or
   `feature/<short-description>` for features/additions, and the corresponding
   `fix/` names for fixes. Include the GitHub issue ID only when one exists.
   Branch descriptions contain lowercase letters, numbers, and hyphens.
3. The implementer changes and verifies only that ticket in its worktree,
   following [the engineering guidelines](engineering_guidelines.md). Keep
   conventional commit summaries without descriptions. The coordinator
   checks the acceptance criteria and evidence before presenting it for user
   review. Do not mark the ticket done without verified criteria.
4. For small or medium work, present the verified result for user review.
   After explicit approval, stage only that ticket's change on current local
   `develop`, verify the combined result, and create one single-parent commit
   with a specific Conventional Commit summary. Confirm the resulting tree and
   ticket status. Keep remote publication and branch cleanup separately
   authorized.
5. For a genuinely large branch, obtain authorization to publish, then push
   it and open a pull request targeting `develop` with a specific technical
   title. When a GitHub issue exists,
   include `Closes #<issue-id>` in the body; otherwise omit it. Keep the body
   to a few concise end-state bullets, without test reports, development
   history, or exhaustive file lists.
6. Wait for required checks and explicit user approval. Do not enable
   auto-merge. If review changes are needed, the implementer updates the same
   branch/worktree and the coordinator presents it again.
7. After approval, manually squash-merge the pull request into `develop` as
   one commit with a specific Conventional Commit title describing the change.
   Do not use `Merge branch '<branch-name>'` for this single-parent commit.
8. Verify the pull request merged and its remote branch was deleted. Then
   synchronize `develop`, remove the ticket's local worktree, and delete its
   local branch. A squash does not make the branch's commits ancestors of
   `develop`; if normal local branch deletion refuses, force-delete only the
   exact branch after verifying the merged result and that no needed work
   remains. Never clean up an unmerged or still-needed branch/worktree.

## Incorporating upstream changes

Synchronize `upstream/master` by merging it locally into `develop` and pushing the resulting merge commit directly. This requires explicit user authorization for each synchronization. Do not create a synchronization branch, issue, or pull request.

The merge commit has the previous `develop` tip and the incorporated `upstream/master` tip as its parents. This ancestry records exactly which upstream changes have already been merged and keeps later synchronizations focused on new upstream commits. Do not rebase or squash an upstream synchronization: rebasing rewrites the shared fork history, while squashing discards the upstream ancestry.

1. Obtain explicit authorization to create and push the upstream synchronization merge commit directly on `develop`.
2. Update the local remote references and fast-forward `develop` to its remote tip:

   ```bash
   git fetch origin --prune
   git fetch upstream --prune
   git switch develop
   git merge --ff-only origin/develop
   ```

3. Start the merge without committing so conflicts, generated files, and verification can be handled before creating the single merge commit:

   ```bash
   git merge --no-ff --no-commit upstream/master
   ```

4. Resolve any conflicts, preserving both the upstream changes and intentional fork-specific behavior. Stage every resolved file:

   ```bash
   git add <resolved-files>
   ```

5. Regenerate derived files and run the full test suite against the uncommitted merge result:

   ```bash
   ./gen.sh
   fvm flutter test
   ```

   Review and stage any generated changes before continuing. If the merge must be abandoned, run `git merge --abort` instead of committing a partial result.

6. Create the single merge commit:

   ```bash
   git commit -m "chore: merge upstream master"
   ```

7. Verify that the upstream tip is an ancestor of `develop` and that the worktree is clean:

   ```bash
   git merge-base --is-ancestor upstream/master develop
   git status --short --branch
   ```

8. Push the merge commit directly:

   ```bash
   git push origin develop
   ```

## Protected branches

Pushing local `develop` requires separate explicit authorization; approval for a local commit does not authorize a push. Force pushes and deletion remain prohibited for `develop`.

Direct pushes, force pushes, and deletion are prohibited for `master`, including for repository administrators.

- Large feature and fix pull requests target `develop`.
- Only `develop` may be promoted to `master`.
- A promotion uses a merged commit titled `Merge branch 'develop'`. Linking a release-tracking issue is recommended, but not required.
- Large feature and fix pull requests use squash merging with a descriptive Conventional Commit title. Upstream synchronization uses an explicitly authorized local merge commit pushed directly to `develop`. Rebase merging and automatic merging remain disabled.

The pull request policy workflow validates the base and source branches. Issue references remain optional. Set the descriptive squash commit title when merging; repository settings delete merged remote branches.

The workflow checks out the policy script from the pull request's base commit. Keep its invocation compatible with the version on `develop` while changing the policy, or the change's own pull request can fail before the new script is merged.

### Release validation

The `Release validation` job runs for pull requests targeting `master` and can
also be started manually. It installs the Flutter version from `.fvmrc` through
FVM, initializes dependencies and generated code, analyzes application code and
workspace packages, and runs application, CLI, and tooling tests.
Informational lints do not fail the check. Analysis excludes root application
tests because of existing cast warnings; those tests are compiled and run.
Warnings and errors in the analyzed code fail validation.

After publishing this workflow and completing a successful run, add
`Release validation` to the required status checks for `master`, alongside
`Pull request policy`. Keep the up-to-date requirement enabled. Committing the
workflow locally does not activate GitHub protection.

Dependabot Actions updates target `develop`. The policy permits their
`dependabot/github_actions/*` branches only when the pull request author is
`dependabot[bot]` and both source and target repositories are
`timberpile/Boorusama`. The workflow passes this event metadata through
environment variables, preserving the validator's two-argument interface.

## GitHub CLI example

For issue `42`:

```bash
git fetch origin
git worktree add -b feature/42-load-original-on-zoom \
  .worktrees/42-load-original-on-zoom origin/develop
git push -u origin feature/42-load-original-on-zoom
gh pr create \
  --repo timberpile/Boorusama \
  --base develop \
  --head feature/42-load-original-on-zoom \
  --title "feat(posts): load original media on zoom" \
  --body 'Closes #42'
```

After explicit approval to merge:

```bash
gh pr merge \
  --repo timberpile/Boorusama \
  --squash \
  --delete-branch \
  --subject "feat(posts): load original media on zoom"
```

After confirming the merge and remote branch deletion, synchronize `develop`
and remove the exact local worktree and branch. Do not force-remove a dirty
worktree. A squash-merged branch may need `git branch -D` after its result and
any remaining commits have been checked, because its commits are not ancestors
of `develop`.
