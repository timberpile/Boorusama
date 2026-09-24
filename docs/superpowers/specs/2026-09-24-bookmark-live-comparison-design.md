# Bookmark Live Comparison Design

## Goal

Compare the real-device bookmark behavior and performance of the current
`develop` architecture with `feature/bookmark-post-behavior-parity` using the
same 1,000 live posts, profiles, emulator, interaction sequence, and measured
conditions.

The comparison must show the cost and behavior of the richer stored-post model
without treating network variability or test-data drift as an architectural
result.

## Scope

The comparison covers:

- 500 Danbooru posts and 500 Gelbooru V2 posts;
- authenticated profiles recreated after clearing app data;
- live post resolution followed by local bookmark creation;
- cold bookmark loading, first-grid presentation, memory use, Hive size, grid
  scrolling, mixed-source viewer navigation, and post details;
- preservation of native per-booru presentation in the feature branch;
- a fixed functional sequence that exposes known bookmark-viewer failure
  modes;
- a concise report comparing pinned `develop` and feature-branch revisions.

This is a one-time comparison. The importer and measurement instrumentation are
temporary benchmark code and will not be merged into the product. Import time
is setup data and is never included in performance results.

The comparison does not mutate server favorites, votes, comments, tags,
follows, or any other remote state. It does not establish long-term performance
budgets or replace the deterministic performance guards in the normal Flutter
test suite.

## Revisions and Environment

Each run records the exact Git commit, Flutter version, Android emulator ID,
Android version, build mode, manifest hash, and timestamp. The default device
is `emulator-5556`, and every ADB or Maestro operation explicitly targets that
device.

Both revisions use the Dev flavor in profile mode. They run sequentially on the
same emulator; parallel emulator runs are not comparable because host load can
change frame and memory results. The `develop` revision is pinned before any
test data is collected. The feature revision includes the provider-cardinality
optimization and performance guards being evaluated.

Before each revision, the Dev package `com.timberpile.boorusama.dev` is stopped
and all of its app data is cleared. Danbooru and Gelbooru V2 profiles are then
created through the normal profile flow from repository-local
`.test_credentials` values.

Credential values must never appear in source files, fixtures, manifest data,
shell output, logs, screenshots, reports, or responses. Automation may read
only the required keys locally and inject them into the assigned emulator
without printing their values. No screenshots are captured while credential
fields are visible.

## Frozen Post Manifest

The comparison uses one versioned JSON manifest retained as a non-sensitive
test artifact. It has exactly 1,000 entries:

```json
{
  "schemaVersion": 1,
  "entries": [
    {"sequence": 0, "profile": "danbooru", "postId": 123},
    {"sequence": 1, "profile": "gelbooru_v2", "postId": 456}
  ]
}
```

`sequence` is contiguous, starts at zero, and defines the expected visible
bookmark order. `profile` is exactly `danbooru` or `gelbooru_v2`. `postId` is a
positive integer. A `(profile, postId)` pair may occur only once. Profile IDs
are logical keys rather than local database IDs, which change after every app
reset.

The entries alternate profiles wherever possible so adjacent viewer pages
exercise dynamic presentation switching. The importer accounts for the
bookmark sort direction when writing records so the visible order matches
`sequence`.

Each profile contributes 500 general/safe, non-deleted posts. A curated subset
at the start covers static images, animation or video, notes, comments,
parent/child relationships, sources, uploader data, and differing metadata.
The remaining entries form a realistic large library. The manifest contains no
credentials, tags, source URLs, or media URLs.

Candidate collection happens once before either measured run. The frozen
manifest is then validated through both configured profiles. Validation
requires:

- schema version `1`, 1,000 contiguous entries, and no duplicate identities;
- exactly 500 Danbooru and 500 Gelbooru V2 entries;
- every live response to exist and return the requested ID;
- no deleted, banned, or unavailable post;
- successful resolution of every curated case;
- a recorded SHA-256 digest.

If any manifest post becomes unavailable, the comparison stops. A replacement
is selected once, the manifest digest changes, and both revision runs restart
from cleared app data. A missing post is never skipped or replaced for only one
revision.

## Temporary Import Harness

The temporary Dev-only harness has four focused parts:

1. immutable manifest values and strict parsing;
2. a shared import coordinator;
3. one thin post-loading adapter per architecture;
4. a Dev-only page showing preflight, fetch, validation, write, rollback, and
   completion progress.

The shared coordinator resolves the two profiles by logical key and booru type.
It loads posts with bounded concurrency and limited retry/backoff for transient
network failures. It holds all resolved posts until preflight is complete and
verifies their identities before the first bookmark write.

The `develop` adapter uses the existing engine post repository. The feature
adapter uses the origin-aware repository so every stored post carries its
actual profile identity. Both adapters return the normal application `Post`
type for their revision.

After successful preflight, the coordinator writes bookmarks through the
normal `BookmarkRepository` using each profile's real image resolver and post
link generator. Writes follow the reverse of the desired visible order when
the configured bookmark sort is newest-first. The feature revision therefore
uses its real snapshot codec and booru payload codec rather than constructing
benchmark-specific bookmark objects.

If a write fails, the harness removes every bookmark created by that run and
verifies that storage is empty. A partial library is never accepted as a test
state. The final verification reloads storage and requires the exact count,
identity set, profile distribution, and expected order before enabling the
measured test phase.

