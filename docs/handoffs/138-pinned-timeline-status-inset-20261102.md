# Issue #138 — Pinned timeline status-bar inset

The [final integration verification](#final-integration-verification) supersedes
the original local-only delivery status recorded below.

This follow-up fixes the pinned Pool timeline appearing behind Android's status
bar. It continues `feature/138-mixed-viewer` in its existing isolated worktree.
Base: `06359ccf19b3c57760b2ad359002dbbf16f27e0d`.
Runtime/test candidate: `d31f49ac4846f65e60efaaadb91945249b8089ac`.
The documentation-only handoff commit follows that candidate.

## Cause and correction

Pool galleries omit their top SafeArea because the floating action bar owns the
system inset. Once that bar scrolled away, `PinnedHeaderSliver` placed the
timeline at viewport y=0. Its controls consequently overlapped the status bar.

The shared timeline now calculates the uncovered top system inset from its
painted leading position and adds only that remaining space. Initial gallery
content keeps its existing position; a returning action bar and an ancestor
SafeArea do not produce duplicate padding. Floating timeline behavior, sorting,
restoration and persistence remain unchanged.

## Automated verification

The application regression failed before the fix: pinned controls were at 0dp
with a 24dp status inset. The new shared-header test also failed with an
unconsumed inset; its already-consumed SafeArea case passed.

After correction:

```bash
fvm flutter test --no-pub --concurrency=6 \
  test/core/posts/listing/timeline_header_sliver_test.dart \
  test/application/pool_bookmark_flow_test.dart \
  test/application/timeline_toolbar_scroll_flow_test.dart \
  test/application/bookmark_timeline_toolbar_flow_test.dart
```

**61 passed.** Shared-header cases check initial content position, approaching
the leading edge, deep scrolling, hit testing and upward action-bar reveal,
with and without an ancestor SafeArea. The existing Pool matrix additionally
asserts controls remain below the system inset at 320×844, 390×844, 844×390 and
1280×800 with 1×/2× text and both pinning settings.

Scoped analysis of the changed three Dart files returned exit 0 with **0 errors,
0 warnings and 17 informational findings**. Changed Dart files were formatted;
`git diff --check` passed.

**Complete final gate passed:** `./scripts/run_regression_tests.sh`, exit 0,
2026-11-02 22:13:34–22:26:39 UTC, six workers, on the clean runtime/test
candidate above. **6,015 application tests, 1,654 package/CLI tests across all
13 suites, and 72 Python tooling tests passed.** Pull-request-policy and
Android-release shell checks passed. The two pre-existing `go_router` skips
remain excluded from passing counts. Commit and clean status were unchanged
through completion. This pass is reused only for the subsequent documentation
updates; no runtime or test changes followed it.

## Android acceptance and limits

An exclusively leased `emulator-5554` was controlled through Maestro without
resetting application data. The live Danbooru Series used the same safe search
and gallery as the prior layout acceptance. With pinning enabled and the action
bar scrolled away, the Ordered label moved from y=8px to y=56px, below the
48px status bar. The post count moved from y=24px to y=72px. Opening the sort
menu retained access to Latest. Upward scrolling returned the action bar and
placed Ordered directly beneath it, without a second system inset.

The debug Android x64 build succeeded from the recorded candidate. Local and
installed APK SHA256 matched:
`ec9c233241e8af71f84829bf5022a731ded3b8ef93b8da5e9127269152d27cb8`.
The known libavif native-hook and Android toolchain warnings remain; no SDK
source or generated runtime files changed during verification.

This acceptance checks header positioning and menu access. The captured media
region contained loading placeholders; it does not establish new decoded-media
readiness. Exact responsive sizes and text scaling are automated evidence, not
additional device claims.

The original pinning setting (off) and Safebooru (Danbooru) Browse profile were
restored and confirmed. The lease was released. No bookmark/remote mutations,
font, rotation, network or media-loading settings were changed. The QA search
remains in normal Search history.

Durable ignored logs, screenshots, provenance and acceptance records are in
`.worktrees/_artifacts/138-pinned-status-inset/`.

No push, merge, PR, issue closure or branch/worktree deletion was performed.
Keep #138 open and retain the existing branch/worktree. A changed combined
integration candidate requires complete regression verification.

## Final integration verification

The user approved the final test and merge on 2026-11-02. This authorizes the
normal squash integration, publication to `origin/develop`, completed issue
closure and task branch/worktree cleanup; no PR is requested.

The task was rebased without conflicts onto
`e6853897a6dbe5cd3c14fa8c6af4623a2403893d`, including the Pixiv identity fix #137.
`git range-diff` confirms all nine approved task commits retained identical
patches. The complete combined candidate is
`dc4909166ad97a182691cb90d91bd8c6f6916dc8`.

`./scripts/run_regression_tests.sh` passed with exit 0 on that clean candidate,
2026-11-02 22:40:46–22:53:36 UTC, using six workers:

- **6,032 application tests passed.**
- **1,655 package/CLI tests passed across all 13 suites.**
- **72 Python tooling tests passed.**
- Pull-request-policy and Android-release shell checks passed.
- The two existing `go_router` skips remain excluded from passing counts.

Commit and clean status remained unchanged through completion. Analysis of all
44 changed Dart files returned exit 0 with **0 errors, 0 warnings and 45
informational findings**. Their format check reported **44 files, 0 changed**.
`git diff --check` passed. Only this documentation update follows the final gate;
the integrated runtime/test tree must match the verified candidate.

No additional Android build or device acceptance was performed for this
integration. The earlier Android evidence and its stated source/media limits
remain as recorded above and in the preceding gallery handoff.

Final integration logs and recovery evidence are retained outside the task
worktree in `.worktrees/_artifacts/138-approved-integration-20261102/`.
