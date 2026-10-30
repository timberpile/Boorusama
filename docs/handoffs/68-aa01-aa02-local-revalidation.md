# #68 — AA02 local revalidation

Session `local-AA01-AA02-20261030`; branch `feature/group-neighboring-series`.
Final runtime/test candidate: `a487585b943c729e6a6b0b70343085e94123cd46`.
Original published author head `771082d9c58363348d74b97a2da23732cdd921f0`
was preserved. Existing clean isolated worktree reused. No active writer was
found before claim `6523251858`; review moved to in-progress for remediation.
Instructions remain develop `894ab270693cdb054a5d527c96182e21e2b14ffc`.

## Original claims and independent current verdicts

Exact original IDs, auditor revisions, withdrawals and severity disagreements
remain in the pinned [AA02 source map](https://github.com/timberpile/Boorusama/blob/604e7a15a6c19db340c5e8584cf4c0ab0fc1a331/docs/reviews/AA02/remediation/source-map.md).
Original Pool reports, actual mixed selectors, admission/cache/projection,
identity/source policy, backup apply/projector and action consumers were read.

| Original IDs / ingestion locations | Canonical cause | Current independent verdict and evidence |
| --- | --- | --- |
| AA02-A01-F0002; AA02-A02-F0002 | AA02-C0002 | Confirmed prefix limit repaired. Actual lazy mixed-grid construction admits bounded nearby windows after the initial 40 saved Posts. One active plus one latest queued lookup remains; cache size/age, four-profile and 40-member budgets remain. Deferred metadata affects only the existing unseen suffix; active tag/source filters disable admission, generation changes revoke queued publication. Real 90-Post viewport test reaches deep Series 114/113, keeps every request <=40, observes bounded request growth and settled scroll offset, then selection restores all 90 raw Posts. Separate held-response test rejects projection into a newly filtered grid. No full-library network scan added. |
| AA02-A03-F0005; AA02-A05-F0004 | AA02-C0007 | Confirmed substring bug repaired for both Post and Pool predicates. Shared parsed-host equality accepts normalized exact hosts and rejects substring, subdomain and URL-path lookalikes. Host-only picker semantics retain same-host ports/schemes and group/tag constraints. Regression first reproduced the old substring result, then passed. |
| AA02-A01-F0001; AA02-A02-F0003; AA02-A04-F0003; INGEST-AA02-POOL-ACCOUNT-COUNTERCHECKS | AA02-C0001 | Product/data-model risk retained. Current identity is engine/normalized host/Pool ID; B may modify A's site-global reference while strict reopening still requires A's hint. Source does not authorize per-profile persisted keys. Preserve strict refusal to borrow another account, existing group actions and v4/v5/v6 backup compatibility. Same-host identity/action/migration policy requires an explicit decision. A04's defect wording and policy caveat are both preserved. |
| AA02-A03-F0002 | AA02-C0006 | Projected #68/#107 score-order conflict retained. Mixed comparator can re-sort scored Posts by saved/upload date after composition; no combined candidate or chosen Pool score placement exists. Do not invent a score policy in this branch. |
| INGEST-AA02-A03-T009-IMPORT-PREVIEW | AA02-C0032 | Withdrawn hypothesis remains rejected. Actual post-apply hint remap and planned-change projector both preserve mapped Pool hints; no claimed preview/apply discrepancy established. |
| INGEST-AA02-POOL-SELECTION-BACKUP | AA02-C0039 | Separate combined #68/#108 gate: typed Post/Pool selection, membership, covers and backup/import require final composed regression. Standalone tests do not establish it. |

## Executed verification

Pinned FVM Flutter 3.47.2, concurrency six. Existing ignored dependencies and
outputs were available; no dependency/schema/generated runtime change committed.

- Original targeted Pool scope: 11 passed. New exact-host regression failed on
  the substring implementation and passed after the correction.
- Final complete bookmark directory plus real application Pool flow: 615 passed,
  including viewport admission, filter/late response, coalesced refresh,
  selection, Undo, source opening and narrow/2x shared picker behavior.
- Final `./scripts/run_regression_tests.sh`: exit 0; 5,392 application tests, 1,603 package/CLI tests, both shell tooling suites and 72 Python tests passed. Router retained two existing skips.
- Scoped FVM analysis: zero errors, zero warnings, 23 informational findings
  (style/import/default-value findings in the inspected scope). No clean
  analyzer claim; these were not expanded into unrelated cleanup.
- Changed Dart formatted; final diff reviewed; git diff --check passed.
- Native callback/finalizer diagnostics occurred in passing execution and
  remain unattributed. No workaround or suppression was introduced.

Logs: `/tmp/boorusama-aa-revalidation/68-*`. The viewport offset assertion is a
controlled widget scenario, not a measured live-device performance benchmark
or proof for every delayed viewport/anchor interleaving.

## Remaining gates

No APK build/install, authenticated live Danbooru/Szuru, device gesture/scroll,
manual same-host A/B, backup on-device or combined acceptance was performed.
Site-global identity and account-action policy remain open; no persisted
migration was attempted. Future approved integration needs combined score,
selection/backup and complete exact-candidate regression. No PR, develop
integration, issue closure, branch deletion or release occurred.
