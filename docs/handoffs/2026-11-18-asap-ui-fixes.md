# Five bounded fixes: local implementation and verification

Implemented on `bug/2026-11-18-asap-ui-fixes`, based on
`8155acbfa281a983029de53b659e5f760222e5ec`.
The remote `origin/develop` tip was checked with
`git ls-remote origin refs/heads/develop` and matched that baseline.
The checked implementation and tests are committed as `0c16f5b591db3fcbec42804d22ff332701e51297`.
This report is a subsequent documentation-only change.

## Changes

1. **English-only authoring:** `AGENTS.md` explicitly limits new or changed
   strings to `en-US.json` unless translations are requested. Existing locales,
   English fallback, localization calls and normal generation remain supported.
   This bundle introduces no translation-input changes.
2. **Bookmark sources:** choices follow the displayed direct/subtree structural
   scope, including portable received Post, Pool/Related and native Group origins.
   Local All retains its local projection. Listing results, suggestions,
   unavailable counts, refresh and retry share one effective selection.
   Loaded scopes clear obsolete session selections, including empty Groups that
   omit the filter bar; pending/failed loads and inactive/obsolete views cannot
   clear them. Tag/Seen narrowing does not invalidate a structurally valid source.
3. **Pixiv creator images:** both resolved-Page and metadata-only Work information
   opt into a small artist-row avatar hook. Supplied, validated Pixiv URLs use
   `BooruImage` with captured nullable access, a fixed 40-pixel circular frame,
   activity gating and the existing letter fallback. Captions, source actions and
   the no-Page `PostSource.none()` fallback remain intact. Supported CDN transport
   aliases and credential stripping are unchanged.
4. **Folder mosaics:** inspect at most four existing collection candidates using
   stored cover facts and current policy. Preserve the existing first four cells
   when they already contain the eligible cover; otherwise replace the fourth
   cell with the first eligible Pool/Related candidate. Newly reserved cells
   cannot initiate backfill. Existing visible missing-cover cells and standalone
   cards retain their recovery path. Receiver-local choices, selected covers,
   membership and publication are unchanged.
5. **Live Danbooru/Safebooru Pool cache:** every Pool sharing a last Post receives
   its cover. ID batches remain deduplicated and retain the single-last-candidate
   policy. Request failures preserve good entries and stay retryable through
   normal listing reloads; successful missing candidates remain cached separately.
   Overlapping loads coalesce, and obsolete/disposed generations cannot publish.

## Verification

The final runtime candidate passed **1,382 scoped tests**, with no skipped tests:

```sh
fvm flutter test --no-pub --concurrency=6 \
  test/core/bookmarks \
  test/application/bookmark_hierarchy_screen_flow_test.dart \
  test/boorus/pixiv/works \
  test/boorus/pixiv_following_artist_card_test.dart \
  test/boorus/danbooru_pool_covers_test.dart \
  test/core/content/pixiv_media_request_regression_test.dart \
  test/core/posts/details/mixed_post_details_page_test.dart \
  test/application/pixiv_parent_work_navigation_test.dart
```

After making the mosaic fixtures explicitly use 320 dp and doubled text, the
complete cover file passed again: **33 tests**, no skips, with unchanged runtime:

```sh
fvm flutter test --no-pub --concurrency=6 \
  test/core/bookmarks/public_group_cover_test.dart
```

Coverage includes the actual received-Group route/menu and sync publications,
direct/subtree and empty-Group navigation, filter carry-over, absent profiles,
portable mixed records, exact source matching, loading/error/inactive-view
guards, stable mirror/read state, Pool/native priority, receiver choices,
policy restoration, visible recovery budgets and fixed mosaic geometry.
Work coverage includes saved metadata round trips, both information paths,
narrow/enlarged layouts, captured access across profile switches, revocation,
invalid/missing/failed images, cache reuse and synthetic CDN requests through the
real media wrapper. Supported `i.pximg.net`/`s.pximg.net` requests carry the image
Referer without API credentials; other CDN subdomains gain no transport exception.
The seeded Work tests add no metadata lookups.

Live Pool tests use controlled repository completions and the actual listing
order-change entry point. Their counters measure logical ID-batch calls;
transport-level cascading metadata requests were not measured. Source choices
and newly reserved mosaic candidate selection caused zero metadata discovery
in the tested component paths. Existing visible recovery remains separately
exercised by the bookmark suite.

Affected-scope analysis completed with **0 errors, 0 warnings and 282
informational findings**, exit 0:

```sh
fvm dart analyze \
  lib/core/bookmarks \
  lib/boorus/danbooru/pools/pool \
  lib/boorus/pixiv/works \
  lib/core/posts/details_parts/src/artist_section.dart \
  lib/core/posts/details/src/widgets/mixed_post_details_page.dart \
  test/boorus/danbooru_pool_covers_test.dart \
  test/boorus/pixiv/works/work_creator_avatar_test.dart \
  test/boorus/pixiv/works/work_source_test.dart \
  test/core/bookmarks/bookmark_source_scope_test.dart \
  test/core/bookmarks/bookmark_list_controls_test.dart \
  test/core/bookmarks/public_group_cover_test.dart \
  test/core/bookmarks/bookmark_details_page_test.dart \
  test/core/posts/details/mixed_post_details_page_test.dart \
  test/application/bookmark_hierarchy_screen_flow_test.dart \
  test/core/content/pixiv_media_request_regression_test.dart
```

All 26 changed Dart files passed
`fvm dart format --output=none --set-exit-if-changed`; `git diff --check` passed.
Concurrency 6 came from `python3 scripts/physical_core_count.py`.
The fresh worktree required `fvm install`, application/CLI dependency restoration
and `./gen.sh` for missing ignored runtime outputs. No generated Dart was edited
or committed, and no locale files changed.

Durable logs are in the primary workspace's
`.worktrees/_artifacts/2026-11-18-asap-ui-fixes/`:
`final-regressions-with-empty-scope.log`, `final-mosaic-layout.log`,
`analyze-final.log`, `format-final.log` and `codegen.log`.
The successful runner retains image-failure diagnostics from intentional failure
fixtures, a Dart VM finalizer diagnostic and a pre-existing navigation hit-test
warning. The revocation test consumes only the expected detached image-stream
cancellation failure and separately checks that no stale image remains.

## Limits and delivery

UI verification was widget-only, including real component paths at 320 dp,
doubled text and the keyboard where relevant. No APK, Android/emulator run,
authenticated live service or owner library was exercised. In particular, the
owner's specific blank Pool-only folder/reference was not inspected; this change
does not establish starvation as the cause of a separate Pool-only failure.

The complete application/every-package/repository-tooling integration gate was
not run and remains required before any separately authorized merge. Broader
Safebooru candidate discovery and all other deferred handoff work remain outside
this bundle. No push, PR, integration, issue publication/closure or branch
cleanup was performed.
