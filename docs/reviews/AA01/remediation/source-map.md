# AA01 source provenance map

## Checkpoint status

All 34 files in the three pinned AA01 report directories have been read, including all 15 branch reports, cross-branch records, manifests, inventories, summaries and review histories. This is an ingestion checkpoint, **not completed independent validation**. AA02 ingestion and primary-source assessment remain in progress; the application-edit gate remains closed. No application changes or runtime tests have been performed.

Original identifiers are preserved. Repeated cycle mentions are history, not additional reporting agents or findings. Canonical IDs below are stable reservations; they do not imply correctness. The source conclusions are the auditors' claims, not remediation verdicts. Each source review uses the five exact code SHAs in [audit-inventory.md](audit-inventory.md), with common original base `422aeae087c1108e655d85d1a3dac25120456cd6`.

## Pinned audit revisions

| Source | Audit SHA | Report directory |
|---|---|---|
| AA01-A01 | 290c41b9cdcbdfbfbb949c2116899c8cc07374b8 | docs/reviews/AA01/agent-01 |
| AA01-A02 | 737b3e06a0a56ba7938db013df9826d647eff4fe | docs/reviews/AA01/agent-02 |
| AA01-A03 | db5834b6f3bf36e712d500e82a66e4ca05164d82 | docs/reviews/AA01/agent-03 |

All 28 numbered original findings are retained in the pinned inputs. AA01-A03 is a final static-review handoff with incomplete timing/protocol requirements, not an explicit user-closure record. Its complete static coverage must not be represented as completed runtime verification. No ongoing source review is stated in that final handoff.

## Numbered original findings

`static` and `high-confidence` in this table describe the **source auditor's** confidence. All source lifecycles are open/retained. References identify the canonical source section by its original ID within the linked file; later cycle sections preserve its evolution.

