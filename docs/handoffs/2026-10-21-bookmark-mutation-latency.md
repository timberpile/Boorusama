# Bookmark mutation latency: local verification handoff

Verification results and scoped corrections are recorded in
[the local verification report](2026-10-21-bookmark-mutation-verification.md).
The assignment and unverified status below describe the original handoff.

## Assignment and branch

Continue `fix/bookmark-mutation-latency` in an isolated local worktree. Verify the implementation, fix scoped defects, commit and push the corrections, and report the tested commit and results. Do not open a PR, merge into `develop`, delete branches/worktrees, or overwrite the separate server-favorites worktree without further authorization.

- Repository: `timberpile/Boorusama`.
- Branch base: `03b1cb422fad84402103ee1f9544910a4d92ef77` (`develop` when this work started).
- Implementation tip before this documentation commit: `4d32b3d25af1ccaf2f08c2f6459ac6a2d4118687`.
- Original local work: `feature/44-server-favorites`, `.worktrees/44-server-favorites`, reported at `cce0285bc`. That branch/commit was not available through the remote repository during implementation. Its existing `addPostsToGroup` optimization was not directly inspected or merged here.

Read `AGENTS.md`, the relevant development/engineering guidelines, and the existing worktree instructions. Fetch the remote branch and reuse its worktree if one already exists. Preserve unrelated local changes. Do not assume this branch contains the unpublished server-favorites work.

## Verification status: important

The implementation and tests were committed through the GitHub connector. Relevant source, interfaces, call paths, and principal diffs were inspected. No local checkout of the user's repository or Flutter/Dart/FVM toolchain was available; direct GitHub downloads from the execution container also failed.

**No Dart formatter, analyzer, Flutter tests, application build, benchmark, or Android measurement was run.** The new tests are unexecuted, not evidence of a passing red/green cycle. This branch is not yet verified for integration. Start with formatting, compilation and the targeted tests; correct API, fixture, lint, or behavior issues before device work.

The previously reported approximately 132 ms to 9 ms host-debug improvement at 5,000 bookmarks belonged to another branch's bulk-add path. It is not a result for this branch, normal toggles, or Android frames.

## Implementation map

### Shared mutation path

`bookmark_provider.dart` now creates a zone-local `BookmarkMutationRepository` for each serialized operation. The existing global coordinator and local mutation queue remain. The temporary repository reads the already-loaded library and records successful writes, including actual persisted IDs. It is not a second long-lived cache.

Normal successful publication applies those changes to the existing library instead of calling the full load/decode/repair sequence. Group and folder metadata are still read from their repositories and validated. An ambiguous bookmark write invalidates the temporary view, so commit-then-throw recovery and rollback consult actual storage. Sessions also expire in `finally`; a late callback must not recover through an earlier operation's snapshot.

Public `runSerializedMutation` remains conservative for external/import/restore callbacks that can write directly to repositories. It invalidates the fast path and reloads, or marks a refresh necessary when `reload: false`. Initial load, explicit reload, and error recovery retain full decoding and repair.

Affected notifier families include normal toggle/set membership, single/new/existing additions, batch additions, removal by identity/group/posts, global deletion, Undo, group/folder operations, and snapshot updates. ID-based removal now resolves its row and target within one serialized operation. Bulk additions deduplicate identities and skip membership writes when there is nothing to add.

### Lookup and immutable state

`BookmarkIdentityLookup` is an optional repository capability. The mutation repository implements indexed subset lookup; ordinary standalone repositories/services retain a full-read fallback. Service methods resolve affected identities rather than decoding the entire library when the capability is available. Global deletion also resolves fresh storage IDs, avoiding stale handles after restoration.

`BookmarkLibraryState.applyCommittedChanges` reuses untouched snapshots and indexes. Membership-only changes retain the item list and post indexes; metadata-only changes retain membership indexes. Actual row changes still shallow-copy affected maps/lists. Membership reconstruction uses separate removal and insertion passes, including storage-ID replacement and identity swaps. This is not a claim that every operation is O(1).

