# P1: Timeline prefetch integration package

## Follow-up: Following Feed Load More placement (verified)

After the previously qualified runtime candidate `c360ce0611bdfbff85d8a7510e91801591f656ac`, the user reported a persistent `Load More` action on opening a long cached Following Feed. The cause is the floating `cached-feed-load-older` action, which had no scroll-position gate; the shared `RawPostGrid` also offered a second identically labeled manual footer for short feeds.

The scoped correction tracks the feed's own scroll controller, including viewport/content metric updates. It shows the explicit pre-history action only within 48 logical pixels of the bottom, including non-scrollable feeds. The shared default footer is hidden until history has explicitly started, when it remains available to recover from a bounded automatic fill that still leaves insufficient content. Other timelines retain the same default footer. Existing cached history access guards, cached feed filters, and update/coverage notices remain unchanged. The regression test checks initial long-feed invisibility, bottom visibility, disappearance after returning to the top, exactly one `Load More` action at the bottom, explicit remote-history dispatch, and the post-start manual fallback.

**Verification complete:** the formatted candidate `bf6286922618890b5733a849138ed3ed0d2a7544` passed all 215 affected feed/listing tests, the complete suite (6,208 application tests plus every package/CLI and repository tooling), and independent source review. Affected analysis reported zero errors/warnings and six infos (exit 1 because infos are fatal). The user approved integration after fetching these changes and requested no further long live campaign. Earlier Android evidence remains explicitly tied to `c360ce061...`. The unreproduced Grid Size symptom remains unchanged, as requested. Realbooru performance investigation is deferred by user decision.

**Branch:** `feature/160-timeline-prefetch-package`
**Issues:** #160, #162 (not #161, whose Pixiv Explore conversion belongs to P8)
**Base:** `origin/develop` at `266a14c0f87f29213d48696bda7c806dc1d05b6e`
**Original source:** `feature/162-unified-page-prefetch` at `dfe1c4690b1dc91d8bc4dc38321be478fac8fa11`, which includes #160 and is directly descended from the base.
**Integration:** Approved by the user on 2026-11-09 after fetching the latest
commits. Publish through the repository integration workflow.

## Work included

- Reuse the shared viewport-based thumbnail cache extent (one viewport) from #160; explicit caller overrides remain supported.
- Reuse a single shared PostGrid pagination prefetch controller with the two-viewport dispatch threshold, bounded three-page fill cycle, and active foreground/route/dispatch guards from #162.
- Keep filtered/sorted cached Following feeds entirely local until **Load older posts / History** is explicitly requested. The shared automatic prefetch is disabled beforehand, including when an older cached page contains fewer than one viewport of posts. Propagate the same source-history gate into the viewer route so viewing a cached post cannot silently trigger remote history.
- After explicit history start, permit bounded shared continuation. An explicit fetch also renews the idle-fill budget without causing an infinite automatic loop.
- Preserve the existing source-specific cursors, GIF/media format selection, Pixiv Favorites settings, and regular pagination controls.

## Realbooru: mandatory measurement before a behavior change

The user's combined candidate still reported lagging Realbooru thumbnails while Gelbooru and Pixiv looked good. A code review shows Realbooru is Gelbooru-v2 thumbnail-only: for high image quality, `gelbooruV2ThumbnailOnlyGridThumbnailMedia` may return two JPEG probes and then three alternate format probes, with the regular thumbnail as placeholder. `ImageCandidatePicker` currently races the first two decoded variants, expands after an 800 ms deadline, and cancels losers. This is a **candidate explanation**, not a confirmed network bottleneck. The separate one-viewport cache change does not guarantee that high-quality probe decodes finish before scrolling.

On Android, measure the actual timeline at low and high quality, small/normal/large grid sizes, cold and warm cache, both scroll directions. Capture non-secret request count, first response/first decoded thumbnail, failed format probes, cache hits, bytes, frame times and whether the thumbnail itself or only high-quality upgrades are late. Compare to `develop` without erasing existing user cache. If several format probes are saturating the connection, implement and test the smallest source-specific request pacing or cached-format reuse fix; do not downgrade user quality settings or disable format fallback without evidence.

## Tests and outstanding gates

### Local qualification on 2026-11-09