| Original ID | Canonical source | Issue / target | Original kind; severity; confidence | Canonical remediation record(s) | Preserved claim / variants |
|---|---|---|---|---|---|
| AA01-A01-F0001 | [cross][a1-cross] | #117/T004; #113/T001 dependency | defect; medium; static | AA01-C0001 | Empty first/intermediate cursor pages stop; nonempty terminal pages expose redundant continuation; #113 fix is not present in #117. |
| AA01-A01-F0002 | [T005][a1-t5] | #118/T005 | defect; high; static | AA01-C0002 | Explicit preview renders without the configured media cover even on an account legitimately allowed adult content. |
| AA01-A01-F0003 | [T005][a1-t5] | #118/T005 | risk; medium; high-confidence | AA01-C0003 | Null xRestrict becomes zero and sanityLevel is ignored; contradictory/missing rating payload incidence is unverified. |
| AA01-A01-F0004 | [T001][a1-t1] | #113/T001 | defect; medium; static | AA01-C0004; AA01-C0005 | Split atomic claims: contradictory total/maxPage fixtures block controller/application pagination tests; fake backend origin wrapper separately drops hasMore. Preserve both symptoms. |
| AA01-A01-F0005 | [T001][a1-t1] | #113/T001 | defect; medium; static | AA01-C0006 | Paginated mode clears prior items, so page-local retained length cannot exhaust a source-wide total on the last nonempty page. |
| AA01-A01-F0006 | [T001][a1-t1] | #113/T001 | defect; medium; static | AA01-C0007 | Gelbooru search-depth cap is treated as evidence of more results; includes empty total=0 and already-reached-total cases. |
| AA01-A01-F0007 | [T002][a1-t2] | #114/T002 | defect; medium; static | AA01-C0008 | Live mixed-case blacklist keys disagree with normalized expressions, actual filtering, hidden count and popup controls. |
| AA01-A01-F0008 | [cross][a1-cross] | #113/T001; #117/T004 | risk; medium; high-confidence | AA01-C0009 | Stale cancelled page-2 completion after refresh can publish an old error and decrement current page 1 to 0. |
| AA01-A01-F0009 | [T002][a1-t2] | #114/T002 | defect; medium; static | AA01-C0010 | Shared blacklist page index becomes invalid after a rule-list shrink or source switch; more-than-30-rule boundary matters. |
| AA01-A01-F0010 | [T004][a1-t4] | #117/T004; shared #118 transport | risk; high; high-confidence | AA01-C0011 | Host-blind Pixiv API bearer attachment to media; preserve foreign absolute-host and ordinary CDN variants, without alleging observed theft. |
| AA01-A01-F0011 | [T005][a1-t5] | #118/T005 | risk; medium; high-confidence | AA01-C0012 | Wrapper artist-level is_muted is discarded; artwork-level mute is independent. Current payload and directory policy remain unverified. Earlier unnumbered mute notes belong to this same history. |
| AA01-A01-F0012 | [T002][a1-t2] | #114/T002 | risk; medium; high-confidence | AA01-C0013 | Earlier async blacklist count can overwrite newer rules/count/filter state; native isolate ordering is not controlled. |
| AA01-A02-F0001 | [T002][a2-t2] | #114/T002 | coverage-gap; medium; high-confidence | AA01-C0014 | Popup shell tests use static Text rather than real controller/rule/post visibility interactions. |
| AA01-A02-F0002 | [cross][a2-cross] | #117/T004; #113/T001 dependency | defect; medium; static | AA01-C0001 | Same cursor continuation boundary; no duplicate finding for repeated references in T001/T004. |
| AA01-A02-F0003 | [T004][a2-t4] | #117/T004 | coverage-gap; medium; high-confidence | AA01-C0015 | Missing Favorites route/profile/privacy/viewer integration tests; isolated client/session tests are not absent. |
| AA01-A02-F0004 | [T005][a2-t5] | #118/T005 | defect; high; static | AA01-C0002; AA01-C0003 | Compound finding split into missing local explicit cover and independent permissive rating classification. |
| AA01-A02-F0005 | [cross][a2-cross] | #117/T004; #118/T005 | risk; high; high-confidence | AA01-C0011 | API bearer unnecessarily reaches CDN; media-only requests may refresh API credentials. No unrelated-party theft claimed. |
| AA01-A02-F0006 | [T005][a2-t5] | #118/T005 | coverage-gap; medium; high-confidence | AA01-C0016 | Missing real Following Artists page, account/privacy transitions and artist-to-source-Search widget tests. |
| AA01-A02-F0007 | [cross][a2-cross] | #117/T004; #118/T005 | risk; medium; high-confidence | AA01-C0017 | Preserve both Pixiv part declarations, shared request options once and both navigation capabilities in a separately authorized combined candidate. No executed conflict. |
| AA01-A02-F0008 | [T001][a2-t1] | #113/T001; #117/T004 consumer | defect; medium; static | AA01-C0009 | Same generation-ownership cause, additional scheduled debounce and both response-order variants: skipped page 2, stale results, inconsistent index. |
| AA01-A02-F0009 | [T002][a2-t2] | #114/T002 | defect; medium; static | AA01-C0010 | Singleton rule-pagination provider survives a new controller/widget key; an invalid slice hides all chips. |
| AA01-A02-F0010 | [T002][a2-t2] | #114/T002 | defect; medium; static | AA01-C0013 | Same stale async count publication; source calls it a defect whereas A01 retains risk classification. Vote does not decide correctness. |
| AA01-A02-F0011 | [T001][a2-t1] | #113/T001 | defect; medium; static | AA01-C0007 | Search-cap maxPage outranks known total. Source calls origin an inherited acceptance gap; A01 also identifies newly persistent empty-page behavior. Check variants independently. |
| AA01-A03-F0001 | [cross][a3-cross] | #117/T004; #113/T001 dependency | defect; medium; static | AA01-C0001 | Same shared Grid continuation defect; session itself advertises the cursor correctly. |
| AA01-A03-F0002 | [T004][a3-t4] | #117/T004 | defect; high; static | AA01-C0018 | Full mutable config keys session provider; id/auth/privacy keys retained PostScope. Cosmetic config edits can dispose the fetcher still held by Grid. This is not a credential-change leak claim. |
| AA01-A03-F0003 | [T005][a3-t5] | #118/T005 | defect; high; static | AA01-C0002; AA01-C0003 | Missing explicit cover plus reported sanityLevel rating variant. Retain both without counting the agent twice for either cause. |
| AA01-A03-F0004 | [T005][a3-t5] | #118/T005 | risk; medium; high-confidence | AA01-C0019 | New preview strip does not apply local tag blacklist; parity and completeness of supplied tags require a product/contract decision. |
| AA01-A03-F0005 | [T001][a3-t1] | #113/T001 | defect; medium; static | AA01-C0020 | Initial failed page sets hasMore and allows page 2 before page 1 succeeds; distinct from refresh/load-more concurrency. |

