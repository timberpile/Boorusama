# Development workflow

All repository development happens through GitHub issues and pull requests. The workflow keeps `develop` and `master` protected while retaining design, review, and test context in GitHub.

## Features and fixes

1. Create a GitHub issue that describes the behavior, scope, and acceptance criteria.
2. Update local `develop` without creating a merge commit:

   ```bash
   git switch develop
   git fetch origin
   git merge --ff-only origin/develop
   ```

3. Create an issue-linked branch:

   ```bash
   git switch -c feature/<issue-id>-<short-description>
   ```

   Use `feature/` for features and additive changes. Use `fix/` for bug fixes and corrective changes. The description must contain lowercase letters, numbers, and hyphens only.

4. Implement and verify the change on that branch. Development commits use conventional commit summaries.
5. Push the branch and open a pull request targeting `develop`. Its title must be exactly:

   ```text
   Merge branch '<branch-name>'
   ```

   Include `Closes #<issue-id>` in the pull request body so the issue closes when the pull request merges.
6. Wait for required checks and explicit user approval. GitHub auto-merge must remain disabled.
7. Manually squash-merge the pull request. Keep the generated squash commit title unchanged.
8. GitHub deletes the remote source branch automatically. Synchronize `develop`, then delete the local source branch.

## Protected branches

Direct pushes, force pushes, and deletion are prohibited for `develop` and `master`, including for repository administrators.

- Feature and fix pull requests target `develop`.
- Only `develop` may be promoted to `master`.
- A promotion uses a pull request titled `Merge branch 'develop'` and must link its release-tracking issue.
- GitHub permits squash merging only. Merge commits, rebase merging, and automatic merging are disabled.

The pull request policy workflow validates the base branch, source branch, title, and closing issue reference. Repository settings supply the matching squash title by default and delete merged remote branches.

## GitHub CLI example

For issue `42`:

```bash
git switch -c feature/42-load-original-on-zoom
git push -u origin feature/42-load-original-on-zoom
gh pr create \
  --base develop \
  --head feature/42-load-original-on-zoom \
  --title "Merge branch 'feature/42-load-original-on-zoom'" \
  --body 'Closes #42'
```

After explicit approval to merge:

```bash
gh pr merge \
  --squash \
  --delete-branch \
  --subject "Merge branch 'feature/42-load-original-on-zoom'"
```
