# Pixiv Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port JakeDev's completed Pixiv App API, authentication, post pipeline, and multi-feed Explore experience to Boorusama Timber.

**Architecture:** Treat `jakedev/master` at `c663270d9` as the behavioral reference, but add only Pixiv-owned files and narrow integration hunks to the current Timber baseline. Keep the reusable HTTP client in `packages/booru_clients`; connect it to the app through the existing booru builder, repository, provider, configuration, routing, listing, and details abstractions.

**Tech Stack:** Flutter 3.47.2, Dart 3.12, Riverpod, Dio, GoRouter, WebView Flutter, PKCE/OAuth, package:test, flutter_test, project booru/i18n generators.

**Spec:** `docs/superpowers/specs/2026-09-12-pixiv-integration-design.md`

## Global Constraints

- Work only on `feature/pixiv`, based on the current `develop` baseline.
- JakeDev commits `c2694e0c1` through `c663270d9` define final Pixiv behavior.
- Do not import Pawchive, Plus unlock, JakeDev release/version changes, or JakeDev documentation.
- Preserve application version `4.5.0-timberpile.1+185` and all Timber identity changes.
- Preserve newer upstream app-lock, download-network, native-asset, and libavif changes in shared files.
- Register Pixiv with stable booru ID `37`; leave ID `36` unused for compatibility.
- Preserve the reference credential-storage behavior and its explicit unencrypted-refresh-token warning.
- Use FVM for every Flutter and Dart command.
- Use `apply_patch` for deliberate source edits; inspect every reference file before reproducing it.
- Commit only after the task-specific tests pass.

---

### Task 1: Pixiv App API Client and DTOs

**Files:**

- Create: `packages/booru_clients/lib/pixiv.dart`
- Create: `packages/booru_clients/lib/src/pixiv/pixiv_auth_client.dart`
- Create: `packages/booru_clients/lib/src/pixiv/pixiv_client.dart`
- Create: `packages/booru_clients/lib/src/pixiv/pixiv_constants.dart`
- Create: `packages/booru_clients/lib/src/pixiv/pixiv_headers.dart`
- Create: `packages/booru_clients/lib/src/pixiv/types/pixiv_enums.dart`
- Create: `packages/booru_clients/lib/src/pixiv/types/pixiv_exceptions.dart`
- Create: `packages/booru_clients/lib/src/pixiv/types/pixiv_illust_dto.dart`
- Create: `packages/booru_clients/lib/src/pixiv/types/pixiv_illust_list_result.dart`
- Create: `packages/booru_clients/lib/src/pixiv/types/pixiv_illust_user_dto.dart`
- Create: `packages/booru_clients/lib/src/pixiv/types/pixiv_image_urls_dto.dart`
- Create: `packages/booru_clients/lib/src/pixiv/types/pixiv_series_dto.dart`
- Create: `packages/booru_clients/lib/src/pixiv/types/pixiv_tag_dto.dart`
- Create: `packages/booru_clients/lib/src/pixiv/types/pixiv_token_dto.dart`
- Create: `packages/booru_clients/lib/src/pixiv/types/pixiv_ugoira_metadata_dto.dart`
- Create: `packages/booru_clients/lib/src/pixiv/types/pixiv_user_detail_dto.dart`
- Create: `packages/booru_clients/lib/src/pixiv/types/types.dart`
- Create: `packages/booru_clients/test/pixiv/mock_pixiv_server.dart`
- Create: `packages/booru_clients/test/pixiv/pixiv_auth_client_test.dart`
- Create: `packages/booru_clients/test/pixiv/pixiv_client_test.dart`
- Create: `packages/booru_clients/test/pixiv/pixiv_dio_exception_test.dart`
- Create: `packages/booru_clients/test/pixiv/pixiv_illust_dto_test.dart`
- Create: `packages/booru_clients/test/pixiv/pixiv_token_dto_test.dart`

