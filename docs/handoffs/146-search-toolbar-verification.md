# Search toolbar overlap verification (#146)

Base: `4542aaa44e5002f7d546fb4ec96bf4cb0523cee5`.
Branch: `bug/146-search-toolbar-overlap`.

The Search editor is positioned outside the results viewport. Its top sliver
only reserved space at list start; a separately floating Timeline Toolbar could
therefore reveal beneath the editor after scrolling. A controlled geometry test
reproduced overlap for top placement at 320dp with normal and 150% text; bottom
placement passed. Before refinement, the covered toolbar also failed hit testing.

Reserve the currently visible top editor extent in the results viewport, driven
by the editor's existing animation and search/selection state. Remove the
redundant list-start displacement for native and Post results. Bottom placement,
options/suggestions and their independent displacement remain unchanged. This
uses the existing shared search-region sizing contract, without profile offsets.

Final checks:

- `fvm dart format lib/core/search/search/src/widgets/raw_search_page_scaffold.dart test/core/search/search_toolbar_overlap_test.dart`: passed.
- `timeout 30s fvm flutter test --no-pub --concurrency=6 test/core/search/search_toolbar_overlap_test.dart test/core/search/search_profile_switch_test.dart`: 10 passed. Four top/bottom/text-scale cases include selected tags, actual reverse scroll, reachable toolbar, selection and keyboard insets; nearby account/query transfer and narrow menu controls also pass.
- `timeout 20s fvm dart analyze lib/core/search/search/src/widgets/raw_search_page_scaffold.dart test/core/search/search_toolbar_overlap_test.dart`: no issues.
- `git diff --check`: passed.

The initial new fixture lacked an enum import and failed compilation. A short
startup attempt then timed out before results; neither is counted as passing.
The corrected baseline produced two top-placement overlap failures, then the
final candidate passed the focused checks above.

Not run: full suite, emulator/Maestro, live APIs/accounts, APK build/install or
Android visual acceptance. Owner QA: open Browse Search, scroll down/up with top
and bottom placement, selected tags, enlarged text, keyboard and selection; both
Search and Timeline Toolbar controls must remain accessible. Full integration
qualification remains deferred.
