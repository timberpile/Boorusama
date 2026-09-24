# Development workflow

The standard development workflow uses pull requests to retain review and test context. GitHub issues are recommended for work that benefits from tracked requirements or discussion, but they are not required. Direct commits to `develop` are permitted only when the user explicitly authorizes one for the current change.

In a fresh Git worktree, run `fvm dart pub get` from
`packages/boorusama_cli` before the first `./gen.sh`; the generator imports the
CLI package configuration from that directory.

## Issue descriptions

Keep issue descriptions short and proportional to the problem. Small issues
should use a few concise sentences or bullets describing the problem, relevant
reproduction context, and expected behavior. Include longer explanations or
implementation details only when necessary to understand the issue.

Do not include validation reports, test counts or results, static-analysis
results, testing tool logs, or development history in issue descriptions. Keep
verification details in work reports or review discussions instead.

## Direct commits to develop

- Direct commits to `develop` require explicit user authorization for the current change. Authorization does not carry over to later changes.
- An authorized direct commit may omit the GitHub issue, work branch, and pull request.
- Keep each authorized direct change in a focused conventional commit.
- Except for the explicitly documented `upstream/master` synchronization,
  every local commit added to `develop` must have one parent. Never merge a
  feature or fix branch into local `develop`; replay an authorized direct
  change onto the latest `origin/develop` instead.
- Before pushing local `develop`, verify that its outgoing range contains no
  merge commits:

  ```bash
  git rev-list --min-parents=2 origin/develop..develop
  ```

  The command must produce no output. If it prints a commit, rebuild the
  unpushed commits as a linear chain before pushing.
- Direct commits to `master` remain prohibited.

## Features and fixes

1. Consider creating a GitHub issue to describe the behavior, scope, and acceptance criteria. An issue is recommended for substantial or user-facing work, but it is optional.
2. Update local `develop` without creating a merge commit:

   ```bash
   git switch develop
   git fetch origin
   git merge --ff-only origin/develop
   ```

3. Create a work branch. Include the issue ID when an issue exists:

   ```bash
   git switch -c feature/<issue-id>-<short-description>
   ```

   Without an issue, omit the ID:

   ```bash
   git switch -c feature/<short-description>
   ```

   Use `feature/` for features and additive changes. Use `fix/` for bug fixes and corrective changes. The description must contain lowercase letters, numbers, and hyphens only.

4. Implement and verify the change on that branch. Development commits use conventional commit summaries.
5. Push the branch and open a pull request targeting `develop`. When an issue exists, include `Closes #<issue-id>` in the pull request body so it closes when the pull request merges. Otherwise, omit the closing reference. Keep the description to a few concise bullets describing only the meaningful end-state changes introduced when merged. Do not include implementation details, test history, development phases, temporary steps, or exhaustive file-level summaries unless they are essential to understanding the result.
6. Wait for required checks and explicit user approval. GitHub auto-merge must remain disabled.
7. Manually squash-merge the pull request. Set the resulting commit title to `Merge branch '<branch-name>'`.
8. GitHub deletes the remote source branch automatically. Synchronize `develop`, then delete the local source branch.

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

Direct pushes to `develop` are permitted only under the explicit-authorization rule above. Force pushes and deletion remain prohibited for `develop`.

Direct pushes, force pushes, and deletion are prohibited for `master`, including for repository administrators.

- Feature and fix pull requests target `develop`.
- Only `develop` may be promoted to `master`.
- A promotion uses a merged commit titled `Merge branch 'develop'`. Linking a release-tracking issue is recommended, but not required.
- Feature and fix pull requests use squash merging. Upstream synchronization uses an explicitly authorized local merge commit pushed directly to `develop`. Rebase merging and automatic merging remain disabled.

The pull request policy workflow validates the base and source branches. Issue references remain optional. The squash commit title must be set when merging; repository settings delete merged remote branches.

The workflow checks out the policy script from the pull request's base commit. Keep its invocation compatible with the version on `develop` while changing the policy, or the change's own pull request can fail before the new script is merged.

## GitHub CLI example

For issue `42`:

```bash
git switch -c feature/42-load-original-on-zoom
git push -u origin feature/42-load-original-on-zoom
gh pr create \
  --repo timberpile/Boorusama \
  --base develop \
  --head feature/42-load-original-on-zoom \
  --title "Load original image on zoom" \
  --body 'Closes #42'
```

After explicit approval to merge:

```bash
gh pr merge \
  --repo timberpile/Boorusama \
  --squash \
  --delete-branch \
  --subject "Merge branch 'feature/42-load-original-on-zoom'"
```
