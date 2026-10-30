# Remediation outcomes — separate from the original baseline

The initial assessment snapshot is `8996890b9a429ffe7e666b9e5505a3489e260d21`. Its 72-record classification and original provenance remain reconstructible and must not be replaced by post-fix conclusions. This file and per-branch records track implementation outcomes; no runtime verification has occurred.

| Branch / target | Pre-change SHA | Observed post-change SHA | Changes | Remaining gate |
|---|---|---|---|---|
| feature/117-pixiv-favorites / T004 | e2929259b7725c484d11483d6ea48270079eb2f4 | cee89c991a5fdc01d7ec8f89adbc3828974a7334 | 148c435509180a548f3b2de68f83409c31411024: C0011/C0018; cee89c991a5fdc01d7ec8f89adbc3828974a7334: C0021 manual safety | [T004 local handoff](local-handoffs/T004.md): tests/actual page/identity bootstrap/dependencies |

At this checkpoint: **two source commits on one implementation branch; two causes implemented-static-review-only (AA01-C0011,C0018), one partial safety correction (AA02-C0021); 13 authored tests, zero tests executed.** The original C0015 Favorites-page coverage gap remains. Exact-final-SHA GitHub check-runs returned zero. No CI pass or final acceptance is claimed. Shared auth copies on #92/#118 were not changed.

#118, #113, #114 and #68 remain qualified candidates requiring fresh ownership/ref checks. Historical/deleted/protected branches, product-policy questions, unverified external contracts and combined-candidate requirements retain the specific dispositions in the baseline matrices. No original claim is silently removed after a patch.
