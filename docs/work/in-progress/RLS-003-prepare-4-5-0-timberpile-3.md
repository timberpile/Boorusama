# Prepare 4.5.0-timberpile.3 release metadata and notes

Priority: High
Affected feature: Local develop release preparation

## Request and acceptance criteria

- Prepare application version `4.5.0-timberpile.3+187` (previous published release `.2+186`).
- Summarize all user-relevant changes since published `v4.5.0-timberpile.2`, using the actual tag tree as baseline.
- Keep release notes in English, following CHANGELOG.md; short bullets and separate `Breaking changes`, `Major changes`, and `Fixes and improvements` subsections. Breaking changes go first and describe lost compatibility concretely.
- Include only changes already integrated on develop. Include the now-integrated DATA-010/DATA-012 changes; exclude other queued work.
- Verify actual reader compatibility and release metadata; preserve all older changelog sections byte-for-byte.
- No promotion, tag, remote push or release publication. Prepare changes for user review before develop integration.

## Claim

Claimed 2026-10-05 by coordinator `/root`; implementer `/root/release003`; branch `chore/4-5-0-timberpile-3`; worktree `/home/timber/code/Boorusama/.worktrees/release-4-5-0-timberpile-3`.

Read AGENTS.md, docs/development_workflow.md, docs/work/README.md and release CLI documentation/source. Scope: pubspec.yaml, CHANGELOG.md and this ticket only. Source tests must not be changed to accommodate prose.

## Implementation and verification (2026-10-05)

- Prepared `4.5.0-timberpile.3+187` and 24 short English release-note bullets. Breaking changes appear first, with the disappearance of unsupported existing data in bold.
- Audited all commits and changed paths from actual `v4.5.0-timberpile.2` to current develop `4a5881332`; excluded documentation-only work and already shipped `.2` features, and included completed DATA-010/DATA-012 work. The coordinator verified the previous published release was `.2+186`.
- Reader audit: profile Hive loading requires canonical UUID keys; integer-owned pin/feed rows are ignored; numeric profile references in archives fail validation. Bookmark loading ignores old URL-only rows, and the bookmark backup codec accepts only source version 4. No local migration or converter exists for these records. Other supported legacy JSON/ZIP categories remain importable.
- Scheduled refresh is disabled, while initial population of previously unattempted feed entries remains possible. Notes therefore describe scheduled refresh rather than claiming every request requires manual refresh.
- `fvm dart pub get` succeeded in the fresh CLI worktree. All 75 existing release CLI tests and all 20 Android release-script scenarios passed.
- The production `PubspecInfo`, `ReleaseVersion`, and `Changelog.sectionFor` implementations parsed the exact candidate as `4.5.0-timberpile.3+187`, build `187`, tag `v4.5.0-timberpile.3`, and extracted all three subsections. Older changelog sections are byte-for-byte identical to the base checkout.
- No application source or tests changed. The complete Flutter suite was not repeated for metadata-only edits; the coordinator verified 2,219 tests on the exact integrated application tree at `4a5881332`. No APK build, device test, promotion, tag, push, or publication was performed.
- Prepared for coordinator and user review; local develop integration still requires explicit approval. This ticket remains in progress until that delivery step is approved and verified.

## Coordinated review (2026-10-05)

Coordinator reviewed commit `282fab92c6b63eadddbe4aef158788d1c1e7ef77`: only version, concise changelog and this ticket changed; candidate worktree is clean. Independently verified unchanged historical changelog bytes and ran the production version/tag/build/changelog extractor successfully. Read fresh passing test logs (75 release CLI tests, 20 Android script scenarios). Prepared isolated branch is ready for user review; develop integration and publication remain unapproved.
## Wording review (2026-10-05)

- Simplified all major-change bullets and several fixes following user feedback, focusing on everyday benefits while retaining the same integrated feature coverage and explicit compatibility warnings.
- Version remains `4.5.0-timberpile.3+187`; only changelog wording and this evidence entry changed. Production changelog extraction, older-section byte preservation, and `git diff --check` were verified again. Existing release test results remain applicable; no source or tests changed.

## Approved import follow-through (2026-10-05)

- Added the approved DATA-010 requirement for matching site profiles during bookmark imports to Breaking changes, and updated the concise import improvement wording for DATA-012 profile selection. Both changes are now integrated on develop `4a5881332` and included in this release candidate.
- Version and older release sections remain unchanged. Verified production release parser/changelog extraction, byte-for-byte older-section preservation, and diff whitespace checks. No application source or tests changed.

## Current develop alignment (2026-10-05)

- Rebased the release branch onto `4a5881332`, retaining the coordinator's ticket criteria/review and the latest concise wording. Resolved only ticket conflicts; application source matches develop. Reread current AGENTS.md and development workflow after rebase.
- Verified exact version/build/tag and all three release-note subsections with the production parser; older changelog sections remain byte-for-byte identical to develop. `git diff --check` passes. No primary-checkout edits, release integration, or remote actions were performed.
