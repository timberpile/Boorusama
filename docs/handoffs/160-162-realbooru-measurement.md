# P1 Realbooru Android measurement — 2026-11-09

## Result

**Performance acceptance remains unresolved.** P1 does not demonstrate a
consistent improvement over the specified develop base. Ordinary thumbnails,
as well as high-quality upgrades, can arrive late. These measurements do not
establish connection saturation, so no source-specific pacing, quality,
format-fallback, or cache-format policy change was made.

## Candidate and method

- Baseline: `266a14c0f87f29213d48696bda7c806dc1d05b6e`.
- P1 runtime/test candidate: `bba2c565c6b6a430ac7cf69e4e014656d62ebb47`.
  The final candidate `c360ce0611bdfbff85d8a7510e91801591f656ac` subsequently
  fixes only the cached history action's navigation inset, with regression
  coverage. These timing measurements remain evidence for the earlier candidate;
  no performance improvement is claimed for the final candidate.
- Android Phone1, exclusively leased `emulator-5554`, 720 × 1600 physical
  pixels, density 320, font scale 1.0; Flutter 3.47.2 / Dart 3.13.2.
- Both builds used the ordinary production bootstrap through `lib/main.dart`,
  real public Realbooru requests, debug mode, and identical diagnostic observers
  in separate detached worktrees. Diagnostic observers are absent from P1.
- Each variant covered Low/High quality × Small/Medium/Large grids × cold/warm
  image cache: **24 cases**, each with two forward and two reverse gestures
  (**96 scroll intervals**). Settings were profile-specific. Live page exposure
  and gesture distance vary; this is observational evidence, not a controlled
  throughput benchmark or a causal regression result.
- Cold cases used new, dedicated image-cache namespaces. Only those generated
  directories were cleared. Existing user image cache was preserved. Warm cases
  reused the process and namespace. This measures isolated image-cache coldness,
  not cold OS/network/service caches.
- Final captures all have zero dropped counter records and zero logical active
  adapter requests after draining. Earlier provisional VM-timeline/profiler
  captures were rejected because ring eviction and stale native request records
  made them unsuitable for complete-case timing.

The adapter observer preserves the native transport and counts adapter attempts,
response headers, streamed body bytes, cancellation, status, and errors. Attempts
are not proven wire requests, and received body bytes exclude protocol overhead.
The image-cache observer records first image availability and decoded-memory cache
status. Availability includes scheduling, I/O, cache work and decoding; it is
**not CPU decode duration**. A successful memory miss without an adapter request
suggests encoded-memory/disk reuse, without identifying a direct disk-cache hit.
Native Flutter frame timings are grouped by actual scroll notifications.

## Thumbnail availability comparison

The following medians use matching image identities in each cold pair, measured
from the image request to first thumbnail availability. They include prefetched
offscreen requests; the viewport repeat below separately checks initial tiles.

| Quality / grid | Matched thumbnails | Baseline | P1 |
| --- | ---: | ---: | ---: |
| Low / Small | 33 | 1.500 s | 2.488 s |
| Low / Medium | 16 | 0.632 s | 1.373 s |
| Low / Large | 4 | 0.494 s | 0.554 s |
| High / Small | 36 | 3.839 s | 18.856 s |
| High / Medium | 16 | 1.256 s | 3.178 s |
| High / Large | 3 | 0.704 s | 0.825 s |

The High/Small outlier was repeated with a paint-only observer recording tile
identity, index, time and bounds. Across 33 matched thumbnails, availability was
6.42 s baseline versus 9.51 s P1. For the initial 12 painted tiles, ordinary
thumbnail availability followed first tile paint by a median **6.27 s baseline
versus 9.16 s P1** (ranges 6.254–6.349 s and 9.070–9.212 s), before scrolling.
Paint is not a physical display/presentation measurement. This repeat reduces
the original outlier's magnitude but still shows unresolved ordinary-thumbnail
delay, beyond a late high-quality upgrade.

In that repeat, matched thumbnail response headers were faster under P1
(median 549 → 185 ms), while body-completion-to-availability grew
(4.12 → 6.41 s). The original High/Small cold pair similarly had faster headers
and a much longer post-body interval. This does not identify the cause of that
interval. A read-only VM CPU-sampling attempt returned RPC error 100 because
profiling was disabled; it produced no usable CPU profile.

## Requests, cache reuse and frames

High quality produces substantial probe traffic. Baseline High/Small cold recorded
107 probe attempts, 50 confirmed probe 404s, and 27 cancellations before headers;
probe bodies totaled approximately 6.89 MB versus 150 KB for thumbnails. P1's
corresponding case recorded 81 probe attempts, 37 confirmed 404s, and 10
pre-header cancellations. These counts alone do not establish saturation.

Warm Low cases mostly required no HTTP, although P1 Low/Small encountered three
new requests. Baseline warm High/Medium and High/Large needed no adapter requests;
warm High/Small still produced 55 probes, 48 pre-header cancellations, and five
confirmed 404s. P1 warm High/Small produced 43 probes, 41 pre-header cancellations,
and one confirmed 404. Different viewport exposure prevents treating unmatched
warm counts as a controlled comparison.

Frame results are mixed. For High/Large cold, forward total-frame p95 changed
61.6 → 82.1 ms while reverse changed 31.5 → 28.0 ms, pooling frames by direction
and using the summary helper's rounded percentile index. Other cells also mix increases
and decreases. Debug mode, an emulator, differing distances/exposure, service
variation, and limited repetitions prevent release-device responsiveness or a
causal performance regression claim.

Existing preferred-format history already reuses known winners. One observed
warm cached `.jpeg` load remained pending long enough for the 800 ms decoded-image
deadline to expand alternate probes; some were canceled shortly afterward.
This is a possible follow-up seam, not evidence that removing fallback, lowering
quality, or changing global image-provider equality is appropriate.

## Reproducibility and remaining work

Durable local evidence is under
`.worktrees/_artifacts/160-timeline-prefetch-package/`:

- `matrix/*.json`, `matrix-summary.csv`, and `scroll-frames.csv`: sanitized final
  counters and per-gesture frame summaries; `summarize_metrics.py` validates and
  regenerates both CSVs. The CSV availability medians include cache hits and
  repeated records; the table above instead compares matching identities' first
  cold misses, so the medians need not agree.
- `matrix-build-provenance.json`, retained measurement APKs and diagnostic source
  snapshots/patches: build and observer correspondence.
- `repeats/*high-small-cold*.json` and initial screenshots: bounded viewport
  repeat; `repeats/p1-post-body-cpu.json`: failed CPU-sampling attempt.
- `full-regression-final.log`: complete host regression on the P1 candidate;
  this is separate from Android timing evidence.

An independent read-only review validated all 24 captures and the repeat and
agreed that source correctness passed while Realbooru performance acceptance
remained unresolved. Next investigation should obtain a useful CPU/cache/decode
profile of the post-body interval and repeat under release/profile conditions
before choosing a behavioral fix. No integration or publication is authorized.