Final runtime/test candidate: `bf6286922618890b5733a849138ed3ed0d2a7544`.
Subsequent handoff/report edits do not alter that candidate's runtime tree.
Android acceptance used `c360ce0611bdfbff85d8a7510e91801591f656ac`. The latest
fetched commits additionally place the cached history action only at the timeline
end, hide the duplicate pre-history footer, and retain the normal manual footer
after explicit history start. They received independent source review and the
new automated checks below; no additional live campaign was performed.

Local review and Android acceptance fixed five integration gaps:

- Cached feeds of every length retain an explicit **Load older posts** entry;
  the short-feed-only condition previously stranded longer cached feeds.
- Automatic fill counts actual debounced dispatches rather than canceled queue
  reservations. Explicit manual dispatch renews the bounded fill budget, including
  promotion of an already queued automatic request.
- Grouped Danbooru search/artist grids use the enclosing PostGrid's shared fill
  owner; their competing local fill loop was removed.
- Regression fixtures distinguish offscreen cached tiles, settled masonry
  geometry, terminal artist data and explicit pool slicing from automatic fill.
- The cached history/update actions respect the destination's bottom navigation
  padding. On Android, the old action overlapped navigation: its center opened
  Bookmarks instead of history. The regression reproduced the overlap for both
  one-post and 40-post feeds, then passed with the inset correction.

Verification completed with Flutter 3.47.2 / Dart 3.13.2 and six physical-core
workers:

- Changed Dart files formatted with `fvm dart format`.
- Requested targeted listing/Following/Favorites/cache suite: **957 passed** at
  the earlier local candidate; subsequent consumer changes are covered by the
  final complete run.
- Grouped search/artist consumer checks: **76 passed**; explicit pool slicing:
  **2 passed**.
- After the device finding, all **38 feed-page tests passed**, including the
  navigation-obstruction regression at narrow width and enlarged text.
- After fetching the latest end-of-feed/manual-fallback changes, **215 affected
  feed/listing tests passed** and the complete local suite passed again on the
  final runtime/test candidate.
- `./scripts/run_regression_tests.sh` on the final candidate: **exit 0**,
  **6,208 application tests passed**, all package/CLI suites and repository
  tooling passed, including 76 Python tests. Two package tests were skipped by
  their suite. No interrupted/earlier failed run is reused as the final pass.
- Affected analyzer runs: **zero errors and warnings**, 12 informational findings
  across the earlier core and grouped-consumer runs. The final inset-related run
  had zero errors/warnings and three infos (exit 1 because infos are fatal).
  Flutter VM finalizer diagnostics and
  locale fallback messages appeared during tests despite passing results; those
  messages are retained in the logs rather than asserted to be preexisting.
- Independent review of the exact runtime/test candidate against the specified
  base: **no remaining correctness findings**. This was a source review; the
  reviewer did not independently rerun tests or control the device.

Behavior tests cover cached short/long feed history gating, the actual viewer
live-source gate, explicit history continuation, manual renewal, bounded empty
page fill, refresh, route/activity/background cancellation, debounce cancellation,
page-mode changes and paginated grids never automatically advancing. Narrow
360 logical-pixel width with enlarged text is covered for the explicit cached
history control, including an 88 logical-pixel navigation obstruction. Host tests
do not establish live API/device timing.

Durable local logs are in
`.worktrees/_artifacts/160-timeline-prefetch-package/`, particularly
`latest-full-regression.log` (final complete pass), `latest-targeted.log`,
`full-regression-history-inset.log` (Android inset candidate),
`full-regression-final.log` (earlier candidate), `history-inset-green.log`,
`history-inset-analyze.log`, `targeted-qualified.log`, `consumer-regressions.log`,
`pool-page-size.log`, `analyze-final.log` and `analyze-consumers.log`.

### Android qualification

See [Realbooru Android measurement](160-162-realbooru-measurement.md) for the
completed 24-case low/high-quality, three-grid-size, cold/warm, both-direction
comparison and bounded viewport repeat. **Realbooru lag remains; performance
acceptance is unresolved.** Connection saturation was not established, so image
quality, fallback and request pacing policies remain unchanged.

The uninstrumented ordinary-main dev/debug APK used for Android acceptance was
built from `c360ce0611bdfbff85d8a7510e91801591f656ac` and installed without
clearing app data. Its SHA-256 is
`11ce00f68f0e0b1ea87b0ddad0de3c072464a7a1951df12e633137b06178b2a6`;
the installed APK hash matched. The final repeat build completed without a rerun
warning, produced the identical APK, and left all 4,368 captured Dart runtime/test
inputs unchanged. See `history-inset-final-build-provenance.json`.

