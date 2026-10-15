# 0035 — GitHub in-app updates

| Field | Value |
| --- | --- |
| Priority | Normal |
| Area | App updates / Android distribution |
| Status | In progress |
| Branch | `feature/0035-github-in-app-updates` |
| Agent/session | ChatGPT, 2026-10-15 |
| Worktree | Remote GitHub branch via connector; no local checkout/worktree available in this session |
| Base | `develop` at `d4e15586f06192f0ff4315d36a3f61ae69a752d5` |

## Problem

The existing GitHub release checker exposes only a Home search-bar indicator and opens the release page. Checks are effectively once per provider lifetime; no on-resume policy or manual status is available. Users must download and install the correct APK manually.

## Scope and acceptance criteria

- [ ] Preserve GitHub-release update notifications and release notes, with at most one automatic foreground check per 24 hours and a forceable manual check.
- [ ] Expose a localized Updates entry/status in Settings and report network errors clearly when checked manually.
- [ ] Parse existing `boorusama-update.json` APK assets; compare Android build numbers as well as version names and choose an APK compatible with the device's supported ABIs.
- [ ] On GitHub Android builds, user explicitly downloads the APK, sees cancel/progress, and can initiate Android's confirmation installer after digest/size and package/version/signature validation.
- [ ] Provide unknown-app-sources permission guidance and a GitHub release-page fallback; never silently install or download.
- [ ] Gate APK installation strictly to GitHub Android builds. Play build's merged Android manifest must **not** request `REQUEST_INSTALL_PACKAGES`.
- [ ] Exercise version parsing, ABI choice, download validation, cooldown, and install safety in automated tests; document device validation not possible in this environment.
- [ ] Do not change the release workflow format or merge into `develop` as part of this task.

## Constraints

Follow `AGENTS.md`, `docs/work/README.md`, and `.agents/skills/implement-change/SKILL.md`. Reuse existing release-manifest receipts and app i18n. Kotlin native platform code should reject arbitrary APK paths. Android must make the final signature decision.

## Progress / verification

2026-10-15: Investigated existing updater, release manifest generator, settings, Android flavors, and signing workflow. Created dedicated branch. GitHub connector allows committed source edits, but the execution environment has no local repository, Flutter/FVM or Android SDK/emulator; compilation, formatting, widget tests, merged-manifest inspection, and on-device installation will remain **unverified** until run in a suitable checkout. Do not mark this work item done or integrate before the required full verification gate.

## Implementation handoff (2026-10-15)

Implemented on this branch:
- Existing GitHub release checker now compares numeric Android build codes where available and parses APK artifact architecture, size and SHA-256 from the existing release manifest.
- 24-hour cooldown for successful foreground checks, one-hour in-memory backoff after errors, cached results in the existing misc Hive box, manual force-check and an opt-out preference persisted in Settings.
- App lifecycle observation at the root (foreground/resume); an Updates settings section reports status and offers Check now.
- Android-only GitHub APK download with progress, cancellation, private cache storage, size and SHA-256 verification; manual OS installer launch, unknown-source permission guidance, browser fallback.
- Android platform channel rejects APKs outside the private updates cache, checks matching package ID, strictly newer version code, expected build/version and exact current signing certificate. The OS installer handles final approval.
- Install-request permission is set through a release-channel Gradle manifest placeholder. GitHub releases should contain REQUEST_INSTALL_PACKAGES; Play and development builds should not.
- Added controlled-clock cooldown tests, ABI/release link tests, build number tests, and settings persistence tests. Added English and German UI strings.

**Not verified**: No local repository/SDK checkout in this session. Cannot run fvm dart format, ./gen.sh, fvm flutter test, Gradle Kotlin compilation, manifest-merge inspection, emulator or physical install tests. Treat this branch as a working implementation candidate, not merge-ready.

**Required checkout verification before merge**:
1. Run `./gen.sh` to generate i18n, then `fvm dart format` on modified Dart files.
2. Run `fvm flutter analyze` for the changed paths and `fvm flutter test test/app_update`. Fix any compilation/test failures; run the full regression suite `./scripts/run_regression_tests.sh` on the integration candidate.
3. Produce signed GitHub release APK and Play AAB variants. Inspect their *merged* manifests: REQUEST_INSTALL_PACKAGES must be present only in GitHub builds, absent in Play builds. Ensure RELEASE_CHANNEL dart-defines reaches Gradle as expected.
4. Perform actual signed version-N to N+1 Android upgrade tests for arm64 and armv7 if available; test unknown-sources opt-in, denied permission, cancel, checksum/size mismatch, signing mismatch, no compatible ABI, app data preservation, and Play variant behavior.
5. Review whether signature rotation should be supported. Current preflight intentionally rejects different signers; user can fall back to the GitHub release page.

No PR, merge, or release was created.
