# Native timeline refresh verification (#169)

Base: `4542aaa44e5002f7d546fb4ec96bf4cb0523cee5`.
Branch: `bug/169-pixiv-refresh-state`.

The controller cleared entries and viewer occurrences before awaiting refresh,
even though successful `_load(replace: true)` already replaces them. Retain the
old entries, occurrence IDs and pagination availability until an authorized
response succeeds. Failed refreshes retain usable cards and a Retry action;
both retry and explicit continuation replace the failed refresh page rather
than appending it. Existing generation/cancellation and authorization guards
remain in force. Disposed/revoked refresh calls do not start a new generation.

The native grid uses the existing Post-grid placeholder sliver for initial
loading, with the actual column count. Existing-content refresh has no competing
footer progress spinner; ordinary pagination retains its footer progress.

Final checks:

- `fvm dart format lib/core/content/widgets/native_content_grid.dart test/core/content/native_content_grid_test.dart`: passed.
- `timeout 30s fvm flutter test --no-pub --concurrency=6 test/core/content/native_content_grid_test.dart`: 9 passed, including the actual placeholder/footer widget path, retained occurrences, failed refresh/retry, late results, authorization revocation and pagination/continuation controls.
- `timeout 30s fvm dart analyze lib/core/content/widgets/native_content_grid.dart test/core/content/native_content_grid_test.dart`: zero errors/warnings, 3 informational existing-style findings.
- `git diff --check`: passed.

The initial 75-second guarded test command with the same file exceeded fresh
compilation time (exit 124); no tests completed and teardown emitted termination
errors. It is not a pass. The smaller cached run above completed on unchanged
final code/tests in about one second of test execution.

Not run: full suite, emulator/Maestro, live API/account tests, APK build/install,
Android visual/manual acceptance. Owner QA: refresh populated Pixiv Browse/Search
and Explore while offline, retry after recovery, paginate, and switch accounts
while a request is pending. Existing Works should remain usable until successful
replacement; initial load should show placeholders. Shared native consumers are
covered by focused controller/widget tests only. Full integration qualification
remains deferred; this branch is for owner testing.