**Interfaces:**

- Produces: `PixivAuthClient.exchangeCode`, `PixivAuthClient.refresh`, and the final `PixivClient` search/detail/ranking/following/recommended/user/ugoira methods from `jakedev/master`.
- Produces: nullable-safe Pixiv DTO factories and `PixivIllustListResult` pagination data consumed by the app repository in Task 2.
- Consumes: existing Dio and crypto dependencies already declared in the workspace.

- [ ] **Step 1: Add the final reference client tests without implementation**

Reproduce the six test files exactly from `jakedev/master`, not from the earlier `c2694e0c1` snapshot. The final `pixiv_client_test.dart` must include Ranking, Following, Recommended, pagination, and malformed-response cases.

Reference inspection commands:

```bash
git show jakedev/master:packages/booru_clients/test/pixiv/pixiv_client_test.dart
git diff c2694e0c1..jakedev/master -- packages/booru_clients/test/pixiv
```

- [ ] **Step 2: Verify the tests fail because the Pixiv library is absent**

Run:

```bash
cd packages/booru_clients
fvm dart test test/pixiv
```

Expected: failure resolving `package:booru_clients/pixiv.dart` and Pixiv API types.

- [ ] **Step 3: Add the final client and DTO implementation**

Reproduce every listed client file from `jakedev/master`. Preserve these exact public concepts:

```dart
enum PixivFollowRestrict { all, public, private }

class PixivClient {
  Future<PixivIllustListResult> getRanking({
    required PixivRankingMode mode,
    DateTime? date,
    int page = 1,
  });
  Future<PixivIllustListResult> getFollowedIllusts({
    PixivFollowRestrict restrict = PixivFollowRestrict.all,
    required int page,
  });
  Future<PixivIllustListResult> getRecommendedIllusts({required int page});
  Future<PixivIllustListResult> searchIllust({
    required String word,
    PixivSearchTarget searchTarget = PixivSearchTarget.partialMatchForTags,
    PixivSearchSort sort = PixivSearchSort.dateDesc,
    DateTime? startDate,
    DateTime? endDate,
    int page = 1,
  });
  Future<PixivIllustDto?> getIllustDetail({required int illustId});
}

class PixivAuthClient {
  Future<PixivTokens> exchangeCode({
    required String code,
    required String codeVerifier,
  });
  Future<PixivTokens> refresh({required String refreshToken});
}
```

Use the reference's endpoint constants, OAuth headers, MD5 request-time hash,
nullable JSON conversion, `next_url` offset parsing, and Dio exception mapping.
Do not copy any non-Pixiv package changes from JakeDev.

- [ ] **Step 4: Format and run the focused client tests**

Run:

```bash
fvm dart format packages/booru_clients/lib/pixiv.dart packages/booru_clients/lib/src/pixiv packages/booru_clients/test/pixiv
cd packages/booru_clients
fvm dart test test/pixiv
```

Expected: all Pixiv package tests pass.

- [ ] **Step 5: Run the complete booru client suite**

Run:

```bash
cd packages/booru_clients
fvm dart test
```

Expected: all tests pass.

- [ ] **Step 6: Commit the client layer**

```bash
git add packages/booru_clients/lib/pixiv.dart packages/booru_clients/lib/src/pixiv packages/booru_clients/test/pixiv
git commit -m "feat(pixiv): add app API client"
```

---

### Task 2: Pixiv Engine, Post Pipeline, and OAuth Configuration

**Files:**

