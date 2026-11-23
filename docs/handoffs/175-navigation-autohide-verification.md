# Native navigation autohide verification (#175)

Base: `4542aaa44e5002f7d546fb4ec96bf4cb0523cee5`.
Branch: `bug/175-pixiv-navigation-autohide`.

NativeContentGrid lacked the NavigationScrollBoundary used by RawPostGrid.
Browse/Explore use the native grid directly. On this base, destination-local
Pixiv Search uses DefaultSearchPage/PostGrid, explaining the working negative
control; direct native Search also lacks the boundary. Add the existing adapter
at the native scroll viewport, with the existing selection bridge. Search's outer
notification listener handles only its search region; it does not forward chrome
deltas. Thus native and compatibility Search both forward each event once.
The cumulative preview also checks Search after #174 switches it to native Works.

Actual final checks:

- `fvm dart format lib/core/content/widgets/native_content_grid.dart test/boorus/pixiv/works/work_navigation_autohide_test.dart`: passed (the unchanged existing listing test was restored before final checks).
- `timeout 30s fvm flutter test --no-pub --concurrency=6 test/boorus/pixiv/works/work_navigation_autohide_test.dart test/core/navigation/navigation_scroll_boundary_test.dart`: 10 passed. Browse, Explore, direct native Search, profile-local fallback Search, exact one-event delta and ordinary shared boundary exemptions.
- `timeout 20s fvm flutter test --no-pub --concurrency=6 test/boorus/pixiv/works/work_timeline_selection_test.dart`: 9 passed.
- `timeout 20s fvm dart analyze lib/core/content/widgets/native_content_grid.dart test/boorus/pixiv/works/work_navigation_autohide_test.dart`: zero errors/warnings, 3 informational findings.
- `git diff --check`: passed.

An earlier guarded run used an incomplete navigation-catalog fixture and then
hit its 75-second guard. It is a failed/incomplete attempt, not a pass. The fixture
was supplied and the final isolated test file above completed successfully.

Not run: emulator/Maestro, live APIs/accounts, APK build/install, full regression
suite, Android visual/manual checks. Owner QA: scroll down/up in Pixiv Browse,
Explore and Search, return from the viewer, enter selection and open a menu;
compare a non-Pixiv Browse profile. No animation curve or navigation policy was
changed. Full develop-integration qualification remains deferred.
