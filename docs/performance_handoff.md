# Continue locally: performance diagnostics and cache regression

## Start here

Repository: `timberpile/Boorusama`.
Task branch: **`fix/cache-performance-diagnostics`**.
Base when this branch was created: **`f4972eb54119fce98360c4c2303bbce375b8e722`**, verified against remote `develop`.

Continue this branch in a linked task worktree. Do not start again from develop
and discard the prepared work. Everything needed is versioned in this branch;
no chat attachment, sandbox URL or manually downloaded ZIP is required.

Inspect the working tree, `AGENTS.md`, the applicable project-local skill,
`docs/development_workflow.md`, and `docs/engineering_guidelines.md` first.
Use FVM for Flutter/Dart. Keep code, commits and repository documentation in
English; report to Timber in German. Preserve the primary checkout, other task
worktrees, uncommitted changes, user data and credentials.

From the primary repository, fetch this branch and inspect existing worktrees:

```sh
git fetch origin fix/cache-performance-diagnostics
git worktree list
```

If neither the branch nor its worktree exists locally, a suitable checkout is:

```sh
git worktree add --track -b fix/cache-performance-diagnostics \
  .worktrees/perf-cache-diagnostics origin/fix/cache-performance-diagnostics
```

Otherwise resume the matching worktree; do not reset or force-checkout it.
Check for concurrent/local performance work before editing overlapping files.
Publication of this preparation branch was explicitly requested. It does not
permit pushing develop/master, opening a PR, publishing a release or deleting
other branches. Final local integration remains subject to the user's approval
and the current repository workflow; never merge this unverified preparation.

## What is already prepared

A diagnostic-only implementation contains a bounded recorder, native Flutter
frame timing/lifecycle adapter, safe route categories, settings UI, English/German
translations, named operation instrumentation, a JSON report analyzer and tests.
The cache eviction algorithm, GIF playback and image quality are deliberately
unchanged so a diagnostic-only baseline can be preserved.

A one-time workflow applies 31 source changes (21 existing files and 10 new files)
in a clean linked worktree, verifies every base blob/anchor/destination, runs the
Python checks, and publishes only this branch. It removes its staging source
bundle and its own workflow after successful integration.

**Read `docs/performance_preparation.json` when present.** It records actual source
integration checks and limitations. It is not evidence that Flutter compiled.
If the receipt and `lib/foundation/performance/performance_diagnostics.dart` exist,
the source integration is already applied; do not run the installer again.

If `.agents/handoffs/performance-diagnostics/apply.py` is still present and the
source integration is absent, automated preparation did not complete. The same
integration is available locally, with no external input:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover \
  -s .agents/handoffs/performance-diagnostics/tests -v
