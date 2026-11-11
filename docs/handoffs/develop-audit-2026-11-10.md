# Develop audit and package evidence — 2026-11-10

## Scope, baseline and authorization

This is an **incremental, incomplete audit and preparation report**, not a completed repository-wide audit or a parallel task queue. GitHub Issues own task state. The production baseline is `2e2ea428ba323706e37a65e45903d3959df439d4` on `develop`; the working-master comparison is `422aeae087c1108e655d85d1a3dac25120456cd6`. P1–P6 are integrated. Develop was rechecked and remains unchanged. No feature combination is described as a develop review.

The user authorized isolated task/review branches, actual commits and pushes. There is no authorization to merge into develop, close issues, open PRs or publish releases. This audit branch's temporary workflows are verification infrastructure, **not a product integration source**. No APK delivery is required.

This session implemented the independent #165 media correction and reconciled/verified the existing #161 pagination correction. It did **not** implement #164, finish the remaining P8/P9/P10 packages or complete the requested nine-domain independent audit. No independent Astra XHigh execution interface or authenticated Android/Maestro session was available or used. Historical independent-review and device evidence below is explicitly attributed to its original candidate and handoff.

## Confirmed develop findings and remediation

### #165 — Pixiv public media Referer removed: high severity

**Impact:** The user reports working API metadata but failed thumbnails/originals in Browse, Explore and Following on develop, with working images on master. The catalog's normal source URL is `https://pixiv.net/`; `PixivRepository.extraHttpHeaders` supplies the existing `https://www.pixiv.net/` image Referer.

**Locations:** `packages/booru_clients/boorus.yaml`; `packages/booru_clients/lib/src/pixiv/pixiv_constants.dart`; `lib/boorus/pixiv/pixiv_repository.dart`; `lib/core/configs/network/src/types/media_request.dart`; `lib/core/http/client/src/data/source_media_http_adapter.dart`.

**Demonstrated cause:** Commit `2e2ea428` introduced exact-source hostname checks at both URL resolution and the scoped transport boundary. Both independently remove the public root Referer because `pixiv.net` and `www.pixiv.net` differ. Master did not apply this new source-origin filtering to ordinary image URLs. This is not an assumption based solely on the error text.

**Evidence:** Real request-path tests exercise the engine's header provider, resolver, scoped media provider/adapter and ImageFetcher; only the remote server is simulated. The canonical profile fails while the www profile passes on the unchanged runtime. Controlled credential-free requests to the user's thumbnail and original URLs returned 403/HTML without the Referer and 206/image data with it. Those live checks read 1,024-byte ranges; they do not establish full decoding or Android acceptance.

**Published correction:** `bc4763d1b264504d3fa448ac3ef28b6a0173daf3` shares a narrow public-header predicate between both boundaries. Only the canonical HTTPS Pixiv root, its existing HTTPS www-root Referer and exact HTTPS/443 `i.pximg.net`/`s.pximg.net` destinations receive the alias permission. Credential-origin authorization, installation boundaries, explicit overrides and persisted profile identities are unchanged.

**Compatibility checks:** Tests cover both source spellings, thumbnail/preview/original variants, unbound resolved requests, both independent filters, explicit replacement hosts, redirects, malicious lookalikes, nondefault ports, insecure/non-root Referers, credential stripping and absence of account interceptors. Existing adjacent tests exercise revocation, cancellation, caching, rendering and other consumers. Android/account acceptance and independent review remain outstanding.

### #165 — HTTP rejection concealed as Empty response: medium severity

**Locations:** The image strategies in `lib/core/images/booru_image.dart` and `lib/core/images/booru_image_candidates.dart`, with propagation through `packages/retriable/lib/src/retry_utils.dart` and `packages/extended_image/lib/src/image_fetcher.dart`.

**Cause/evidence:** `silent: true` converts a rejected request into null, which the fetcher reports as `Empty response`. A real BooruRawImage widget regression reproduces loss of HTTP 403 diagnostics. A successful zero-byte body has a different error path and was not established by the user's message.

**Published correction:** `9b52df7b6aa4728cc84067a57f2599cd4d1da9c1` removes the two silent flags without changing retry policy. Candidate probes remain quiet through their existing `printError: false`. `40f306ea5d035ebfac454700b60a3692129745a0` fixes the new diagnostic fixture's callback cleanup before binding invariants. Earlier fixture timeout/cleanup failures were test defects, not separate application findings.

### #161 — Explore drops continuation and caches stale exhaustion: medium severity

**Location:** `lib/boorus/pixiv/explore/providers.dart`, with existing shared conversion in `lib/boorus/pixiv/posts/parser.dart` and continuation ownership in PostGridController.

**Cause:** Explore discards the API's explicit continuation metadata when converting filtered posts, and its repository-level terminal-page cache survives refreshes/late responses. Empty or hidden-only pages can appear terminal, while a refreshed feed can retain an obsolete end state.

