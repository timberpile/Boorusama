# Issue #64 — Artist Page handoff

Branch: `feature/64-artist-page`.
Starting HEAD for this continuation: `2f66c21e67159436970540aa0a4fdc9a7ae39b02`.
Status: implementation, complete local regression and Android checks completed locally on 2026-10-28. No integration, push, PR or issue closure is authorized by this continuation.

## Approved reference and implementation

The [2026-10-28 HTML mockup](../../designs/mockups/2026-10-28-artist-page.html), supplied in the implementation handoff bundle, supersedes the earlier mockup. It was opened in a local Chromium browser and its mobile/desktop, aliases, Wiki, Follow, related-tag sorting and post sorting interactions were exercised. The HTML is a documentation reference, never a runtime asset.

- Mobile has one continuous profile/posts scroll view. Large screens have an independently scrollable profile beside the existing shared PostGrid. Route-owned keys retain the grid and profile state when those panes move; the existing controller, tile/context-menu actions, selection, pagination, preferences and blacklist controls remain in use.
- A clipped 124 dp banner (plus the system inset) blurs the newest filtered post's exact grid-thumbnail URL through BooruImage and its existing cache. It requests no decorative higher-resolution image or extra post query, remains newest under Popular, and uses a themed fallback for missing, animated/video or failed media. Filtering changes conservatively clear a retained banner when its visibility cannot be established from Popular results.
- A neutral 82 dp avatar overlaps the banner. Back, the existing compact Follow control and a Kurumi bulk-download/copy menu overlay it. Follow retains its account/folder business logic and normal accessible hit target; its height intentionally follows the existing control rather than the mockup's smaller visual target.
- Known Names starts collapsed and aliases copy with feedback. Wiki requires usable content. Related Tags opens a scrollable Kurumi sheet of ordinary category-colored chips, with deterministic count/A–Z sorting and remembered sort. Empty/invalid tags are omitted, and the action counts the available deduplicated set from the existing capped provider.
- Related-tag counts come from the nested tag DTO's tag-wide `post_count`, not an artist intersection. Unknown/synthetic zero totals are omitted. Count tooltips describe posts with the tag.
- External profile chips identify X handles and Pixiv account IDs, validate HTTP(S), deduplicate normalized URLs, preserve full URL tooltips/accessibility, and retain the safe launcher. Three links are previewed; Show All exposes every valid active link. Phone metadata labels and chip widths are compact; controls wrap at enlarged text.
- One Posts heading/count sits beside visible independent Search and the existing grid settings menu. An opt-in blacklist-only configuration header removes the duplicate posts-count line. The count uses the controller's reported total when supplied, otherwise its loaded count (matching the old grid's fallback), and is retained while refreshing. Artist metadata counts never substitute for this listing count.
- Search and Wiki explicitly retain the originating profile. Tests cover a non-global profile, no saved-Topic mutation, and Back preserving sort, scroll, controller identity and post request count.
- Live testing exposed an existing lookup bug: an alias owner could precede the canonical artist in the API response. The client now prefers an active exact-name match within that response while preserving the existing alias-only fallback and making no additional request. Controlled client tests and the real `kantoku` page verify the fix.
- The obsolete artist header/word-cloud hooks from the earlier branch implementation were removed from the generic tag scaffold. Those tag/character consumers return to their previous layout; the artist uses narrow opt-in hooks in the responsive region and shared grid. BooruImage gained an optional themed failure widget; its existing consumers retain their defaults.

## Automated verification

Pinned FVM Flutter: 3.47.2. Ordinary test concurrency: 6, detected with `python3 scripts/physical_core_count.py`.

- `./gen.sh i18n`: passed validation and regenerated the ignored translation outputs from the changed English inputs.
- `fvm dart format` on changed Dart files: completed.
- Scoped `fvm flutter analyze --no-pub --no-fatal-infos`: no issues. Scope includes Danbooru artists/tag details, core tag details, changed shared image/grid widgets and affected test files.
- Artist Page test file: 13 tests passed on the final runtime implementation. Covers nullable listing totals, profile-scoped Search/Wiki/tag routes, scroll/sort/controller/request preservation, responsive reparenting, aliases/copy, link preview/identity validation, banner media/settings/filtering, and sheet sorting.
- Shared image fallback file: 5 tests passed, including the optional decorative failure surface and existing fallback chains.
- Earlier expanded consumer run (artists, Follow, secondary routes, tags, listing and images): 144 passed before the final additional regressions; the final complete run below supersedes that earlier source state.
- Complete `packages/booru_clients` suite: 206 tests passed, including five canonical/alias/deleted/empty artist lookup cases. The final complete run below repeats this package gate.
- `git diff --check`: passed. The copied approved HTML matches the supplied reference.