The 28 numbered originals currently map to 31 atomic source-to-cause links and 20 provisional unique causes. These are different quantities; no validated-defect total is asserted at this checkpoint.

## Unnumbered observations and corrected hypotheses

The `INGEST-*` identifiers below were assigned by remediation to source locations, **not supplied by an auditor**. Ordinary repeated verification checklists are retained in branch coverage, not manufactured into additional defects. These 14 distinct observations/hypotheses are recorded separately from the 28 numbered originals. Earlier relationship-mute notes are already retained in F0011's lifecycle, not counted again.

| Ingestion reference | Source location(s) at the audit SHA above | Canonical record | Source disposition and preserved nuance |
|---|---|---|---|
| INGEST-AA01-A01-T003-C1-C2 | agent-01/branches/T003.md, cycles 1 and 2 | AA01-C0021 | Initial impression of missing full Search integration coverage was explicitly corrected when existing SearchPageScaffold tests were found. Preserve the withdrawal and runtime-unrun distinction. |
| INGEST-AA01-A01-T002-C5 | agent-01/branches/T002.md, cycle 5 | AA01-C0022 | Mixed-origin numeric-ID blacklist-count hypothesis was countered by mixed Bookmarks using RawPostScope with no blacklist tags. Do not promote it to a demonstrated bug. |
| INGEST-AA01-A01-T002-SEARCH | agent-01/branches/T002.md, search/#115 integration notes | AA01-C0023 | Duplicate Search header/toolbar concern is deferred #115 UX integration, not a proved #114 defect or permission to implement #115. |
| INGEST-AA01-A01-T004-RETRY | agent-01/branches/T004.md, error/retry notes | AA01-C0024 | Generic Grid error recovery restarts page 1 while session supports cursor retry; expected UI behavior remains an acceptance question, not an established new Pixiv defect. |
| INGEST-AA01-A01-T004-MALFORMED | agent-01/branches/T004.md, malformed response notes | AA01-C0025 | Strict handling of nullable/malformed artwork entries needs an actual API contract; do not relax validation on a speculative payload. |
| INGEST-AA01-A01-T004-C10-LOG | agent-01/branches/T004.md, cycle 10 logging countercheck | AA01-C0026 | No separate credential-log disclosure established; logging behavior is distinct from media Authorization transport. |
| INGEST-AA01-A01-T005-C2-EMPTY | agent-01/branches/T005.md, cycle 2 | AA01-C0027 | Empty-but-continuing artist list displays no_content while Load More remains available; wording proposal, not lost continuation. |
| INGEST-AA01-A01-T005-C5-URL | agent-01/branches/T005.md, cycle 5 | AA01-C0028 | Invalid squareMedium does not fall back to valid medium; optional up-to-three previews permit omission, no proved requirement breach. |
| INGEST-AA01-A01-T005-BLACKLIST | agent-01/branches/T005.md, additional integration/verification notes | AA01-C0019 | Earlier policy-sensitive local blacklist observation corroborates the separately numbered A03 claim; no assumed parity contract. |
| INGEST-AA01-A02-T001-C1-C3 | agent-02/branches/T001.md and review-log.md, cycles 1 and 3 | AA01-C0029 | Hypothesis that production adapters report page-local total was not established after concrete producer inspection. Distinct from contradictory test fixtures and paginated retained-length behavior. |
| INGEST-AA01-A02-T002-C4 | agent-02/branches/T002.md and review-log.md, cycle 4 | AA01-C0030 | Apparent legacy showPostListConfigHeader regression was rejected as an intentional requirement: keep serialized field but do not reinterpret it as the new pin setting. |
| INGEST-AA01-A03-T001-C2-PERPAGE | agent-03/branches/T001.md, cycle 2 | AA01-C0031 | Existing Danbooru/Szurubooru pool PostScope keys omit postsPerPage while fetcher captures it; inherited caller risk to inspect, not a claimed #113-introduced regression. |
| INGEST-AA01-A03-T002-L10N | agent-03/branches/T002.md, Findings; repeated for artist title in T005 | AA01-C0032 | Fork-local English/German fallback extensions could move to the standard catalog; localization maintenance proposal, not a demonstrated functional failure. Do not fabricate generated output. |
| INGEST-AA01-A03-T005-CONFIG | agent-03/branches/T005.md, no-finding safeguards | AA01-C0033 | Full config identity can cause an unnecessary Following reload on cosmetic edits, but the widget reads new provider state directly and does not retain the disposed Favorites fetcher. |