Collection preview/deletion operations use an optional authoritative snapshot callback inside the notifier's serialized boundary. Standalone services retain their previous load-and-repair behavior. Stale-preview validation and rollback must remain intact.

### Grid and viewer interaction

`KurumiLikeButton` has opt-in `controlled` and `enabled` parameters. Only the bookmark quick action opts into controlled mode. Every enabled tap is forwarded even while a previous callback or animation is pending; the notifier serializes the writes. Callback return values cannot override a newer externally supplied state. Removing a bookmark resets the controlled animation. Loading disables the actual interaction instead of falling back to a local-only toggle.

Default behavior remains unchanged for server-favorite consumers: existing pending-operation and animation locks are retained. Audit all consumers locally before changing those defaults.

Both bookmark buttons select per-post presentation through `bookmarkButtonStateProvider`. Tag counts and available source URLs select the immutable item list rather than every library update. Bookmark grid refreshes ignore irrelevant metadata and out-of-view membership changes, coalesce same-frame library refresh requests, and retain the existing viewer-visible refresh gate.

There is no speculative optimistic success state: icons still reflect committed library state. Measure persistence-to-display latency separately from input acceptance.

### Hydration

Hydration fetches and retry/backoff waits no longer hold the global mutation lock. Each recovered response uses a short serialized compare-and-commit. A deleted/replaced/newer bookmark or cancellation causes the old response to be skipped rather than resurrecting or overwriting data. The current guard intentionally requires the same immutable bookmark instance, so a full reload/restore also supersedes outstanding responses.

Standalone hydration service callers keep direct persistence through an optional commit callback. Superseded responses are currently counted as skipped and logged with the existing `requestCancelled` reason. No new localization or storage schema was introduced.

## New regression coverage to execute

- `test/core/bookmarks/bookmark_mutation_latency_test.dart`: warmed ordinary operations without whole-library reads/repairs; shared and final removal; Undo with new storage ID; batch deduplication; index sharing; queued rapid toggles; commit-then-throw recovery; external-mutation reload; hydration fetch not blocking a toggle.
- `test/core/bookmarks/bookmark_library_delta_test.dart`: delta state/indexes compared with cold reconstruction, identity remapping, immutability, and no-op identity reuse.
- `test/core/bookmarks/bookmark_view_contents_changed_test.dart`: content-relevant versus metadata/out-of-view refreshes.
- `test/core/bookmarks/bookmark_derived_state_test.dart`: retained tag/source results and selective button notifications.
- `test/core/bookmarks/bookmark_mutation_session_test.dart`: deferred callbacks cannot publish a completed operation's stale snapshot.
- `packages/kurumi/test/controlled_like_button_test.dart`: pending/animated rapid input, out-of-order callback completion, disabled state, and preservation of default interaction locks.

Keep and run the existing service, provider, group/folder, hydration, Undo, viewer and application-flow suites. Some older fault-injection fixtures fail on a numbered full-library read. If that read was intentionally removed, move the injected failure to the corresponding real recovery/publication boundary; do not delete the behavioral assertion or simply weaken it.

## Local verification commands

Use the repository's normal FVM/bootstrap setup. Run generation only when missing generated output or changed inputs require it. Example shell commands from the task worktree:

```bash
BASE=03b1cb422fad84402103ee1f9544910a4d92ef77
export TEST_CONCURRENCY="$(python3 scripts/physical_core_count.py)"

# Format only Dart files changed by this task, then review the formatting diff.
git diff --name-only -z --diff-filter=ACMR "$BASE"...HEAD -- '*.dart' \
  | xargs -0 -r fvm dart format
git diff --check

fvm flutter analyze
fvm flutter test --no-pub --concurrency="$TEST_CONCURRENCY" test/core/bookmarks
fvm flutter test --no-pub --concurrency="$TEST_CONCURRENCY" test/application

(
  cd packages/kurumi
  fvm flutter analyze
  fvm flutter test --no-pub --concurrency="$TEST_CONCURRENCY"
)

# Broad core/model and shared-widget changes require the complete gate.
./scripts/run_regression_tests.sh
```