Final complete local gate: **passed, exit 0**. Command: `./scripts/run_regression_tests.sh`, concurrency 6. Checked state is the final runtime/test content in this commit, following starting HEAD `2f66c21e67159436970540aa0a4fdc9a7ae39b02`; only this documentation result update followed the run. Earlier superseded runs were stopped and are not counted as passes.

| Suite | Passed | Skipped |
| --- | ---: | ---: |
| Application | 5,349 | 0 |
| booru_clients | 206 | 0 |
| boorusama_cli | 254 | 0 |
| cache_manager | 59 | 0 |
| coreutils | 191 | 0 |
| dtext | 59 | 0 |
| extended_image | 47 | 0 |
| filename_generator | 31 | 0 |
| flutter_sqlite3_migration | 45 | 0 |
| foundation | 65 | 0 |
| go_router | 436 | 2 existing |
| i18n_cli | 32 | 0 |
| kurumi | 167 | 0 |
| retriable | 16 | 0 |

Both shell suites passed (`test-pull-request-policy.sh` and `test-android-release-scripts.sh`), and Python tooling reported 72 tests, OK. The unchanged go_router skips are “Redirect only GoRoute redirects to a valid route based on fragment” and “Imperative navigation canPop It should return false if Navigator.canPop() returns false.” No new skip or exclusion was introduced.

## Android and visual verification

Built with `fvm flutter build apk --debug --flavor dev --no-pub`, installed with `adb install -r` without clearing app data, and controlled through Maestro MCP on exclusively leased `emulator-5554`.

Final local and installed APK SHA-256 match:
`6327308484e872761cead875e80c58b68f008ff98efa4318a18bacc1155d5e85`.

Actual checks used the real Danbooru `kantoku` page opened from a post:

- Correct canonical artist's aliases/external accounts; collapsed/expanded names; compact external-link preview and Show All/Show Less.
- Newest/Popular, separate artist-prefilled Search and Back, Wiki and its return, Follow folder picker opened and cancelled, and a real blacklisted-post control. No Follow destinations were changed.
- Related sheet opened/dismissed, A–Z sorting exercised, scrolling with enlarged text, ordinary category colors and real tag-wide totals.
- Phone at 360 dp; 320 dp with 200% system text; 1440×1000 logical desktop-width Android window. Two-pane layout and independent profile scrolling inspected against the reference. Native desktop execution is a separate unrun check; the responsive widget tests also cover 1200 dp.
- Final-source screenshots: `/tmp/issue64-final-phone.png`, `/tmp/issue64-final-desktop.png`, `/tmp/issue64-final-320-text200.png`, `/tmp/issue64-final-sheet-text200.png`. Additional interaction screenshots remain under `/tmp/issue64-*.png`. These are local evidence, not app assets or published artifacts.

The emulator was restored to physical 720×1600, density 320 and font scale 1.0; its lease was released. System-level Android display changes can recreate the activity; the widget resize regression specifically verifies preservation within the mounted artist route.

## Limits and delivery boundary

- Native Linux/Windows/macOS execution and exhaustive external-browser destination checks were not performed. URL formatting/validation and the retained launcher path are covered locally; no account identity resolution API or avatar lookup was introduced.
- The final Android artifact corresponds to the current task source; no release/profile performance benchmark was performed. Nonfatal toolchain deprecation and documented libavif native-hook warnings occurred during builds/tests; actual exit statuses determine the results above.
- This task branch has not been combined with current `develop`. Fresh origin refs were inspected at the start (six task commits ahead, two develop commits behind); no reset/rebase/merge was performed. Any later approved integration must verify its combined candidate with the complete local suite.
- Keep `Refs #64` until the issue workflow's acceptance/publication criteria are met. No push, PR, merge, issue closure, branch deletion or worktree removal was performed.