- Modify: `packages/booru_clients/boorus.yaml`
- Modify: `packages/i18n/translations/en-US.json`
- Modify generated: `lib/boorus/registry.g.dart`
- Create: `lib/boorus/pixiv/pixiv.dart`
- Create: `lib/boorus/pixiv/pixiv_builder.dart`
- Create: `lib/boorus/pixiv/pixiv_repository.dart`
- Create: `lib/boorus/pixiv/client_provider.dart`
- Create: `lib/boorus/pixiv/auth/auth_interceptor.dart`
- Create: `lib/boorus/pixiv/auth/login_page.dart`
- Create: `lib/boorus/pixiv/auth/pkce.dart`
- Create: `lib/boorus/pixiv/auth/session_expired_dialog.dart`
- Create: `lib/boorus/pixiv/configs/extra_data.dart`
- Create: `lib/boorus/pixiv/configs/widgets.dart`
- Create: `lib/boorus/pixiv/posts/link_generator.dart`
- Create: `lib/boorus/pixiv/posts/parser.dart`
- Create: `lib/boorus/pixiv/posts/providers.dart`
- Create: `lib/boorus/pixiv/posts/query.dart`
- Create: `lib/boorus/pixiv/posts/types.dart`
- Create: `lib/boorus/pixiv/tags/providers.dart`
- Create: `test/booru_site_url_test.dart`
- Create: `test/pixiv_auth_test.dart`
- Create: `test/pixiv_test.dart`

**Interfaces:**

- Consumes: Task 1's `PixivClient`, `PixivAuthClient`, DTOs, enums, and exceptions.
- Produces: `createPixiv`, `PixivBuilder`, `PixivRepository`, Pixiv auth/config providers, `PixivPost`, Pixiv query conversion, and tag extraction.
- Produces: booru registry entry `BooruType.pixiv` backed by ID `37` and site `https://pixiv.net/`.

- [ ] **Step 1: Add the final engine and authentication tests**

Reproduce `test/pixiv_test.dart`, `test/pixiv_auth_test.dart`, and
`test/booru_site_url_test.dart` from `jakedev/master`. In the site test retain
only the generally applicable existing cases plus Pixiv; do not introduce a
Pawchive expectation.

The tests must cover:

```text
Pixiv URL registration
illust-to-post parsing, including multi-page works and large detail media
query and pagination behavior
PKCE generation
OAuth redirect parsing
serialized refresh and rotated-token persistence
malformed stored metadata fallback
session-expiry behavior
```

- [ ] **Step 2: Verify the root tests fail before app integration exists**

Run:

```bash
fvm flutter test test/booru_site_url_test.dart test/pixiv_test.dart test/pixiv_auth_test.dart
```

Expected: failures for missing Pixiv app modules and missing `BooruType.pixiv`.

- [ ] **Step 3: Register Pixiv without importing Pawchive**

Append this entry to `packages/booru_clients/boorus.yaml`:

```yaml
- pixiv:
    metadata:
      id: 37
      display-name: Pixiv
      single-site: true
    protocol: https_2
    sites:
      - https://pixiv.net/
```

Run the booru generator:

```bash
./gen.sh booru
```

Verify `lib/boorus/registry.g.dart` imports `pixiv/pixiv.dart` and maps
`BooruType.pixiv` to `createPixiv`. Confirm there is no Pawchive import or
registry entry.

- [ ] **Step 4: Add the engine and final post parser**

Reproduce the engine, repository, post, query, tag, and link-generator files
from JakeDev. Use `6df4abb87` as the pre-Explore builder shape, but use
`jakedev/master` for `posts/parser.dart` so post details select the large image
variant and multi-page works retain all page media.

The engine entry point remains:

```dart
BooruBuilder createPixiv(Ref ref) => BooruBuilder(
  config: BooruYamlConfigs.pixiv,
  builder: PixivBuilder(),
  repository: PixivRepository(ref),
);
```

- [ ] **Step 5: Add OAuth PKCE and configuration behavior**

Reproduce the auth and configuration files from `jakedev/master`, including
the later `xRestrict` metadata additions. Keep the reference data split:

```dart
apiKey: refreshToken
passHash: PixivExtraData(
  userId: user.id,
  userName: user.name,
  isPremium: user.isPremium,
  xRestrict: user.xRestrict,
  tokenExpiry: expiry,
).toPassHash()
```

