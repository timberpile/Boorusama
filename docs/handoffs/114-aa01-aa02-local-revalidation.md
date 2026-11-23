# #114 — AA01/AA02 local revalidation

[Current all-branch review](114-all-live-review-2026-10-30.md) supersedes the technical-readiness status below; this record retains its original evidence.

Session `local-AA01-AA02-20261030`; branch `feature/114-timeline-toolbar`.
Final runtime/test candidate: `b4bc9a9201284f5a585cecb050d796b6e7e719c7`.
Instructions: develop `894ab270693cdb054a5d527c96182e21e2b14ffc`.
Prior published author head `5bb52794468b172b7d6878fb825b42b00d654675`
was preserved. The previous writer released ownership; this session claimed
issue #114 in comment `6522785672`. New runtime changes are in `4e7d9b902`
and consumer corrections in the final candidate above.

## Source claims and current independent verdicts

Original IDs and exact audit sources remain in the pinned
[AA01 map](https://github.com/timberpile/Boorusama/blob/896baacf5bb64fba43a355580742e0d821f89d17/docs/reviews/AA01/remediation/source-map.md)
and [AA02 map](https://github.com/timberpile/Boorusama/blob/604e7a15a6c19db340c5e8584cf4c0ab0fc1a331/docs/reviews/AA02/remediation/source-map.md).
The original T002 reports, actual controller, popup, consumers, settings and
legacy serialization were independently inspected.

| Original IDs / ingestion locations | Canonical cause | Verdict, correction or boundary |
| --- | --- | --- |
| AA01-A01-F0007 | AA01-C0008 | Confirmed and repaired. All rule keys use normalized expression strings; live replacements preserve unchanged disabled states and remove obsolete keys. Filtering, counts and chip toggles use the same rule identity. |
| AA01-A01-F0009; AA01-A02-F0009 | AA01-C0010 | Confirmed and repaired. Pagination belongs to each popup state, clamps when its rules shrink, and starts at page one for a replacement popup/source. Tests exercise 75 rules on page three shrinking to 35 on page two and a source replacement. |
| AA01-A01-F0012; AA01-A02-F0010 | AA01-C0013 | Confirmed race repaired. Generation and rule revisions revoke stale count, URL-filter and lazy initial-rule completions. Snapshot publication waits for both current count and URL filtering. Mutations invalidate ongoing work. Controlled completion tests execute the actual matching algorithm with old/new completions reversed. |
| AA01-A02-F0001 | AA01-C0014 | Confirmed coverage gap repaired. New tests mount the actual PostListConfigurationHeader, BlacklistControls and real controller with normalized rules and Posts. They toggle individual rules, Hide all and Show all, assert displayed post identities/counts, and exercise 320 px, enlarged text and keyboard obstruction. Synthetic shell tests remain separate. |
| INGEST-AA01-A01-T002-C5; AA02-A02-F0004; INGEST-AA02-A03-T018-MIXED-ID | AA01-C0022 | The original Bookmarks trigger remains rejected because RawPostScope has no blacklist rules. The actual mixed Cached Feed trigger is valid: equal numeric IDs from different source hosts must remain distinct. Count and filtering now use booru type, normalized source host (profile fallback when absent), and post ID. Real mixed-origin regression preserves the unblocked source. |
| INGEST-AA01-A01-T002-SEARCH; INGEST-AA02-TIMELINE-FOLLOW-INTEGRATION | AA01-C0023; AA02-C0038 | Deferred combined UX acceptance for #114/#116 and future #115/#105. This correction does not implement another Search redesign. |
| INGEST-AA01-A02-T002-C4 | AA01-C0030 | Rejected migration hypothesis retained. The new pin setting is independent of the serialized legacy header flag. An obsolete settings test was corrected to assert the new control while preserving the legacy default. No backup reinterpretation was added. |
| INGEST-AA01-A03-T002-L10N; INGEST-AA02-A05-T018-L10N | AA01-C0032 | Catalog migration remains an optional maintenance proposal. Existing localized fallback bridges remain; no invented generated catalog output. |

## Executed verification

Pinned FVM Flutter 3.47.2; ordinary concurrency six. Missing ignored outputs
were generated with the documented dependency/i18n setup and `./gen.sh`.

- Final targeted controller/popup/toolbar scope: 159 tests passed.
- Full execution exposed three stale consumer expectations: the removed legacy
  settings control and two unscoped scroll-view finders in Favorites menus.
  The final consumer run passed 18 tests without weakening geometry assertions.
- `./scripts/run_regression_tests.sh` on the final candidate: exit 0;
  5,505 application tests, 1,608 package/CLI tests, both shell tooling suites,
  and 72 Python tests passed. Router retained two existing skips.
- Final scoped FVM analysis: no errors, warnings or informational findings.
- Changed Dart files formatted; `git diff --check` passed.
- Passing application execution emitted the pre-existing native callback /
  finalizer diagnostic. It remains unattributed and was not suppressed.

Logs are under `/tmp/boorusama-aa-revalidation/114-*` in this workspace.
Stopped exploratory popup harness runs are not counted as passes; the final
real-controller harness passed before full verification.

## Remaining acceptance

No APK build/install, live-service, or manual device acceptance was performed.
Real gesture/assistive popup behavior and combined Search/Feed layouts remain
manual gates. No combined develop candidate was created; future integration
requires its own complete regression. Publication does not approve integration,
PR creation, issue closure, task deletion or release.
