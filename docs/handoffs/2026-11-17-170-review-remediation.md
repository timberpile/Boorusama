# Issue #170 review remediation

Refs #170. Extends `aaf50146c859b8a6f1f20c113a40c27f0421585b`.

Following Topics sorts the final unique display projection after query/profile
filtering and directly subscribed received Topics are collected. Publisher
sections, read-only mirror hierarchy and folder ordering remain intact. Filtered
candidates start in canonical tree/placement order, so returning to Manual
restores saved placement order independently of topic record positions.

## Verification

Three real narrow-page tests failed before the correction: filtered Home,
filtered nested folder and directly subscribed received Topics from two
publishers. They verify both added-date modes, profile/query filters, other sort
choices, Manual restoration and unchanged persisted positions/definitions.
Independent review identified the separate placement-versus-record ordering case;
its deliberately reversed placement regression failed with the original filtered
candidate construction and passes with the final projection.

```sh
fvm flutter test --no-pub --concurrency=6 test/core/search/following_topics
```

Final related scope: **791 passed**. A further unchanged-source focused red/green
check passed all **3** new page tests after byte-for-byte restoration of the final
source. Changed-file analysis: zero errors/warnings, **22 informational findings**.
The preexisting page test still selected Material PopupMenuItem and expected four
sort choices; it now checks the current Kurumi menu and its added-date choices while
preserving its order assertions.

Logs: `.worktrees/_artifacts/pre-release-remediation-20261117/170-*.log`.
No emulator/device, live subscription or full application regression on this
feature branch was performed. The cumulative preview's full gate is separate;
this feature correction is intentionally excluded from that preview and develop.
