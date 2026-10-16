# Upstream v4.6.1 migration implementation report

**Completed locally:** 2026-10-16

**Task branch:** `maintenance/upstream-v4.6.1-migration`

**Worktree:** `.worktrees/upstream-v4.6.1-migration`

## Commits and ancestry

- Current fork baseline: `e8bf883912ecd5a8c4154472a962aa0aabf0c09a`.
- Decision-document import: `37a32f617ade5530ea988c20b6e6f5684bd046f3`.
- Pinned upstream v4.6.1 commit: `5b04bf6a164f028d41701299367d0dde74dde330`.
- Real two-parent merge: `c08bb851acfe253e65cd307660cdbe465894fe7c`.

The merge commit has parents `37a32f617ade5530ea988c20b6e6f5684bd046f3`
and `5b04bf6a164f028d41701299367d0dde74dde330`. The pinned upstream commit is an
ancestor of the result.

## Implemented scope

All 68 approved decisions in `decisions.md` were applied while resolving the
upstream merge. The result includes the approved bootstrap/runtime boundaries,
storage and identity safeguards, cache and native platform changes, coordinated
network recovery, site compatibility, Kurumi and input/accessibility updates,
grid/viewer/search behavior, durable download sidecars and lifecycle work, and
the release-policy changes.

Key protected outcomes include:

- Existing bookmark Hive fields 15 and 16, profile UUIDs, `PostOrigin`, bookmark
  identity, folders, Following, and backup compatibility remain intact.
- `Post.sitePostId` exposes genuine site identifiers without introducing a new
  bookmark Hive field; Sankaku and Pixiv retain their approved special handling.
- `ApiRequestCoordinator` remains the single request-admission and pacing layer.
- Fork package identity, flavors, signing configuration, and privacy defaults are
  retained; no signing material was replaced.
- The candidate version is `4.6.1-timberpile.1+190`, the changelog starts with
  `4.6.1-timberpile.1`, and `background_downloader` is pinned to
  `fd67fff9ee4ad4cdf415dc3285289cad9289cefe`.
- A prioritized [manual acceptance checklist](MANUAL_ACCEPTANCE_CHECKLIST.md) is
  provided for user-run upgrade, data, network, media, download, and responsive
  UI checks.

## Verification

The final runtime tree represented by merge commit `c08bb851a` passed:

- `./scripts/run_regression_tests.sh` — exit 0. This covered 3,796 application
  tests, every package and the CLI, pull-request policy tests, Android release
  script tests, and 61 Python tooling tests.
- `fvm flutter analyze --no-fatal-infos` — exit 0 with no errors or warnings.
  The strict analyzer invocation reports the candidate's 193 info-level
  diagnostics and therefore exits nonzero under the repository's fatal-info
  default.
- `fvm dart format` on changed Dart files — passed.
- Focused core, HTTP recovery, Realbooru, and complete Kurumi suites — passed.
- `git diff --check`, staged diff checks, unresolved-index checks, conflict-marker
  checks, and both merge ancestry checks — passed.

The complete regression suite was rerun after the final warning cleanup, so its
result applies to the committed runtime tree. This report and the README status
update are documentation-only changes made afterward.

## Remaining acceptance and authorization boundaries

The following were not performed and remain explicit acceptance work:

- User-run manual UI and upgrade checks in the linked checklist.
- A physical-device or emulator Android build/install/upgrade test, including
  verification of effective split-APK version codes and the installed signer.
- Live Rule34 API-host behavior and public network/CDN validation. The existing
  functioning host remains the fallback where live evidence was unavailable.
- Play Store version-code allocation checks and any public release validation.

No branch was pushed, no pull request was created, no integration into `develop`
or `master` was performed, and no tag, draft, artifact, or release was published.
Those actions require separate authorization. Because the device/native/live
checks above remain open, this report records local implementation and automated
verification rather than claiming production upgrade acceptance.
