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
