# Upstream 4.6.3 stability port — #186

## Scope, authority, and evidence

Implement the relevant fixes and stability improvements from upstream v4.6.1 through v4.6.3 without replacing fork-specific architecture. The user requested an exhaustive audit, a dedicated branch, concrete code adaptations, and durable per-item progress. Features and security/backend policy changes must be discussed separately.

- Task branch: `maintenance/186-upstream-4-6-3-stability`.
- Fork baseline: `d9203ae62dcbc5ff81e0bd70702607fb24070787` on `develop`.
- Upstream target: `khoadng/Boorusama@2ad0e28adb3c82bea6d94f41bf0785f2ffec92a5` (`v4.6.3`).
- [Issue #186](https://github.com/timberpile/Boorusama/issues/186) is the only progress/acceptance tracker. Update its existing checklist rather than creating another queue in Markdown.
- [Source inventory](../reviews/186-upstream-4-6-3-inventory.md) accounts for all 30 release-side commits, all 77 changed paths, and the four-commit downloader dependency gap. `Uxx` and `Dxx` below refer to that inventory.

This is a source-reviewed implementation specification, not an applied runtime patch. Code sketches below are proposed adaptations and have not been compiled. No Flutter, device, Windows-native, or live-site tests were run during the remote audit. Do not infer implementation or integration readiness from this document.

Read current `AGENTS.md`, relevant repository skills, and the development/engineering workflows before implementation. Continue this branch; reconcile any later `develop` changes without overwriting other agents' work. Preserve the unified `Post`/origin model, content-access revocation, profile-specific settings, request coordination, and manually declared Riverpod providers. No blanket merge, PR, merge into `develop`, issue closure, version bump, or release is authorized here.

## Implementation order

Use small, independently reviewable commits referencing #186. All applicable fixes matter; this order follows dependencies rather than assigning lower-priority fixes to an optional backlog.

1. Client response compatibility, request coalescing, and core pagination metadata.
2. Gelbooru browse/bulk consumers and failure propagation.
3. Protection/network fixes, preserving coordinator and actor guards.
4. Download/sidecar fixes; isolate the dependency/backend decision.
5. App-lock and settings-restore corrections, then directory selection.
6. Bookmark shuffle and performance fixes; verify existing origin-bound downloads.
7. Localization contracts, complete regression verification, and the final coverage audit.

Do not include gated behavior from the decision section merely because it shares a commit with an approved fix.

## U26 — e621 response compatibility

**Current gap:** the fork DTO still uses the legacy response structure. The application parser produces the fork's `E621PostRecord`, unified `Post`, `PostOrigin`, and `PostDetailFacts`; replacing it with upstream application types would regress that architecture.

**Change these surfaces:**

- `packages/booru_clients/lib/src/e621/e621_client.dart`: add the upstream `v2=true` and `mode=extended` query parameters to list, single-post, and popular-post requests. Retain supported wrapped and unwrapped response shapes, authentication, and request-interruption behavior.
- `packages/booru_clients/lib/src/e621/types/post_dto.dart`: port the `files`-based dispatch, `_fromFiles`, `_fromLegacy`, and nullable parsing helpers from U26. Preserve the legacy DTO interface consumed by the fork.
- `lib/boorus/e621/posts/providers.dart`: adapt the conversion-failure diagnostic, not the whole provider. Keep source settings and existing result semantics.
- `lib/boorus/e621/posts/parser.dart`: retain the current record/codec pipeline and detail facts. Exercise JPG/WebP fallback and video alternatives rather than assuming that successful DTO parsing implies successful rendering.

The new-schema mapping is concrete: `files.meta` supplies extension, size, MD5 and duration; `files.original` supplies original URL/dimensions; `files.preview` and `files.sample` supply image variants; `files.video` supplies video alternatives; `stats` supplies score/favorite/comment data; `has` supplies notes/children/sample facts. Missing objects must not cause unchecked casts or invent metadata.

Where the new DTO supplies `alt`, the existing parser needs an explicit image fallback rather than ignoring a valid WebP-only preview:

```dart
final previewUrl = dto.preview?.url ?? dto.preview?.alt ?? '';
final sampleUrl = dto.sample?.url ?? dto.sample?.alt;
```

Verify this against representative v2 fixtures. Cover video alternatives when image-sample data is absent; preserve them without inventing an image URL. Missing original media should follow the existing visibility/unavailable-media policy, not manufacture a playable URL. Warn when non-deleted DTOs are returned but none can be converted; do not log response bodies or credentials.

**Tests:** new package fixtures for legacy/v2, list/single/popular wrappers, null/deleted/restricted media, numeric duration, tags and relationships, JPG/WebP and video alternatives. Add application conversion checks for original byte size/dimensions/format, ratings, favorite state, origin binding and source pagination facts. A changed API fixture is evidence; this audit did not establish a live-site outage.

## U28 — Zerochan malformed responses

**Files:** `packages/booru_clients/lib/src/zerochan/zerochan_client.dart` and new client-level regression tests.

Port the bounded `items`-object extractor and narrowly scoped HTTP-500 recovery from U28. Normal JSON parsing stays first. For a malformed string response, locate the candidate object and scan balanced braces/brackets while respecting quoted strings and escapes; then use `jsonDecode` and validate the expected shape. Never use a broad regular expression to strip arbitrary HTML from JSON.

Only recover an HTTP 500 when a complete, structurally valid post-list payload is present. Preserve the original error for ordinary error pages, truncated JSON, missing `items`, or invalid DTO payloads. An unparseable response must not become an empty successful page and terminate pagination. Keep cancellation/interruption exceptions distinct from parse failures. Log recovery counts/status, not the raw response.

**Tests:** valid JSON, warning/HTML prefix and suffix, escaped quotes and braces in strings, recoverable 500, ordinary 500, truncated object, empty valid array, non-map entries, cancellation. Do not generalize this exception to other endpoints or all status codes.

## U25 — Gelbooru pagination, coalescing, and bulk error handling

This is not a provider-only cherry-pick. It crosses client DTOs, shared result contracts, origin wrappers, browsing, and bulk collection.

### Client and shared contracts

In `packages/booru_clients/lib/src/gelbooru/gelbooru_client.dart`:

- Include `limit` in the `RequestDeduplicator` key. Currently concurrent `limit: 1` count probes and ordinary pages with identical tags/page share a key and can share the wrong response. This is request coalescing, not a persistent-cache migration.
- Extend `GelbooruPosts` with `lastId`, computed from the raw DTO sequence **before** filtering missing-MD5 posts. Preserve raw source-count facts needed by the fork; visible-list length is not the source stride.
- Keep `RequestInterruption` behavior and authentication intact.

In `lib/core/posts/post/src/types/post_repository.dart`, add `useCursor` and `cursor` without removing `prepareGroupRows`:

```dart
const PostFetchOptions({
  this.cascadeRequest = true,
  this.prepareGroupRows = false,
  this.useCursor = false,
  this.cursor,
});
```

Add `int? nextCursor` to core `PostResult`, its empty constructor, `copyWith`, equality props, and `toResult`. Preserve `hasMore`, `rawPostCount`, and `rawUniquePostCount`. Keep existing default/raw/group-row option behavior; only bulk Gelbooru-capable flows opt into cursor continuation.

**Required fork-only adaptation:** `lib/core/posts/post/src/data/origin_aware_post_repository.dart` reconstructs results in `bindPostResultOrigin`. Prefer preserving every result field by copying only posts:

```dart
PostResult<Post> bindPostResultOrigin(
  PostResult<Post> result, {
  required PostOrigin origin,
}) => result.copyWith(
  posts: bindPostsOrigin(result.posts, origin: origin),
);
```

The current `PostRepositoryBuilder` forwards options/results; preserve that. Audit `post_repository_impl.dart`, `post_repository_ext.dart`, and every `PostResult(...)`/`toResult(...)` consumer for reconstruction that would drop the cursor or fork metadata. Test origin binding explicitly; adding fields only in the upstream-listed files is insufficient.

### Browse and bulk continuation

Create `lib/boorus/gelbooru/posts/pagination.dart` from the upstream implementation and adapt `posts/providers.dart` to unified `Post`. Keep `listingSettingsForAuthProvider(config.auth)`, not upstream's global listing settings.

Retain the upstream ID-filter intersection and ascending/descending logic. ID cursors are valid only for default/ID order and supported numeric ID bounds. Do not silently apply them to random, score, negative-ID, or unsupported sort queries. Validate positive page/limit inputs. Preserve an explicit bounded/error behavior for unsupported deep paging instead of claiming every sort is unlimited.

Use `GelbooruPageCursors` per repository/query/limit, reset at page-one refresh, and adapt the upstream bounded sequential-hop/count-probe approach for distant jumps. Count probes must pass through the existing API coordinator and cancellation gates. Unknown counts are not zero: do not report EOF solely because a probe could not establish a count. Validate cursor advancement; duplicate/non-monotonic IDs must fail rather than loop. Source mutations during absolute page jumps are not a snapshot-consistency guarantee.

In `lib/core/bulk_downloads/src/providers/post_fetcher.dart`, propagate repository errors and retain `nextCursor` through blacklist filtering. A page with no visible posts but an advancing raw cursor is not EOF. Preserve the fork's raw-progress/`hasMore` facts wherever collection termination relies on them. Adapt the bulk `PostResult` separately from the core type of the same name.

In `dry_run.dart`, retain the cursor after every page, including fully filtered pages. **Do not copy upstream's `onError: ... return null` block.** Upstream still converts later-page fetch failures to `DryRunStatusCompleted`. Use the existing failed-state path for real failures, preserve collected records, and keep cancellation distinct from failure. The intended structure is:

```dart
final nextResult = await fetcher.getPosts(
  tags: tags,
  page: page,
  task: task,
  cursor: cursor,
);
if (nextResult.isEmpty) {
  // A genuine end, not an exception or a filtered source page.
  page--;
  break;
}
rawPosts = nextResult.posts;
cursor = nextResult.nextCursor;
```

Leave exceptions for the existing outer failure handler after adapting cancellation handling. Do not introduce unbounded automatic retries. Check all other `PostFetcher` consumers now that errors are no longer encoded as empty results.

**Tests:** adapt upstream `test/application/gelbooru_pagination_flow_test.dart` and `test/support/gelbooru_pagination_backend.dart`. Add concurrent different-limit requests; descending/ascending and intersecting bounds; unsupported sorts; sequential and distant pages; refresh/limit changes; missing counts; raw rows filtered in the client or repository; cursor propagation through origin binding; non-advancing IDs; failure on page 2 after successful page 1; cancellation and cooldown; no premature complete status and no request-budget bypass.

## U01, U06, U07 — Protection retries

**Files:** protection solver/orchestrator/event/diagnostic files, `lib/core/ddos/handler/protection_handler.dart`, and `lib/core/http/client/src/interceptors/dio_protection_interceptor.dart`.

Port these together, with the accompanying upstream tests:

1. U01 fixes the clearance-cookie recognition typo (`aft` -> `atf`). Add positive and negative classification tests rather than broadening every cookie to clearance.
2. Add `isClearanceCookie` throughout the solver interfaces/wrappers and orchestrator.
3. Capture immutable per-request original headers in `RequestOptions.extra` before protection header mutation. Pass those as `ownHeaders` to `prepareRequestHeaders`.
4. After bounded browser-clearance alternatives fail, permit one app-identity retry. Remove only protection clearance cookies; preserve the request's own authentication/session headers. Clear/rebuild protection-derived headers so a rejected browser identity is not retained accidentally.
5. Share only the origin-level decision to use app identity, never another request's header map. U07 ensures concurrent waiters can all retry even when one has already selected that origin policy.
6. Reset policy on a newly solved challenge and forget a failed app-identity fallback as upstream specifies. Record the new diagnostic event without exposing header values.

**Fork constraints:** preserve `_skipProtectionRecovery`, `isApiSafeRead`, `ApiRequestClass.bulkTransfer`, the 429 exclusion, `apiNegotiatedKey`, `_recoverRule34Safely`, its bounded cancellation-aware delay, and loaded-browser-page handling. Never replay favorite/vote mutations automatically. Keep coordinator admission and access-revocation checks on every network dispatch. Redirects must not reintroduce original credentials across an unauthorized origin.

**Tests:** adapt the upstream challenge-browser, solver, and diagnostic tests. Add concurrent same-origin reads with different auth headers, alternate-clearance exhaustion, exactly one own-identity attempt, new-solve reset, cancellation while waiting/retrying, 429 cooldown, unsafe methods, bulk transfers, profile revocation, and cross-origin redirect/header isolation. Test accepted browser-page fallback separately from successful network retry.

## U04, U05, U19, U27 — Protocols and diagnostics

### U04: forced-protocol detection

Pass `protocolOverridden` from the resolved **user override**, not merely a site default, through `lib/core/http/client/src/providers/dio.dart` into the interceptor/handler. Record the once-per-origin diagnostic when a forced protocol remains blocked. Do not silently change the user's configured protocol. The new unsolicited error toast is gated separately; the diagnostic correction is in scope.

### U05: Rule34 site preference

In `packages/booru_clients/boorus.yaml`, add `protocol: https_1` to the Rule34 site entry, preserving fork quick-profile and endpoint/parser overrides. In `lib/core/boorus/booru/src/booru.dart`, consult site-level metadata before engine defaults.

Do **not** copy upstream's `url.contains(site.url)` matching. Reuse an existing canonical site matcher if suitable; otherwise compare parsed scheme/normalized host/effective port and any configured base-path boundary. A query string mentioning Rule34, a suffix/lookalike domain, or another Gelbooru installation must not inherit this preference. Preserve explicit user protocol precedence and existing API/CDN transport routing. Regenerate the catalog normally when its inputs change; do not hand-edit generated Dart.

**Tests:** exact Rule34 profile, trailing slash/normalized hostname, lookalike hosts, unrelated engines/sites, paths/query strings, explicit override versus detected preference, and the existing Rule34 request-coordination/favorite-action behavior. Coordinate with the existing #179 branch; do not overwrite it.

### U19: TLS error categories

In `lib/core/http/client/src/types/http_utils.dart`, narrow certificate matching and broaden handshake matching:

```dart
bool _isCertificateException(Object? error) {
  final value = error.toString().toLowerCase();
  return value.contains('certificate') || value.contains('cert_');
}

bool _isHandshakeException(Object? error) {
  final value = error.toString().toLowerCase();
  return value.contains('handshake') ||
      value.contains('ssl_error') ||
      value.contains('err_ssl_') ||
      value.contains('tlsv1_alert');
}
```

Keep certificate detection before the broader handshake branch. Preserve fork `ApiCooldownException`/`RateLimitedError`, cancellation, and authentication/server-error handling. This changes error reporting, not certificate verification or transport security.

**Tests:** adapt `test/core/http/connection_error_test.dart`; cover real certificate markers combined with TLS text, ALPN/handshake errors, generic network errors, cancellation and cooldown.

### U27: accurate adapter diagnostics

Add the actual loaded Cronet-availability value to report context in `production_boorusama_bootstrap.dart`; log resolved adapter inputs in the Dio adapter factory; log the forced-protocol diagnostic through the app logger. Remove the unconditional `backend configured androidCronet=true` message from `lib/core/downloads/background/widgets.dart`. The bootstrap/widget delta is logging only, not a download-lifecycle redesign. Do not log URLs with query credentials, headers, or private payloads.

## U02 — Sidecar rejection must not discard media

**Files:** `lib/core/downloads/background/downloader.dart`, downloader result types and notifier, English strings, and `test/downloads/sidecar/cache_download_test.dart`.

Port the `_prepareSidecar` separation: a destination-related `FileSystemException` during sidecar preparation may produce no sidecar store and allow the media operation to proceed. Keep sidecar preparation outside the media-success decision. Do not catch JSON/programming errors as destination restrictions, and do not describe every filesystem error as a permissions problem. Preserve cleanup of any partially prepared sidecar state.

Only attach `sidecarId` and the finished callback when preparation succeeded. Add `metadataSkipped` (default false) to `DownloadTaskInfo`, equality, and the `withMetadataSkipped` result transformation. Apply it to both `DownloadEnqueued` and `DownloadCompleted`, including cache saves. A real media write/enqueue failure remains a failure. Propagate the warning through the shared download path without adding duplicate per-file bulk notifications; preserve #171's toast-duration policy and #61's notification scope.

Do not overwrite fork rendition-qualified filenames, source authorization checks, URL resolution, content revocation, or immediate activity reporting in `download_notifier.dart`.

**Tests:** sidecar accepted/rejected; media success/failure independently; cache save; no orphan callback/sidecar ID; canceled preparation; no false success when storage is full or media cannot be written; one appropriate warning; bulk notification behavior unchanged.

## U13 — Duplicate download admission

Create/adapt `pending_downloads.dart` and `pending_downloads_provider.dart`, but do not use the upstream URL-only identity as the fork's complete key.

The admission key must distinguish the source actor/access identity, resolved media URL, resolved target directory and filename, and rendition. Two requests for the same URL in different profiles or destinations can be legitimate. Build the key after filename/media resolution and before any further asynchronous preparation or enqueue. Keep a synchronous reservation to close the double-tap race, then associate an enqueued task with that same identity before releasing preparation ownership.

Both pending and active checks must use the same scoped identity. Reuse existing task metadata where it proves that identity; when an old task lacks enough information, do not suppress a different download using only its URL. Never persist or log credentials as a key. Any added optional metadata field must remain backward-compatible with restored jobs.

Use `try/finally` for failed/canceled preparations; retain active ownership until the task reaches a terminal state. Provider disposal and duplicate callbacks must not leak claims. Repeat calls should not emit duplicate observer/activity events. Recheck `isCurrent`/access guards after awaits and before enqueue; deduplication is not authorization.

The upstream delayed one-second queued toast in `download_activity/scope.dart` is a separate UX decision. Do not include it by accident while porting the race fix.

**Tests:** simultaneous same-key requests admit once; same URL/different actor, target or rendition remain independent; waiting and active tasks; failure then retry; cancellation/revocation; cached completion; terminal-event cleanup and disposal; legacy task metadata; no accidental cross-profile suppression.

## U12 and D01–D04 — Wi-Fi/VPN and the downloader dependency

The fork uses `fd67fff9...`; the target uses `76d516e0...`. The latter includes a Windows WinHTTP backend and its callback-lifetime crash fix, not only the Android VPN change. Inspect the four commits listed in the inventory before touching `pubspec_overrides.yaml`.

The required Android change is precisely:

```kotlin
NetworkRequest.Builder()
    .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
    .removeCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
    .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
    .build()
```

Keep the Wi-Fi transport requirement; do not implement the fix by allowing mobile data. The fork's `resolveDownloadNetworkConstraint` should continue selecting the existing policy; the relevant upstream defect is in the native network request.

**Two explicit integration paths:**

- If the Windows backend change is approved, pin `background_downloader` to the complete `76d516e098a7c91462bdede1c726be81a7f1a4ab` revision and regenerate the lockfile with FVM. Include D03: WinHTTP must not be introduced without closing all cached clients and draining native callbacks before task-isolate exit.
- Otherwise backport only D04 onto the currently pinned revision in an authorized dependency fork. Do not invent a commit SHA, patch the global pub cache, create another repository without authorization, or silently change Windows transport. The Kotlin change is specified; publication/pin selection remains gated until an authorized dependency location or the full update is chosen.

Preserve the fork's `go_router` path override and unrelated dependency pins. The package version alone is insufficient evidence because these revisions report the same package version.

**Tests:** Android Wi-Fi, Wi-Fi plus VPN, mobile plus VPN, network loss/transition and cancellation; Wi-Fi-only jobs must not run over cellular. If D01 is selected, run native Windows downloads, protected responses, concurrent pause/cancel, proxy behavior, and certificate/mTLS fallback. Check the native callback-drain assumption against the resolved `win_http` version; ordinary Dart tests cannot prove absence of native VM termination. Do not remove the drain delay without an actual completion mechanism.

## U08, U23, U24 — App-lock reliability without fail-open recovery

**Files:** `lib/foundation/applock/src/{app_lock,app_lock_session,biometrics,device_authenticator,local_auth_device_authenticator}.dart`, app-lock scope, fakes, and associated tests.

U08: move authentication-in-progress and pending-prompt state into `AppLockSession`. Consume one pending biometric prompt after the frame, verify mounted/current lock state after awaits, and distinguish backgrounding caused by the system authentication prompt from actual app backgrounding. Returning from that prompt must not immediately request authentication again. Recheck device support on real resume.

U23: use the upstream device-authentication support contract rather than OR-ing hardware `canCheckBiometrics` with device support. Remove obsolete interface/getter/fake requirements together. Treat exceptions as unavailable authentication, not as successful unlock. Verify enrollment behavior on the supported OS rather than inferring it from a fake.

U24 must be split. Port error feedback, retry, and support revalidation. **Do not port the unauthenticated `onDisable` path.** Upstream reaches `_UnverifiableLock` on provider errors as well as an unavailable authenticator, and can route failed/missing PIN reads to that surface. That is a security-policy change, not an automatically safe recovery fix.

For the fork, retain locked state on transient credential/device errors. A retry of a failed PIN read must actually create a new `repository.hasPin()` future; the upstream `late final` future cannot provide that retry by itself. Allow only an already authorized and successfully verified alternative authenticator. No credential deletion, settings change to `none`, or privacy-cover removal follows merely from a failed check. Keep retry/error surfaces in existing Kurumi style and localize necessary text in English.

**Tests:** cold start/resume, PIN versus biometric mode, one automatic prompt, canceled/failed auth, auth-caused lifecycle events, disposal during an await, no enrolled lock, temporary device/plugin error, PIN storage error and retry, missing PIN with/without a valid alternative. Assert explicitly that no error/unavailable result disables the lock or clears credentials. Adapt `test/app_lock/session_test.dart`, `test/application/app_lock_flow_test.dart`, and platform fakes; do not copy an upstream expectation that approves fail-open behavior.

## U22 — Restore settings while retaining the local lock

`SettingsBackupSource` currently calls queued `replaceSettings`. The fork's `SettingsNotifier.updateWith` evaluates its selector inside the serialized mutation operation. Use that existing mechanism, not upstream's removed `updateSettings` method or an early snapshot of `settingsProvider`:

```dart
executor: (incoming, _) async {
  final saved = await ref
      .read(settingsNotifierProvider.notifier)
      .updateWith(
        (current) => incoming.copyWith(
          appLockType: current.appLockType,
          appLockTimeoutSeconds: current.appLockTimeoutSeconds,
        ),
      );
  if (!saved) {
    throw StateError('Restored settings could not be saved');
  }
},
```

This preserves the lock values at the moment the queued restore executes, including a lock change queued before it. Do not import, erase, or regenerate local PIN credentials as part of settings restoration. Retain other fork settings replacement semantics. Keep save failure visible to the existing import failure handling instead of reporting successful restoration.

**Tests:** extend `test/application/backup_restore_flow_test.dart`: enabled/disabled/PIN/device locks in both incoming and local settings, retained timeout and credentials, unrelated settings restored, a preceding queued lock change, failed persistence, and repository state after failure. Use completion barriers, not sleeps.

## U03 — Android directory repair

In `lib/foundation/plugin_app_file_picker.dart`, add the pure `repairPickedDirectory` helper and normalize directory results only for the applicable Android path cases. Port the patterns for `/storage/raw/...` and `/storage/emulated/<user>/downloads`; preserve an existing legitimate lowercase directory, otherwise use the Android `Download` spelling. Keep cancellation/null and unrelated paths unchanged.

Do not turn `content://`/SAF identifiers into guessed filesystem paths or imply that normalization grants persistent permissions. Avoid introducing synchronous filesystem work in unrelated flows; retain an injectable existence probe for helper tests. Coordinate with `bug/172-backup-folder-recovery`: path repair does not replace its missing-folder/permission recovery work.

**Tests:** adapt `test/foundation/picked_directory_test.dart`; cover raw paths, multiple users, existing lowercase folders, normal paths, null/cancel, non-Android inputs and SAF values. Device acceptance is limited to the Downloads shortcut and actual access to the selected folder.

## U09 and U14 — Bookmark downloads and shuffle

### U09: keep the stronger existing download behavior

The fork's `bookmark_provider.dart::downloadBookmarks` already resolves the originating profile, uses `source.auth`/`source.download`, observes access state, and rejects missing/anonymous origins instead of borrowing credentials from a compatible profile. Keep it. Upstream's first-matching-profile/current-profile fallback is not an appropriate replacement.

**Verification:** mixed-origin selections use their own folders and extractors; removed/replaced source accounts cannot be borrowed; revoked/anonymous actors enqueue nothing; snapshot and native payload paths retain quality and filename behavior. This is verification work, not a new implementation claim. Reconcile existing #62 coverage before adding redundant tests.

### U14: stable random order

In `bookmark_shuffle_provider.dart`, replace list-position-dependent `Random(seed).shuffle` with ranking by a stable item key and the current seed. Require a namespaced key at every call site, including `bookmark_group_selectors.dart` and mixed post/pool/native-group selectors. Preserve the fork's monotonically increasing explicit-shuffle seed.

Use a deterministic tie-break; upstream's hash-only comparison does not guarantee relative order for collisions. A proposed implementation shape is:

```dart
List<T> applyShuffleToList<T>(
  List<T> items, {
  required String Function(T) key,
}) {
  final currentSeed = seed;
  if (currentSeed == null) return items;
  final rows = [
    for (final item in items) (item: item, key: key(item)),
  ];
  rows.sort((a, b) {
    final rank = Object.hash(currentSeed, a.key)
        .compareTo(Object.hash(currentSeed, b.key));
    return rank != 0 ? rank : a.key.compareTo(b.key);
  });
  return [for (final row in rows) row.item];
}
```

Keys identify the logical stored item, not its current index, mutable tags, or updated timestamp. `Object.hash` provides session-local ordering, not a promised cross-process persistent permutation. Do not create a fresh fallback seed on every selector rebuild; create/retain it at the appropriate session/provider boundary. Preserve the existing bounded group-preview sampling rather than replacing it with a full-library sort.

**Tests:** addition/removal/filtering preserves the relative order of surviving items, explicit shuffle changes the seed, repeated rebuilds stay stable, equal-rank tie-breaks, mixed types with overlapping numeric IDs, group/subtree selectors, and unchanged efficient cover sampling. Adapt the upstream bookmark shuffle/library tests to fork models.

## U10 — Moebooru tag-map processing

In `lib/boorus/moebooru/tag_summary/{types,repo}.dart`, add `getTagSummaryData()` returning the cached/fetched DTO and keep `getTagSummaries()` as a compatible wrapper for existing consumers. In `tags/providers.dart`, move DTO parsing and map construction to a pure top-level helper executed with `Isolate.run` on native platforms and directly on web. Transfer only sendable DTO data; do not capture `Ref`, clients, or repositories in the isolate closure. Remove the redundant sort only from the map-building path, not from UI consumers requiring ordered lists.

**Tests:** equivalent categories/tags for cached and remote DTOs, empty/malformed optional data, large fixtures, web/native helper equivalence, provider disposal and failure propagation. Use deterministic operation/completion checks, not fragile elapsed-time assertions.

## U11 — Layout-sized preview decoding

Add opt-in `decodeAtLayoutSize` to the fork's `BooruImage`/internal image path and a pure layout-to-decode-dimension helper. Set one limiting decode dimension in physical pixels according to image aspect ratio and `BoxFit`; constrain only for finite, positive layout/device-pixel-ratio inputs. Define the unknown-image-size fallback explicitly and test it. Do not accidentally downsample the full viewer or originals used by download/share.

The fork has additional URL fallback recursion, content-access checks, cached bytes/access keys, and placeholder/aspect-ratio behavior. Pass the option through every recursive/fallback path, and preserve access-scoped image identity. Check memory/provider cache keys so a decoded thumbnail cannot substitute for the full-size viewer image. Preserve source bytes in the disk cache.

Enable it only at the upstream preview call sites: `_internal/preview_post_grid.dart`, `related_posts_section.dart`, and `sliver_details_post_list.dart`, adapted to current fork code. Coordinate with #163 thumbnail-aspect work and #160 prefetch work; do not replace those implementations.

**Tests:** adapt `test/core/images/layout_decode_size_test.dart`; portrait/landscape, cover/contain, fractional DPR, invalid/unbounded constraints, unknown dimensions, cached-memory and network paths, fallback recursion, authorization revocation, placeholder aspect ratio, and a preview-to-full-viewer transition without reduced image quality.

## U15–U18, U20–U21, U29–U30 — Explicit exclusions and contract checks

- U15 release asset naming and U20 release-branch preparation are not silently imported. `.agents/skills/prepare-release/SKILL.md` explicitly excludes the legacy CLI/release services because they do not implement the fork's release workflow. Do not execute even their plan mode. Their existing tests remain allowed as part of the full suite; excluded runtime automation is not re-enabled.
- U21/U30 upstream version/build replacements must not overwrite the fork identity or lower its build number. U18/U29 repeat older feature notes and add no runtime feature. A later authorized release must derive its upstream-base version and build number from the final integrated candidate/history; this audit does not perform that release.
- U16 is an optional translation-content refresh, not a prerequisite for these stability fixes. Preserve existing locales and fork strings; author required new application strings only in `en-US.json`, then use normal generation.
- U17 repairs `settings.privacy.app_lock.timeout_seconds`, `try_again_in`, and `booru.using_status` introduced/changed by U16. Those keys are absent in the fork's Russian resource, which uses the English fallback; do not create a false bug or import hundreds of translations to repair it. Add/retain placeholder-contract and fallback checks. If U16 is later accepted, import its corrected final state together with U17, never the intermediate invalid strings.

## Decisions deliberately not made

| Gate | Separate decision | Safe work that proceeds without it |
|---|---|---|
| G1 | Disable a lock without successful authentication when credentials/device verification are unavailable | Lifecycle, support detection, error reporting, retry, and restore safety |
| G2 | New delayed queued-download toast and unsolicited forced-protocol toast | Duplicate admission and accurate protocol diagnostics |
| G3 | Adopt the additional Windows WinHTTP backend carried by the full dependency update, or choose an authorized location for an Android-only backport | The exact Wi-Fi/VPN patch, dependency audit, and test specification |

Optional translation refresh and release naming policy remain outside this fix-only scope rather than being smuggled into an implementation commit. Do not treat a gate as a reason to abandon unrelated fixes.

## Verification and delivery contract

During implementation, run directly related tests with FVM and preserve evidence per commit. New package fixtures need the complete affected package suite and meaningful application consumers. Use `fvm dart format`, analyze affected scope, and run normal generation only when changed inputs require it. Before any later authorized integration, run the complete application, package/CLI, and repository-tooling suite described in `docs/engineering_guidelines.md` on the exact final candidate; targeted tests alone do not establish integration readiness.

Prefer pure/unit/widget/application tests for parsing, cursor progress, coalescing, retry budgets, locks, settings transactions, and layout math. Use controlled clocks/completers. Use an emulator only for necessary Android OS integration, after following the exclusive lease procedure; Windows-native callback lifetime requires Windows. State unperformed platform checks explicitly.

For every implemented topic, update the existing #186 checklist with the implementation commit and verification evidence independently. Leave unsupported/not-run claims open. Compare the finished changes against the inventory so shared files and tests are not lost. Record new findings in #186, not a second tracker.

Commit and push owned changes on this task branch. Do not merge, open a PR, close #186, modify other task branches, change release versions, invoke release automation, or implement G1–G3 without the corresponding decision.
