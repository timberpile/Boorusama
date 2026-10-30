# Coverage and agent agreement — initial baseline

Repository `timberpile/Boorusama`; exact full branch names, code/base SHAs and source-local translations: [audit-inventory.md](audit-inventory.md). Exact source IDs, source audit SHAs, paths, severities/confidence and retained/withdrawn history: [source-map.md](source-map.md) and its pinned [AA01 companion](https://github.com/timberpile/Boorusama/blob/896baacf5bb64fba43a355580742e0d821f89d17/docs/reviews/AA01/remediation/source-map.md). Every source ID maps to an independent matrix decision.

**A complete first static branch pass is not a completed audit protocol or runtime acceptance. Not mentioned is not evidence of absence.** Full-branch coverage below is separate from defect-specific applicability. For conservatism, no fraction claims every complete branch reviewer inspected a particular hidden/shared trigger. Raw reporting-agent counts are shown with the version cohort; a missing specific-trigger coverage statement is uncertainty, not an extra negative vote. Integration-only records have no inspected combined-candidate denominator.

## Selected, available and branch-review cohorts

All three discovered AA01 agents and five AA02 agents are available; no declared expected agent is missing. AA01 selected only T001–T005. All task versions within each listed cohort match the frozen inventory.

| Branch targets / issues | Selected / available | Complete first static passes | Partial / excluded |
|---|---|---|---|
| T001–T005 / #113,#114,#116,#117,#118 | 8 / 8 | AA01:01,02,03; AA02:01,02,03,04,05 | None partial at first-pass level |
| T006/#92,T007/#95,T009/#112,T010/#107,T011/#97,T012/#98,T013/#106,T015/#91,T016/#99,T017/#104,T018/#108 | 5 / 5 AA02 | 01,02,03,04,05 each | AA01 not in standalone scope |
| T008/#68 | 5 / 5 AA02 | 01,02,03,04 | A05 partial; actual filter source covered, full negative coverage unavailable |
| T014/Maestro | 5 / 5 AA02 | 01,02,03,04,05 | No real pilot execution |
| T019/#53,T020/#76 historical | 5 / 5 globally selected AA02 | 01,04 | 02,03,05 exclude these historical targets |
| T021/#111 historical/deleted | 5 / 5 globally selected AA02 | 01,02,04,05 | 03 excluded; remediation's current-develop countercheck is not an audit vote |
| T022/source bundle | 5 / 5 globally selected AA02 | 01 | Remaining scopes exclude coordination target |
| T023/publication policy | 5 / 5 globally selected AA02 | 01,02 | Remaining scopes exclude policy target |

AA01 reported passes/cycles: A01 eleven, A02 six, A03 two. AA02: A01 23 first passes and 16 second passes among 20 active/uncertain targets; A02 20 first/eight second; A03 18 first/12 second; A04 21 first/two historical second; A05 17 full active plus partial #68 and separate historical #111, no complete second round. Timing/protocol requirements remain unverified; closure does not turn incomplete cycles into complete negative coverage.

## Exact reporting agents for all 31 numbered-report causes

Notation `AA01:01 F0001` means original ID `AA01-A01-F0001`. All 50 numbered originals remain retained by their source auditors: **ever-reported count equals source-retained count**, not independent agreement. Repeated cycles count once. Compound original IDs can map to distinct causes. Shared causes are not duplicated across issues.

| Cause | Exact reporters / original IDs | Unique reporting agents | Independent baseline result |
|---|---|---:|---|
| AA01-C0001 | AA01:01 F0001,02 F0002,03 F0001; AA02:01 F0004,03 F0003,04 F0005,05 F0002 | 7 | Validated; #117 depends on separate #113 |
| AA01-C0002 | AA01:01 F0002,02 F0004,03 F0003; AA02:05 F0003 | 4 | Validated explicit cover |
| AA01-C0003 | AA01:01 F0003,02 F0004,03 F0003; AA02:01 F0003,03 F0004 | 5 | Likely; known rating versus nullable contract distinguished |
| AA01-C0004 | AA01:01 F0004 | 1 | Validated contradictory fixtures |
| AA01-C0005 | AA01:01 F0004 | 1 | Validated fake hasMore loss, same original split |
| AA01-C0006 | AA01:01 F0005 | 1 | Validated paginated global-total bookkeeping |
| AA01-C0007 | AA01:01 F0006,02 F0011 | 2 | Validated search-cap precedence |
| AA01-C0008 | AA01:01 F0007 | 1 | Validated normalized keys |
| AA01-C0009 | AA01:01 F0008,02 F0008 | 2 | Validated refresh/load-more ownership |
| AA01-C0010 | AA01:01 F0009,02 F0009 | 2 | Validated blacklist pagination lifetime |
| AA01-C0011 | AA01:01 F0010,02 F0005; AA02:05 F0001 | 3 | Validated shared media authorization; retain #92 variant |
| AA01-C0012 | AA01:01 F0011 | 1 | Uncertain wrapper mute contract |
| AA01-C0013 | AA01:01 F0012,02 F0010 | 2 | Validated stale async publication |
| AA01-C0014 | AA01:02 F0001 | 1 | Validated coverage gap |
| AA01-C0015 | AA01:02 F0003 | 1 | Validated coverage gap |
| AA01-C0016 | AA01:02 F0006 | 1 | Validated coverage gap |
| AA01-C0017 | AA01:02 F0007 | 1 | Projected integration; no combined review denominator |
| AA01-C0018 | AA01:03 F0002 | 1 | Validated retained Favorites fetcher |
| AA01-C0019 | AA01:03 F0004 | 1 | Uncertain policy; AA01:01 also unnumbered |
| AA01-C0020 | AA01:03 F0005 | 1 | Validated initial-page skip |
| AA01-C0022 | AA02:02 F0004 | 1 | Validated Feed; AA01's different Bookmarks hypothesis rejected |
| AA02-C0001 | AA02:01 F0001,02 F0003,04 F0003 | 3 | Likely identity-policy risk; A03/A05 also unnumbered counterpositions |
| AA02-C0002 | AA02:01 F0002,02 F0002 | 2 | Validated first-40 admission; A05 specific applicability not established |
| AA02-C0003 | AA02:01 F0003 | 1 | Uncertain nullable visibility/mute contract |
| AA02-C0004 | AA02:02 F0001 | 1 | Likely UX risk; A01/A03 defend callback safety |
| AA02-C0005 | AA02:03 F0001 | 1 | Rejected native-error premise |
| AA02-C0006 | AA02:03 F0002 | 1 | Projected mixed-grid score ordering |
| AA02-C0007 | AA02:03 F0005,05 F0004 | 2 | Validated host matching, including relevant A05 partial coverage |
| AA02-C0008 | AA02:04 F0001 | 1 | Historical/current append defect |
| AA02-C0009 | AA02:04 F0002 | 1 | Historical defect; current global path source-corrected |
| AA02-C0010 | AA02:04 F0004 | 1 | Historical/current covered-route APK reference |

## Issue-level reported problems and validation

Counts here deliberately isolate **numbered** reports. All unnumbered records and authors remain in the following section/source map and must not be silently counted as absence. Kind and assessment for every unique cause are in the two finding matrices; these differ from agent totals.

| Issue/target | Exact agents ever/still retaining numbered problem reports | Unique associated numbered causes / validation |
|---|---|---|
| #113/T001 | AA01:01,02,03 = 3/3 | AA01-C0004–C0007,C0009,C0020: six validated; C0001 is a #117 dependency, not an unfixed #113 Grid defect |
| #114/T002 | AA01:01,02; AA02:02 = 3/3 | AA01-C0008,C0010,C0013,C0022: four defects; C0014 one coverage gap |
| #116/T003 | 0/0 | No numbered problem; withdrawn coverage hypothesis separately preserved |
| #117/T004 | AA01:01,02,03; AA02:01,03,04,05 = 7/7 | AA01-C0001,C0009 consumer,C0011,C0018 defects; C0015 gap; C0017 integration risk |
| #118/T005 | AA01:01,02,03; AA02:01,03,05 = 6/6 | AA01-C0002,C0011 shared defects; C0003 likely; C0012,C0019 and AA02-C0003 uncertain; C0016 gap; C0017 integration |
| #92/T006 | AA02:05 = 1/1 | AA01-C0011 shared defect |
| #95/T007 | AA02:03 = 1/1 | AA02-C0005 rejected; source never withdrew |
| #68/T008 | AA02:01,02,03,04,05 = 5/5 | AA02-C0002,C0007 defects; C0001 policy risk; C0006 integration risk |
| #112/T009 | AA02:02 = 1/1 | AA02-C0004 risk; shared auth consumer is not an extra standalone vote |
| #107/T010 | AA02:02,03 = 2/2 | AA01-C0022 inherited Feed defect; AA02-C0006 integration risk |
| #53/T019 | AA02:04 = 1/1 | AA02-C0008 historical defect |
| #76/T020 | AA02:04 = 1/1 | AA02-C0009 historical defect, partial current correction |
| #111/T021 | AA02:04 = 1/1 | AA02-C0010 historical defect |
| T011/#97,T012/#98,T013/#106,T014/Maestro,T015/#91,T016/#99,T017/#104,T018/#108,T022,T023 | 0/0 numbered | Unnumbered proposals, corrected hypotheses, risks and coverage limits are not omitted |

## Unnumbered observations, withdrawals and revisions

The 14 AA01 and 37 AA02 ingestion rows each identify their exact reporting agents and source locations. The corresponding matrices distinguish proposal, risk, gap, historical defect, rejection, and current presence. Do not add these location records to numbered-original totals or count repeated locations from one agent as multiple votes.

- Withdrawn/rejected AA01 hypotheses: C0021 Search coverage, C0030 legacy-setting migration, C0026 alleged token/header logging. C0022's withdrawn Bookmarks trigger does not dispose of AA02's different Feed trigger.
- AA02 source counterchecks: C0014,C0018,C0020,C0032,C0033. Earlier correction claims C0030/C0031 preserve history; C0021's now-proven manual-token writer adds independent evidence, not another reporting agent.
- Proposals and declared Maestro/privacy limits remain mandatory rechecks, even without numbered defect votes. The corrected C0015 polarity is an ingestion erratum, not an additional application finding.

No revised audit inputs were observed at baseline closure. Any newer source/code cohort must be recorded separately before recalculating agreement. Minority findings may be correct; many reporters may share an invalid premise. The source maps plus matrices, not voting, define the complete local revalidation set.
