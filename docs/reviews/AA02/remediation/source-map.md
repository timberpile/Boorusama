# AA02 authoritative provenance map

All 134 pinned AA02 report files and the separate 34 AA01 files were ingested. Initial independent decisions are now complete in [finding-matrix.md](finding-matrix.md) and baseline-validation-01 through -04. No application repair or runtime pass belongs to this baseline. Original conclusions below remain the auditors' claims, not remediation verdicts.

The complete pre-validation transcription, including original severities, confidence, compound symptoms and lifecycle notes, is preserved at [source-map.md, cb9cb3e88074e463067fdfe781b0eae842989e42](https://github.com/timberpile/Boorusama/blob/cb9cb3e88074e463067fdfe781b0eae842989e42/docs/reviews/AA02/remediation/source-map.md). This current map retains every original and ingestion ID and supplies the classification destination. **Erratum:** INGEST-AA02-A02-T001-CHEVRON previously inverted its source: the auditor says a childless folder **cannot** be entered through its chevron. The source and independent decision are corrected below; this is not another audit finding.

## Pinned identities and revisions

| Agent | Exact immutable audit branch | Audit SHA | Files |
|---|---|---|---:|
| AA02-A01 | review/AA02/agent-01 | b00d6d25c5e060cb98632ad93a3a7fa64507fa00 | 30 |
| AA02-A02 | review/AA02/agent-02 | 5012c4e19783e319c4491ba737517542d0de692c | 27 |
| AA02-A03 | review/AA02/agent-03 | bbc004db66596d082fc4470abbd27f83b2e00250 | 24 |
| AA02-A04 | review/AA02/agent-04 | 0df3bc984af5da8dda9b0ef9f419266183f0f70c | 28 |
| AA02-A05 | review/AA02/agent-05 | c658f7c455d39208672aeeac45462c387cbb315d | 25 |

Paths below are relative to `docs/reviews/AA02/agent-<ID>/` at that exact agent SHA. Original finding IDs identify sections; later cycle sections remain history, not extra votes. Exact full task branch identities, code SHAs, bases and source-local T translations are in [audit-inventory.md](audit-inventory.md). Never select a task branch from a source-local T number alone.

The [AA01 pinned map](https://github.com/timberpile/Boorusama/blob/896baacf5bb64fba43a355580742e0d821f89d17/docs/reviews/AA01/remediation/source-map.md) preserves its 28 numbered originals and 14 ingestion records. Shared AA01 causes keep their existing IDs. Across both batches: 50 numbered originals, 54 atomic numbered mappings, 31 unique numbered-report causes. The 72 total canonical records include unnumbered risks, proposals, withdrawals and historical corrections; these are not interchangeable totals.

## All 22 numbered originals

All numbered originals remain retained in their pinned source audits. An independent rejection does not pretend the source agent withdrew its claim. Original severity/confidence and fuller history remain in the pinned transcription above. `V01`–`V04` refer to the corresponding baseline-validation document; `AA01` refers to the pinned AA01 matrix/branch evidence.

| Original ID | Canonical source location | Issues / remediation target | Original conclusion and preserved variants | Canonical record(s) / independent evidence |
|---|---|---|---|---|
| AA02-A01-F0001 | branches/T009.md, F0001 | #68 / T008 | Medium static defect: same-host B can match/change A's Pool reference; account policy explicitly uncertain. | AA02-C0001 / V01; likely policy risk, no guessed migration |
| AA02-A01-F0002 | branches/T009.md, F0002 | #68 / T008 | Medium static defect: first 40 Posts permanently bound admission; retain cached-prefix, filters, source budgets and frozen anchors. | AA02-C0002 / V01; validated |
| AA02-A01-F0003 | branches/T021.md, F0003 | #118 / T005 | Low suspected risk: nullable rating and independently nullable visibility/mute accepted. | AA01-C0003 / AA01; AA02-C0003 / V03; split atomic signals |
| AA02-A01-F0004 | branches/T020.md, F0004; cross reference | #117 / T004; #113 dependency | Medium static defect: empty continuing cursor page stops Grid; terminal nonempty page permits extra request. | AA01-C0001 / AA01 |
| AA02-A02-F0001 | branches/T012.md, F0001 | #112 / T009 | Medium high-confidence risk: fresh button-list identity dismisses More on benign rebuild; callback freshness must remain. | AA02-C0004 / V01; likely UX risk |
| AA02-A02-F0002 | branches/T018.md, F0002 | #68 / T008 | Medium static defect: cached/ineligible prefix consumes admission before later visible entries. | AA02-C0002 / V01 |
| AA02-A02-F0003 | branches/T018.md, F0003 | #68 / T008 | Medium policy-sensitive risk: B's save remains hinted to A; deleting A prevents reopen. Strict refusal to borrow B is a safeguard. | AA02-C0001 / V01 |
| AA02-A02-F0004 | cross-branch-findings.md, F0004; T014/T009 | #114 / T002; #107 / T010 | Medium inherited static defect: Cached Feed equal numeric IDs across origins overfilter or undercount. RawPostScope Bookmarks is a different trigger. | AA01-C0022 / AA01; Feed validated, original Bookmarks trigger rejected |
| AA02-A03-F0001 | branches/T011.md, F0001 | #95 / T007 | Low static defect claim: native UnimplementedError escapes Artist sharing; finally already restores busy state. | AA02-C0005 / V01; independently rejected by adapter catch |
| AA02-A03-F0002 | cross-branch-findings.md, F0002; T009/T014 | #68 / T008; #107 / T010 | Medium projected risk: mixed-grid savedAt resort can override added score ordering after composition. | AA02-C0006 / V01; no combined candidate |
| AA02-A03-F0003 | branches/T020.md, F0003 | #117 / T004; #113 dependency | Medium static cursor/Grid defect, including filtered first/later empty pages. | AA01-C0001 / AA01 |
| AA02-A03-F0004 | branches/T021.md, F0004 | #118 / T005 | Medium high-confidence risk: xRestrict null/0 with sanityLevel 6 disagrees with established mapper; live incidence unproven. | AA01-C0003 / AA01 |
| AA02-A03-F0005 | branches/T009.md, F0005 | #68 / T008 | Low static defect: exact-host menu feeds substring Pool predicate; Post path inherits same weakness, no credential leak established. | AA02-C0007 / V01; validated |
| AA02-A04-F0001 | branches/T001.md, F0001; cycle 2 | #53 / T019 historical | Medium static inherited omission: same-list append misses preloader invalidation; comparing two aliases' lengths is insufficient. | AA02-C0008 / V02; historical/current source checked |
| AA02-A04-F0002 | branches/T002.md, F0002 | #76 / T020 historical | Medium static defect: truthful empty original URL reaches Original renderer despite sample. | AA02-C0009 / V02; current global path corrected, explicit profile path remains |
| AA02-A04-F0003 | branches/T009.md, F0003 | #68 / T008 | Medium policy-sensitive defect claim: same-host identity/action; defer persisted schema changes pending contract. | AA02-C0001 / V01 |
| AA02-A04-F0004 | branches/T016.md, F0004; cycle 2 | #111 / T021 historical/deleted | Low static defect: covering Flutter route discards verified APK reference; not normal OS background. | AA02-C0010 / V02; current source remains |
| AA02-A04-F0005 | branches/T020.md, F0005; cross | #117 / T004; #113 dependency | Medium static cursor/Grid defect; independent #113 is not already in #117. | AA01-C0001 / AA01 |
| AA02-A05-F0001 | cross-branch-findings.md, F0001; T003 | #92 / T006; #117/T004; #118/T005; #112 consumer | High inherited static defect: media gets API bearer/refresh; preserve CDN, foreign absolute host and redirect boundaries, no observed exfiltration. | AA01-C0011 / AA01 |
| AA02-A05-F0002 | branches/T020.md, F0002 | #117 / T004; #113 dependency | Medium static cursor/Grid defect, not a new cause per page. | AA01-C0001 / AA01 |
| AA02-A05-F0003 | branches/T021.md, F0003 | #118 / T005 | Medium defect in detailed report, risk in inventory: allowed explicit preview lacks configured local cover. Preserve the source discrepancy. | AA01-C0002 / AA01 |
| AA02-A05-F0004 | branches/T009.md, F0004 | #68 / T008 | Low static substring defect within partial branch coverage; relevant filter inspected, not full negative coverage. | AA02-C0007 / V01 |

## All 37 unnumbered ingestion records

`INGEST-*` IDs are remediation-assigned location references, not auditor-supplied IDs. Each row preserves all repeated locations/variants. Original reports remain pinned by the agent table. Routine test checklists are coverage, not invented extra defects. Classification outcomes are in the matrix and its evidence documents; every row remains a mandatory local recheck.

| Ingestion ID | Source locations | Canonical record | Original lifecycle / preserved claim; independent destination |
|---|---|---|---|
| INGEST-AA02-A01-T001-QUEUE | A01 T001 safeguards; A04 T001 counterchecks | AA02-C0011 | Possible serial speculative latency; foreground independent. V02 |
| INGEST-AA02-A01-T002-LABELS | A01 T002 ambiguity notes | AA02-C0012 | Generic HTML metadata-label contract uncertain. V02 |
| INGEST-AA02-SHARE-QUALITY | A01 T003; A02 T004; A04 T003 | AA02-C0013 | Original-before-thumbnail fallback policy, no requirement breach established. V03 |
| INGEST-AA02-A01-SHARE-AWAIT | A01 T003/T015 | AA02-C0014 | Missing-await hypothesis rejected because service returns void. V03 |
| INGEST-AA02-A02-T001-CHEVRON | A02 branches/T001.md inherited navigation note | AA02-C0015 | **Childless folder cannot be entered through its chevron.** Corrects earlier ingestion inversion; inherited scope outside checkbox keys. V04 |
| INGEST-AA02-TOAST-TEARDOWN | A01 T006; A03 T006 cycle 2 | AA02-C0016 | Possible disposed inset notifier with surviving toast; reachable root-teardown interaction unproven. V04 |
| INGEST-AA02-A02-T009-DATE | A02 T009 ordering semantics | AA02-C0017 | Newest/Oldest means upload date, no contrary contract. V04 |
| INGEST-AA02-A02-T009-STALE-SORT | A02 review-log cycle 2 T009; branch report | AA02-C0018 | Retained sort hypothesis withdrawn after keyed PostScope countercheck. V04 |
| INGEST-AA02-SELECTION-MISSING-ACCOUNT | A02 T010; A03 T015 | AA02-C0019 | Local Bookmark mutation without resolved profile is policy question, not Browse-auth borrowing. V03 |
| INGEST-AA02-A02-T012-VOTE | A02 T012 cycle 2; review-log | AA02-C0020 | Disabled vote removal bypass rejected by null callback. V01 |
| INGEST-AA02-A02-T016-ACCOUNT-METADATA | A02 T016 stored identity note | AA02-C0021 | Source hypothesis: mismatched ID/token may fetch other public Favorites. V03 independently establishes manual-token writer; this is not a new audit vote. |
| INGEST-AA02-A02-T017-BOUND | A02 T017; cycle-2 log | AA02-C0022 | Take three before filtering may leave fewer; up-to-three contract. V03 |
| INGEST-AA02-MAESTRO-SELECTORS | A01/A03/A04/A05 T008; A02 T019 pilot sections | AA02-C0023 | Actual DocumentsUI/YAML/import/restart unqualified. V04 |
| INGEST-AA02-MAESTRO-APK | Same five Maestro reports | AA02-C0024 | Installed APK versus source equivalence not established. V04 |
| INGEST-AA02-MAESTRO-SECRETS | Same five Maestro reports | AA02-C0025 | Common JSON key scan cannot certify opaque/binary secrets absent; no actual disclosure. V04 |
| INGEST-AA02-A01-T022-BUNDLE | A01 T022 full-source note | AA02-C0026 | Hypothetical historical committed secret in bundle; none identified. V04 |
| INGEST-AA02-A02-T020-POLICY | A02 T020 authority note | AA02-C0027 | Proposal does not override planning/no-push/current instructions. V04 |
| INGEST-AA02-ICON-OPACITY | A03/A04/A05 T010 | AA02-C0028 | Fixed disabled asset opacity is intentional style, not proved malfunction. V04 |
| INGEST-AA02-A05-T015-VM | A05 T015 implementation-log note | AA02-C0029 | Historical VM/native diagnostic not independently attributed to #108; another author's run not ours. V03 |
| INGEST-AA02-A05-T012-ALIAS-HISTORY | A05 T012 previous correction | AA02-C0030 | Earlier alias-only behavior reported corrected before audit. V04 verifies source/test patch and current presence. |
| INGEST-AA02-A05-T006-TOAST-HISTORY | A05 T006 earlier measured overlap | AA02-C0031 | Earlier manual overlap reportedly corrected; preserve history without adopting pass. V04 |
| INGEST-AA02-A03-T009-IMPORT-PREVIEW | A03 T009 cycle 2; review-log | AA02-C0032 | Preview/apply hint mismatch withdrawn after post-apply remap. V01 |
| INGEST-AA02-A02-T006-DESKTOP | A02 T006 matcher ownership | AA02-C0033 | Initial matcher unchanged by selected-tag feature, no introduced defect established. V04 |
| INGEST-AA02-A04-T012-OLD-QUERY | A04 T012 async checks | AA02-C0034 | Old-query ordering unexecuted; provider/generation guards present. V04 |
| INGEST-AA02-A04-T015-TINY-DIALOG | A04 T015 keyboard viewport | AA02-C0035 | Extreme-height overflow unverified, actual narrow/IME test exists. V03 |
| INGEST-AA02-SHARE-SELECTION-INTEGRATION | A01/A02/A04 cross; #92/#108 acceptance | AA02-C0036 | Combined consumer acceptance needed, not asserted source conflict. V03 |
| INGEST-AA02-VIEWER-OVERLAY-INTEGRATION | A01/A02/A04 cross; A03 T013/T017; #104/#106/#112 | AA02-C0037 | Combined gestures/menu/Undo obstruction, retain human UX gate. V04 |
| INGEST-AA02-TIMELINE-FOLLOW-INTEGRATION | A01/A02/A04 cross; A03/A04/A05 #116 | AA02-C0038 | #114/#116 and future #115/#105 alignment; deferred features not authorized. V04 |
| INGEST-AA02-POOL-SELECTION-BACKUP | A01/A04 cross; #68/#108 | AA02-C0039 | Typed selection, membership, covers, backups need combined regression. V04 |
| INGEST-AA02-POOL-ACCOUNT-COUNTERCHECKS | A03 T009 cycle 2; A05 T009 partial | AA02-C0001 | Unnumbered identity-policy questions, strict source reopening retained. V01 |
| INGEST-AA02-A01-T017-MORE | A01 T017; contrasting A03 T017 | AA02-C0004 | Defensive closure explicitly recognized; no proven regression without benign-update UX evidence. V01 |
| INGEST-AA02-TOTAL-CONTRACT | A03 T007 cycles 1/2; A05 T007; A01/A02 checks | AA01-C0029 | No page-local/approximate total producer established; distinct actual fixtures/cap defects. AA01 |
| INGEST-AA02-A03-T018-MIXED-ID | A03 T018 multi-origin uncertainty | AA01-C0022 | Hypothesis without actual Feed tracing; A02 numbered trigger independently establishes consumer. AA01 |
| INGEST-AA02-PIXIV-PARTS | A01/A02/A04 cross; A03/A05 Pixiv notes | AA01-C0017 | Both parts/options/navigation must survive later combination. AA01 |
| INGEST-AA02-A05-T018-L10N | A05 T018 maintenance note | AA01-C0032 | English/German bridge migration proposal, no fabricated generation. AA01 |
| INGEST-AA02-A04-T021-PAYLOAD | A04 T021 response acceptance | AA01-C0025 | Unobserved API shape mismatch remains contract question. AA01 |
| INGEST-AA02-A05-T016-SIGNING | A05 T016 native policy/device note | AA02-C0010 | Expected debug/release signer refusal is counter-evidence against bypass, not route-covered APK retention. V02 |

## Disagreements and repair tracking

Pool identity requires a product/data-model decision despite agreement on the code path. More-menu closure protects fresh callbacks despite possible nuisance. Pixiv known rating, unknown fields, artist mute, local blacklist and explicit cover remain separate causes. Cached Feed numeric identity is not disproved by the different RawPostScope Bookmarks trigger. API continuation validation does not establish media credential safety. Closed/integrated historical issues neither prove correction nor authorize patching protected/deleted branches.

Use [finding-matrix.md](finding-matrix.md) for independent classification and [remediation-log.md](remediation-log.md) plus per-branch records for later repair commits. Local verification must reconsider every original and ingestion record, including rejected/resolved/web-fixed causes and each distinct reported variant.
