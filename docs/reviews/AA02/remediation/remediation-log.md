# Remediation log — AA02 / coordinated AA01

Session `remediation-AA01-AA02-20261030`. Earlier detailed logs remain in the unrevised commits below. Inputs, initial decisions and repair outcomes are separate records. No background work or unexecuted test pass is implied.

## Durable report checkpoints

| Commit | Result |
|---|---|
| `7b720d3fc46592f17066f94d3c86c36f7a2d10ea` | AA02 A01/A02 intake and initial source freeze |
| `c498ca58b0409864d3cef16c0c922a7a1f5d9ebd` | Complete 134-file AA02 intake; AA01 separately 34 files |
| `6b04dd2ee9a70e39bcc998ec88cf336ca27f0ba0` | Eight independent Pool/share/viewer decisions |
| `6babef391ad0735ce74333b6b1af97d3b016c712` | Five historical/current Realbooru/update decisions |
| `cb9cb3e88074e463067fdfe781b0eae842989e42` | Nine Pixiv/share/selection decisions; concrete manual-token writer |
| AA01 `896baacf5bb64fba43a355580742e0d821f89d17` | All 33 AA01 initial decisions |
| `8996890b9a429ffe7e666b9e5505a3489e260d21` | All remaining AA02 decisions, 72-record baseline, original-ID map/erratum, coverage and narrow write allowlist |

The baseline refresh accounted for all 36 existing branches: all eight audit heads and all task heads still matched; #111 remained deleted. The C0015 ingestion polarity was corrected without adding a finding. Baseline counters remain 50 numbered originals / 54 atomic numbered links / 31 numbered-report causes, and 72 total records (29 validated-static, 10 likely, 11 uncertain, 9 rejected, 13 proposals). Those are not current functional-bug or repaired-cause counts.

## 2026-10-30 — T004 / #117 remediation unit

- Reread task AGENTS.md and Pixiv README, checked relevant tree instructions and actual auth/provider/UI source, and refreshed #117 comments and ref. Prior writer explicitly released; posted scoped claim `6541012695` before source edits.
- Published `148c435509180a548f3b2de68f83409c31411024` on the existing branch, parent e2929259: exact-origin bearer/401 guards, API redirect hardening, full session/controller identity, nine fake-transport regression cases.
- Published `cee89c991a5fdc01d7ec8f89adbc3828974a7334`, parent 148c4355: manual credential edits clear old identity before updating the token; four actual auth-tab regression cases. Unknown-account bootstrap remains explicitly partial/pending.
- Used parent-based atomic trees and expected-head non-force updates. Read full commit patches, reread each remote ref, inspected final auth/key/callback code and the actual API-key-field forwarding. Combined comparison contains only the intended five files and two commits. Observed final head cee89c9; exact-head check-runs returned zero.
- No local SDK/format/analyzer/build/test/device operation and no workflow launch. Thirteen tests were authored, not executed. C0015 real Favorites-page coverage and #113/#118 integration remain open. Shared auth correction has not propagated to siblings.
- Added branches/T004.md, local-handoffs/T004.md and remediation-outcomes.md; full provenance remains in the baseline maps. The shared-registry versus private-interceptor-registry distinction is clarified in the branch record.
- **Next exact action:** verify this report checkpoint, release the scoped #117 writer with its local handoff, refresh #118 ownership/current instructions/head, then apply the independently supported preview-cover/known-rating correction. Continue #113, #114 and #68 only after their own fresh ownership checks. Do not repeat audit intake or create duplicate shared-auth fixes.
