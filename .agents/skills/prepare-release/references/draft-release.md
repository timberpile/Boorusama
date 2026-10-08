# Draft release delivery

Read this only when the user explicitly requests delivery through a GitHub
draft. Use the current repository workflow for branch operations. All `gh`
operations must explicitly target `timberpile/Boorusama`.

## Record owned actions

Keep a non-secret record at `artifacts/releases/<tag>/actions.json` in the
task worktree (already ignored), or a user-chosen persistent location. Link it
in the handoff. Before cleanup, preserve the record in an authorized durable
location outside that worktree; retain the worktree if it contains the only
copy. For local-only preparation, record the baseline and own edits/commits
without loading the rest of this delivery procedure.

Record repository, version/tag, branch tips before/after, original version and
changelog, the preparation diff/commit, release PR, verified head and merge
parents, tag existence before/after and commit, draft ID/URL, asset names/hashes,
and created artifact/worktree paths. Distinguish newly created resources from
pre-existing ones. Record intent before each write and confirm the observed
result afterward; mark uncertain results after timeouts until reconciled. Never
store tokens, key material, credentials, or secret command arguments.
For reused drafts, snapshot the original metadata and asset inventory; record
each metadata edit and newly uploaded asset with its ID and hash separately.

## Establish the delivery scope

Fetch current `origin` refs and tags; inspect the intended candidate, existing
release PRs, tags, releases, and workflows triggered by branch/tag pushes. Stop
if a required push would trigger public publication through other automation.
Identify existing outgoing commits before integrating or pushing `develop`;
confirm that they belong to the intended release. Preserve unrelated changes
and worktrees. Resolve material candidate or scope changes before delivery.
An existing public release for the intended tag is a stop condition before
delivery writes; report it without changing that release.

Confirm that the production signing key and build tools are available without
exposing secrets. If they are unavailable, complete local preparation and report
the blocker; do not promote an unbuildable candidate or substitute debug signing.
Do not bypass branch protection, force-push, move existing tags, or delete a
release during delivery. Local cleanup follows the development workflow;
remote branch deletion needs separate authorization. Never delete the
long-lived `develop` or `master`.

## Integrate and promote

Before integration or promotion, complete the local test suite required by
`AGENTS.md` against the final prepared diff. Further edits require a full local
rerun before another final review or delivery attempt; passing PR checks alone
do not satisfy this preparation requirement.

1. Integrate the verified preparation as one scoped commit into clean local
   `develop`. Reconcile current `origin/develop` and any required release history
   using the development workflow. Recheck the final version and changelog if
   the candidate changed. Push only the intended release contents normally.
   The explicit draft request fixes the publication branch as `develop`; there
   is no separate task-branch publication unless requested.
2. Create or reuse the release PR with head `develop` and base `master`. Follow
   the repo's PR-description rules. Verify `Pull request policy` and
   `Release validation` passed for the current PR head; pending, failed, or
   skipped checks do not qualify. Stop on failed checks or protection conflicts;
   address only in-scope failures without bypassing checks or changing policy.
3. Merge with a real merge commit titled `Merge branch 'develop'`. With `gh`,
   use `--merge` and `--match-head-commit` for the verified head. Do not enable
   auto-merge, use admin bypass, or delete `develop`. Fetch and verify the merge
   commit on `origin/master`, its parents/ancestry, and its version/changelog.
4. Use that exact merge commit as the immutable artifact and tag source. Do
   builds in an isolated checkout of it, preserving the primary checkout.

## Build and verify artifacts without the release automation

Use normal build commands with FVM, not the CLI's `release` commands or
`github-release.yml`. The ordinary `build.sh apk` path is allowed; ensure it uses
FVM and production options. Inspect the current build configuration for flavor,
release channel, build metadata, and ABI selection rather than copying stale
options. For Android, use `prod`, release mode, `RELEASE_CHANNEL=github`, and the
permanent production signing key.

Prepare the expected Android split APKs for arm64-v8a, armeabi-v7a, and x86_64.
Keep established asset names; inspect the existing receipt naming code as a
reference without executing the release services. Verify each APK directly with
`apksigner` and `apkanalyzer`: production application ID
`com.timberpile.boorusama`, the intended version name, correct ABI, and the
permanent signer certificate, never a debug certificate. The current per-ABI
version-code offsets are +2000 for arm64, +1000 for armv7, and +4000 for x64;
verify these against the current build output/configuration. Record checksums,
sizes, and the source commit. Do not claim device or upgrade acceptance from a
successful build.

Create `boorusama-update.json` directly, matching the current updater's contract.
Inspect the publisher/reader code only as format references. Include version,
fullVersion, buildNumber, tag, releaseUrl, notes, and artifact filenames, sizes,
and SHA-256 values; retain the current schema fields. This manifest belongs only
in the draft assets. Do not publish it separately or update a public feed.

## Tag and create the draft

After successful verification, create an annotated `v<version-name>` tag on the
verified release merge commit and push that exact tag. If it already exists,
verify both local and remote resolution to that commit; stop on any mismatch.
Do not let GitHub create a tag implicitly from its default branch.

Extract the candidate's changelog section into a temporary notes file, preserving
its short categorized bullets. Create the release with `gh release create`,
explicitly passing `--repo timberpile/Boorusama`, `--draft`, `--verify-tag`, the
title, `--notes-file`, and the verified artifact paths, including the manifest.
Draft status is distinct from prerelease status; a prerelease flag never replaces
`--draft`. Apply a prerelease flag only if the user requested it.

If retrying or resuming, inspect the remote state before another write. Reuse an
existing draft for this tag only after verifying its identity and assets; keep
`--draft=true` explicit on metadata edits. Do not overwrite unknown assets or
modify an already public release. A timeout does not establish that creation
failed. Do not delete/recreate a draft or move a tag to recover automatically.
Verified missing assets can be uploaded to the same still-draft release using
`gh release upload`, with exact paths and without `--clobber`. Recheck draft
status and asset hashes before and after; stop on unexpected edits.

Read the release back and confirm `isDraft=true`, the intended tag/commit,
complete release notes, and the expected assets. Compare downloaded draft
assets with local hashes. Never use `--draft=false`, omit `--draft` on creation,
or start public publishing to make a check pass.

## Synchronize and hand off

Bring the verified release merge back into `develop`: fast-forward when
possible, otherwise use the authorized real merge from `origin/master`. Preserve
newer work; verify a history-only synchronization has an empty tree diff and
`origin/master` is an ancestor before pushing. Follow the normal cleanup rules
only after verified integration; preserve needed release artifacts until draft
uploads are verified. Do not roll back remote merges or tags after a later
failure; report the exact partial state and remaining step.

Return the draft URL, release PR and merge commit, version/tag, verified asset
hashes, synchronization status, and any unresolved checks. State that public
download/update and published-release verification remain unperformed while the
release is a draft. The user reviews the draft and clicks **Publish release**;
the skill must stop before that action.
