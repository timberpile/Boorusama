---
name: prepare-release
description: Prepare a new Boorusama version and concise categorized changelog, optionally deliver through a GitHub draft, or undo recorded release actions on request. Never publish a public release.
---

# Prepare a release

Prepare a reviewable version and changelog update from the intended release
candidate. When explicitly asked to complete the release through a GitHub draft,
also perform integration, promotion, tagging, builds, draft creation, and release
history synchronization. Follow [AGENTS.md](../../../AGENTS.md) and the
[development workflow](../../../docs/development_workflow.md) for isolation,
integration, and authorization. Base isolated preparation on `develop`.

A generic request to prepare a release stays local. An explicit request such as
"Create the next release through a GitHub draft" authorizes the draft delivery
steps described in that workflow; do not ask for each step again. Show the
prepared version, release notes, candidate, and check results before starting
delivery. Respect any narrower authorization or requested review checkpoint.
Creating or editing this skill does not authorize executing a release.

The final GitHub release must remain a **draft**. Publishing it publicly is the
user's manual step, including when they request "the full release". Do not
publish to Google Play, mark a draft public, or change a public update feed.
An explicit request to remove this draft-only policy is a separate skill/policy
change; do not treat a request to run the release as that policy change.

Record the skill's own changes using the **Record owned actions** section in
[Draft release delivery](references/draft-release.md), including for local-only
preparation; local-only work needs just that section. If the user explicitly
requests undo/revert, use
[Requested recovery](references/recovery.md) instead of preparing another
release. Never roll back automatically after a failed step or promise that all
shared history and external effects can be erased.

## Existing release automation is deliberately excluded

Do not run `release.sh`, the CLI's `release` commands, or the release services in
`packages/boorusama_cli/lib/src/release`. Do not invoke them indirectly through
`build.sh`, another wrapper, or a release workflow. Prepare `pubspec.yaml` and
`CHANGELOG.md` directly. Do not repair or extend that automation as part of this
skill. It does not implement the fork's current release workflow; even its plan
mode can push a tag.

Read `.github/workflows/release-validation.yml` for validation requirements and,
when useful for the handoff, `.github/workflows/github-release.yml` for the
existing build/publishing behavior. Reading these files does not authorize
dispatching the release workflow or using its release commands. Required PR
validation may run normally, including tests of the existing tooling.

## Establish the candidate and increase the version

- Identify the current version, intended candidate commit, and previous release
  tag. Inspect the actual file changes since that release as well as relevant
  commits. Squash or merge history can repeat already shipped work; commit
  subjects alone do not establish the release contents.
- Unless the user specifies another target, increase the last numeric component
  of the current release version by one and the build number by one. Preserve
  the fork's base version and suffix convention: for example,
  `4.5.0-timberpile.3+187` becomes `4.5.0-timberpile.4+188`. For a plain `X.Y.Z`
  version, increment the patch component. Clarify an unfamiliar version scheme
  rather than silently changing it.
- Set `pubspec.yaml` to the new full version. The top changelog heading is
  `# <version-name>`, without a leading `v` or the `+<build-number>` suffix.
- When continuing an already prepared candidate, keep its target version;
  do not increment again merely because the skill is invoked again. Check for
  conflicting existing version sections and known release tags. Resolve
  uncertainty about the previous release or intended target before finalizing
  the update; disclose remote state that has not been checked.

## Write short, useful release notes

Keep the changelog's existing language, currently English. Derive the notes from
changes actually included in the candidate. Preserve previous release sections
and reuse any relevant draft notes, checking them against the final changes.

Use these categories in this order; omit categories with no entries:

- **Breaking changes:** lost compatibility, changed defaults with significant
  consequences, unsupported old data/exports, or required user action. State
  the consequence and any required action directly. Do not promise migration
  or recovery unless the implementation supports it.
- **Features:** additions and substantial improvements that users will care
  about. Describe the capability or benefit, not the implementation.
- **Fixes and improvements:** small behavior changes, polish, and bug fixes.
  Combine closely related minor fixes when that keeps the list useful.

Write brief bullets, preferably short phrases. Keep one main point per bullet;
split long sentences instead of adding clauses. Put noteworthy changes first
within each category. Avoid technical identifiers, ticket numbers, commit logs,
test results, and internal-only refactors unless they explain a user impact.
Keep breaking-change consequences explicit even when they need slightly more
space. Check both missing noteworthy changes and claims about unfinished or
unintegrated features.

## Verify and hand off

- Check that the version increased correctly and matches the nonempty top
  changelog section. Check the final diff for unrelated changes and Markdown
  errors. Preserve the top-level version headings used by changelog readers.
- Use FVM for Dart/Flutter checks. During preparation, run the directly relevant
  version and changelog-reader tests, currently
  `test/version_test.dart` and `test/core/changelogs/changelog_repository_test.dart`,
  and `git diff --check`. After the last edit, run the complete local suite
  required by `AGENTS.md` before final review, handoff, or starting delivery,
  including for version/changelog-only changes. Resolve failures and rerun the
  complete suite after further edits. Targeted passes and release CI do not
  replace this local qualification; required PR checks must also pass for the
  final candidate. Tests of existing release tooling remain allowed as part of
  the complete suite; never execute the excluded release commands or services
  or substitute their tests for candidate validation. Generate output only when
  required by changed inputs or missing generated files.
- Report the old and new full version, previous release baseline, candidate
  commit, changed files, checks actually performed, and unresolved blockers.
  Distinguish local preparation from CI, device, upgrade, and publication
  verification; do not infer those results from local tests.
- For an explicitly requested GitHub draft delivery, continue with
  [Draft release delivery](references/draft-release.md). Otherwise report the
  local preparation and remaining delivery steps. Preserve authorization
  already granted in the conversation without asking for it again.