**Prepared existing correction:** Continue the existing `bug/161-pixiv-explore-pagination` branch; preserve original implementation `6c26e5cabc8723049bda8f6cf1121694fb8adb5a`, reconcile the pinned develop base and format with FVM. Use the already-existing `pixivIllustListResultToPostResult` helper and let the grid controller own session exhaustion. Origin and error/cooldown handling remain unchanged. The delta against develop is exactly one production file, its test and its handoff.

**Evidence:** New tests against the unchanged develop implementation produce three passes and 14 intended assertion failures. The candidate passes 257 focused Pixiv/shared-listing tests, including filtering, explicit end signals, refresh, retry, independent feeds and late terminal responses. No Work/Page cutover or #165 media change is hidden in this branch; it still inherits the independent image bug until that separately approved prerequisite is reconciled.

## Candidate identity and actual verification

| Issue | Runtime/test candidate | Published documentation checkpoint |
| --- | --- | --- |
| #165 | `40f306ea5d035ebfac454700b60a3692129745a0` | `650b79fff19758031f0e5e08ce0350957756f48b` on `bug/165-pixiv-media-loading` |
| #161 | `e9a2a2e06e987173f40f84fad14b73084a4207f5` | `22e52295dae2d75a7da878d63e617988dbd4d5b1` on `bug/161-pixiv-explore-pagination` |

FVM 4.3.1 / Flutter 3.47.2 / Dart 3.13.2 were used on hosted Linux. Handoff-only commits do not alter these runtime candidates.

| Check | #165 | #161 |
| --- | --- | --- |
| Focused adjacent tests | 194 passed | 257 passed |
| Formatting / whitespace | Passed | Passed |
| Scoped analyzer | Zero errors/warnings; eight informational diagnostics | No issues |
| App suite in first complete-run attempt | 6,782 passed; ten FFmpeg skips | 6,791 passed; ten FFmpeg skips |
| Why that complete-run attempt stopped | Missing `rg` after the app suite; package/tooling stages not reached | Same missing `rg` after the app suite |
| Supplemental real FFmpeg suite on the same candidate | 16 passed; zero skipped | 16 passed; zero skipped |
| Fresh complete runner with dependency corrected | Final result not yet established at this checkpoint | Final result not yet established at this checkpoint |
| Additional local tooling | Both shell suites passed; Python attempts interrupted by tool timeouts, not counted as passes | Same |

The supplemental FFmpeg run covers **all ten cases skipped in each original app run**. Its 16 cases include six already executed in the root suite; do not double-count them as 16 newly covered cases. Nothing in the product or tests was changed to remove those skips; FFmpeg/FFprobe were installed in the supplemental environment.

Exact evidence:

