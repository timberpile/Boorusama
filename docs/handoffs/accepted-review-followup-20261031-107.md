# Accepted review follow-up handoff — #107

Prepared 2026-10-31. Branch `feature/107-local-post-sorting`.

Verified implementation/test candidate: `c20551e329943131f790b3f160e13e27dbc4b0c4`. The final handoff commit changes documentation only; the separate final branch index records that exact resulting HEAD.
Merge base with local develop: `422aeae087c1108e655d85d1a3dac25120456cd6`. Local develop remained `de5928283aa39f0d67d6a834e42d4fa5e9369b86`; primary checkout remained detached at `405ef9ee9c7f0821d3601866373884015c5323f5`.
State: PARTIAL — accepted independent changes prepared; named UX choice remains open.

## Result and review

Feed defaults to Newest without Clear/Feed Order. Cached search is always reachable; a separate compact History/Cached chip reflects actual scope independently of sort/query. Source selection is hidden when redundant and preserves a missing selected source for recovery. Feed and Bookmark search/filter controls share floating hide/reveal behavior; the Bookmark title sits above the combined header. Timestamp keys are parsed once per sort.

Reviewed default remote-history eligibility, local-only request guards, stable ties, tag/source narrowing and invalidation, retained filter state across empty/nonempty grids, ghost-source recovery and Bookmark header overlap. Actual Bookmark flow tests caught the search bar not revealing with filters, then a title overlap; both were corrected.

Shared #114 controls 8be01654ebf69fbea50c3773d8f8f00b2beadaf2 are cherry-picked as 5ddc96099c10932aced3675f6635c3c9f043c389. TimelineHeaderSliver also carries the stable transparent-child repair from caa1ec196d748f2091b24a6bfd7511716dd4472c.

## Verification

- Complete local gate: `./scripts/run_regression_tests.sh` — PASS, 1011.8 s, exact candidate `c20551e329943131f790b3f160e13e27dbc4b0c4`. Application, every local package/CLI, both shell suites and Python tooling ran; two existing go_router skips remain.
- Android build: `fvm flutter build apk --debug --flavor dev --dart-define-from-file=env/dev.json --no-pub` — PASS, 154.0 s, build commit `c8609cfc7290790c4a79beba35e384b480406b0a`.
- Non-runtime changes after that build: `test/core/bookmarks/bookmark_details_page_test.dart`.
- Scoped final analysis: `fvm flutter analyze --no-pub --no-fatal-infos lib/core/bookmarks/src/pages/bookmark_page.dart lib/core/bookmarks/src/widgets/bookmark_appbar.dart lib/core/bookmarks/src/widgets/bookmark_option_selector.dart lib/core/bookmarks/src/widgets/bookmark_scroll_view.dart lib/core/bookmarks/src/widgets/bookmark_sort_button.dart lib/core/posts/listing/src/widgets/timeline_header_sliver.dart lib/core/posts/listing/src/widgets/timeline_option_selector.dart lib/core/posts/listing/src/widgets/timeline_toolbar.dart lib/core/search/following_topics/src/pages/topic_feeds_page.dart lib/core/search/following_topics/src/providers/cached_feed_tag_index_provider.dart lib/core/search/following_topics/src/types/cached_topic_feed_filter.dart lib/core/search/following_topics/src/widgets/cached_feed_filter_bar.dart test/application/bookmark_timeline_toolbar_flow_test.dart test/core/bookmarks/bookmark_details_page_test.dart test/core/posts/listing/timeline_controls_test.dart test/core/search/following_topics/cached_feed_filter_bar_test.dart test/core/search/following_topics/cached_feed_sort_history_test.dart test/core/search/following_topics/cached_topic_feed_sort_test.dart test/core/search/following_topics/topic_feed_test.dart` — PASS: 0 errors, 0 warnings, 12 informational findings. Informational findings are not described as lint-clean.
- Changed Dart files formatted with FVM. `git diff --check 422aeae087c1108e655d85d1a3dac25120456cd6 c20551e329943131f790b3f160e13e27dbc4b0c4` passed.
- Focused evidence `controls-final-v2`: `fvm flutter test --no-pub --concurrency=6 test/core/search/following_topics/cached_feed_filter_bar_test.dart test/core/search/following_topics/cached_feed_sort_history_test.dart test/core/search/following_topics/cached_topic_feed_sort_test.dart test/core/search/following_topics/topic_feed_test.dart test/core/bookmarks/bookmark_list_controls_test.dart` — PASS (14.7 s). Earlier dirty-state focused runs are superseded by the complete clean committed-candidate pass above.
- Focused evidence `bookmark-scroll-green-v2`: `fvm flutter test --no-pub --concurrency=6 test/application/bookmark_timeline_toolbar_flow_test.dart test/application/bookmark_library_flow_test.dart test/application/bookmark_collection_selection_flow_test.dart test/core/bookmarks/bookmark_list_controls_test.dart test/core/bookmarks/bookmark_search_bar_test.dart` — PASS (42.3 s). Earlier dirty-state focused runs are superseded by the complete clean committed-candidate pass above.
- Focused evidence `title-geometry-final`: `fvm flutter test --no-pub --concurrency=6 test/core/bookmarks/bookmark_details_page_test.dart test/application/bookmark_timeline_toolbar_flow_test.dart` — PASS (42.4 s). Earlier dirty-state focused runs are superseded by the complete clean committed-candidate pass above.
- Focused evidence `model-benchmark`: `fvm flutter test --no-pub --concurrency=1 /home/timber/code/Boorusama/.worktrees/_artifacts/accepted-review-followup-20261031/107-model-benchmark.dart` — PASS (18.3 s). Earlier dirty-state focused runs are superseded by the complete clean committed-candidate pass above.
- Focused evidence `model-benchmark-optimized`: `fvm flutter test --no-pub --concurrency=1 /home/timber/code/Boorusama/.worktrees/_artifacts/accepted-review-followup-20261031/107-model-benchmark.dart` — PASS (15.5 s). Earlier dirty-state focused runs are superseded by the complete clean committed-candidate pass above.
- Focused evidence `production-cost-probe-v2`: `fvm flutter test --no-pub --concurrency=1 /home/timber/code/Boorusama/.worktrees/_artifacts/accepted-review-followup-20261031/107-production-cost-probe.dart` — PASS (14.7 s). Earlier dirty-state focused runs are superseded by the complete clean committed-candidate pass above.

