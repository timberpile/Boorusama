# #117 — AA01/AA02 local revalidation

[Current all-branch review](117-all-live-review-2026-10-30.md) supersedes the technical-readiness status below; this record retains its original evidence.

Session `local-AA01-AA02-20261030`; branch `feature/117-pixiv-favorites`.
Final runtime/test candidate: `bc6c7e47a1342d4c2004d0350c167928dad392c7`.
Instructions remain develop `894ab270693cdb054a5d527c96182e21e2b14ffc`.
Prior published author head `cee89c991a5fdc01d7ec8f89adbc3828974a7334`
and its preceding auth/session remediation are preserved. They belong to the
previous writer, whose claim was released. This session claimed issue #117 in
comment `6522949825`. Shared auth correction is owned here only, without
propagation into #92 or #118.

## Original claims and independent current verdicts

Exact auditor revisions, original IDs and compound variants are retained in the
[AA01 map](https://github.com/timberpile/Boorusama/blob/896baacf5bb64fba43a355580742e0d821f89d17/docs/reviews/AA01/remediation/source-map.md)
and [AA02 map](https://github.com/timberpile/Boorusama/blob/604e7a15a6c19db340c5e8584cf4c0ab0fc1a331/docs/reviews/AA02/remediation/source-map.md).
Original Favorites/transport reports, actual auth/session/controller/client,
configuration writers and share consumers were inspected independently.

| Original IDs / ingestion locations | Canonical cause | Current verdict, correction and evidence |
| --- | --- | --- |
| AA01-A01-F0010; AA01-A02-F0005; AA02-A05-F0001 | AA01-C0011 | Previous exact-origin repair independently verified. API requests alone receive bearer/401 recovery; CDN/foreign/scheme/port/userinfo/subdomain variants do not refresh or retain stale Authorization. Added actual uncached ShareMediaPreparation consumers for CDN and foreign media with the authenticated Dio: no Authorization, safe Referer preserved, no extra refresh, temporary lease released. No observed theft or live credential trace claimed. |
| AA01-A03-F0002 | AA01-C0018 | Previous full-config session/PostScope identity repair independently verified. Real PixivFavoritesPage uses actual validated endpoint requests; cosmetic config changes during initial and next-page loading cancel old work and replace controller/fetcher. Late old results are ignored, new refresh succeeds. |
| AA01-A02-F0003 | AA01-C0015 | Coverage improved with real page/privacy/profile/consumer tests rather than isolated synthetic state. Actual public/private chips, account A/B, initial/load-more/cosmetic changes and cancellation exercised. Favorites-to-viewer/native live journey remains a separately stated acceptance gap. |
| INGEST-AA02-A02-T016-ACCOUNT-METADATA | AA02-C0021 | Previous manual-token stale-identity invalidation verified, and user-approved explicit Verify bootstrap added. Entering a changed token clears old login/passHash; it sends no keystroke requests. Verify calls real OAuth transport, requires access/refresh tokens and positive user ID, and writes the same paired draft fields as OAuth login. Generation/current-token/draft/mounted guards prevent B/C reverse completions or disposal from replacing newer identity. Missing identity is retryable; unverified replacement issues no old-account Favorites request. Normal profile Save persists the verified draft. |
| AA01-A01-F0001; AA01-A02-F0002; AA01-A03-F0001; AA02-A01-F0004; AA02-A03-F0003; AA02-A04-F0005; AA02-A05-F0002 | AA01-C0001 | Confirmed dependency remains open on this standalone branch. Session advertises empty-continuing/nonempty-terminal cursor metadata, but this branch retains the older shared Grid. #113 was verified separately, not combined here. No eager cursor walking or duplicate shared-controller workaround. |
| AA01-A01-F0008; AA01-A02-F0008 | AA01-C0009 | #113 generation repair is independently verified there, not automatically present here. Shared asynchronous refresh/load-more acceptance needs the approved combined candidate. |
| INGEST-AA01-A01-T004-RETRY | AA01-C0024 | Session cursor retry versus generic Grid page-one recovery remains an acceptance question, not a proved separate Pixiv defect. |
| INGEST-AA01-A01-T004-MALFORMED; INGEST-AA02-A04-T021-PAYLOAD | AA01-C0025 | Strict list/DTO/cursor validation retained. No legitimate authenticated malformed response proves a need to relax parsing. |
| INGEST-AA01-A01-T004-C10-LOG | AA01-C0026 | Separate credential-log disclosure hypothesis remains rejected: OAuth Dio has no HTTP logger; interceptor emits fixed messages and ordinary logging uses redacted URLs rather than bearer headers. No exhaustive history scan claimed. |
| AA01-A02-F0007; INGEST-AA02-PIXIV-PARTS | AA01-C0017 | Both independent Pixiv part files, shared options once and both navigation capabilities must survive future integration. No combined conflict or pass claimed. |

## Additional confirmed findings during local execution

The constrained auth tab test exposed an existing Kurumi warning-header Row
that overflowed by 7.8 px at 320 px / 2x text. The actual Flutter error identified
info_container.dart. Its title now uses available width and the header may grow
above its 40 px minimum; warning content and expansion semantics remain. The
initial speculative status-row change was removed after it did not explain the
failure. The actual auth test passes with keyboard obstruction of 220 px.

Full execution also exposed a cache-settings fixture deleting its temporary Hive
directory before FollowingTopicRepositoryNotifier.closeFuture finished. The
fixture now awaits that existing lifecycle signal after each unmount. Five
settings/repository lifecycle consumer tests passed; no production storage logic
was changed. These follow-up test changes are in the final candidate above.

## Executed verification

Pinned FVM Flutter 3.47.2; concurrency six. Missing ignored generated setup was
created with documented CLI/i18n dependencies and gen.sh.

- Final targeted Favorites page, manual credential, origin, session, existing
  auth/parser/explore, share-media and navigation scope: 154 passed before the
  final test-only teardown/diagnostic cleanup follow-up. The final full suite
  executes those same updated files.
- Added media origin consumer run: 11 passed. Settings/repository cleanup: five
  passed. Earlier invalid family override and speculative/hanging harness runs
  are not counted as verification.
- Final `./scripts/run_regression_tests.sh`: exit 0; 5,506 application tests, 1,623 package/CLI tests, both shell tooling suites and 72 Python tests passed. Router retained two existing skips.
- Final scoped FVM analyzer: zero errors, warnings or informational findings.
- Changed Dart formatted; final diff reviewed; git diff --check passed.
- Native callback/finalizer diagnostics also occur on independent passing
  branches; they remain unattributed and were not suppressed.

Logs: `/tmp/boorusama-aa-revalidation/117-*`. The earlier full run failed on the
fixture teardown race and was stopped; only the final completed run is a pass.

## Remaining gates

No APK build/install, real Pixiv endpoint, WebView OAuth login, native Share,
manual-token live account or device acceptance was performed. Tests use fixture
credentials and controlled HTTP adapters; no private account material was read.
#113/#117 cursor/controller behavior and #117/#118 client composition require
separate approved combined candidates and complete final-candidate regression.
#92/#118 still contain their independent older auth boundary. No PR, develop
integration, issue closure, task deletion or release occurred.
