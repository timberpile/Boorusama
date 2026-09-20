# RLS-001: Release Android SDK setup fails

- Priority: High
- Affected feature: GitHub release workflow
- Agent/session: Codex, 2026-09-20
- Work branch: `fix/release-android-sdk-tools-package`
- Dependency: None

## Problem

[Release run 35512118328](https://github.com/timberpile/Boorusama/actions/runs/35512118328) fails during `Set up Android SDK`. The pinned setup action requests the removed `tools` package by default, so `sdkmanager` exits before the APK build starts.

## Expected behavior

Both release jobs request only the available `platform-tools` package from the setup action. A new release run proceeds beyond Android SDK setup.

## Acceptance criteria

- The build and published-release verification jobs override the pinned action's package default.
- Workflow syntax and focused configuration checks pass.
- A release run on the updated workflow passes Android SDK setup.

## Progress

- Confirmed the failure in the run log and the default in the pinned action's `action.yml`.
- The focused configuration check failed before the change, finding zero corrected steps.
- Upstream commit `f94243dcc` makes the same `packages: platform-tools` override in its release workflow. The explicit override is required even in setup-android v4.0.1, whose pinned `action.yml` still defaults to `tools platform-tools`.
- The focused configuration check and YAML parse pass after updating both release jobs; `git diff --check` passes.
- [Test release run 35512453886](https://github.com/timberpile/Boorusama/actions/runs/35512453886) completed successfully from the fix branch at `1fdf5aeab`. Android SDK setup, split APK build, APK verification, artifact upload, and draft release publishing all passed.
- The run created a draft prerelease for `v4.5.0-timberpile.2-test` with three APK assets and an update manifest. Published-release verification was skipped because the run used `draft=true`.