Use a shared in-flight refresh future in the interceptor. Persist rotated
refresh tokens through the current config repository, retry the original
request once, and route terminal refresh failure to the authentication tab.

- [ ] **Step 6: Merge only the Pixiv authentication strings**

Add `pixiv.auth` to the current English translation document while preserving
all current app-lock and download-network strings. The required keys are:

```text
login_title, login_failed, try_again, webview_unsupported,
refresh_token_label, paste_token_hint, premium_account,
credential_export_warning
```

Run:

```bash
./gen.sh i18n
```

- [ ] **Step 7: Format and run the engine/authentication tests**

Run:

```bash
fvm dart format lib/boorus/pixiv test/booru_site_url_test.dart test/pixiv_auth_test.dart test/pixiv_test.dart
fvm flutter test test/booru_site_url_test.dart test/pixiv_test.dart test/pixiv_auth_test.dart
```

Expected: all three test files pass.

- [ ] **Step 8: Commit app integration and authentication**

```bash
git add packages/booru_clients/boorus.yaml packages/i18n/translations/en-US.json lib/boorus/registry.g.dart lib/boorus/pixiv test/booru_site_url_test.dart test/pixiv_auth_test.dart test/pixiv_test.dart packages/i18n/lib/src/gen
git commit -m "feat(pixiv): integrate OAuth and post pipeline"
```

---

### Task 3: Final Multi-feed Explore and Navigation

**Files:**

- Modify: `lib/boorus/pixiv/client_provider.dart`
- Modify: `lib/boorus/pixiv/configs/extra_data.dart`
- Modify: `lib/boorus/pixiv/configs/widgets.dart`
- Modify: `lib/boorus/pixiv/pixiv_builder.dart`
- Modify: `lib/core/router.dart`
- Modify: `packages/i18n/translations/en-US.json`
- Create: `lib/boorus/pixiv/explore/feed.dart`
- Create: `lib/boorus/pixiv/explore/providers.dart`
- Create: `lib/boorus/pixiv/explore/widgets.dart`
- Create: `lib/boorus/pixiv/home/custom_home.dart`
- Create: `lib/boorus/pixiv/home/pixiv_home_page.dart`
- Create: `lib/boorus/pixiv/router.dart`
- Create: `test/pixiv_explore_test.dart`

**Interfaces:**

- Consumes: Task 1 feed methods and Task 2's authenticated client/config metadata.
- Produces: sealed `PixivExploreFeed` variants, `PixivExploreRepository`, feed providers, final Explore UI, Pixiv home navigation, and `/pixiv/explore` routing.

- [ ] **Step 1: Add the final Explore tests before implementation**

Reproduce `test/pixiv_explore_test.dart` from `jakedev/master`. It must test:

```text
JST-yesterday calculation
ranking date clamp from 2007-09-13 through JST-yesterday
date omission for the newest snapshot
ranking mode to time-scale mapping
feed-kind transitions and parameter isolation
R-18 warning rules
Ranking, Following, and Recommended endpoint dispatch
pagination and refresh behavior
```

- [ ] **Step 2: Verify Explore tests fail**

Run:

```bash
fvm flutter test test/pixiv_explore_test.dart
```

Expected: failure resolving `lib/boorus/pixiv/explore` types and providers.

- [ ] **Step 3: Add final typed feeds and providers**

Reproduce `explore/feed.dart` and `explore/providers.dart` from
`jakedev/master`. Retain the sealed variants:

```dart
sealed class PixivExploreFeed extends Equatable {}
final class PixivRankingFeed extends PixivExploreFeed {}
final class PixivFollowingFeed extends PixivExploreFeed {}
final class PixivRecommendedFeed extends PixivExploreFeed {}
```

