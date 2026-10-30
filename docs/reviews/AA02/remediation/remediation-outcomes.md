# Remediation outcomes — distinct from initial assessment

Initial full baseline: `8996890b9a429ffe7e666b9e5505a3489e260d21`. Original source maps and decisions remain reconstructible. **No runtime verification has occurred.**

| Target / exact task branch | Pre-change SHA | Observed post-change SHA | Actual outcome / evidence |
|---|---|---|---|
| T004 / feature/117-pixiv-favorites | e2929259b7725c484d11483d6ea48270079eb2f4 | cee89c991a5fdc01d7ec8f89adbc3828974a7334 | Commits 148c4355,cee89c99: AA01-C0011/C0018 implemented-static-review-only; AA02-C0021 partial identity safety. [Record](branches/T004.md), [handoff](local-handoffs/T004.md) |
| T005 / feature/118-pixiv-following-artists | 1d02bef637966999fbd0b72ecb9c6f0e1eedce8a | 8b9aafbd53be47d0cc8cb2a652ad890135379e85 | AA01-C0002 cover and known-signal portion of C0003 implemented-static-review-only; C0016 coverage partially improved. [Record](branches/T005.md), [handoff](local-handoffs/T005.md) |

Three source commits on two implementation branches. Nineteen new test cases authored (13 on #117; six on #118), zero executed. Exact final heads returned zero GitHub check-runs; no CI pass or acceptance. Full Favorites page interaction, manual-account bootstrap, full Following privacy/navigation and external-policy uncertainty remain open. The shared auth correction is only on #117, not #92/#118.

#113, #114 and #68 remain qualified source candidates requiring fresh ownership/ref checks. Historical/deleted/protected branches and integration/product-policy questions retain their specific baseline deferrals. No original claim disappears after a correction.