## Initial independent investigation already started

For AA01-C0018, source was read directly at `e2929259b7725c484d11483d6ea48270079eb2f4`: Favorites page/provider/session, full PostScope lifetime, BooruConfig versus BooruConfigAuth equality, and DestinationProfileScope. The mismatched identities and disposed-session rejection are present. CurrentBooruConfigScope's parent lifetime and existing tests still require a final countercheck before the assessment is closed. Issue #117 requirements and all two issue comments were read; the earlier author explicitly released its claim, but ownership must be refreshed immediately before any new claim/write.

No other source auditor conclusion has been adopted merely by consensus. All original and current revision checks, final assessments, repair priorities and local acceptance scenarios remain to be completed in finding/branch records.

[a1-t1]: https://github.com/timberpile/Boorusama/blob/290c41b9cdcbdfbfbb949c2116899c8cc07374b8/docs/reviews/AA01/agent-01/branches/T001.md
[a1-t2]: https://github.com/timberpile/Boorusama/blob/290c41b9cdcbdfbfbb949c2116899c8cc07374b8/docs/reviews/AA01/agent-01/branches/T002.md
[a1-t4]: https://github.com/timberpile/Boorusama/blob/290c41b9cdcbdfbfbb949c2116899c8cc07374b8/docs/reviews/AA01/agent-01/branches/T004.md
[a1-t5]: https://github.com/timberpile/Boorusama/blob/290c41b9cdcbdfbfbb949c2116899c8cc07374b8/docs/reviews/AA01/agent-01/branches/T005.md
[a1-cross]: https://github.com/timberpile/Boorusama/blob/290c41b9cdcbdfbfbb949c2116899c8cc07374b8/docs/reviews/AA01/agent-01/cross-branch-findings.md
[a2-t1]: https://github.com/timberpile/Boorusama/blob/737b3e06a0a56ba7938db013df9826d647eff4fe/docs/reviews/AA01/agent-02/branches/T001.md
[a2-t2]: https://github.com/timberpile/Boorusama/blob/737b3e06a0a56ba7938db013df9826d647eff4fe/docs/reviews/AA01/agent-02/branches/T002.md
[a2-t4]: https://github.com/timberpile/Boorusama/blob/737b3e06a0a56ba7938db013df9826d647eff4fe/docs/reviews/AA01/agent-02/branches/T004.md
[a2-t5]: https://github.com/timberpile/Boorusama/blob/737b3e06a0a56ba7938db013df9826d647eff4fe/docs/reviews/AA01/agent-02/branches/T005.md
[a2-cross]: https://github.com/timberpile/Boorusama/blob/737b3e06a0a56ba7938db013df9826d647eff4fe/docs/reviews/AA01/agent-02/cross-branch-findings.md
[a3-t1]: https://github.com/timberpile/Boorusama/blob/db5834b6f3bf36e712d500e82a66e4ca05164d82/docs/reviews/AA01/agent-03/branches/T001.md
[a3-t4]: https://github.com/timberpile/Boorusama/blob/db5834b6f3bf36e712d500e82a66e4ca05164d82/docs/reviews/AA01/agent-03/branches/T004.md
[a3-t5]: https://github.com/timberpile/Boorusama/blob/db5834b6f3bf36e712d500e82a66e4ca05164d82/docs/reviews/AA01/agent-03/branches/T005.md
[a3-cross]: https://github.com/timberpile/Boorusama/blob/db5834b6f3bf36e712d500e82a66e4ca05164d82/docs/reviews/AA01/agent-03/cross-branch-findings.md
