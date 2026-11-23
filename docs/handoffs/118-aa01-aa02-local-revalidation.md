# #118 — AA01/AA02 local revalidation

[Current all-branch review](118-all-live-review-2026-10-30.md) supersedes the technical-readiness status below; this record retains its original evidence.

Session `local-AA01-AA02-20261030`; branch `feature/118-pixiv-following-artists`.
Final runtime/test candidate: `bd45436f6fc1e5649735851831facc18d5246b79`.
Prior writer's `8b9aafbd53be47d0cc8cb2a652ad890135379e85` introduced the
known-rating/cover/reveal-key repair; this session independently reviewed it
and added real consumer coverage, formatting and an explicit refresh-future use.
Ownership was acquired in issue comment `6523187866` after prior release.
Instructions remain develop `894ab270693cdb054a5d527c96182e21e2b14ffc`.

## Original claims and current verdicts

Pinned sources and original lifecycle/severity variants are preserved in the
[AA01 map](https://github.com/timberpile/Boorusama/blob/896baacf5bb64fba43a355580742e0d821f89d17/docs/reviews/AA01/remediation/source-map.md)
and [AA02 map](https://github.com/timberpile/Boorusama/blob/604e7a15a6c19db340c5e8584cf4c0ab0fc1a331/docs/reviews/AA02/remediation/source-map.md).
Original Following reports, actual page/card/provider/parser/DTO/client and
Search-route consumers were inspected. No authenticated payload was obtained.

| Original IDs / ingestion locations | Canonical cause | Independent verdict and evidence |
| --- | --- | --- |
| AA01-A01-F0002; AA01-A02-F0004 cover variant; AA01-A03-F0003 cover variant; AA02-A05-F0003 | AA01-C0002 | Prior correction verified with the actual artist card and shared explicit overlay. Explicit media remains covered until reveal; cover-off preserves artist tap. Newly added cases reset a revealed slot after URL, artist or auth-profile replacement, in addition to published work-ID replacement. Preserve A05's detailed defect versus inventory risk discrepancy. |
| AA01-A01-F0003; AA01-A02-F0004 rating variant; AA01-A03-F0003 sanity variant; AA02-A01-F0003 rating variant; AA02-A03-F0004 | AA01-C0003 | Known signal correction verified: shared parser recognizes x_restrict 1/2 and sanity >=6, and restricted accounts reject known explicit previews. Missing-field semantics and actual contradictory response incidence remain uncertain. No guessed sanity-level-to-R18G policy added. |
| AA01-A01-F0011 | AA01-C0012 | Artist-wrapper mute is distinct from artwork mute; wrapper flag remains discarded. Desired muted-artist/preview policy and current endpoint output are unverified. No guessed omission or extra requests. |
| AA01-A02-F0006 | AA01-C0016 | Real page/endpoint test now holds public A, private A and B requests; confirms cancellation and no late A display, B source SearchRouteContext with user:700, unchanged Browse profile, four supplied works bounded to three previews, and no detail/request growth. Runs at 320 px and 2x text. |
| AA01-A03-F0004; INGEST-AA01-A01-T005-BLACKLIST | AA01-C0019 | Local tag blacklist parity is a product/API contract gate, separate from explicit cover. Supplied tags may be incomplete. No per-card fetch added. |
| AA02-A01-F0003 visibility/mute variant | AA02-C0003 | Explicit false visibility and true artwork mute are excluded; null flag behavior requires authenticated endpoint evidence and policy. Not claimed repaired or a proven live leak. |
| INGEST-AA01-A01-T005-C2-EMPTY | AA01-C0027 | Empty continuing state retains Load More. Optional no_content wording improvement, not lost continuation. |
| INGEST-AA01-A01-T005-C5-URL | AA01-C0028 | Invalid square-medium can omit valid medium; up-to-three optional previews permit fewer. No requirement proves a defect. |
| INGEST-AA01-A03-T005-CONFIG | AA01-C0033 | Cosmetic config can reload a directly watched provider; no retained disposed fetcher as in Favorites. Optimization proposal only. |
| INGEST-AA02-A02-T017-BOUND | AA02-C0022 | Take-three-before-filter can yield fewer. Four-work fixture confirms bounded supplied previews without additional requests. |
| AA01-A02-F0007; INGEST-AA02-PIXIV-PARTS | AA01-C0017 | Preserve both independent Pixiv client parts, shared options once and both navigation tools on a separately approved combined candidate. No merge conflict executed. |
| AA01-A01-F0010; AA01-A02-F0005; AA02-A05-F0001 | AA01-C0011 | Shared transport correction belongs only to #117. This branch still contains the old interceptor; safe preview URL admission does not remove CDN bearer attachment. No sibling auth patch copied here. |
| INGEST-AA01-A03-T002-L10N | AA01-C0032 | Existing English/German bridge remains; catalog migration is maintenance scope, not a proved runtime defect. |
| INGEST-AA02-A04-T021-PAYLOAD | AA01-C0025 | Fixed endpoint, cursor and artist identity validation are retained. No valid current payload proves strict parsing incorrect. |

## Executed checks

Pinned FVM Flutter 3.47.2, concurrency six. Missing ignored setup outputs were
generated through documented CLI/i18n setup and `./gen.sh`.

- Existing published presentation/card/provider scope: 11 tests passed.
- Final actual card/page, presentation/provider, Pixiv parser and navigation
  capability run: 54 tests passed.
- Complete `packages/booru_clients` suite: 219 tests passed, exit 0.
- Final scoped FVM analyzer: zero errors, zero warnings, three informational
  findings (one redundant parenthesis and two existing unbraced conditionals).
  Earlier unused refresh-result warning was resolved.
- Changed Dart scope formatted; `git diff --check` passed.
- No complete application regression, APK build/install, authenticated Pixiv
  endpoint, Android UI or manual acceptance was run on this candidate.

Logs: `/tmp/boorusama-aa-revalidation/118-*`. A newly authored fixture initially
failed compilation and was corrected; only the final 54-test run is a pass.

## Remaining gates

Unknown payload policy, wrapper mute and blacklist behavior need concrete
endpoint evidence/product decisions. Live account restriction/refresh,
empty/error/retry presentation and device visuals remain acceptance work.
No combined #117/#118/develop candidate exists. Current-source auth safety is
not established for this branch by #117's independent tests. Future approved
integration requires the exact combined candidate's complete local regression.
No PR, merge, issue closure, deletion or release was performed or authorized.