Raw command, HEAD, tracked diff, exit status and elapsed time are stored in `<primary checkout>/.worktrees/_artifacts/accepted-review-followup-20261031/107-local-post-sorting/` as phase `.json`/`.log` pairs. Interrupted/superseded/failing earlier runs are retained and are not counted as final passes. Native VM finalizer diagnostics occur in some passing Flutter tests; they are reported separately from exit status. Existing native-hook “File modified during build” and Android toolchain support notices also remain; no unrelated toolchain upgrade was introduced.

## Actual Android checks and limits

Device: `emulator-5554`, exclusively leased and controlled with Maestro. Installed normal APK SHA-256: `b9f8697cc0a62159e7c97f4d9600a09e9f75a90d4061608f232ee2b9d2bcb3bc`.

PARTIAL: sort-control placement remains OPEN. Actual 1000-post QA feed History/Score Cached/search/keyboard/hide/reveal/reset passed; single-source selector was hidden. QA folder/topic/feed removed. Actual Bookmark device library had only two posts, so off-top scroll proof is from actual production flow tests at 1x/2x with keyboard. Controlled tests count remote-history requests; local sort/filter adds none. Host benchmark uses one warm-up plus five serial 10k-post runs: Score median 295.4 -> 33.8 ms, query/Newest 343.3 -> 31.9 ms, tag index 56.7 -> 41.3 ms. Raw runs preserved. These are model costs, not Android frame times; provider/build costs were not isolated as separate live measurements. Additional current production probe (1000 snapshots, one warm-up plus five serial measured runs): provider cold recompute median 6.123 ms (4.486-8.598), cached read 0.012 ms (0.007-0.026), Score transition pump 224.870 ms (175.094-267.578), tag draft edit 79.716 ms (73.401-87.557), tag-submit transition pump 199.843 ms (162.472-229.151). All runs asserted zero post and media/metadata requests. Transition pump includes actual controller/filter/build/layout/paint in the debug host; it is not an isolated build duration or an Android frame-time measurement. Provider recomputation and its cached read were measured separately; no additional provider or rendering rewrite is justified by these host totals.

Detailed actual observations and provenance are retained in `107-device-observations.json`.

Task fixtures and settings were restored: task-created local groups/posts/topic/feed were removed, settings restored, the original device APK reinstalled with matching installed APK hash, original Safebooru (Danbooru) profile selected and lease released. No remote account mutations or recipient sends occurred. Share/copy checks changed the clipboard and ordinary QA searches remain in local search history; existing history was not cleared.

## User review checklist

1. Open a populated Feed: Newest, History chip, Search Cached..., no Clear/Feed Order; compare sort labels/icons with Bookmarks.
2. Select Score or enter a cached query/source: chip says Cached. Newest restores History only after other local conditions are cleared.
3. Scroll down then slightly up in Feed and Bookmarks, with keyboard and enlarged text. Search and filters reveal together below the title.
4. Check multiple/missing sources, tag changes, selection, older metadata and stable equal-score ties.

## Delivery boundary

All task changes are committed locally. No PR, push, develop integration, issue closure, branch/worktree deletion or release was performed. This isolated branch pass does not prove a later combined develop candidate; merging sibling changes or rebasing runtime code requires verification of that resulting candidate. User acceptance is still outstanding.

## Correction commits

The prior branch implementation is retained except for the accepted corrections described above. These are the correction checkpoints since the starting handoff:

```text
c20551e329943131f790b3f160e13e27dbc4b0c4 test: assert fixed Bookmark title geometry after toolbar correction (#107)
c8609cfc7290790c4a79beba35e384b480406b0a chore: remove unused Bookmark toolbar import (#107)
29bf9956b66ceedccb129d7021ba528100814e22 fix: reveal Bookmark search and filters below the fixed title (#107)
7c83f9193a51eb6f20f6d2a136af98fbb0abcb1f perf: avoid repeated cached timestamp parsing (#107)
8b6a1e89c55582001784ba8f8d6e67a57b42a366 fix: clarify cached Feed scope and restore timeline controls (#107)
5ddc96099c10932aced3675f6635c3c9f043c389 refactor: share composable timeline controls (#114)
```
