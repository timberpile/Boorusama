# Bookmarks: unhandled Group source loss

Integration of this fix and the MiteMite lifecycle fix was approved on
2026-11-20. The original local-only constraints below describe preparation;
[complete integration qualification](mitemite-service-lifecycle.md#10-develop-integration-qualification-2026-11-20)
now records the combined develop candidate and full local pass.

## Scope and evidence

Repository: `timberpile/Boorusama`. Continue the existing `bug/mitemite-service-lifecycle` branch/worktree; do not create another branch. Its MiteMite lifecycle fix and regression tests are already implemented (examined branch head `4b8a03c979f676dfa19300417726816ed7af808d`); preserve them. The Group source guard was examined on `develop` at `5b17615346d2a162ebe287e400e97c60aa666798` and matches this branch. Read current `AGENTS.md` and `.agents/skills/debug-issue/SKILL.md`, and reconcile any later/local changes. No issue is assigned.

Opening Bookmarks now works visually, but logs twice report `Unhandled Exception: Error: Group source unavailable`. Both traces originate at `contentGroupSourceProvider`, `group_source_provider.dart:66`, during Riverpod's scheduled refresh.

Confirmed in the published code: line 66 rejects a null `contentAccessContextProvider(key)` before constructing the source. The context intentionally becomes unavailable for missing/mismatched profiles, obsolete access keys, and loading/failed visibility policy. This guard is not proof of a server outage and must remain. The same provider blob exists on the earlier feature snapshot `026798566a6361f4b12038c2111954ddaf1fcf3d`.

At handoff preparation, the user's invalidating transition and escaping consumer were unknown; the stack identified the throw site alone. The local findings below reproduce an escaping production subscription. The original session's exact invalidating transition remains unknown. Do not assume this is caused by the MiteMite fix. The Android predictive-back warning is separate and outside scope.

## Investigate, then fix

1. Reproduce against the user's actual local revision. Trace the requested key and current profile/auth/policy epochs through `content_access_provider.dart`; record only non-secret diagnostics. Exercise initial loading and a valid-to-unavailable transition while Bookmarks remains mounted. Determine whether unavailability is expected or caused by unnecessary invalidation.
2. Find the escaping subscriber/future:
   ```sh
   rg -n 'contentGroupSourceProvider|contentGroupSourceStateProvider' lib test
   ```
   Audit direct watches, `listen`/`listenManual` subscriptions without error handling, derived futures, and callbacks surviving a source change. A catch around the initial read does not handle later notifications. Inspect cover repair via `native_work_mosaic_cover.dart`, prepared reads, and metadata/member consumers as applicable; these are investigation targets, not confirmed culprits.
3. Add a failing regression for the identified production path, then make the smallest correction. `contentGroupSourceStateProvider` already exposes an async error state; reuse it for suitable UI consumers rather than adding another generic wrapper. Operational listeners must cancel/update their owner on source loss; futures must have timely error handling. Do not add an empty catch or silence global logging.

## Preserve these contracts

- Missing authorization blocks new requests and stale results. Preserve `groupSourceFailureState` clearing revoked data, cancellation, and single source ownership/disposal.
- Temporary policy loading can recover through the existing bookmark access resolver and a fresh key. Missing/ambiguous profiles remain unavailable; never bypass checks or reuse an obsolete key.
- Keep ordinary request failures observable and retryable. Do not erase saved bookmarks, change storage formats, upgrade Riverpod, or alter Android navigation for this fix.

## Tests and completion

Use provider/widget tests with controlled completion, including a scheduled refresh without awaiting `.future`: valid source -> policy loading/revocation -> recovery; removed profile/stale key; repeated Bookmarks navigation and disposal. Assert no uncaught zone/framework errors, no stale requests/data, and successful recovery. Checking only the final UI misses this report.

Reuse fixtures in `test/core/content/group_source_registration_test.dart` and nearby access/member tests. Run affected Bookmark tests and:

```sh
fvm flutter test --concurrency="${TEST_CONCURRENCY:-$(python3 scripts/physical_core_count.py)}" test/core/content
git diff --check
```

Format/analyze changed Dart files. Follow `AGENTS.md` for broader verification and the complete integration gate. Commit the scoped result and report the confirmed escape path, tests, and remaining uncertainty. No push, PR, issue closure, or merge is authorized by this handoff.

Sources: [source guard and existing async wrapper](https://github.com/timberpile/Boorusama/blob/5b17615346d2a162ebe287e400e97c60aa666798/lib/core/content/groups/group_source_provider.dart#L59-L92); [access validation and policy revocation](https://github.com/timberpile/Boorusama/blob/5b17615346d2a162ebe287e400e97c60aa666798/lib/core/content/content_access_provider.dart#L112-L194).


## Local findings and fix (2026-11-20)

Continuation baseline: `7b87f28c167aa0364ca71d85aedfbc83963207dd`, the
published documentation-only descendant of lifecycle fix
`4b8a03c979f676dfa19300417726816ed7af808d`. The existing isolated worktree and
branch were reused. The MiteMite implementation and regression file remain
byte-for-byte unchanged. Later develop has adjacent viewer/member-model changes;
those were inspected and were not brought into this scoped continuation.

### Confirmed escape path

`PixivWorkGrid.build` directly watched `contentGroupSourceProvider(access.key)`
to retain its source. During a controlled valid -> policy-loading transition,
Riverpod refreshed this synchronous provider before the access-driven widget
rebuild could drop the old subscription. Its deliberate null-context error
reached the widget listener as an uncaught framework/zone error, with the same
`group_source_provider.dart:66` and scheduled-refresh stack as the report.
The regression failed on the original code and passed after the correction.
This establishes a real escape path; it does not identify the original user's
specific profile/policy transition or prove why their log contained two errors.

The widget now watches the existing `contentGroupSourceStateProvider` instead.
Request-time source reads still run inside the native controller's error
handling. This retains visible, retryable request errors while letting expected
source loss propagate as async state before the widget rebuilds. The source
provider still rejects missing authorization and still exclusively owns source
disposal. No global logging, access guard, epoch, storage, or cancellation code
was changed.

The call-site audit also covered native Work cover repair, prepared reads,
summary/details/member providers, viewer admission callbacks, and the unused
Pixiv compatibility accessor. Cover repair already watches async source state;
its access, bookmark ownership, and cancellation checks remain. Provider tests
with no `.future` waiter confirm that source loss clears previously published
metadata/member data without uncaught errors. No unnecessary production
invalidation was demonstrated.

### Regression and verification evidence

Nine new cases cover scheduled policy loading/failure, profile removal and stale
keys, fresh-key recovery, initial policy loading without client construction,
source-error presentation, late listing responses after revocation/unmount,
and three repeated visits to the real Bookmarks browser while its Work grid
remains mounted in the background. Existing offline-refresh coverage now also
presses Retry and verifies recovery on the same authorized source. The provider
cases exercise the real registry/source ownership and complete requests through
controlled gates; the widget cases inspect intermediate framework exceptions
and error widgets rather than only the final UI.

- Before the production change, the focused scheduled-refresh widget regression
  failed with `Error: Group source unavailable`; the same regression then passed.
- The expanded focused command on
  `test/boorus/pixiv/works/work_listing_entry_points_test.dart` and
  `test/core/content/group_source_registration_test.dart` passed 27 tests.
- Final affected-suite command, using the detected six workers (or the configured
  override):

  ```sh
  fvm flutter test --no-pub \
    --concurrency="${TEST_CONCURRENCY:-$(python3 scripts/physical_core_count.py)}" \
    test/core/content test/core/bookmarks test/boorus/pixiv/works \
    test/core/backups/mitemite/provider_lifecycle_test.dart
  ```

  Result: exit 0, **1,452 passed**, no failures or skips. This includes the nine
  new regression cases and all 13 preserved MiteMite lifecycle regressions.
- `fvm flutter analyze --no-pub --no-fatal-infos` on `work_listing.dart` and the
  two changed test files: exit 0, no errors, no warnings, two informational
  redundant-default-argument findings in the existing listing fixtures.
- `fvm dart format --output=none --set-exit-if-changed` on those same three files:
  exit 0, no formatting changes. `git diff --check` passed.
- The final runtime/test tree was unchanged during the affected-suite pass;
  only this outcome documentation changed afterward. Review confirmed the
  existing source ownership, revocation/data-clearing, and cancellation paths
  remain unchanged.

Durable logs are under the ignored
`.worktrees/_artifacts/group-source-error-handling/` directory, including
`source-loss-before.log`, `provider-refresh-before.log`,
`focused-expanded.log`, `affected-suites.log`, and `analyze-final.log`.

The original device sequence and authenticated live-service behavior remain
unverified. At that scoped handoff no emulator/APK or complete local integration suite had
been run. The linked integration qualification records the later full local pass;
device and authenticated live-service acceptance remain unverified. No branch
was created, and no push, merge, PR, or issue mutation was performed.
