# Rule34 and Safebooru pinned-search tracking

Implemented on `feature/chronological-pinned-search-support`, including the existing
pinned-search feature branch because it has not reached `origin/develop`.

Rule34 and Safebooru.org use XML post-list endpoints to obtain `created_at`
that JSON can omit. The XML parser preserves typed fields and total counts.
Shared date parsing handles padded whitespace and single-digit days.

Generation, static analysis, and the Android development build passed.
After integrating bounded snapshots and NEW indicators, the full suite passed
1,039 tests and the focused pinned-search suite passed 121 tests. See completed
[PS-001](../done/PS-001-bounded-newest-post-refresh.md) for that decision and
verification. Engine adapters and unsupported-profile messaging are queued in
[PS-005](../done/PS-005-engine-refresh-adapters.md).

Maestro verified the user's Safebooru `absurdres` pin on the updated emulator
build: Refresh All established a baseline, removed the unsupported warning,
showed Last checked, and a subsequent refresh remained successful.
Authenticated Rule34 validation still requires a configured Rule34 profile.
No commit, push, or pull request has been created.
