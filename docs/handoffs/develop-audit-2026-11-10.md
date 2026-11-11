# Develop audit and package evidence — 2026-11-10

## Scope and authorization

This is an incremental engineering report, not a completed repository-wide audit or a parallel task queue. GitHub Issues own task status. The reviewed production baseline is `2e2ea428ba323706e37a65e45903d3959df439d4` on `develop`; the working `master` comparison is `422aeae087c1108e655d85d1a3dac25120456cd6`. P1–P6 are already integrated. No feature combination is being described as a develop audit.

The user authorized isolated task/review branches, real commits and publication to origin. There is no authorization to merge into develop, close issues, open pull requests or publish releases. The workflows on this audit branch are temporary review infrastructure and are not a product integration source.

The current author has no independent Astra XHigh execution interface or Android/Maestro session. Historical reviewer/device evidence below is attributed to its actual source and candidate; it is not a new review or device pass by this author.

## Confirmed develop findings

### #165 — Pixiv's public image Referer is removed (high priority)

**Impact:** On the catalog's normal `https://pixiv.net/` profile, Pixiv thumbnails, previews and originals are rejected while API metadata remains available. The user reports Browse, Explore and Following failures on develop and working images on master. No authenticated Android reproduction has been performed in this session.

**Locations and root cause:**

- `packages/booru_clients/boorus.yaml` configures the Pixiv site as `https://pixiv.net/`.
- `lib/boorus/pixiv/pixiv_repository.dart:111` supplies `kPixivImageReferer`, whose value is `https://www.pixiv.net/` in `packages/booru_clients/lib/src/pixiv/pixiv_constants.dart`.
- `lib/core/configs/network/src/types/media_request.dart:37–48` and `:80–91` require an exact source hostname before retaining a public root Referer.
- `lib/core/http/client/src/data/source_media_http_adapter.dart:77–79` and `:177–203` independently apply the same exact-host check.

Commit `2e2ea428` introduced both relevant filters. Master did not apply this new source-origin filter to ordinary Pixiv image URLs. The configured `pixiv.net` and engine-owned `www.pixiv.net` mismatch therefore drops the header at two separate boundaries. This is not inferred solely from the server's error message.

**Reproduction:** The new tests exercise the actual engine header provider, `MediaRequest.resolve`, `contentMediaDioProvider`, scoped HTTP adapter and `ImageFetcher`; only the remote server is simulated. The canonical profile fails with HTTP 403 while the `www` profile passes. Direct scoped-transport and unbound-resolved-header cases independently reproduce the two boundaries.

Controlled live requests to the two reported URLs supplied no credentials. Without a Referer, both returned HTTP 403 and 146 bytes of HTML. With the existing Pixiv public Referer, the thumbnail returned HTTP 206/image-webp and the original returned HTTP 206/image-jpeg; each range request returned 1,024 image bytes. These are CDN observations, not an Android UI acceptance or a full-file decode.

**Correction published:** `bc4763d1b264504d3fa448ac3ef28b6a0173daf3` on `bug/165-pixiv-media-loading` preserves only the exact public Pixiv root alias for `i.pximg.net` and `s.pximg.net` over HTTPS/443. Both boundaries share the predicate. Source credential authorization, installation-path checks and explicit override stripping remain unchanged. Foreign redirects, lookalike hosts, nondefault ports, insecure schemes and non-root Referers are not granted the new exception.

**Compatibility risks and checks:** Cover both profile spellings, thumbnail/preview/original variants, explicit replacement hosts, redirects, rejected aliases, credential removal and omission of account interceptors. Existing revocation, cancellation, caching, preloading, download, saved-media and other-engine consumers require adjacent/full regression. Final qualification is still in progress at this checkpoint.

### #165 — Rejected image requests lose their useful diagnostics

`lib/core/images/booru_image.dart:512–516` supplies `FetchStrategyBuilder(silent: true)`. The retry wrapper consequently returns null after a rejected request. `packages/extended_image/lib/src/image_fetcher.dart:33–35` then reports `Empty response`, concealing the actual HTTP status. A zero-length successful body has a different error and is not established by the reported message.