- #165 red test: [42922922442](https://github.com/timberpile/Boorusama/actions/runs/42922922442), test-only candidate `b28185e1e9fd829fdef965c9d310e728fd0b6d2f`.
- #165 focused/analyzer/first full attempt: [42926187330](https://github.com/timberpile/Boorusama/actions/runs/42926187330).
- #161 red/positive/analyzer/first full attempt: [42927539360](https://github.com/timberpile/Boorusama/actions/runs/42927539360).
- Fresh complete runner: [42930406283](https://github.com/timberpile/Boorusama/actions/runs/42930406283), separate jobs/artifacts for the two immutable candidates.
- Native-media supplement: [42931390172](https://github.com/timberpile/Boorusama/actions/runs/42931390172), both jobs successful.

Read the complete-run outcome and exact artifact before calling either candidate fully qualified. Do not substitute a completed app suite for package/CLI and tooling coverage. Downloaded evidence archives were verified against published SHA-256 digests. Raw output stays in Actions artifacts and ignored `.worktrees/_artifacts/` evidence, not large committed logs.

Separate owning handoffs:

- [#165 media handoff](https://github.com/timberpile/Boorusama/blob/bug/165-pixiv-media-loading/docs/handoffs/165-pixiv-media-loading-2026-11-10.md).
- [#161 pagination handoff](https://github.com/timberpile/Boorusama/blob/bug/161-pixiv-explore-pagination/docs/handoffs/161-pixiv-explore-pagination.md).

## Remaining rollout packages: observed source and readiness

| Package | Preserved source ref | Actual state |
| --- | --- | --- |
| P7 / #156 | `maintenance/156-shared-source-groups-package` — `01c69f6bb7aae98f23ce7cd7d515b48ab5e078e5` | Existing full regression/Android evidence applies to runtime `fbefa7c248e93f02ca0d83a7c956bd4e6e888946`; the later delta was verified as documentation only. Owner acceptance/integration remains separate. It still inherits #165 on its current prerequisite. |
| Viewer / #164 | `feature/164-redesign-shared-post-viewer-modes` — `36123effd9d49d14a1107ae38f0e775b8d660732` | Approved specification and standalone HTML, not an implemented or qualified viewer. |
| P8 / #140 | `feature/140-pixiv-work-viewer` — `d7298c5a06883977966421aec0d11ecf4d2564e4` | Reviewed source foundation; production listing/shared-viewer cutover not complete. |
| P8 / #141 | `feature/141-pixiv-work-page-bookmarks` — `01fa085840f8442246505b1ad1d883e01a4fecdb` | Reviewed Work/Page target foundation; generic unsaved-group picker, production actions and final package qualification remain. |
| P8 / #161 | Runtime `e9a2a2e06e987173f40f84fad14b73084a4207f5` on its existing bug branch | Isolated pagination component prepared as described above; not completion of P8. |
| P9 / #144 | `feature/144-folder-based-collection-sync` — `4dbc9f08adb8bcbce17877d71d80a57ba475243c` | Design branch. Runtime remains in historical Combined; no new standalone extraction or qualification is claimed. |
| P10 / #157 | `feature/157-native-nhentai-galleries` — `cf71fb22e142564d96a1f25cce85a48898ec52fc` | Reviewed native client/source foundation; not the completed production engine or approved shared Gallery viewer. Prepare last after the viewer/P8 foundation. |

### Evidence and approved decisions that must survive preparation

P7's existing `docs/handoffs/156-shared-source-groups-package-2026-11-10.md` attributes independent review to **GPT-6.1 Sol High**, not Astra. It records 6,899 app tests, 1,686 package/CLI tests, 76 Python tests, two shell suites and scoped Android acceptance. These are historical unchanged-candidate results, not reruns or new reviews by this author. Do not extend #156 into unrelated Gelbooru/Rule34 support. A changed develop combination requires requalification even when P7's feature delta itself is unchanged.

For #164, read `docs/designs/2026-11-10-unified-post-viewer.md` and `docs/designs/mockups/2026-11-10-unified-viewer.html` on its branch. The approved Immersive/Details interactions supersede older coordination notes, including their single-tap mode-toggle description. Do not revive the Combined experimental viewer or introduce a separate unrelated fullscreen implementation.

The approved #140 gesture decision is already recorded: horizontal media gestures navigate Pages; horizontal Details-content gestures navigate Works; reaching the final Page does not automatically switch Work. Preserve genuine Work/Page identities, independent bookmark targets, missing-page slots, profile isolation, downloads/sharing, preload and restoration. The #141 issue dependency text was corrected: #137/#138 are completed prerequisites; #140 uses #164; #124 concerns remote Favorites rather than local bookmarks.

P9's historical production handoff retains the received collection after withdrawal. The later rollout handoff requires **verified signed Stop Publishing to remove the received mirror unless another valid subscription retains it**. Missing/offline files must never delete content. This mismatch was recorded in #144; it has not been corrected in an extracted runtime. Preserve outside memberships, hierarchy, strict read-only enforcement, rollback, identity/signature checks and anti-resurrection behavior. Resolve genuinely open UX choices rather than inventing replacements.

P10's foundation handoff records November 8 public-v2 JSON/media observations. They are historical, endpoint-specific evidence, not fresh live compatibility proof for a new app candidate. Reconcile the native foundation with the approved shared Gallery/Page viewer rather than importing Combined wholesale.

The later coordination source is `maintenance/package-extraction-2026-11-09` at `4f921668dc96e3a99bbd104cb96bd20216942289`, particularly `docs/handoffs/sequential-rollout-local-acceptance-2026-11-10.md`. Historical Combined at `252e8954dab8c0842f83a2082c67f4841111c34e` is evidence/reference only, not an authorized integration source.

## Review coverage and remaining gates

Inspected source concentrates on engine/media headers, URL resolution, public versus credential authority, redirects, access/revocation, retry diagnostics, media widgets, Pixiv Explore continuation and shared grid state. Relevant tests, package histories, approved designs and qualification handoffs were reconciled. Source re-review was performed by the author, not independent agents.

The full nine-domain independent audit is **unfinished**. This report does not certify all storage/migrations/backups, authentication paths, feeds, platform integrations, UI/accessibility, performance/concurrency or CI/tooling. No speculative concern has been promoted to a confirmed defect. A green suite would not establish a bug-free application or flawless UI.

Independent review, authenticated Android acceptance and owner approval remain separate gates for #165/#161 and each package. Preserve existing user/agent changes and evidence. Do not merge, close issues, publish releases or open PRs. Reuse valid results on an unchanged candidate across documentation/status updates; repeat the full gate when runtime/tests/dependencies or the develop combination change.

## Local-agent start prompt

> Read current AGENTS.md and the repository skills/workflows first. Resume from the pinned evidence in this report and the separate #165/#161 handoffs; fetch refs and preserve all existing worktrees/edits. Establish the final complete-regression results, obtain actual independent reviews and perform scoped Android acceptance with the exclusive emulator lease. Keep the media correction separate from pagination and all feature packages. Do not merge without explicit owner approval; prefer accepting #165 before reconciling dependent candidates. Preserve valid unchanged P7 evidence. Implement the approved #164 shared viewer before P8's final Work/Page cutover, reconcile P9 against the later signed-withdrawal/read-only/hierarchy requirements, and prepare P10 last. Then complete the independent audit of the actual latest published develop, pinning its SHA and triaging evidence-backed findings through GitHub Issues. Continue real commits and pushes on owning branches; never substitute an audit/Combined branch as an integration source or claim unavailable reviewer/device results.
