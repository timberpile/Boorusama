# Issue #174 review remediation

Refs #174. Extends `21f06536857a7f1598a92b239155055d2dcd7a62`.

Native search results receive route page, position and page mode. An explicit page
forces paginated mode. The grid restores once after authorized results and layout,
using indexed anchors for both standard and variable-height masonry layouts.
Query/account/route changes recreate the route-scoped grid and scroll controller.
Legacy positions index usable compatibility Posts within the loaded page; the
containing Work is selected using transient counts from the actual DTO projection.
Unknown counts, omitted originals and out-of-range positions have explicit tests.

Failed refreshes retain the authorized Work source and its usable envelopes.
Fresh successful results replace envelopes and advance member generations only
after access and API request-generation checks. Incomplete fresh manifests cause
a lazy detail reload. The shared envelope cache supports explicit fresh seeding
without accepting ordinary stale seeds after invalidation.

## Verification

Actual SearchPage regressions failed on the original route for global infinite
mode with explicit page 4. Coverage verifies position 91 maps to Work 30, standard
and variable masonry layouts, once-only restoration, query reset, account switch,
previous/next controller actions and one Work per card. Original on-refresh source
invalidation failed the offline cache test; original non-replacing seeding failed
the successful 3-to-2 Page refresh test. Independent review found both freshness
and sparse Page mapping cases; their corrections were reviewed again.

```sh
fvm flutter test --no-pub --concurrency=6 test/boorus/pixiv/works test/core/content/native_content_grid_test.dart test/core/content/group_envelope_cache_test.dart
```

Final source result: **128 passed**. Changed-scope analysis: zero errors/warnings,
8 informational findings. The cumulative preview separately verifies its #169
retained-refresh and #175 navigation/autohide interactions and full suite.
A preliminary command included a controls test absent from this standalone branch;
that command was incomplete and was replaced by the command above.

Durable logs: `.worktrees/_artifacts/pre-release-remediation-20261117/174-*.log`.
No live Pixiv, authenticated account, emulator or device acceptance was performed.
