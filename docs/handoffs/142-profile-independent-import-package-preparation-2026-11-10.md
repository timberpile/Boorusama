# P5 profile-independent import preparation — 2026-11-10

Historical preparation report. Superseded by [qualification on accepted P4](142-profile-independent-import-current-develop-2026-11-10.md), including the native-discovered unaddressable self-Replace correction. No P5 publication or integration is authorized yet.

## Candidate and scope

Branch: `feature/142-profile-independent-import-package`. Runtime/test candidate:
`2fb6cb48772a819713637d6d5f4a4d41ff973474`. Own delta base:
P4 `bac318388b8540a57941c9f2145920f131a4dec1` (same runtime/tests as
P4 handoff commit `0ff22c009`). The final report commit changes documentation only.

Only the four historical #142 runtime/test commits were replayed, then reconciled
with current P4 admission and recovery. The historical cumulative branch was not
merged. This package retains unavailable records/hierarchy without requiring a
matching profile, keeps required Topic dependencies separate, restores exact
local rollback slots without trusting incoming file IDs, and revokes stale UI
actions immediately when profile availability changes. Anonymous/public readers
and native Group activation remain P6/P7; later experimental packages stay out.

## Reproduced self-Replace defect and correction

A synthetic 3,201-Post library is encoded to actual production v10 transfer bytes,
decoded, dependency-planned and projected. Before repair, an automatically chosen
reader enriched every absent optional profile hint, yielding **3,201 updated
Bookmark Data records** for an otherwise unchanged copy. Apply performed the same
rewrite. This was a real semantic mutation, not merely an incorrect displayed count.
`self-replace-red.log` records the failing regression.

Preview and apply now share `mapBookmarkImportProfiles`. It validates compatible
known content identities and compares complete transfer shapes excluding file-local
ID and optional profile hints. An identical incoming payload retains local-only
fields, including sourceUrl and loaded Details, even with no mapping or an
already-equal hint. Implicit profile resolution preserves an absent hint; an
explicit choice or non-null incoming hint still maps to the requested compatible
profile. New or genuinely edited payloads retain ordinary import behavior.
No count suppression, guessed identity or file-ID authority was introduced.

The mapper is exercised by twelve hint/mapping/explicit-choice combinations,
four actual Hive preview/Replace scenarios, a real metadata edit and the large
fresh-byte no-op. Actual imports check stored payloads, local IDs, sourceUrl,
loaded Group Details and independent membership dates. The 3,201-record synthetic
copy now has zero created/updated/deleted records and zero preview rows; genuine
changes remain visible and are stored.

A neighboring legacy-repository fallback assumed every incoming record had a
mapped hint. The final correction collects only present hints, preserving an
unchanged existing hintless record while mapping new records and explicit choices.
Canonical HTTP/IPv6 installation boundaries remain covered. Durable codecs already
normalize Group dates; an initial timezone hypothesis was not a confirmed defect.
At this preparatory stage opaque/unaddressable records remained outside no-op
matching. The later native gate demonstrated a self-Replace defect in that limit;
the current qualification report documents its conservative correction without
universal identity deduplication.

## Independent review and automated evidence

Independent actual GPT-6.1 Sol, High effort, source verdict: **APPROVE SOURCE** at
`2fb6cb487`, in `sol-high-provisional-final-review-2fb6cb487.md`. The reviewer
identified a first-draft local-only-field loss when mappings were absent or hints
already equal. The final mapper and actual-storage matrix resolve that finding.
The review did not substitute old-parent or P4 results for P5 verification.

`./init.sh` passed, including localization validation/generation. All 24 changed
Dart files format cleanly. Final affected analysis: exit 0, zero errors, zero
warnings and 63 informational findings. Nine directly related files passed all
112 tests at exact `2fb6cb487`, including 18 self-Replace tests.

An earlier clean `740cb1482` run had 108 passes and four legacy-import failures
from the null assumption; it is not a pass. Initial draft compile/API failures
and `self-replace-green.log` are superseded, not green evidence. Use final
`targeted-final-2fb6cb487.log`/`.exit`, analysis and format logs.

The complete `./scripts/run_regression_tests.sh` also passed on exact
`2fb6cb487`, exit 0: **6,600 application tests**, **1,677 package/CLI tests**
across all 13 roots, both repository shell suites and **76 Python tests**. Two
existing GoRouter skips remain; no full test root was skipped. Use
`complete-regression-2fb6cb487.log`/`.exit` and its candidate record.
Flutter host VM-finalizer diagnostics are retained in the raw log; they did not
correspond to a failed test or nonzero runner exit. This is host automated
coverage, not device verification.

The independent Sol High reviewer subsequently reconciled the final candidate,
exit marker, all counts, targeted pass, analyzer and formatter in the same final
review report. Its conclusion is source approval plus complete local automated
verification; device, user acceptance and integration remain separate gates.

Evidence root:
`.worktrees/_artifacts/sequential-continuation-20261110/p5/`.

## Remaining acceptance and later packages

No P5 Android/Maestro, current-library manual self-roundtrip or live service test
was performed. The zero-change result above uses a controlled synthetic library,
not the user's current personal library. At this historical stage P5 was still
stacked on unintegrated P4. Its own delta has since been replayed onto accepted
P4 develop; see the current qualification report for final-candidate evidence. Do not request P5 acceptance alongside
P4. Its eventual manual checks cover self-Replace, missing-profile copies,
mixed/legacy files, retained hierarchy/dates/details and absence of unintended
profile creation/removal/binding.

P6/P7 source preparation is recorded separately in ignored
`p6-p7/preparation-review.md` and `source-boundaries.txt` under the shared evidence
root, refreshed against exact `2fb6cb487`. Six source-only extraction patches
and their inventory are retained in `p6-p7/extraction-patches/`. Disposable-index
checks find one historical P6-own hunk conflict in `bookmark_provider.dart`; the
P4 pinned storage session must survive snapshot-upgrade cancellation adaptation.
Offline/cache reference patches apply to their historical P6 base. These checks
do not create a candidate; P7 applicability cannot be inferred before P6 exists.
No new P6/P7 candidate or qualification is claimed. P6 needs function-level
cache/outage/Realbooru reconciliation while retaining admission/revocation, plus
actual affected-site/Post-ID unavailable explanations. P7 needs its core native
Group delta separated from late mixed P4/P6 repairs and genuine Szurubooru Pool
acceptance. Their full regression, independent review and leased Android gates
remain outstanding. P8–P10 remain experimental references.