Fix failures on this branch and rerun the relevant checks. The final integration candidate must pass the complete runner, not only the new tests. Record exact commands, exit results, commit, and any environment limitations.

## High-priority behavioral review

1. Check every direct bookmark repository writer, including imports, restore, hydration, and the unpublished feature-44 code. An out-of-band write must not leave the published library trusted but stale. Keep authoritative reload boundaries for unknown writes.
2. Exercise failures before a write, after a committed write, during membership update, during rollback, and during publication/recovery. A failed refresh must retain the previous UI snapshot and force reconciliation before the next mutation. Verify that Undo uses actual restored IDs, later deletions invalidate stale Undo, and shared bookmarks are never deleted early.
3. Add/extend tests for a successful hydration response arriving after deletion, deletion plus re-add, a newer snapshot, cancellation, and import/restore. The included hydration blocking test holds a fetch open but does not cover all successful-response races. Check both interactive responsiveness and total hydration throughput now that successful rows publish individually.
4. Cover group/folder duplication, movement, deletion and stale previews through the notifier, not just standalone services. Verify there are no unexpected full snapshot reads on the warm success paths, while standalone fallback tests remain valid.
5. Verify rapid input in both grid and viewer, across target switches, errors, widget disposal and navigation. Inspect picker/context-menu behavior and all `KurumiLikeButton` consumers, especially server favorites. Preserve current target-selection and Undo semantics rather than silently redesigning them.

## Performance and Android validation

Use a reproducible disposable library at small size and around 5,000 bookmarks, including multiple memberships and a large target group. Compare this branch against the exact base on the same setup. Reconcile separately with the local `cce0285bc` feature branch rather than attributing its benchmark to this change.

Measure new addition, existing-post group addition, removal with remaining memberships, final-membership deletion, Undo, no-op membership assignment, bulk add/remove, and rapid add/remove sequences. Separate queue wait, storage write wall time, synchronous decode/index work, publication/list refresh, and input lockout. Report p50/p95 and sample counts; do not turn host timings into brittle unit-test thresholds. Use real Hive-backed measurements as well as deterministic operation-count tests.

The warm success-path contract is zero whole-library snapshot reads/decodes/repairs for normal notifier mutations. That contract alone does not prove acceptable frame timing or perceived responsiveness.

Before touching an emulator, read `docs/android_emulator.md` and acquire its exclusive lease. Use Maestro MCP as required by the repository. Reproduce the reported debug behavior on both grid quick actions and the viewer, then measure frame behavior in a profile build on a suitable target. Cover ordinary taps, rapid alternation, long-press/group picker, context menus, selection actions, Undo, and interaction during a held or rate-limited hydration fetch. Do not expose test credentials in logs, screenshots, fixtures, or commits.

Remaining costs to profile include group metadata scans/copies, whole target-group membership serialization/sorting in Hive, shallow library map/list copies for real row changes, group-browser previews, suggestion indexes, and actual content filtering/sorting. These were not replaced with a new persistent cache or storage schema. Optimize further only where the measurements justify it.

## Feature-44 reconciliation and delivery

Inspect the actual current local server-favorites branch before combining code. In particular, compare its `addPostsToGroup` publication, automatic Favorites-to-Bookmarks additions, manual favorites fetches, and any direct repository writes against the new shared mutation boundary. Preserve the existing feature behavior and do not blindly replace its already optimized path with an older implementation.

Finish with committed, pushed scoped corrections and a report naming the exact tested candidate, checks, real timing results, unresolved issues, and whether integration is now justified. Do not claim success from test source alone, and do not merge or close issue 44 under this handoff's authorization.
