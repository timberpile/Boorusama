# Pixiv media loading regression — issue #165

Historical qualification checkpoint. The final combined review, owner acceptance
and integration are recorded in the [P7 qualification handoff](p7-pixiv-qualification-2026-11-11.md).
Outstanding gates below describe this earlier checkpoint.

## Candidate and authorization

- Branch: `bug/165-pixiv-media-loading`.
- Runtime/test candidate: `40f306ea5d035ebfac454700b60a3692129745a0`.
- Develop prerequisite: `2e2ea428ba323706e37a65e45903d3959df439d4`.
- Working-master source comparison: `422aeae087c1108e655d85d1a3dac25120456cd6`.

Subsequent handoff-only commits do not alter the tested runtime, tests or dependencies. This correction is independent of #161, #164 and P7–P10. No PR, release, merge into develop or issue closure is authorized. The user builds their own APK.

## Demonstrated cause

Commit `2e2ea428` introduced exact-origin public-Referer filtering in both `MediaRequest.resolve` and `SourceMediaHttpClientAdapter`. The catalog configures `https://pixiv.net/`, while the existing Pixiv engine supplies `https://www.pixiv.net/`. Both boundaries remove that public header for the ordinary catalog profile. Master did not apply this new filtering to ordinary image URLs. Persisted profile identities and media URLs must not be rewritten to work around the mismatch.

Controlled requests to the user's reported thumbnail and original URLs supplied no credentials. Without the Referer, both returned HTTP 403 and HTML. With the existing Pixiv Referer, both returned HTTP 206 and image data. These were 1,024-byte range checks, not full-file decodes or authenticated Android UI acceptance. The observations are retained in [run 42921812249](https://github.com/timberpile/Boorusama/actions/runs/42921812249).

A second defect concealed the cause: the application's two `FetchStrategyBuilder(silent: true)` configurations converted rejected requests into null, which `ImageFetcher` reported as `Empty response`. A successful zero-byte body has a different error path; the reported message did not establish an empty server body.

## Published correction

`bc4763d1b264504d3fa448ac3ef28b6a0173daf3` shares one public-root predicate between URL resolution and every transport redirect hop. Its narrow alias permission covers only the canonical HTTPS Pixiv root, the existing HTTPS `www.pixiv.net` root Referer and `i.pximg.net`/`s.pximg.net` over port 443. It is not a general www normalization or credential-origin exception. Source installation checks and explicit media-host override stripping remain unchanged. Foreign hosts, lookalikes, private/query/fragment Referers, insecure aliases and nondefault ports receive no new permission.

`9b52df7b6aa4728cc84067a57f2599cd4d1da9c1` removes `silent: true` from the raw-image and candidate-image strategies. The original failure status is retained; expected candidate probes remain quiet through their existing `printError: false`. Retry policy, cancellation, cache identity and persisted formats are unchanged. `40f306ea5d035ebfac454700b60a3692129745a0` corrects the diagnostic fixture's cleanup before Flutter's binding invariants.

Four production files and two regression files differ from develop. The tests exercise the actual engine-header provider, URL resolver, scoped media provider/adapter, fetcher and rendered failure widget. Only the remote server is simulated. Coverage includes canonical/www profiles, media variants, both independent header boundaries, unbound resolved requests, explicit overrides, redirects, rejected aliases and credential stripping.

## Actual verification

Toolchain: FVM 4.3.1, Flutter 3.47.2 and Dart 3.13.2 on hosted Linux. No test or diagnostic was suppressed to obtain a pass.

| Check | Recorded result |
| --- | --- |
| Test-only candidate `b28185e1e9fd829fdef965c9d310e728fd0b6d2f` | Three passed and five failed on the intended assertions: [red run 42922922442](https://github.com/timberpile/Boorusama/actions/runs/42922922442). |
| Formatting and patch whitespace on final runtime candidate | Passed. |
| Media boundary/rendering and adjacent tests | **194 passed** in [run 42926187330](https://github.com/timberpile/Boorusama/actions/runs/42926187330). |
| Scoped analyzer | Zero errors/warnings; **eight informational diagnostics**, retained in the log. |
| Application suite in that first full-run attempt | **6,782 passed; ten FFmpeg-dependent tests skipped** because FFmpeg was absent. The runner then stopped because `rg` was missing, before package/tooling execution. This was not a complete regression pass. |
| Supplemental native media suite on the same candidate | **16 passed, zero skipped**, including all ten previously skipped cases, with real FFmpeg/FFprobe in [run 42931390172](https://github.com/timberpile/Boorusama/actions/runs/42931390172). |
| Fresh complete runner with `ripgrep` installed | [Run 42930406283, issue 165 job](https://github.com/timberpile/Boorusama/actions/runs/42930406283/job/130227417197). At this checkpoint its final result has not been established; do not infer a full pass from the prior app result. |
| Additional local tooling checks | Both repository shell suites passed in an isolated checkout of the exact candidate. Local Python attempts were interrupted by execution-tool timeouts; they are not Python passes or confirmed product failures. |

The native-media artifact SHA-256 is `70d8ea6051e46eabe84dcb97aa67d5e5b6be3363eab85e31612724ac5114d153`. Downloaded evidence archives were checked against their published digests. CI artifacts retain the immutable candidate SHA and raw logs; ignored local evidence is retained under `.worktrees/_artifacts/165-verification/`. The first fixture timeout and subsequent binding-cleanup failure were test defects, corrected before the final candidate, not additional application findings.

## Review and acceptance still required

The author re-reviewed the changed request boundaries, redirect behavior, credentials, retry propagation and adjacent consumers. This is **not independent review**. No independent Astra XHigh execution interface was available or invoked. No Android/Maestro or real-account UI acceptance was performed.

An independent reviewer must inspect the final delta, especially public Referer permission versus credential authority and failure propagation. On Android, follow the exclusive emulator lease and restore the original test environment. Exercise Browse, Explore and Following thumbnails; preview/original quality; Favorites; saved/offline images; retry, cancellation and preloading; canonical and existing www-root profiles; neighboring engines and account switching. Preserve the only copy of user data and never publish credentials.

Read the final complete-run outcome and artifact before claiming technical qualification. Before any approved integration, verify the final combination with current develop. Reuse valid unchanged-candidate results across documentation-only updates; runtime/test/dependency changes or a changed develop combination require the full gate again. Automated results are separate from independent review, Android acceptance and the user's integration approval.

Prefer reviewing and accepting this independent correction before reconciling #161 and P7 onto a develop base containing it. Do not create an alternative combined integration source, merge the audit infrastructure, or silently treat any implementation/test result as merge permission.
