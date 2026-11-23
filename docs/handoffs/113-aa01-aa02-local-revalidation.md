# #113 — AA01/AA02 local revalidation

[Current all-branch review](113-all-live-review-2026-10-30.md) supersedes the technical-readiness status below; this record retains its original evidence.

Session: `local-AA01-AA02-20261030`. Repository: `timberpile/Boorusama`.
Branch: `bug/113-collection-pagination`. Runtime/test candidate:
`fac473cfc27a385617ff15d830efaffdd8c660c1` (resolve against this handoff's parent history). No integration,
PR, issue closure, release, task deletion, or device operation occurred.

## Provenance and current source

Fetched origin before work. Instructions remain at develop
`894ab270693cdb054a5d527c96182e21e2b14ffc`. The three earlier remediation
commits (`0ad03c15`, `8b7a0b50`, `54009fb3`) were already published; they
are the prior writer's changes, not this session's work. Their issue claim
was explicitly released. This session claimed the branch in issue comment
`6522664032`, created its isolated worktree, and preserved the primary checkout.

Original provenance is retained in the immutable
[AA01 source map](https://github.com/timberpile/Boorusama/blob/896baacf5bb64fba43a355580742e0d821f89d17/docs/reviews/AA01/remediation/source-map.md)
and [AA02 source map](https://github.com/timberpile/Boorusama/blob/604e7a15a6c19db340c5e8584cf4c0ab0fc1a331/docs/reviews/AA02/remediation/source-map.md).
The source reports, controller, producer adapters, finite snapshots, actual Pool
consumers, and test fixtures were independently inspected. Original IDs retain
their original audit revisions; verdicts below concern the final standalone
branch, not a combined develop/Favorites candidate.

## Original claims and independent verdicts

| Originals / ingestion locations | Canonical cause | Current verdict and rationale |
| --- | --- | --- |
| AA01-A01-F0004, fixture variant | AA01-C0004 | Confirmed historical fixture defect; repaired and executed. The earlier writer fixed selection/pagination fixtures. Full local execution additionally found contradictory initial completion metadata in network recovery, Search lifecycle, and ten mixed-viewer cases. Corrected metadata while preserving behavioral assertions. |
| AA01-A01-F0004, fake-origin variant | AA01-C0005 | Earlier repair verified: both true and false `hasMore` survive fake origin enrichment. |
| AA01-A01-F0005 | AA01-C0006 | Earlier source-stride correction verified against actual Szurubooru/Nozomi repository providers, including later pages, missing DTOs, unknown/zero totals and Nozomi's bounded request stride. No stride inferred from locally retained count. |
| AA01-A01-F0006; AA01-A02-F0011 | AA01-C0007 | Earlier correction verified: trustworthy terminal totals and actual Gelbooru stride bound continuation before the independent search-depth ceiling. Explicit continuation retains authority. |
| AA01-A01-F0008; AA01-A02-F0008 | AA01-C0009 | Earlier request-generation ownership verified with gated stale success/failure, queued debounce cancellation, newer-load latch ownership, refresh queuing and obsolete URL-filter completion. Added disposal coverage. |
| AA01-A03-F0005 | AA01-C0020 | Initial failure retries page one. Independent extension found that paginated Next could still skip a failed page. `hasNextPage` now requires a successfully loaded page; a failing regression passed after the correction. Same-page retry remains available. |
| INGEST-AA01-A03-T001-C2-PERPAGE | AA01-C0031 | Earlier scope-key repair verified in the actual Danbooru and Szurubooru Pool widgets: changed page size replaces the controller, and refresh/load-more/order use the new ID slices. |
| INGEST-AA01-A02-T001-C1-C3; INGEST-AA02-TOTAL-CONTRACT (A03 T007, A05 T007, A01/A02 checks) | AA01-C0029 | Uncertain producer-contract risk retained. Inspected producers provide source-wide totals; no legitimate page-local/approximate-total counterexample was established. No speculative relaxation. |
| AA01-A01-F0001; AA01-A02-F0002; AA01-A03-F0001; AA02-A01-F0004; AA02-A03-F0003; AA02-A04-F0005; AA02-A05-F0002 | AA01-C0001 | #117 dependency remains separate. Standalone #113 tests establish empty continuing and nonempty terminal pages; they do not establish actual Pixiv cursor behavior on an approved combined candidate. |

Other #114 blacklist causes are owned on that branch and were not copied here.
No original finding was erased by a repair or a rejected hypothesis.

## Executed verification

Pinned FVM Flutter 3.47.2. Fresh dependencies and missing ignored outputs were
initialized through CLI pub get and `./gen.sh`; no generated output or dependency
change was committed. The first pre-bootstrap run failed to compile and is not
a pass. A baseline targeted run passed 123 tests. The first full application
run exposed 12 fixture failures; those were repaired and the affected Search/
recovery suites passed 11 tests, and the entire mixed-viewer file passed 46.

Final checked runtime/test commit: `fac473cfc27a385617ff15d830efaffdd8c660c1`.

- `./scripts/run_regression_tests.sh`: exit 0. All 5,518 application tests,
  1,608 package/CLI tests, both shell tooling suites and 72 Python tests passed.
  The router package retained two existing individual skips.
- Final `fvm dart analyze` on the controller, three changed engine adapters,
  new producer/Pool/generation tests and repaired Search/recovery consumers:
  no errors, warnings or informational findings.
- All task Dart files formatted with `fvm dart format`; `git diff --check` passed.
- Native callback/finalizer diagnostics occurred during passing application
  runs. They were not suppressed or claimed fixed; this independently confirms
  occurrence outside #108 but does not establish their cause.

## Remaining gates

No Android build/install, live-service or manual device acceptance was performed.
Real small/large collections, restricted/deleted IDs, page-size changes, retry,
and rapid refresh still need relevant device acceptance. #117 cursor consumption
requires a separately authorized combined candidate. The branch has not been
combined with current develop; its complete standalone pass is not the required
future final-integration-candidate pass. Publication of this branch does not
authorize acceptance or integration.