python3 .agents/handoffs/performance-diagnostics/apply.py . --check
python3 .agents/handoffs/performance-diagnostics/apply.py .
```

The installer accepts preparation-only descendants of the base, but refuses any
changed instrumentation input even when an anchor still matches. Do not bypass
that check: explicitly port against new code when necessary. It refuses dirty,
primary, detached and shared checkouts and validates before writing. Review the
result and remove the known temporary staging directory/workflow only after
successful application. Do not reintroduce a manual archive/download step.

The cloud environment has no FVM, Flutter, Dart or device, and cannot clone GitHub
through its shell. Python checks are not Flutter/device validation. No cache fix
or causal device measurement has been completed by this preparation.

## Evidence and task priority

Timber reports release-mode stutters in normal search, bookmark grids and
GIF-heavy bookmark groups. Upstream is smooth under comparable usage, including
many simultaneous GIFs. In the fork, about 3,400 disk-cache images (~1 GB) produced
stutters; clearing the cache restored smooth scrolling everywhere; refilling to
about 1,800 images made hiccups noticeable again. Upstream remains smooth with
about 7,000 images (~700 MB).

This is strong evidence for a fork cache regression, not proof that GIF rendering
is intrinsically too expensive. File count, content and memory state changed
together; do not claim a measured causal attribution until it exists.

In the audited cache implementation:

- `_occupied` folds over all generations to compute occupied bytes.
- `_trim()` sorts unpinned generations, then recomputes `_occupied` for each.
- Releasing ordinary read/write leases calls `_trim()` even below the limit.
- `_commit()` also sorts candidates before establishing whether eviction is needed.
- Recency journaling flushes updates; each 128 records triggers full-index encoding.

The first four create unnecessary global and potentially quadratic main-isolate
work. Upstream's ordinary cache-read path does not have this eviction/index system.
The main files are `packages/cache_manager/lib/src/image_cache_manager.dart`,
`image_cache_index.dart`, and `packages/extended_image/lib/src/cache_usage_image_provider.dart`.
Confirm the mechanism still exists at your working revision and identify the
introducing commit through targeted history inspection when possible.

## Required next steps, in order

### 1. Finish and verify diagnostics

Follow `docs/performance_diagnostics.md`. Resolve the pinned SDK dependencies,
regenerate translations, format/analyze the affected code, and fix actual compile
or test failures without changing the cache algorithm yet. The new page needs
normal translation generation before it can compile. Refresh lockfiles only as
required by the new local dependency; avoid unrelated upgrades.

```sh
fvm flutter pub get
(cd packages/boorusama_cli && fvm dart pub get)
./gen.sh
fvm flutter analyze --no-pub
(cd packages/foundation && fvm flutter test --no-pub test/performance_recorder_test.dart)
fvm flutter test --no-pub test/foundation/performance_navigation_test.dart
python3 -m unittest discover -s scripts/tests -p test_analyze_performance.py
```

Inspect nearby Kurumi settings patterns and retain consistent layout. Verify the
settings page at narrow width and enlarged text. Test recording start/stop,
markers, clear, export/copy, delayed release callbacks, background/resume and
navigation. Check actual release recordings contain valid frames while scrolling;
a report that rejects most timestamps is not evidence of smooth performance.

Validate that frame timestamps and `Timeline.now` share a usable native timebase
on the pinned SDK and target platform. Preserve historical route attribution for
batched callbacks. Keep synchronous elapsed spans separate from asynchronous wall
time. Neither is a sampled CPU stack; overlap is not proof of causation. No FPS or
dropped-frame count should be invented from idle intervals.

Recording is off by default, bounded to five minutes and 2,048 events, and uses
fixed enum labels. Do not record URLs, tags, queries, post IDs, names, credentials,
exception text or per-image stack traces. No per-frame file writes or console spam.
Recording is in-memory and does not survive process death. Export stops recording
before serialization so export work does not create its own lag samples.

Add cheap cache-state counters for this investigation if needed: entry count,
retained bytes, configured limit and work counts. Do not poll `getStats()` (it
validates every file) or evaluate `_occupied` per frame. Use existing/maintained
O(1) counters, or an explicit one-time scan outside the interaction window.

### 2. Preserve a diagnostic-only baseline

Commit the buildable diagnostic-only state before optimizing. Record its exact
SHA, flavor/build flags and SDK. This comparison commit must remain reproducible
through subsequent work. No need for another broad audit.

**Preserve the populated problematic cache.** Do not clear it, uninstall the app,
clear app data or modify bookmarks. Preserve app ID, signing and the supported
upgrade path when installing builds. Use only disposable synthetic cache data in
tests. Follow the exclusive emulator lease procedure for any emulator use.

Use the diagnostics page under Settings -> Data and Storage -> Advanced.
For capture from app-shell creation, append to the existing build/run command:

```text
--dart-define=BOORUSAMA_PERF=true
--dart-define=BOORUSAMA_REVISION=<the-actual-built-commit-sha>
```

The revision flag cannot describe dirty edits; record those separately. This is
not a native process-start profiler. Reproduce, export, then analyze with:

```sh
python3 scripts/analyze_performance.py boorusama-performance.json
```

Device unavailability must not prevent implementation or deterministic tests.
Record missing real-device baseline data explicitly rather than claiming it exists.

### 3. Implement the minimal cache fix separately

Maintain occupied bytes incrementally, skip candidate collection/sorting when
capacity eviction is unnecessary, and handle retired-generation cleanup separately.
Check both `_trim()` and `_commit()`. Do not alter GIF playback, image quality,
thumbnail policy, cache format or unrelated application behavior in this patch.

Preserve reader leases and generation ownership. Retired-but-pinned bytes must
continue counting according to the current policy until actual deletion. Cover
replacement of the same key, multiple generations, clears during writes, zero
limit, oversized entries, failed I/O, externally missing files, initialization
and restart/index reconciliation. Add focused regression tests for these behaviors.
Protect scaling with deterministic work counts or a separate benchmark, not fragile
millisecond assertions in ordinary tests. Do not build a general benchmark framework.

Keep checkpoint policy unchanged for the first A/B comparison. If it remains
significant, make a separate change for coalesced recency updates or off-isolate
encoding. Do not weaken crash recovery or durable metadata guarantees merely to
avoid flushes; approximate last-used information and file ownership are different.

### 4. Compare and run final verification

Compare the diagnostic-only and fixed revisions on the same device, media,
settings and refresh rate, with the existing large cache retained. Include about
1,800/3,400 entries and larger where practical, counting bytes separately. Test
cached-image revisits, new image loads, normal search, group overview, GIF-heavy
groups, viewer swipes and process restart with retained disk cache. Keep automatic
backup/refresh settings constant between runs. Measure logging enabled/disabled
once to check diagnostic overhead.

Inspect UI/raster frame distributions, scheduling delays, synchronous eviction
scan/index-encoding spans, and queue waits separately. Do not sum nested spans.
Acceptance means smooth scrolling with the previously problematic filled cache,
not smooth scrolling only after clearing it or disabling GIFs.

After the final edit, run the complete current local suite required by AGENTS and
`docs/engineering_guidelines.md`: application, all package/CLI suites, repository
shell tests and all Python tooling tests. Focused passes or the preparation workflow
do not replace this. Build debug and release, verify device capture/export where
available, review the final diff, and report blockers without claiming readiness.

## Deferred findings, not blanket implementation scope

Keep these separate unless residual measurements point to them:

- Redundant ImageInfo clones not disposed; unnecessary stream-listener replacement.
- Preloader same-URL cancellation race, swallowed errors treated as success,
  unbounded completed history and stale cache-presence assumptions.
- Refresh/load-more overlap without stale-request generation protection.
- Full bookmark decode/index reload after small mutations, broad view invalidation,
  rebuilt bookmark URL sets, and full sorts for four cover previews.
- Full-collection origin/media resolution for adjacent viewer preloading.
- Whole-feed snapshot reconstruction after individual automatic refreshes and
  preview recomputation on progress-only state changes.
- Main-isolate export encoding, expensive feed-history merging/request volume,
  redundant image byte copies and missing shared-request lifecycle ownership.

Not every secondary finding is known to be fork-introduced. Establish that
through history/upstream comparison or measurement before making that claim.

## Final report

Report base, diagnostic-only and fixed SHAs; branch/worktree; actual diagnostics
integration; cache changes/invariants; tests/builds really run; device A/B conditions
and results or unavailable measurements; integration/publication status; remaining
work. Distinguish "code defect fixed", "tests passed" and "device stutter eliminated".
No additional downloaded handoff files should be necessary.
