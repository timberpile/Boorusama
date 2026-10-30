# AA02 independent initial finding matrix

All initial decisions complete. Sources: [original-ID map](source-map.md), [target/code revision inventory](audit-inventory.md), and validation documents [01](baseline-validation-01.md), [02](baseline-validation-02.md), [03](baseline-validation-03.md), [04](baseline-validation-04.md). Shared AA01 causes retain the [AA01 assessment snapshot](https://github.com/timberpile/Boorusama/blob/896baacf5bb64fba43a355580742e0d821f89d17/docs/reviews/AA01/remediation/finding-matrix.md), rather than being counted again here.

**No application fixes or test passes are included in this initial matrix. All local verification is pending.** Presence refers to the exact source snapshots in the validation documents; historical/current differences are explicit. Later repair outcomes must not rewrite the original assessment. 'Not-needed' means no new source correction justified by this claim, not exemption from local rechecking.

| Canonical ID | Kind | Assessment | Current presence | Severity / priority | Initial repair disposition | Evidence |
|---|---|---|---|---|---|---|
| AA02-C0001 | risk / identity policy | likely | site-global identity present | medium / P2 | blocked-product/data-model-decision | 01; preserve strict source reopening and backup identity |
| AA02-C0002 | defect | validated-static | present | medium / P2 | needs-local-investigation for bounded viewport admission | 01; no unbounded library fetch |
| AA02-C0003 | payload-contract risk | uncertain | permissive null branch present; bad legitimate payload unknown | medium / P2 | needs-local-investigation | 03; separate known rating, wrapper mute and explicit cover |
| AA02-C0004 | UX/state risk | likely | defensive menu invalidation present | low / P3 | needs-local-investigation | 01; do not remove fresh-callback safety |
| AA02-C0005 | reported defect hypothesis | rejected | alleged escaping native error absent | low / P3 | not-needed | 01; concrete adapter catches UnimplementedError |
| AA02-C0006 | integration risk | likely | no combined candidate | medium / P2 | blocked-separate-integration | 01; score order versus mixed saved-date resort |
| AA02-C0007 | defect | validated-static | present | low / P2 | focused candidate after ownership | 01; exact parsed hosts for Post and Pool filters |
| AA02-C0008 | historical defect | validated-static | present in inspected develop | medium / P2 | deferred-scope: integrated branch | 02; same-list append misses preloader refresh |
| AA02-C0009 | historical defect | validated-static | global path corrected; explicit profile path remains | medium / P2 | deferred-scope / local reachability check | 02; preserve truthful unknown metadata |
| AA02-C0010 | historical defect | validated-static | present in inspected develop | low / P2 | deferred-scope: deleted integrated branch | 02; preserve verified APK while covered, not installer launch |
| AA02-C0011 | latency risk / optimization | likely | intentional serialization present | low / P3 | not-needed without measured failure | 02; visible loader independent of speculative queue |
| AA02-C0012 | payload-contract risk | uncertain | no conflicting valid HTML fixture | low / P3 | needs-local-investigation | 02; generic dimensions label meaning |
| AA02-C0013 | improvement / quality policy | proposal-only | fallback order present | low / P3 | not-needed | 03; Original before thumbnail is explicitly tested |
| AA02-C0014 | rejected hypothesis | rejected | claimed Future absent | low / P3 | not-needed | 03; ShareService.sharePost returns void |
| AA02-C0015 | improvement / inherited navigation | proposal-only | leaf-folder onOpen disabled | low / P3 | deferred-scope | 04; corrected ingestion polarity |
| AA02-C0016 | lifetime risk | uncertain | surviving root-teardown toast not established | low / P2 | needs-local-investigation | 04; no speculative notifier ownership change |
| AA02-C0017 | improvement / date semantics | proposal-only | upload-date sorting present | low / P3 | not-needed | 04; no insertion-time requirement |
| AA02-C0018 | rejected hypothesis | rejected | alleged retained sort controller absent | low / P3 | not-needed | 04; filter-keyed PostScope |
| AA02-C0019 | improvement / local-operation policy | proposal-only | credentialless local bookmark action present | low / P3 | not-needed | 03; remote actions remain account-gated |
| AA02-C0020 | rejected hypothesis | rejected | unavailable vote removal disabled | low / P3 | not-needed | 01; null callbacks and descriptor enabled state |
| AA02-C0021 | inherited defect | validated-static | manual credential path present | medium / P1 | focused safety candidate; bootstrap needs coherent coverage | 03; old account ID survives manual token change |
| AA02-C0022 | improvement | proposal-only | take-before-filter bound present | low / P3 | not-needed | 03; up-to-three is not exactly three |
| AA02-C0023 | coverage gap | validated-static | DocumentsUI qualification pending | medium / P2 | needs-local-investigation | 04; actual pilot, leased emulator |
| AA02-C0024 | coverage gap | validated-static | installed-source provenance not checked | medium / P2 | needs-local-investigation | 04; build/install exact candidate locally |
| AA02-C0025 | privacy assurance risk boundary | validated-static | heuristic scan limitation present; no leak established | medium / P2 | manual privacy review | 04; opaque/binary data cannot be certified by JSON-key scan |
| AA02-C0026 | historical-content exposure risk | uncertain | no actual secret identified | low / P3 | deferred-scope | 04; no workflow launch or history rewrite |
| AA02-C0027 | policy proposal | proposal-only | inactive proposal | low / P3 | deferred-scope | 04; current instructions/explicit authorization govern |
| AA02-C0028 | improvement / style choice | proposal-only | fixed asset opacity present | low / P3 | not-needed | 04; size, semantics and disabled callback retained |
| AA02-C0029 | native diagnostic risk | uncertain | runtime not inspectable here | medium / P2 | needs-local-investigation | 03; other author's exit-zero run not ours |
| AA02-C0030 | historical defect | validated-static | reported alias defect source-corrected before audit | medium / P2 | not-needed | 04; correction 27e43be and current closure inspected |
| AA02-C0031 | historical correction / geometry risk | likely | measured obstruction added; runtime residual unclear | low / P2 | needs-local-investigation only for residual geometry | 04; original device claim not adopted |
| AA02-C0032 | rejected hypothesis | rejected | preview/apply discrepancy absent on reported path | low / P3 | not-needed | 01; post-apply hint remap and projector both inspected |
| AA02-C0033 | rejected introduced-regression hypothesis | rejected | matcher ownership unchanged from base | low / P3 | not-needed | 04; do not claim an unrelated inherited defect is introduced |
| AA02-C0034 | async response risk scenario | uncertain | no bypass of existing generations established | low / P2 | needs-local-investigation | 04; controlled request ordering tests |
| AA02-C0035 | layout risk scenario | uncertain | no concrete supported failing geometry | low / P2 | needs-local-investigation | 03; actual narrow/2x/IME test already exists |
| AA02-C0036 | integration coverage gap | validated-static | no combined candidate | medium / P2 | blocked-separate-integration | 03; actual #92/#108 native Share journey |
| AA02-C0037 | integration risk | likely | no combined candidate | medium / P2 | blocked-separate-integration | 04; #104/#106/#112 gestures, menus, obstruction |
| AA02-C0038 | integration risk | likely | no combined candidate | medium / P2 | blocked-separate-integration | 04; #114/#116, no #115/#105 scope expansion |
| AA02-C0039 | integration risk | likely | no combined candidate | medium / P2 | blocked-separate-integration | 04; #68/#108 typed selection, covers, backup |

## Consistent baseline counters

AA02's 39 reserved canonical records: 11 validated-static, 8 likely, 7 uncertain, 6 rejected, 7 proposal-only. These include historical defects, coverage gaps and a privacy-assurance limit; **11 is not a count of current functional bugs**. AA01's 33 records: 18 validated-static, 2 likely, 4 uncertain, 3 rejected, 6 proposal-only. Across both nonoverlapping canonical namespaces: **72 records = 29 validated-static + 10 likely + 11 uncertain + 9 rejected + 13 proposal-only**. The separate original numbered-report totals remain **50 originals / 54 atomic mappings / 31 unique numbered-report causes**. Unnumbered ingestion records and repeated variants are not additional audit votes.

Implementation outcomes currently: zero source repair commits, zero tests executed. Remediation-priority candidates are #117 shared Pixiv transport/session/account safety, #118 preview cover/known rating, #113 pagination and test contracts, #114 blacklist state/identity, and #68 exact-host filtering. Historical branches, policy decisions, uncomposed integrations and speculative live contracts retain concrete limitations above.
