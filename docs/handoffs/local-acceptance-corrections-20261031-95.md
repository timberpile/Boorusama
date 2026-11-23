# Local acceptance corrections — Issue #95

## Scope and commits

Branch: `feature/95-artist-links`. Initial commit: `d2cbe436fda244333e4bf270af8fe704fd09031c`. Final runtime/test candidate: `5174cb7489713d876c69ece15a239d8dec4a9a83`. This report is a subsequent documentation-only commit; its final HEAD is listed in the aggregate handoff. The complete regression below checked this exact candidate; report-only updates do not change it.

Local corrections only. No push, merge, PR, issue closure or branch deletion was authorized or performed.

## Changes and diagnosis

Moved the existing ArtistLinkShareButton from ArtistPostsHeader to the ArtistIdentity image-overlay action row, immediately beside Follow and before More. Originating-profile identity, safe filenames, shared .bslink serialization/import and standard Share semantics are unchanged. Runtime commit72a328817f66bf3a92f4d18a7d941598c475172b; follow-up5174cb removes an obsolete test import.

Production header/share-adapter tests cover320dp at 1x/2x and 1280 dp at 2x, action ordering/safe edges and the existing single-document payload.

## Executed checks

- `fvm flutter test --no-pub --concurrency=6 test/core/posts/links test/boorus/danbooru_artist_page_test.dart test/boorus/danbooru_artist_socials_test.dart` — PASS; evidence `95-focused-qualified.log/.json`.
- `fvm flutter analyze --no-pub --no-fatal-infos lib/boorus/danbooru/artists/artist/src/widgets/artist_identity.dart lib/boorus/danbooru/artists/artist/src/widgets/artist_posts_header.dart test/core/posts/links/artist_link_share_button_test.dart test/boorus/danbooru_artist_socials_test.dart` — PASS; evidence `95-analysis-final.log/.json`.
- `fvm flutter build apk --debug --flavor dev --no-pub` — PASS; evidence `95-build.log/.json`.
- `./scripts/run_regression_tests.sh` — PASS; evidence `95-full-final-v2.log/.json`.

The complete runner includes application tests, every tested package/CLI and repository tooling. Default concurrency was 6 physical cores. Scoped analysis: 0 errors, 0 warnings, 2 informational findings (details in its log). The exact build command and source state are recorded above. No old handoff pass is substituted for this candidate.

## Device evidence and remaining acceptance

Normal exact-source APK on emulator-5554: ArtistIdentity showed Follow, the existing standard Share icon (accessible Boorusama Link File label), then More, all in the upper image overlay. The Posts header no longer contained the action. Invoking it opened the Android share chooser for the artist document; the chooser was dismissed without choosing a recipient or sending data. Screens95-live-upper-share and95-live-share-chooser. Manual review: open Artist Page, find Share beside Follow in the upper image overlay, invoke it and inspect the .bslink name/system share sheet, dismiss it, and confirm profile identity on import. Wide layout and enlarged text are covered by targeted widget tests; do not mistake a Posts-section Share action for the intended header location.

## Integration and evidence limits

Individual branch verification does not verify a future combined develop candidate. That candidate needs the complete integration gate after any runtime/test/dependency changes.

Durable local logs, JSON provenance and private device evidence: `/home/timber/code/Boorusama/.worktrees/_artifacts/local-acceptance-corrections-20261031/`. Important development files were retained outside `/tmp`. GitHub claim metadata stayed local after automatic approval review rejected the attempted persistent issue comment under this local-only task; no comment was posted.
