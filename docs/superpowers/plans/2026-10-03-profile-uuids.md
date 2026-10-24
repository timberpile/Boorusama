# Profile UUID implementation plan

> **Historical implementation plan (completed).** Do not execute these steps
> as a new task. Use the current subsystem docs and GitHub Issues for future
> work. Retired local-ticket procedures below are not applicable.


The canonical profile UUID behavior is included in the [post origin and profile model](../../post_architecture.md#runtime-model). This historical plan retains additional migration decisions from the original `feature/idea-002-profile-uuids` implementation. Existing integer profile data and archives need no migration, but unsupported archives must fail before import writes. Engine IDs, remote post IDs, and Hive row keys unrelated to profiles stay numeric.

## 1. Canonical profile identity and storage

- Write failing tests for new profile IDs, duplicate IDs, edit identity retention, and malformed UUID parsing.
- Convert `BooruConfig.id`, repository methods, Hive profile keys, settings current selection/order, and route IDs to lowercase UUID strings. Keep a nonpersisted new-profile marker distinct from a real ID.
- Ensure launch with old integer-keyed records fails safely or falls back to setup without a crash. Do not read or migrate them as valid profiles.

## 2. Dependent profile references

- Write failing tests for pin/feed ownership, deletion/rollback, and cached post origin resolution with UUID hints.
- Convert profile ownership and all related provider, repository, Hive, cache, and route signatures. Preserve numeric engine and remote post/user IDs.
- Run focused configuration, subscription, and post tests.

## 3. Export and import identity

- Write failing tests for UUID archive round-trip, repeat import, profile Copy, explicit mapping of unmatched UUIDs, same UUID with incompatible engine/site, and integer archive rejection before mutation.
- Convert profile references, export selections/templates, runtime snapshots, import projections, dependency mapping, transaction and recovery paths to UUIDs. New imported profiles preserve their UUID; Copy mints one and remaps selected dependents. Automatic mapping requires equal UUID and compatible engine/site.
- Run focused export/import tests.

## 4. Performance and verification

- Measure serialized bytes and decode/load time for a representative feed containing 500 cached posts before and after conversion; record method and results in the ticket. Remove repeated hints only if the measured cost warrants it and resolution semantics remain correct.
- Format changed Dart files, generate only when generation inputs changed, run targeted analysis and tests, then the full Flutter suite and `git diff --check`.
- Review every acceptance criterion, record evidence in the ticket, and leave the branch for coordinator review without publication or integration.