The two harness variants live only on isolated comparison branches or patches.
They are never merged into `develop` or the feature branch. Their shared logic
and manifest remain equivalent; only the post-loading adapter may differ.

## Measurement Model

Import, profile creation, network retries, manifest validation, and media-cache
preparation are explicitly unmeasured.

For each revision:

1. complete setup and verify all 1,000 bookmarks;
2. stop the app process;
3. perform one unmeasured cold-start warm-up;
4. perform four measured cold starts and use their median;
5. warm the thumbnails needed by the fixed UI sequence without measuring;
6. perform the measured scroll and viewer sequence;
7. perform destructive local behavior checks only after performance runs;
8. restart once more and verify final persistence.

Temporary structured markers measure the actual repository load and the first
grid frame. They emit only metric names, elapsed durations, counts, run numbers,
and revision labels. Android process tooling records memory after settling and
Hive storage size. Frame statistics are reset immediately before the scripted
grid/viewer sequence and collected immediately afterward.

The report records:

- median Hive bookmark-load duration;
- median time from opening Bookmarks to the first meaningful grid frame;
- process memory after the loaded grid settles;
- slow and missed frame counts during the fixed interaction sequence;
- frames exceeding 16 ms and 32 ms where the available tooling exposes them;
- Hive bookmark storage size;
- exact bookmark count and profile distribution.

Image downloads are excluded from load timings. The UI sequence runs only
after its required thumbnails have been cached in an unmeasured pass. Any
remaining network request is recorded as a confounder rather than silently
attributed to the post architecture.

## Functional Sequence

The same scripted sequence is used on both revisions:

1. open the complete 1,000-item bookmark view and confirm count and mixed
   profile markers;
2. scroll through fixed grid distances in both directions;
3. open a curated Danbooru post and verify its expected native presentation;
4. swipe to an adjacent Gelbooru V2 post and verify that toolbar, overlays,
   details builder, and profile marker change dynamically;
5. continue across a fixed set of alternating posts, including static and
   animated/video media;
6. open details for both engines and navigate back without an assertion or
   stale-profile error;
7. confirm no valid-profile post shows the generic fallback warning;
8. remove one local bookmark while its viewer is open and confirm that the
   current media remains visible until leaving the bookmark view;
9. leave and reopen Bookmarks, confirm the count is 999, and verify the removed
   identity is absent;
10. restart the app and confirm the remaining 999 bookmarks retain their
    identity, order, and profile distribution.

Read-only native controls may be inspected. Controls that mutate remote state
are not activated. The `develop` run is observational baseline data: known old
behavior is recorded, not adopted as the expected feature behavior.

## Comparison Rules

Correctness failures are unconditional on the feature revision. These include
crashes, assertions, black media, wrong profile markers, incorrect count or
order, lost profile identity, native presentation failing to switch, or an
unexpected generic fallback.

Performance does not use a single noisy pass/fail threshold. The report flags
the feature revision for investigation when:

- median bookmark loading is at least 25 percent and 100 ms slower;
- settled process memory is at least 25 percent and 50 MiB higher;
- slow-frame behavior materially worsens, especially repeated frames above
  32 ms;
- results vary enough across the four measured runs to make the median
  misleading.

Hive size is contextual because the feature deliberately stores more native
data. Its absolute and per-bookmark values are reported without requiring
equality with the simplified `develop` records.

## Failure Handling

Setup stops on invalid credentials, profile mismatch, manifest drift, missing
posts, duplicate identities, partial writes, or unexpected network failures.
The cause and affected logical profile/ID are reported without exposing
credentials or post media.

A failed measured run is repeated only after classifying whether the cause is
the app, backend, network, emulator, or test tooling. Product defects are
reproduced once before any fix. Source edits are not made while a comparison
run is in progress, and the pinned revision never changes between repetitions.

## Artifacts and Delivery

The retained artifacts are:

- this design;
- an implementation and execution plan;
- the frozen 1,000-entry manifest and SHA-256 digest;
- an evidence report with revision hashes, environment, raw run values,
  medians, functional outcomes, confounders, and conclusions.

Credentials, APKs, screenshots containing sensitive fields, image caches,
Hive databases, temporary importer code, and temporary instrumentation are not
retained as project artifacts.

After the report is reviewed, temporary comparison branches and worktrees are
removed only with explicit approval. No benchmark helper is merged into the
application.

## Acceptance Criteria

- The manifest contains and validates exactly 500 Danbooru and 500 Gelbooru V2
  identities and has a recorded digest before either measured run.
- Both revisions start from cleared Dev app data and recreate the same two
  authenticated profiles without credential disclosure.
- Both imports use normal post and bookmark repositories and produce the exact
  manifest library before measurement.
- Import and network setup are excluded from all performance metrics.
- Four measured cold starts per revision produce raw values and a median.
- The fixed functional sequence is executed against both pinned revisions on
  the same emulator.
- The feature revision passes every correctness check or each failure is
  reported and reproduced.
- The final report distinguishes measured architecture cost, intentional
  storage growth, network/tooling confounders, and baseline-only old behavior.
- Temporary product code is not merged and is cleaned up only after review and
  explicit approval.
