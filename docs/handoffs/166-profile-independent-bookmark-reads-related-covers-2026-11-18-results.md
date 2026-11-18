# #166 owner remediation — implementation and verification

The authoritative owner handoff is [166-profile-independent-bookmark-reads-related-covers-2026-11-18.md](166-profile-independent-bookmark-reads-related-covers-2026-11-18.md). Earlier account-bound Bookmark plans are superseded for saved reads.

## Result

Saved Post, Pool/Series, Related and native Group reads choose the first exact-engine/exact-installation local profile in persisted order, ignoring saved profile hints. A proven URI also pins transport, port and installation path. Only an existing explicitly permitted anonymous source with its registered adapter can supply the fallback. An HTTP failure does not cycle accounts. Active viewers and requests retain their captured actor and reject revoked authorization.

MiteMite publication removes local profile hints before signing. Personal backups and local/received canonical records keep their existing codec contract. Existing foreign-hint received records work without republishing or resubscription. No protocol migration, forced revision, release or general storage-migration policy was introduced.

Covers persist their selected image and filtering facts. Current policy may suppress the same image without replacing it; permitted display returns when policy allows. A receiver-local durable choice stays outside publisher payloads/read state and is pruned against confirmed ownership. Failed cache writes retain the confirmed choice and remain retryable. New Related saves use up to 40 eligible cached direct-family members without fetching; missing covers use bounded serialized `parent:<anchor>` discovery. Saved Related oldest/newest changes fetch outside the journal and commit preference plus cover atomically with stale-record/request guards. Explicit Pool reselection requires authoritative source member-order evidence, never a different sampled window.

Discovery is pinned for one visible attempt and cannot restart under a different actor while covered. A new visible period/source revision may select a fresh reader. Existing receiver choices remain available to the current permitted reader independently of discovery. Cover quality/radius/media resolve inside the image source scope.

Native cover and metadata patches preserve unrelated records, membership dates, native sourceGroup index facts, details and Related order. A late metadata refresh cannot undo a newer Related order/cover commit.

## Delivery

Runtime source commits: `8851c1fac37526b922e14838b4592ac1b60b6ca2` and `85ca623e23cacd83eb9d39548a430dd5211d9f06` on `bug/166-pool-bookmark-covers`. The final preview runtime is `d88871594af3efaf1011575cebef1dc0129f4996` on `maintenance/pre-release-bugfix-preview-20261117`.

All 19 previously inventoried bugfix replays remain ancestors. Both new runtime replays and both owner-handoff documentation replays have matching source/replay patch IDs. Feature #170 at `3bd9dd97df3f5e5ddf051d1f1086b0b207f07da3` is excluded by both ancestry and patch comparison. No develop integration, issue closure, PR, branch/worktree deletion or release occurred.

## Verification

Final complete local gate on preview runtime `d88871594af3efaf1011575cebef1dc0129f4996`:

| Check | Result |
| --- | --- |
| `./scripts/run_regression_tests.sh` | Exit 0, uninterrupted; 14 suite completion summaries; no test failures |
| Application | 7,708 passed |
| Every package/CLI | 1,711 passed; two existing `go_router` skips |
| Total Flutter/Dart | **9,419 passed** |
| Repository Python tooling | **76 passed** |
| PR policy and Android release shell tests | Both passed |
| Changed Dart formatting and `git diff --check` | Exit 0 |

Generation ran only where needed: `./gen.sh i18n` for the changed English source-load message, exit 0. Full verification used the repository's detected six physical cores. The 80-test consumer command covered `test/core/bookmarks/public_group_cover_test.dart`, `test/application/public_group_refresh_flow_test.dart`, `test/application/public_group_viewer_flow_test.dart`, and `test/application/pool_bookmark_flow_test.dart` through `fvm flutter test --no-pub --concurrency 6 --reporter expanded`.

The full host log contains 59 Flutter VM/finalizer diagnostic occurrences and 105 non-fatal hit-test warnings. These did not fail the tests; this report does not treat the log as diagnostic-free or claim device acceptance.

Baseline-compatible regression assertions against pre-fix `0044520ea`: **38 passed, seven failed, exit 1**, proving hint/order selection, exact transport, cached foreign-profile eligibility, sticky policy display and signed outgoing sanitization failures. Only fixture/API adaptations needed to compile those assertions against the old runtime were applied in the detached verification worktree.

Final issue-branch focused checks: **50 passed, exit 0** for Reader/native persistence/application availability, followed by **80 passed, exit 0** for complete public Reader, Pool/Related and cover consumer suites. The new lifetime and quality regressions include their observed failing-before cases. Independent read-only review found no remaining confirmed blocker after corrections.

Changed-file preview analysis: **zero errors, zero warnings, 244 informational findings, exit 1**. This is not a clean analyzer exit. Dart formatting and diff checks are recorded with the final candidate.

An earlier preview run at `64b9b182a` found consumer failures and was interrupted. Its shell returned 0 after interruption; it is explicitly invalidated and is not used as a full-suite pass.

Durable local evidence is under `.worktrees/_artifacts/166-profile-independent-20261118/`, including exact argument arrays in `verification-commands.json`, baseline failures, focused passes, final full-suite result, patch inventory and independent-review notes.

## Acceptance limits

No device, emulator/Maestro, live-service or real multi-device MiteMite acceptance was performed. No new native JVM/APK build was run because no native build inputs changed. Earlier native build artifacts do not represent this new Dart runtime. Final Android acceptance remains with the owner. General release and migration policy remains a separate owner discussion.

Owner Android focus: open a subscribed Series anonymously and with multiple local profiles; save/reopen a Related family; suppress and restore its selected cover through policy changes; change saved Related oldest/newest order and verify the new cover plus member navigation/Back.