After the user approved the legacy import confirmation, the provided export was
used to import one copied Pixiv profile and later one copied Gelbooru profile,
with no existing-profile changes/removals in either preview. A stale hosted
Maestro channel was recovered through a fresh local Maestro MCP session, without
resetting app data. Completed ordinary-main checks:

- Pixiv Favorites: two public items with decoded thumbnails, an empty private
  collection, refresh, viewer swipe/back, and background/resume. Profile-specific
  Small grid/Pagination settings persisted after restart. Browse page 2 loaded
  manually and remained selected with 139 posts after end-of-page overscroll.
  These checks preceded the final inset-only edit; pagination/media source did
  not change afterward.
- Android inset candidate: a one-post, unfiltered cached feed stayed at page 1 with
  `hasMore=true`, history off and zero continuation dispatches after overscroll
  and a viewer swipe. Read-only VM inspection captured only allowlisted numeric/
  boolean controller state and public post metadata; no account data was logged.
- Android inset candidate: the 1,000-post feed sorted locally with history off and zero
  dispatches. Earlier empty/two-post filtered cases also stayed local, including
  their viewer. These are controller-state checks, not a wire-level HTTP trace.
- Android inset candidate: explicit history worked above the open keyboard on the
  one-post feed, dispatched once, and stopped at exhaustion. On the long feed,
  one explicit dispatch added 50 older posts, reaching 1,050 posts and quiescence.
- Android inset candidate: the corrected overlay ended at y=1392, above navigation
  starting at y=1424; its former y=1472–1568 position intercepted the wrong action.

Authenticated multi-page Favorites remains unverified because the supplied
account has only two public and zero private favorites. Detailed route/background
cancellation and bounded three-page renewal remain primarily automated evidence;
ordinary-main checks do not establish every lifecycle/network combination or
decoded viewer media readiness. Realbooru performance acceptance remains open.

Restoration completed after both campaigns: only the original Default profile
remains and is selected; all test folders/topics, three temporary profiles and
staged credential-export copies were removed. The original
installed APK was restored with SHA-256
`a6c31bf518d151fec6d8100b4623ee24d6845d5953540425a3e2b1e275e559ce`
verified on-device. Display settings remained 720 × 1600, density 320, font scale
1.0, portrait. Dedicated measurement cache directories and ADB forwards were
removed without clearing existing user cache. Phone1, started for this task, was
closed and its lease released. The receipts are `android-acceptance.json` and
`android-resume-acceptance.json` in the artifact directory. No credentials were
committed or logged.

### Commands for future runtime changes

Review and run:
```sh
fvm dart format lib/core/posts/listing/src/widgets/post_grid.dart lib/core/posts/listing/src/widgets/post_grid_controller.dart lib/core/posts/listing/src/widgets/post_grid_prefetch.dart lib/core/search/following_topics/src/pages/topic_feeds_page.dart lib/core/posts/details/src/routes/route_utils.dart test/core/posts/listing/post_grid_prefetch_test.dart
workers="$(python3 scripts/physical_core_count.py)"
fvm flutter test --no-pub "--concurrency=$workers" test/core/posts/listing test/core/search/following_topics test/boorus/pixiv_favorites_page_lifetime_test.dart test/application/timeline_thumbnail_cache_test.dart
./scripts/run_regression_tests.sh
```
Verify no auto history request for short feeds or while inspecting them in the viewer; manual history still works. Check Pixiv Favorites and regular multi-page timelines, empty pages, swipe/refresh, inactive/background tabs, page-mode changes, overscroll and lifecycle cancellation. A paginated grid must never auto-fetch. Get an independent review of the exact P1 candidate. Perform non-destructive ordinary-main Android acceptance with exclusive emulator lease and restoration.

**Accepted delivery scope:** The user approved P1 (#160 and #162), including the
latest fetched changes and the documented Realbooru/multi-page Favorites limits.
No Realbooru performance fix or unperformed live check is claimed. #161 remains
in P8. This approval covers P1 integration, publication, issue closure and task
cleanup; it does not approve another package, a PR or a release.
