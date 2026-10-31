# Accepted review follow-up handoff — #95

Prepared 2026-10-31. Branch `feature/95-artist-links`.

Verified implementation/test candidate: `9b9c072689907c1e6dede232ce4440164ea2d809`. The final handoff commit changes documentation only; the separate final branch index records that exact resulting HEAD.
Merge base with local develop: `422aeae087c1108e655d85d1a3dac25120456cd6`. Local develop remained `de5928283aa39f0d67d6a834e42d4fa5e9369b86`; primary checkout remained detached at `405ef9ee9c7f0821d3601866373884015c5323f5`.
State: prepared for user review; acceptance and integration remain pending.

## Result and review

Artist sharing uses the standard outer Share icon. Its .bslink filename comes from the originating profile and artist, with portable Unicode-preserving sanitization, control/bidi/device-name protection and a 255-byte UTF-8 bound. The existing envelope is unchanged.

Reviewed originating-profile selection rather than global current-profile substitution, Unicode code-point boundaries, forbidden/path/control characters, reserved filename stems, byte budget and envelope compatibility.

No new sibling-branch prerequisite was added by this correction.

## Verification

- Complete local gate: `./scripts/run_regression_tests.sh` — PASS, 957.2 s, exact candidate `9b9c072689907c1e6dede232ce4440164ea2d809`. Application, every local package/CLI, both shell suites and Python tooling ran; two existing go_router skips remain.
- Android build: `fvm flutter build apk --debug --flavor dev --dart-define-from-file=env/dev.json --no-pub` — PASS, 64.0 s, build commit `9b9c072689907c1e6dede232ce4440164ea2d809`.
- Non-runtime changes after that build: none.
- Scoped final analysis: `fvm flutter analyze --no-pub --no-fatal-infos lib/boorus/danbooru/artists/artist/src/widgets/artist_posts_header.dart lib/core/posts/links/boorusama_link_file.dart lib/core/posts/links/share_artist_link_button.dart test/core/posts/links/artist_link_share_button_test.dart test/core/posts/links/boorusama_artist_link_test.dart` — PASS: 0 errors, 0 warnings, 5 informational findings. Informational findings are not described as lint-clean.
- Changed Dart files formatted with FVM. `git diff --check 422aeae087c1108e655d85d1a3dac25120456cd6 9b9c072689907c1e6dede232ce4440164ea2d809` passed.
- Focused evidence `focused-final-v2`: `fvm flutter test --no-pub --concurrency=6 test/core/posts/links` — PASS (18.6 s). Earlier dirty-state focused runs are superseded by the complete clean committed-candidate pass above.

Raw command, HEAD, tracked diff, exit status and elapsed time are stored in `<primary checkout>/.worktrees/_artifacts/accepted-review-followup-20261031/95-artist-links/` as phase `.json`/`.log` pairs. Interrupted/superseded/failing earlier runs are retained and are not counted as final passes. Native VM finalizer diagnostics occur in some passing Flutter tests; they are reported separately from exit status. Existing native-hook “File modified during build” and Android toolchain support notices also remain; no unrelated toolchain upgrade was introduced.

## Actual Android checks and limits

Device: `emulator-5554`, exclusively leased and controlled with Maestro. Installed normal APK SHA-256: `dc69616491ee8f403f30f50328c09bd19d29f7914e12112bb8a10174c503b5e4`.

Actual public ASCII artist and native Danbooru-malberrybush.bslink filename passed live. Unicode, unsafe names, byte bounds and profile collisions are controlled regression coverage.

Detailed actual observations and provenance are retained in `95-device-observations.json`.

Task fixtures and settings were restored: task-created local groups/posts/topic/feed were removed, settings restored, the original device APK reinstalled with matching installed APK hash, original Safebooru (Danbooru) profile selected and lease released. No remote account mutations or recipient sends occurred. Share/copy checks changed the clipboard and ordinary QA searches remain in local search history; existing history was not cleared.

## User review checklist

1. Open Danbooru Artists > malberrybush > actual Artist page. Check the Posts header standard Share icon.
2. Share the link file: native filename should be Danbooru-malberrybush.bslink.
3. Check a different originating profile and Unicode/long artist names; cancel the chooser without a recipient.

## Delivery boundary

All task changes are committed locally. No PR, push, develop integration, issue closure, branch/worktree deletion or release was performed. This isolated branch pass does not prove a later combined develop candidate; merging sibling changes or rebasing runtime code requires verification of that resulting candidate. User acceptance is still outstanding.

## Correction commits

The prior branch implementation is retained except for the accepted corrections described above. These are the correction checkpoints since the starting handoff:

```text
9b9c072689907c1e6dede232ce4440164ea2d809 fix: share artist links with source profile filenames (#95)
```
