# Guard unified-post pipeline performance

Priority: Normal
Affected feature: `feature/bookmark-post-behavior-parity`

## Problem

The unified post pipeline adds snapshot decoding, per-post presentation lookup,
and origin resolution to bookmarks and Following Feeds. The branch has broad
correctness coverage but no repeatable performance workload in the normal test
suite. In particular, presentation-provider state can grow with individual
post payloads instead of the small set of supported presentation types.

## Expected behavior

Representative snapshot and real-Hive workloads run under `fvm flutter test`,
emit stable benchmark telemetry, and protect deterministic scaling properties
without relying on narrow wall-clock thresholds.

## Acceptance criteria

- Equivalent presentation requests reuse bounded provider state instead of
  retaining one provider per post.
- A representative mixed-engine snapshot workload measures encode, JSON
  round-trip, decode, and serialized size in the normal test suite.
- A real-Hive bookmark workload measures write and cold reopen/load behavior.
- Deterministic invariants and generous catastrophic-runtime/size guards fail
  regressions without making normal CI sensitive to small timing variance.
- Focused and full test suites pass.

## Constraints

- Keep image decoding, rendering FPS, and device-profile measurements outside
  unit tests; debug-mode widget timings are not stable CI signals.
- Do not add external benchmark dependencies.
- Preserve engine payload validation and generic fallback behavior.

## Progress

Agent: Codex (`/root`)
Branch: `feature/bookmark-post-behavior-parity`

- 2026-09-24: Claimed after user approval of the hybrid performance-test
  design.
- 2026-09-24: A red provider-cardinality test observed 500 retained
  presentation-provider elements for 500 equivalent payloads. Presentation
  requests now key provider state by booru type and payload contract instead
  of individual post contents; all current codec and presentation support
  checks were verified to use those same contract dimensions.

## Completion evidence

- The focused performance suite passed all five tests. Its isolated telemetry
  for 1,000 representative posts was 23.954 ms encode, 93.417 ms JSON
  round-trip, 46.925 ms decode, and 2,002,931 serialized bytes.
- Resolving 5,000 origins against 50 profiles took 9.22 ms in the isolated
  run.
- Writing 1,000 native Gelbooru bookmarks to Hive took 354.679 ms; closing,
  reopening, and loading them took 141.713 ms, with 2,317,610 bytes on disk.
- `fvm flutter test --no-pub` passed all 1,424 tests.
- Focused analysis of the seven changed Dart files completed with no issues.
