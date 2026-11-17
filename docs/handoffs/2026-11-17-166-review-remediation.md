# Issue #166 review remediation

Refs #166. Extends source candidate `09f0233fe167e4112828eff24057c2f3d9ae7e89`.

Cover recovery patches a single canonical record under the serialized coordinator
and journal commit guard. It preserves native source-group indexes, details,
identity and timestamps; legacy records retain their storage type. Received and
shared records use an access/policy/source-revision scoped presentation cover and
never mutate publisher payloads, digests, checkpoints or organization.

Lookup futures deduplicate only in flight. Completed outcomes have a one-minute
cooldown and a 256-entry bound; provider keep-alive ends with the lookup. Ordinary
revisits can retry after connectivity recovers.

## Verification

Real Hive regressions failed before the correction for native index corruption
and received-record mutation. Controlled-clock queue tests reproduced permanent
error retention. The final focused command passed **93 tests**:

```sh
fvm flutter test --no-pub --concurrency=6 test/core/bookmarks/pool_cover_native_persistence_test.dart test/core/bookmarks/pool_cover_backfill_test.dart test/core/bookmarks/pool_bookmark_refresh_failure_test.dart test/core/bookmarks/pool_bookmark_source_policy_test.dart test/application/pool_bookmark_flow_test.dart
```

The existing explicit-refresh fixture consumed its only response during automatic
cover recovery on the original candidate too. It now supplies a separate response
for the explicit refresh, preserving its assertions. Changed-scope analysis found
70 informational findings, zero warnings/errors. Independent review found no
runtime defects; its public-success coverage request was added and passed.

Durable red/green logs are under
`.worktrees/_artifacts/pre-release-remediation-20261117/166-*.log`.
The cumulative preview report records the full-suite and native gates separately.
No live service, emulator, Android device or authenticated subscription acceptance
was performed. Missing or ambiguous originating profile identity still fails
closed; this correction does not invent a profile mapping for legacy imports.