Ranking defaults to Daily at `pixivRankingNewestDate()`. Clamp dates to
`DateTime.utc(2007, 9, 13)` through yesterday on the JST calendar. Dispatch
each feed to its matching Task 1 client method.

- [ ] **Step 4: Add the final floating-header Explore UI**

Reproduce `explore/widgets.dart` from `jakedev/master` at `c663270d9`, not the
earlier ranking page or the intermediate `bd2e056b9` layout. The header floats
over the paginated grid and displays only controls meaningful to the selected
feed. Preserve the R-18 account-setting warning.

- [ ] **Step 5: Wire Pixiv home and routes narrowly**

Add the final `home/custom_home.dart`, `home/pixiv_home_page.dart`, and
`router.dart`. Update `PixivBuilder` to expose the final Pixiv home and custom
home builders. In `lib/core/router.dart`, add only:

```dart
import '../boorus/pixiv/router.dart';
...
...pixivRoutes,
```

Do not add JakeDev's Pawchive router.

- [ ] **Step 6: Add final Explore translations and regenerate**

Merge `pixiv.explore` from JakeDev into the current English translations. It
must include the title, content-restriction warning, three feed labels, three
follow restrictions, and all final ranking-mode labels. Preserve every newer
upstream and Timber key.

Run:

```bash
./gen.sh i18n
```

- [ ] **Step 7: Format and run focused Pixiv tests**

Run:

```bash
fvm dart format lib/boorus/pixiv lib/core/router.dart test/pixiv_explore_test.dart
fvm flutter test test/booru_site_url_test.dart test/pixiv_auth_test.dart test/pixiv_test.dart test/pixiv_explore_test.dart
```

Expected: all Pixiv integration tests pass.

- [ ] **Step 8: Commit final Explore behavior**

```bash
git add lib/boorus/pixiv lib/core/router.dart packages/i18n/translations/en-US.json packages/i18n/lib/src/gen test/pixiv_explore_test.dart
git commit -m "feat(pixiv): add multi-feed explore"
```

---

### Task 4: Full Regression and Scope Verification

**Files:**

- Verify only; modify implementation files only for failures attributable to the Pixiv port.

**Interfaces:**

- Consumes: all prior tasks.
- Produces: a verified Pixiv feature branch that remains cleanly scoped to the design.

- [ ] **Step 1: Bootstrap and regenerate from a clean dependency state**

Run:

```bash
./init.sh
./gen.sh
git diff --check
```

Expected: bootstrap and generation succeed; no malformed diff appears.

- [ ] **Step 2: Run static analysis**

Run:

```bash
fvm flutter analyze
```

Expected: no issues.

- [ ] **Step 3: Run the root test suite**

Run:

```bash
fvm flutter test
```

Expected: all tests pass.

- [ ] **Step 4: Run every affected workspace-package suite**

Run:

```bash
cd packages/booru_clients && fvm dart test
cd ../i18n && fvm dart test
cd ../i18n_cli && fvm dart test
cd ../coreutils && fvm dart test
```

Expected: all suites pass. If a package has no `test` directory, record that
fact rather than treating it as a failure.

- [ ] **Step 5: Audit branch scope and identity preservation**

Run:

```bash
git diff --name-status develop...HEAD
git diff develop...HEAD -- pubspec.yaml .github android ios macos linux windows web
rg -n "pawchive|com\.degenk\.boorusama|version: 4\.8" lib/boorus/pixiv packages/booru_clients/boorus.yaml pubspec.yaml
```

Expected:

```text
No Pawchive source or route was added.
pubspec.yaml remains 4.5.0-timberpile.1+185.
No platform identity or release workflow changed.
All feature changes are Pixiv, booru registry, router, translation, tests, or design/plan documentation.
```

- [ ] **Step 6: Confirm the final commit structure and clean tree**

Run:

```bash
git log --oneline develop..HEAD
git status --short
```

Expected: the design and plan commits plus three logical implementation
commits; working tree clean.