The corrected widget regression observes an actual `BooruRawImage` failure and its diagnostic output. On the unchanged develop runtime it receives the misleading `Empty response` message rather than HTTP 403. The separate candidate-probing path uses the same silent strategy; its existing `printError: false` is the appropriate mechanism for quiet expected probes without erasing the failure cause.

The diagnostics correction is being prepared and verified separately from the already-published Referer correction. No retry policy, cancellation rule or provider error contract is being replaced.

## Exact regression evidence

| Run | Runtime/test candidate | Actual result |
| --- | --- | --- |
| [42921162950](https://github.com/timberpile/Boorusama/actions/runs/42921162950) | `1c014e59ef45dc56dc1b0dc30882a3eb9df6219d` | Initialization succeeded; tests did not execute because the native libavif build lacked Meson. Not red-test evidence. |
| [42921812249](https://github.com/timberpile/Boorusama/actions/runs/42921812249) | `1c014e59ef45dc56dc1b0dc30882a3eb9df6219d` | Three tests passed; four media assertions failed as expected. The diagnostic fixture timed out and was corrected; that timeout is not an application finding. Includes the controlled live CDN observations. |
| [42922922442](https://github.com/timberpile/Boorusama/actions/runs/42922922442) | `b28185e1e9fd829fdef965c9d310e728fd0b6d2f` | Three tests passed and five failed on the intended assertions, including the corrected diagnostic widget test. No production correction is present in this candidate. |

Pinned toolchain: FVM 4.3.1, Flutter 3.47.2, Dart 3.13.2. Test artifacts retain candidate SHA and command output. CI evidence does not by itself replace the repository's final local integration gate.

The red-test artifact digests are `ce56e558634c72e95d2a6fdc28d1876c5281556f0213232082d132dfbc6c52a7` for run 42921812249 and `53a9cf5424a4cd54a6c012434d6637209264969ac0d8cde16ac7b3ba6e503245` for run 42922922442. Retrieved archives were checked against these digests before use. Raw logs remain in ignored workspace evidence and GitHub Actions artifacts, not in the repository.

## Revalidated package baseline

These are source/evidence observations, not a declaration that all remaining packages are prepared.

| Package | Current source ref | Evidence and actual preparation state |
| --- | --- | --- |
| P7 / #156 | `maintenance/156-shared-source-groups-package` at `01c69f6bb7aae98f23ce7cd7d515b48ab5e078e5` | Its handoff records full regression and Android acceptance on runtime candidate `fbefa7c248e93f02ca0d83a7c956bd4e6e888946`. The subsequent delta is documentation only, verified by comparison. Reuse that unchanged-runtime evidence; owner acceptance/integration remains separate. The baseline also inherits #165 until that independent correction is reconciled. |
| Viewer / #164 | `feature/164-redesign-shared-post-viewer-modes` at `36123effd9d49d14a1107ae38f0e775b8d660732` | Approved specification and standalone HTML, not an implemented viewer. The approved contract supersedes the older coordination handoff's single-tap mode-toggle description. |
| P8 / #140 | `feature/140-pixiv-work-viewer` at `d7298c5a06883977966421aec0d11ecf4d2564e4` | Reviewed source foundation; production listing/viewer cutover and current-package qualification are not complete. Historical Combined UI is not the approved #164 viewer. |
| P8 / #141 | `feature/141-pixiv-work-page-bookmarks` at `01fa085840f8442246505b1ad1d883e01a4fecdb` | Reviewed independent Work/Page target foundation. Generic unsaved-group picker, production actions and final integration remain distinct from that foundation evidence. |
| P8 / #161 | `bug/161-pixiv-explore-pagination` at `db54e43bb38e3d997136c52c3434c35342737df3` | Existing source branch; no new package candidate qualified in this session. |
| P9 / #144 | `feature/144-folder-based-collection-sync` at `4dbc9f08adb8bcbce17877d71d80a57ba475243c` | Design-only branch. Runtime reference exists in Combined; its historical qualification does not qualify an extracted candidate. See the behavioral mismatch below. |
| P10 / #157 | `feature/157-native-nhentai-galleries` at `cf71fb22e142564d96a1f25cce85a48898ec52fc` | Reviewed native client/source foundation, not a completed production engine or approved shared Gallery viewer. Prepare last after the shared viewer/P8 foundation. |

P7's existing handoff attributes independent review to actual GPT-6.1 Sol High, not Astra. Its documented results are 6,899 app tests, 1,686 package/CLI tests, 76 Python tests, two shell suites and scoped Android acceptance. These counts have not been rerun here. The exact handoff is `docs/handoffs/156-shared-source-groups-package-2026-11-10.md` on its package branch.

P9's Combined handoff records retaining a receiver collection after source withdrawal. The later sequential-rollout handoff requires a verified signed Stop Publishing to delete the received mirror when no other valid subscription retains it, while missing/offline files must never delete content. Preserve unrelated memberships and rollback protections when reconciling this difference. The later handoff also requires hierarchy/direct-publication UX corrections and says to discuss unresolved UX choices before finalization. Do not silently declare the historical behavior accepted for the new package.

P10's source handoff records live public v2 JSON and media checks from November 8, plus its exact source-foundation tests. Those observations are historical and limited to the endpoints/hosts tested; they are not fresh compatibility evidence for a new app candidate.

## Review coverage at this checkpoint

Production source inspection has concentrated on image URL resolution, engine headers, Pixiv API/media separation, scoped transport, redirects, retry diagnostics, access identity and revocation, image widgets and their existing tests. Package source histories, approved design documents and the cited qualification handoffs have also been reconciled. The shared viewer's pager/controller/composition is being inspected for #164.

The complete nine-domain independent repository audit requested by the user has **not** been completed. In particular, this report does not certify every storage/migration/backup path, every feed/pagination implementation, all platform integrations, all UI behavior or the complete CI/tooling surface. A green test suite would not establish that claim. No unrelated speculative issue is counted as a confirmed defect.

## Acceptance boundaries

All packages and #165 remain separate approval units. New production/test/dependency changes invalidate qualification of the changed candidate and require appropriate re-verification. Do not merge this audit branch, its toolchain archives or temporary workflows into develop. No APK delivery is required. Authenticated Android verification, actual independent re-review and package-specific user acceptance must be reported separately from automated results.

## Updated #165 qualification evidence

This section supersedes the earlier #165 in-progress checkpoint, but does not turn the partial audit or remaining feature packages into completed work. Runtime/test candidate: `40f306ea5d035ebfac454700b60a3692129745a0` on `bug/165-pixiv-media-loading`. Final verification run: [42926187330](https://github.com/timberpile/Boorusama/actions/runs/42926187330); conclusion: **failure**.

| Check | Actual outcome |
| --- | --- |
| Check formatting and patch whitespace | success |
| Run media boundary and rendering regressions | success |
| Analyze affected production and regression sources | success |
| Run complete repository regression on the exact candidate | failure |

Focused result:
```text
00:26 +194: All tests passed!
```

Full-regression completion summaries:
```text
No completion summary found; inspect the original artifact.
```

The owning handoff is `docs/handoffs/165-pixiv-media-loading-2026-11-10.md` on the bugfix branch. It records root cause, exact commits, negative/positive evidence, log digests and remaining review/Android requirements. The handoff-only branch update preserves the checked runtime tree. No independent reviewer or Android acceptance has been performed, and no integration is authorized.

#161 is being reconciled and qualified separately on its existing `bug/161-pixiv-explore-pagination` branch. Its own handoff, not this #165 result, must establish its eventual candidate and test outcomes. The larger #164/P8/P9/P10 implementations and the requested nine-domain independent audit remain unfinished. P7's unchanged-runtime evidence remains as recorded above.
