# Upstream 4.6.3 source inventory

Static provenance and applicability, not an implementation tracker. Progress lives only in [issue #186](https://github.com/timberpile/Boorusama/issues/186). The concrete port specification is [the handoff](../handoffs/186-upstream-4-6-3-stability.md).

## Reproducible scope

- Fork baseline: `timberpile/Boorusama@d9203ae62dcbc5ff81e0bd70702607fb24070787`.
- Task branch: `maintenance/186-upstream-4-6-3-stability`.
- Upstream v4.6.1: `5b04bf6a164f028d41701299367d0dde74dde330`.
- Upstream v4.6.2: `6094dddc2955aaac4379dcbf9b02ec90581d9ef1`.
- Upstream v4.6.3: `2ad0e28adb3c82bea6d94f41bf0785f2ffec92a5`.
- Merge base: `5a2a4e82e827785f0c296b600e44aae2247b90a4`.

[Exact tag comparison](https://github.com/khoadng/Boorusama/compare/v4.6.1...v4.6.3): 30 commits on the release side, 77 changed paths. The first 21 release-side commits end at v4.6.2; the remaining nine end at v4.6.3. GitHub reports one commit behind because v4.6.1's own build commit is absent from that line. That commit changes only the root version from `4.6.0+187` to `4.6.1+188`; the merge-base comparison therefore differs from an endpoint comparison only in the old version value. This is not a missing runtime fix.

The earlier chat linked main-branch counterparts. The following IDs are the actual release-line commits. Assessing all 77 paths does not establish runtime correctness; translations and excluded release files are classified by applicability, not claimed as tested.

## All 30 release-line commits

| ID | Actual release commit | Change | Fork disposition |
|---|---|---|---|
| U01 | [`202ce6d0df`](https://github.com/khoadng/Boorusama/commit/202ce6d0df46db556a5cf3973094cf4d8ea33066) | Anti-bot clearance cookie | Adapt; correct `aft` to `atf` and test classification |
| U02 | [`e1aea5f148`](https://github.com/khoadng/Boorusama/commit/e1aea5f148475edcfc6735b8f1b0a803c9cd5c7d) | Sidecar failure must not discard media | Adapt; preserve actual media failures and report omitted metadata |
| U03 | [`41a36e779e`](https://github.com/khoadng/Boorusama/commit/41a36e779e2a83f684d0b5260bd8159ad7b2c708) | Downloads-shortcut folder paths | Adapt Android-only normalization; coordinate with #172 |
| U04 | [`53893b3094`](https://github.com/khoadng/Boorusama/commit/53893b3094b3476e13accda902deb5e05a16b688) | Forced-protocol diagnostics | Adopt detection/logging; new unsolicited toast is gated |
| U05 | [`420bf9a431`](https://github.com/khoadng/Boorusama/commit/420bf9a431dcf41f691dcf1f57e16b5f3ac0554c) | Rule34 HTTP/1.1 preference | Adapt with parsed-origin matching, not substring matching |
| U06 | [`26ff275650`](https://github.com/khoadng/Boorusama/commit/26ff2756506dc81d58313d7257144fe68bcf3969) | Retry with the app identity | Adapt; preserve original headers, authentication and cancellation |
| U07 | [`b29789d215`](https://github.com/khoadng/Boorusama/commit/b29789d215c22bac46e79df371ba415bee3dcdad) | Concurrent challenge-sharing retries | Adopt with per-request retry budgets and identity isolation |
| U08 | [`62371bf627`](https://github.com/khoadng/Boorusama/commit/62371bf627cee6f97a98ca48c727738e9dff9e79) | Automatic biometric prompt | Adapt lifecycle state machine; no prompt loops |
| U09 | [`e50a9c1091`](https://github.com/khoadng/Boorusama/commit/e50a9c10911a182a09c17021e590088132253503) | Bookmark-specific download folders | Already covered by stronger origin-bound fork behavior; verify, do not replace |
| U10 | [`54f473af9b`](https://github.com/khoadng/Boorusama/commit/54f473af9b80aad9655c742b3b301dc56c0a1ee8) | Moebooru tag parsing off the UI thread | Adapt pure DTO-to-map work; preserve repository API |
| U11 | [`eb344a0c35`](https://github.com/khoadng/Boorusama/commit/eb344a0c35f49ccd5e0e8501d6a8fee3795f8a12) | Layout-sized sidebar image decoding | Adapt all fork fallback/cache paths; viewer remains full quality |
| U12 | [`490e635793`](https://github.com/khoadng/Boorusama/commit/490e635793ea007cecc36404d043118c2c91f818) | Wi-Fi-only downloads through a VPN | Required fix; dependency backend decision must not be hidden |
| U13 | [`748b096c03`](https://github.com/khoadng/Boorusama/commit/748b096c034ec4f6e1df7da6a7d1d78fa78959ad) | Duplicate queued downloads and queue toast | Adapt scoped deduplication; new delayed queue toast is gated |
| U14 | [`0b279f05d3`](https://github.com/khoadng/Boorusama/commit/0b279f05d36f223ea36dcdd292f1a22cd32bf7aa) | Stable bookmark shuffle | Adapt namespaced keys and tie-breaks across fork selectors |
| U15 | [`50669fbc02`](https://github.com/khoadng/Boorusama/commit/50669fbc028267092f4fe54f995b647f1ef7b8dc) | Release asset names without build number | Exclude from stability port; fork release naming/publishing policy |
| U16 | [`6473a0e71d`](https://github.com/khoadng/Boorusama/commit/6473a0e71dd71cdae46bcd6a38a91505f0372509) | Weblate translation refresh | Optional content update, not required for these fixes; preserve locales |
| U17 | [`0976d0b907`](https://github.com/khoadng/Boorusama/commit/0976d0b9070029a596d314179fef9408907755e3) | Russian placeholder corrections | Affected keys absent in fork; keep valid English fallback and add contract coverage |
| U18 | [`476e5533ca`](https://github.com/khoadng/Boorusama/commit/476e5533ca77743b8bfd48557a77039963633be3) | Repeated 4.6.2 release notes | Exclude duplicated feature list; no new features in this commit |
| U19 | [`67f27257e9`](https://github.com/khoadng/Boorusama/commit/67f27257e9e9c56e52ba6e604c7523688b75c7b3) | TLS versus certificate error classification | Adapt predicates; preserve fork cooldown and cancellation cases |
| U20 | [`d53d4e3f5c`](https://github.com/khoadng/Boorusama/commit/d53d4e3f5c9873c9e155cbc375d240220342049d) | Minor branch for patch release preparation | Exclude: fork explicitly forbids using this legacy release automation |
| U21 | [`6094dddc29`](https://github.com/khoadng/Boorusama/commit/6094dddc2955aaac4379dcbf9b02ec90581d9ef1) | Prepare version 4.6.2 | Exclude upstream version/build replacement |
| U22 | [`6276fa1ebe`](https://github.com/khoadng/Boorusama/commit/6276fa1ebe3700198cfb00ab2a0cda7e516e8006) | Preserve local lock on settings restore | Adapt with queued `updateWith`; preserve values at transaction time |
| U23 | [`a2e2dd86d3`](https://github.com/khoadng/Boorusama/commit/a2e2dd86d39824d7c3b78a8b9a9eac5723e1df8a) | Device authentication availability | Adapt authenticator contract and fakes; verify on real platform |
| U24 | [`b9429ea6a6`](https://github.com/khoadng/Boorusama/commit/b9429ea6a66fc80601a87c8dae15d5231ae6400f) | Retry or disable unverifiable app lock | Split: safe retry is required; unauthenticated disable is gated |
| U25 | [`44db08b522`](https://github.com/khoadng/Boorusama/commit/44db08b5229150f2a6cf1584bd62cec06cacafb3) | ID-based deep pagination | Adapt cursors, limit-aware coalescing and bulk errors; preserve all fork metadata |
| U26 | [`4c531a332a`](https://github.com/khoadng/Boorusama/commit/4c531a332a47c23a9296f700024be98ff70c1f0f) | e621 response format | Adapt DTO/client compatibility; keep unified fork Post model |
| U27 | [`8c7aba0eb8`](https://github.com/khoadng/Boorusama/commit/8c7aba0eb82f3b760c86e823932f8f4d90c9be54) | Network adapter diagnostics | Adopt real availability/context; remove misleading unconditional Cronet log |
| U28 | [`cbc5e5b573`](https://github.com/khoadng/Boorusama/commit/cbc5e5b57371c54b69e35c70201dcbac3adc4e50) | Zerochan malformed-list recovery | Adapt bounded extraction; do not turn arbitrary 500 responses into empty success |
| U29 | [`ded2af60e0`](https://github.com/khoadng/Boorusama/commit/ded2af60e09d01ade799afa7408c15786dd49f02) | Repeated 4.6.3 release notes | Exclude duplicated feature list |
| U30 | [`2ad0e28adb`](https://github.com/khoadng/Boorusama/commit/2ad0e28adb3c82bea6d94f41bf0785f2ffec92a5) | Prepare version 4.6.3 | Exclude upstream version/build replacement |

## All 77 changed paths

The IDs identify the owning review topics; shared files can belong to several topics. This is a coverage map, not an instruction to replace entire fork files. Upstream tests and test-support changes must be adapted to fork models and fixtures.

| Upstream path | Review topics |
|---|---|
| `CHANGELOG.md` | U18, U29 |
| `lib/boorus/e621/posts/providers.dart` | U26 |
| `lib/boorus/gelbooru/posts/pagination.dart` | U25 |
| `lib/boorus/gelbooru/posts/providers.dart` | U25 |
| `lib/boorus/moebooru/tag_summary/repo.dart` | U10 |
| `lib/boorus/moebooru/tag_summary/types.dart` | U10 |
| `lib/boorus/moebooru/tags/providers.dart` | U10 |
| `lib/core/backups/sources/settings_source.dart` | U22 |
| `lib/core/bookmarks/src/providers/bookmark_provider.dart` | U09 |
| `lib/core/bookmarks/src/providers/bookmark_shuffle_provider.dart` | U14 |
| `lib/core/bookmarks/src/providers/local_providers.dart` | U14 |
| `lib/core/boorus/booru/src/booru.dart` | U05 |
| `lib/core/bootstrap/production_boorusama_bootstrap.dart` | U27 |
| `lib/core/bulk_downloads/src/providers/dry_run.dart` | U25 |
| `lib/core/bulk_downloads/src/providers/post_fetcher.dart` | U25 |
| `lib/core/ddos/diagnostics/src/protection_log_recorder.dart` | U06 |
| `lib/core/ddos/handler/protection_handler.dart` | U04, U06, U07 |
| `lib/core/ddos/handler/providers.dart` | U04, U27 |
| `lib/core/ddos/solver/src/protection_event.dart` | U06 |
| `lib/core/ddos/solver/src/protection_orchestrator.dart` | U01, U06, U07 |
| `lib/core/ddos/solver/src/protection_solver.dart` | U01, U06, U07 |
| `lib/core/download_activity/scope.dart` | U13 |
| `lib/core/downloads/background/downloader.dart` | U02 |
| `lib/core/downloads/background/widgets.dart` | U27 |
| `lib/core/downloads/downloader/src/providers/download_notifier.dart` | U02, U13 |
| `lib/core/downloads/downloader/src/providers/pending_downloads_provider.dart` | U13 |
| `lib/core/downloads/downloader/src/types/pending_downloads.dart` | U13 |
| `lib/core/downloads/downloader/src/types/result.dart` | U02 |
| `lib/core/http/client/src/interceptors/dio_protection_interceptor.dart` | U04, U06, U07 |
| `lib/core/http/client/src/providers/dio.dart` | U04, U27 |
| `lib/core/http/client/src/types/http_utils.dart` | U19 |
| `lib/core/images/booru_image.dart` | U11 |
| `lib/core/posts/details_parts/src/_internal/preview_post_grid.dart` | U11 |
| `lib/core/posts/details_parts/src/related_posts_section.dart` | U11 |
| `lib/core/posts/details_parts/src/sliver_details_post_list.dart` | U11 |
| `lib/core/posts/post/src/types/post_repository.dart` | U25 |
| `lib/core/widgets/app_lock_scope.dart` | U24 |
| `lib/foundation/applock/src/app_lock.dart` | U08, U24 |
| `lib/foundation/applock/src/app_lock_session.dart` | U08 |
| `lib/foundation/applock/src/biometrics.dart` | U23 |
| `lib/foundation/applock/src/device_authenticator.dart` | U23 |
| `lib/foundation/applock/src/local_auth_device_authenticator.dart` | U23 |
| `lib/foundation/plugin_app_file_picker.dart` | U03 |
| `packages/booru_clients/boorus.yaml` | U05 |
| `packages/booru_clients/lib/src/e621/e621_client.dart` | U26 |
| `packages/booru_clients/lib/src/e621/types/post_dto.dart` | U26 |
| `packages/booru_clients/lib/src/gelbooru/gelbooru_client.dart` | U25 |
| `packages/booru_clients/lib/src/zerochan/zerochan_client.dart` | U28 |
| `packages/boorusama_cli/lib/src/release/github/receipt.dart` | U15 |
| `packages/boorusama_cli/lib/src/release/prepare/release_branch.dart` | U20 |
| `packages/boorusama_cli/lib/src/release/prepare/service.dart` | U20 |
| `packages/boorusama_cli/test/release/github/receipt_test.dart` | U15 |
| `packages/boorusama_cli/test/release/prepare/release_branch_test.dart` | U20 |
| `packages/i18n/translations/en-US.json` | U02, U04, U24 |
| `packages/i18n/translations/pt-BR.json` | U16 |
| `packages/i18n/translations/ru-RU.json` | U16, U17 |
| `packages/i18n/translations/uk-UA.json` | U16 |
| `pubspec.lock` | U12 |
| `pubspec.yaml` | U21, U30 |
| `pubspec_overrides.yaml` | U12 |
| `test/app_lock/session_test.dart` | U08 |
| `test/application/app_lock_flow_test.dart` | U23, U24 |
| `test/application/backup_restore_flow_test.dart` | U22 |
| `test/application/bookmark_library_flow_test.dart` | U09, U14 |
| `test/application/gelbooru_pagination_flow_test.dart` | U25 |
| `test/application/support/application_test_store.dart` | U09, U14 |
| `test/core/bookmarks/bookmark_shuffle_test.dart` | U14 |
| `test/core/http/connection_error_test.dart` | U19 |
| `test/core/images/layout_decode_size_test.dart` | U11 |
| `test/ddos/challenge_browser_handoff_test.dart` | U01, U06, U07 |
| `test/ddos/protection_diagnostics_test.dart` | U06 |
| `test/ddos/protection_solver_test.dart` | U01, U06, U07 |
| `test/downloads/pending_downloads_test.dart` | U13 |
| `test/downloads/sidecar/cache_download_test.dart` | U02 |
| `test/foundation/picked_directory_test.dart` | U03 |
| `test/support/fakes/test_platform_services.dart` | U23 |
| `test/support/gelbooru_pagination_backend.dart` | U25 |

## Dependency delta beyond the release interval

The fork pins `khoadng/background_downloader@fd67fff9ee4ad4cdf415dc3285289cad9289cefe`. Upstream v4.6.1 already used `3aed772d993117d4f9a1cab3cb7acff982ea453b`; v4.6.3 uses `76d516e098a7c91462bdede1c726be81a7f1a4ab`. Consequently the fork-to-target dependency change contains four commits, not just the Android VPN fix. This older dependency gap is not falsely attributed to newly introduced v4.6.2/v4.6.3 application changes.

[Exact dependency comparison](https://github.com/khoadng/background_downloader/compare/fd67fff9ee4ad4cdf415dc3285289cad9289cefe...76d516e098a7c91462bdede1c726be81a7f1a4ab).

| ID | Commit | Change | Disposition |
|---|---|---|---|
| D01 | [`080d672a7e`](https://github.com/khoadng/background_downloader/commit/080d672a7e11fd1e9d1718667c478e823674b418) | Windows transfers use WinHTTP | Backend change: explicit decision; not silently imported with Wi-Fi fix |
| D02 | [`f09dd55ad1`](https://github.com/khoadng/background_downloader/commit/f09dd55ad183ef4a3144dcd69c317fdcc7df9078) | Protected Windows download test | Required if D01 is accepted; execute on Windows |
| D03 | [`3aed772d99`](https://github.com/khoadng/background_downloader/commit/3aed772d993117d4f9a1cab3cb7acff982ea453b) | Drain native callbacks before task isolate exit | Required with D01; do not take WinHTTP without its crash fix |
| D04 | [`76d516e098`](https://github.com/khoadng/background_downloader/commit/76d516e098a7c91462bdede1c726be81a7f1a4ab) | Wi-Fi NetworkRequest admits VPN transport | Required Android stability fix; retain Wi-Fi transport constraint |

The five dependency paths are `android/src/main/kotlin/com/bbflight/background_downloader/BDPlugin.kt`, `lib/src/desktop/desktop_downloader.dart`, `lib/src/desktop/isolate.dart`, `pubspec.yaml`, and `example/integration_test/windows_transport_test.dart`.

## Additional fork-specific implementation surfaces

These are not omissions from the 77-path upstream inventory: they are integration surfaces unique to this fork. In particular, inspect `lib/core/posts/post/src/data/origin_aware_post_repository.dart` (`bindPostResultOrigin` reconstructs results), `lib/core/posts/post/src/data/post_repository_builder.dart`, `lib/core/posts/post/src/data/post_repository_impl.dart`, `lib/core/posts/post/src/data/post_repository_ext.dart`, `lib/boorus/e621/posts/parser.dart`, `lib/core/bookmarks/src/providers/bookmark_group_selectors.dart`, `lib/core/settings/src/providers/settings_notifier.dart`, and existing content-access/request-coordination consumers. The handoff specifies which require changes versus verification.

## Non-goals and evidence limits

The duplicated changelog features (PIN lock, Wi-Fi preference, sidecars, thumbnail quick actions, media-host overrides, tag management, bulk support, and languages) predate this interval. Do not create new feature work from those repeated notes. Preserve the fork version/build and release policy. No application code or upstream commit has been merged by this audit, and no Flutter, device, Windows-native, or live-site regression test has been run.
