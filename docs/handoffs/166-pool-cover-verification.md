# Pool cover recovery verification (#166)

Base: `4542aaa44e5002f7d546fb4ec96bf4cb0523cee5`.
Branch: `bug/166-pool-bookmark-covers`.

New reference drafts had no cover and visible missing covers had no recovery
path. Remote Pool drafts now prefer supplied, source-bound eligible cached
members; Series membership discovery carries those already loaded members.
New committed Danbooru references schedule background recovery, including native
ContentGroup saves, without awaiting it. Visible saved/imported missing covers
use the same provider. Unsaved picker drafts cannot trigger a persisted backfill.

The shared queue admits one lookup at a time, caches jobs by authorization epoch,
local reference ID and cover policy, and bounds transient retries to two attempts.
Each attempt reads one metadata page of at most 40 members, with no membership,
date or media crawl. Current authorization, blacklist/rating and static-image
checks guard admission and commit. Revoked requests cannot publish a cover.
Loading/policy-loading never displays an unverified cached cover; failed checks
show a localized loading error rather than proving that no cover exists.

A serialized cover-only merge preserves identity, creation/membership dates,
groups and unrelated metadata. Existing valid covers and replaced references
cannot be overwritten by late recovery. Storage/export formats are unchanged.

Final checks:

- `fvm dart format` on the nine changed Dart files: passed.
- `timeout 30s fvm flutter test --no-pub --concurrency=6 test/core/bookmarks/pool_cover_backfill_test.dart test/core/bookmarks/pool_bookmark_refresh_failure_test.dart test/core/bookmarks/pool_bookmark_source_policy_test.dart`: 21 passed.
- `timeout 20s fvm flutter test --no-pub --concurrency=6 test/application/pool_bookmark_flow_test.dart --plain-name 'Pool picker saves its summary without waiting for cover indexing'`: 1 passed. The real native picker persists the reference while the one background request is held pending.
- `timeout 20s fvm dart analyze lib/core/bookmarks/src/providers/pool_bookmark_provider.dart lib/core/bookmarks/src/providers/bookmark_provider.dart lib/core/bookmarks/src/widgets/bookmark_pool_card.dart lib/core/bookmarks/src/types/pool_bookmark.dart lib/core/bookmarks/src/types/pool_bookmark_capability.dart lib/core/bookmarks/src/services/pool_cover_backfill_queue.dart lib/boorus/danbooru/pools/bookmarks.dart test/core/bookmarks/pool_cover_backfill_test.dart`: zero errors/warnings, 42 informational findings.
- `git diff --check`: passed.

Earlier attempts exposed incompatible test fixtures, duplicate requests from
invalidating a freshly keyed metadata provider, and a notifier self-read in the
save scheduler. These were corrected; only the final unchanged candidate's runs
above are passes. Test coverage includes cached/source/rating/blacklist checks,
empty results, bounded transient/permanent failure, repeated reads, serial jobs,
profile removal during fetch, stable IDs/dates and preservation of valid covers.

Not run: emulator/Maestro, live Danbooru/accounts, real user data, APK build/install,
complete regression suite or Android visual acceptance. Owner QA: save a Series
and Collection, inspect imported missing-cover cards, retry after a transient
connection failure, restrict ratings/blacklists and switch/remove profiles while
a lookup is pending. Failed jobs remain bounded for the current authorization/
policy session; policy/auth changes admit new jobs, and explicit refresh remains
available. This branch is prepared for manual acceptance, not develop integration.
