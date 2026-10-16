# Boorusama — Detailed Decision Catalog for the Real Upstream v4.6.1 Merge

**As of:** October 16, 2026 · **Status:** **68/68 decisions approved, 0 open.** Local implementation was commissioned on 2026-10-16 but has not yet been integrated. Separate authorization is required before changes to `develop`, remote pushes, PRs or releases.

> **Pinned comparison:** `timberpile/Boorusama` `develop` at `d4e15586f06192f0ff4315d36a3f61ae69a752d5`; upstream `v4.6.1` peeled at `5b04bf6a164f028d41701299367d0dde74dde330`; merge base `2c0ac699184854d363833ea4a3205aef0895a92b`. The original analysis inspected a supplied Git bundle. No runtime changes were made during that review.

## Comparison Scope

- **150 upstream commits** since the shared ancestor. Some extend or revert older changes; not every commit introduces a new feature.
- Approximately **891 paths changed in upstream** versus the ancestor; a straightforward test merge exposed **106 actual Git conflict paths**. A conflict-free Git merge does **not** guarantee semantic compatibility.
- The fork already incorporated certain upstream 4.6-era ideas before the divergence: PIN/app lock, Wi-Fi downloads, initial favorite-tag redesign, Kurumi and AVIF. Do not count these as new implementation work.
- Protect fork-only architecture: profile UUIDs, bookmark groups/snapshots, Following/Pinned Searches, custom Search/Settings, shared cache, export/import and signing.
- **IDs are stable.** [The authoritative decision log](decisions.md) contains every user's approved final requirement and full test contract. Earlier historical questions or proposals in this catalog do not supersede that log.

## Resolution Policy

For each item either **adopt completely**, **adapt upstream for the fork**, **retain the fork implementation**, or **omit the reverted/unneeded change**. Specify target behavior, data migration, dependencies and regression checks. A successful Git auto-merge alone is **never** evidence that user-visible behavior is correct.

## Topic Summary

| Area | Items | Originally nontrivial decisions |
| --- | ---: | ---: |
| Architecture, privacy, platforms and tooling | 18 | 16 |
| Networking and Cloudflare | 6 | 6 |
| Downloads, backups and export | 8 | 8 |
| Booru-specific changes | 10 | 10 |
| Posts, grid, viewer and media | 14 | 14 |
| Search, interaction, desktop and TV | 8 | 7 |
| Cross-cutting fork architecture safeguards | 4 | 4 |

**Total:** 68 review items (65 originally assessed as substantive and 3 originally treated as routine/obsolete/test maintenance). All **150** upstream commits map to at least one item.

## Dependency-Oriented Review Sequence

1. **Data and bootstrap integrity:** X01/X02, A01, X03/X04 and A15. A merged build is not safe without these.
2. **Active features/UX:** P01/P12/P13, A04, U01–U03, D01 and N02; then site features.
3. **Stability and platforms:** N03–N05, D02, B04, P08, A10 and U04–U06.
4. **Routine maintenance:** lower-risk bug fixes, i18n, CI, tests and docs.

## Detailed Items

Each catalog entry retains the historical upstream change, fork divergence, review question, original commit references and affected/conflicting paths. **Its approved target behavior, migration safeguards, dependencies and full test cases are in the linked English [decision log](decisions.md)**; do not use old questions to reinterpret an approved decision.

## Architecture, Privacy, Platforms and Tooling

### A01 · Application Bootstrap, Runtime and Dependency Injection

**Status:** **APPROVED** (2026-10-15; implementation pending). **Risk:** Critical.

- **Approved resolution (summary):** Use upstream's single bootstrap/runtime and integrate all fork services, recovery gates, profile UUIDs, Following, cache, sharing and native integration without a second startup path.
- **Upstream change:** New BoorusamaBootstrapHost/ProductionBoorusamaBootstrap, main.dart and service factory overrides improve headless testing; the refactor spans 237 files.
- **Fork divergence / merge hazard:** The fork starts through BoorusamaApp and initializes additional export, import, cache, profile and synchronization services. The earlier trial merge adopted main.dart without fully transferring that initialization.
- **Original review question:** Retain the old startup path or migrate to upstream bootstrap? Which fork providers and startup jobs must always run?
- **Binding decision, migration conditions and tests:** [A01](decisions.md#a01--application-bootstrap-runtime-and-dependency-injection). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`a3278c5d2`](https://github.com/khoadng/Boorusama/commit/a3278c5d2ecc3672fea63c68fb21c81a1db2bb07).
- **Affected code paths (examples):** `lib/main.dart`, `lib/core/boorusama_app.dart`, `lib/core/bootstrap/boorusama_bootstrap.dart`, `lib/core/app_scope.dart`.
- **Confirmed merge conflicts in:** `lib/core/boorusama_app.dart`.

### A02 · Kurumi / Material-Cupertino Package Migration

**Status:** **APPROVED** (2026-10-15; implementation pending). **Risk:** High.

- **Approved resolution (summary):** Adopt upstream UI components while retaining fork actions, long-press/selection gestures and menus; the agent writes a prioritized manual UI checklist for the user, not performs manual acceptance.
- **Upstream change:** Kurumi separates standalone Material/Cupertino components, replaces older UI dependencies and changes imports and widgets.
- **Fork divergence / merge hazard:** The fork already uses Kurumi with custom menus, dialogs, viewer and other UI elements. Both source trees pin Flutter 3.47.2 in .fvmrc.
- **Original review question:** Adopt all added Kurumi widgets and semantics globally or only where upstream features need them?
- **Binding decision, migration conditions and tests:** [A02](decisions.md#a02--kurumi--material-cupertino-package-migration). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`9f8ab7bca`](https://github.com/khoadng/Boorusama/commit/9f8ab7bcab67048be3bb865b98c47203d7b121b2), [`e7745aca8`](https://github.com/khoadng/Boorusama/commit/e7745aca83af95f38ac1d2e3f58fa23bf0b92234), [`6adb28be9`](https://github.com/khoadng/Boorusama/commit/6adb28be97b67181a1641df28d9b0c490e4e3f47).
- **Affected code paths (examples):** `packages/kurumi/lib/kurumi.dart`, `packages/kurumi/lib/material.dart`, `pubspec.yaml`.
- **Confirmed merge conflicts in:** `packages/kurumi/lib/material.dart`, `pubspec.yaml`.

### A03 · Kurumi Stability, Animation and Overflow

**Status:** **APPROVED** (2026-10-15; implementation pending). **Risk:** Medium.

- **Approved resolution (summary):** Adopt upstream focus, Escape, animation, menu, layout/overflow fixes without regressing fork interactions.
- **Upstream change:** Stabilizes widget trees, prevents truncated sidebar titles and cancels checkmark deselection animations cleanly.
- **Fork divergence / merge hazard:** The fork modifies Kurumi; even small framework bug fixes can have semantic merge conflicts.
- **Original review question:** Do the isolated fixes improve actual UI/animations without regressions?
- **Binding decision, migration conditions and tests:** [A03](decisions.md#a03--kurumi-stability-animation-and-overflow). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`0ed1a49df`](https://github.com/khoadng/Boorusama/commit/0ed1a49df6e07787e89366ca931dd2f7b3504eef), [`485a728c9`](https://github.com/khoadng/Boorusama/commit/485a728c9802680b480ee949123624d6101cb463), [`c69b3e824`](https://github.com/khoadng/Boorusama/commit/c69b3e824d4acc4d60922ce78e391594846ff2c0).
- **Affected code paths (examples):** `packages/kurumi/lib/src/components`.

### A04 · Responsive Settings Navigation Model

**Status:** **APPROVED** (2026-10-15; implementation pending). **Risk:** High.

- **Approved resolution (summary):** Integrate responsive Settings navigation/state/sidebar while preserving fork Settings Search, categories and dynamic app-toolbar title sizing.
- **Upstream change:** Introduces upstream Settings navigation state, adaptive routes and subsequent layout/Back fixes.
- **Fork divergence / merge hazard:** The fork uses its own SettingsNavigationPane, searchable Settings added on October 14 and additional settings sections.
- **Original review question:** What routing, sidebar, Back, search and deep-link model should survive?
- **Binding decision, migration conditions and tests:** [A04](decisions.md#a04--responsive-settings-navigation-model). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`1f2e90060`](https://github.com/khoadng/Boorusama/commit/1f2e90060765be4369a689522c463f740f254197), [`72c27ed64`](https://github.com/khoadng/Boorusama/commit/72c27ed64b10290bd5e1877a5fbe342572a3948d).
- **Affected code paths (examples):** `lib/core/settings/src/pages/settings_page.dart`, `lib/core/settings/src/widgets/settings_navigation_pane.dart`.
- **Confirmed merge conflicts in:** `lib/core/settings/src/pages/settings_page.dart`.

### A05 · Upstream Settings Search Added and Later Reverted

**Status:** **APPROVED** (2026-10-15; implementation pending). **Risk:** Low.

- **Approved resolution (summary):** Do not restore upstream's reverted Settings Search; keep the existing fork feature.
- **Upstream change:** Adds temporary generated Settings search indices and UI, subsequently reverted before v4.6.1.
- **Fork divergence / merge hazard:** The fork has its own active Settings Search.
- **Original review question:** No feature revival; consider isolated ideas only if explicitly requested.
- **Binding decision, migration conditions and tests:** [A05](decisions.md#a05--upstream-settings-search-added-and-later-reverted). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`408666ef5`](https://github.com/khoadng/Boorusama/commit/408666ef55f2b20f2e65d7eee21dcb01b0f018ca), [`685db1ad5`](https://github.com/khoadng/Boorusama/commit/685db1ad56712e00d4ef8dfe438114948ba6e86e).

### A06 · App Lock: Different Privacy Defaults

**Status:** **APPROVED** (2026-10-15; implementation pending). **Risk:** High.

- **Approved resolution (summary):** Use upstream defaults (Hide App Preview=false, timeout=30s), but preserve previously saved user choices.
- **Upstream change:** Defaults Hide App Preview to false and lock timeout to 30 seconds in v4.6.1.
- **Fork divergence / merge hazard:** The fork already supports PIN, blur and Wi-Fi downloads, but defaults Hide App Preview to true and lock timeout to zero.
- **Original review question:** Which defaults should apply to new installs while respecting existing settings?
- **Binding decision, migration conditions and tests:** [A06](decisions.md#a06--app-lock-different-privacy-defaults). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`c2d3b109e`](https://github.com/khoadng/Boorusama/commit/c2d3b109ef0e2124273858b17ed577e8bdaa1add).
- **Affected code paths (examples):** `lib/core/settings/src/types/settings.dart`.

### A07 · Debug Logging, Log Persistence and Redaction

**Status:** **APPROVED** (2026-10-15; implementation pending). **Risk:** High.

- **Approved resolution (summary):** Integrate upstream logs, viewer/copy/export and redaction without losing fork diagnostics or changing privacy defaults unexpectedly.
- **Upstream change:** Adds persistent diagnostic logging, an interactive log viewer, URL/status highlighting and copy support; final upstream redaction is optional and disabled by default.
- **Fork divergence / merge hazard:** The fork has an older logger and additional cache/diagnostic facilities, with bootstrap and provider conflicts.
- **Original review question:** What retention/redaction/export behavior should apply to persisted logs, particularly credentials?
- **Binding decision, migration conditions and tests:** [A07](decisions.md#a07--debug-logging-log-persistence-and-redaction). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`3bd433423`](https://github.com/khoadng/Boorusama/commit/3bd4334235a091c51e680c28ea852d3d07571a02), [`434a2e516`](https://github.com/khoadng/Boorusama/commit/434a2e516ecae2ce236d4c7592af62961e182a87), [`948af9448`](https://github.com/khoadng/Boorusama/commit/948af94483b7662d1de9a0fbfea7381019cd821a), [`d13fe53a3`](https://github.com/khoadng/Boorusama/commit/d13fe53a3b8cbbba481b4d2d436b124009941b8f).
- **Affected code paths (examples):** `lib/core/debug`, `lib/foundation/loggers`.

### A08 · Typed Cloudflare/DDoS Diagnostics

**Status:** **APPROVED** (2026-10-15; implementation pending). **Risk:** Medium.

- **Approved resolution (summary):** Integrate typed solver, challenge and error diagnostics into A07 logging while preserving Rule34 recovery.
- **Upstream change:** Adds detailed solver/challenge events, structured states, polling and diagnostic logs.
- **Fork divergence / merge hazard:** The fork already implements Rule34/Cloudflare recovery and its own diagnostics.
- **Original review question:** Which events belong in the debug screen, and what needs redaction before storage?
- **Binding decision, migration conditions and tests:** [A08](decisions.md#a08--typed-cloudflareddos-diagnostics). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`480810b11`](https://github.com/khoadng/Boorusama/commit/480810b11a5a66b24be40bc8a80a2a56e681b90c), [`0def24717`](https://github.com/khoadng/Boorusama/commit/0def247178cedd1a058c3695a09b3c159ec3577d).
- **Affected code paths (examples):** `lib/core/ddos/solver`, `lib/core/ddos/diagnostics`.

### A09 · Android Cache Locations and DocumentsProvider

**Status:** **APPROVED** (2026-10-15; implementation pending). **Risk:** Medium.

- **Approved resolution (summary):** Adopt cache-path settings and read-only DocumentsProvider for valid completed media only, adjusted to fork cache filenames, package ID and native channels.
- **Upstream change:** Shows cache directories in Settings and exposes cache content via Android Files DocumentsProvider.
- **Fork divergence / merge hazard:** The fork uses its own persistent LRU image cache and different private storage directories.
- **Original review question:** Which caches may be exposed read-only without leaking private application files?
- **Binding decision, migration conditions and tests:** [A09](decisions.md#a09--android-cache-locations-and-documentsprovider). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`1e6a6607d`](https://github.com/khoadng/Boorusama/commit/1e6a6607dc7750a5c1e94d44531f8251fface3c6).
- **Affected code paths (examples):** `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/kotlin`, `lib/core/settings/src/pages/data_and_storage_page.dart`.
- **Confirmed merge conflicts in:** `android/app/src/main/AndroidManifest.xml`, `lib/core/settings/src/pages/data_and_storage_page.dart`.

### A10 · Embedded Windows WebView and WebView Platform Support

**Status:** **APPROVED** (2026-10-15; implementation pending). **Risk:** High.

- **Approved resolution (summary):** Adopt WebView/browser factory and unsupported-platform fallbacks compatible with fork challenge/browser behavior.
- **Upstream change:** Adds Windows embedded browser and WinHTTP adapter, abstract browser factories and unsupported-WebView fallbacks.
- **Fork divergence / merge hazard:** The fork owns application service providers/bootstrapping and challenge/browser logic.
- **Original review question:** Which Windows/browser features and platform fallback behaviors are needed?
- **Binding decision, migration conditions and tests:** [A10](decisions.md#a10--embedded-windows-webview-and-webview-platform-support). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`4c6138377`](https://github.com/khoadng/Boorusama/commit/4c6138377f9d5357b986584b8aee75d0b8d5dd66), [`8d8ca771b`](https://github.com/khoadng/Boorusama/commit/8d8ca771b393d18f31e21e21881f22f142179397).
- **Affected code paths (examples):** `lib/foundation/browser`, `lib/core/http/client/src/data/winhttp_dio_adapter.dart`.

### A11 · Localization: Arabic, Indonesian and Other Updates

**Status:** **APPROVED** (2026-10-15; implementation pending). **Risk:** Low-medium.

- **Approved resolution (summary):** Import Arabic, Indonesian and other upstream localization fixes without losing fork translation keys or fallbacks; UI localization remains multilingual.
- **Upstream change:** Adds locale resources and Weblate translations, removes unused keys and preserves full locale when switching language.
- **Fork divergence / merge hazard:** The fork has distinct Following, Bookmark Group and Settings Search strings; localization trees diverged.
- **Original review question:** How should localization files be merged without losing keys or weakening fallbacks?
- **Binding decision, migration conditions and tests:** [A11](decisions.md#a11--localization-arabic-indonesian-and-other-updates). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`bdec763aa`](https://github.com/khoadng/Boorusama/commit/bdec763aa3e7d36d774b2f64b7963f79329f9bdd), [`9ba59d05b`](https://github.com/khoadng/Boorusama/commit/9ba59d05b80c07b03e7e8696ee4c4ed8d068f14b), [`d13da93a3`](https://github.com/khoadng/Boorusama/commit/d13da93a3a6e2a8d9299d5a0ef91dd00422aa303), [`a891266bb`](https://github.com/khoadng/Boorusama/commit/a891266bb668caa65f846db9ee40f9b35c840c9e), [`02a28fe7d`](https://github.com/khoadng/Boorusama/commit/02a28fe7d7e94c12a94c926442681cc8d569e2d5), [`889592e57`](https://github.com/khoadng/Boorusama/commit/889592e57f5f22962158c2d9123f1db05f836260), [`e79abb5c0`](https://github.com/khoadng/Boorusama/commit/e79abb5c093aa7e1090653f2adf1b3e68b392328).
- **Affected code paths (examples):** `packages/i18n/translations`, `packages/i18n/lib/src/locales.dart`.

### A12 · Headless Test Harness and Application Flow Tests

**Status:** **APPROVED** (2026-10-15; implementation pending). **Risk:** Medium-high.

- **Approved resolution (summary):** Integrate upstream fake-service/headless app-flow test harness into the unified fork runtime; preserve all fork tests and the user's manual A02 verification boundary.
- **Upstream change:** Adds headless application flow tests and fakes for search, bookmarks, bulk downloads, network recovery and startup.
- **Fork divergence / merge hazard:** The fork has its own integration/repository tests and startup architecture.
- **Original review question:** Which tests can be ported without introducing a parallel runtime?
- **Binding decision, migration conditions and tests:** [A12](decisions.md#a12--headless-test-harness-and-application-flow-tests). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`c22d12fd6`](https://github.com/khoadng/Boorusama/commit/c22d12fd678db968af1356a21a3957ae3f3eda35).
- **Affected code paths (examples):** `test/application`, `test/support`.

### A13 · NixOS Package and Development Shell

**Status:** **APPROVED** (2026-10-15; implementation pending). **Risk:** Low.

- **Approved resolution (summary):** Adopt useful NixOS flake/dev-shell changes only when maintainable; no new platform-support commitment.
- **Upstream change:** Adds Nix flake, reproducible packaging, bundled fonts and ARM64 native/build fixes.
- **Fork divergence / merge hazard:** The fork has its own CLI/CI setup but no corresponding Nix implementation.
- **Original review question:** Should Nix be treated as officially supported build/release infrastructure?
- **Binding decision, migration conditions and tests:** [A13](decisions.md#a13--nixos-package-and-development-shell). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`d3f3a62fa`](https://github.com/khoadng/Boorusama/commit/d3f3a62fa40fc7eadd2a63cd32e145f9cd3d5acd), [`038d1287c`](https://github.com/khoadng/Boorusama/commit/038d1287c04a260faea85e360c98f4baffb8fd97), [`e16ecd2c3`](https://github.com/khoadng/Boorusama/commit/e16ecd2c35236880eea7be4c27e3f957c6609143), [`2d621b683`](https://github.com/khoadng/Boorusama/commit/2d621b68335a62337075b53289f1f986f0631fcf), [`047a5a09e`](https://github.com/khoadng/Boorusama/commit/047a5a09e5e2ff397f23eee21f1cd54672cc80a2).
- **Affected code paths (examples):** `flake.nix`, `nix/package.nix`, `docs/nix.md`.

### A14 · Release CI, Native Assets, SDK and Build CLI

**Status:** **APPROVED** (2026-10-15; implementation pending). **Risk:** High.

- **Approved resolution (summary):** Adopt useful upstream SDK, native asset, build and CI fixes without changing fork flavors, split APKs, signing, pinned Flutter or protected workflows.
- **Upstream change:** Changes Windows CMake/NASM/path handling, native asset retries, long paths, smoke runs, centralized toolchain and Android resource IDs; a build change was later reverted.
- **Fork divergence / merge hazard:** The fork has its own signed Android split APK workflow, CI and Flutter 3.47.2 pin.
- **Original review question:** Which specific toolchain fixes should be used without replacing the fork release workflow?
- **Binding decision, migration conditions and tests:** [A14](decisions.md#a14--release-ci-native-assets-sdk-and-build-cli). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`08088842c`](https://github.com/khoadng/Boorusama/commit/08088842c880bd124715e3d76b73c24945d8ea9a), [`dbfe54fc4`](https://github.com/khoadng/Boorusama/commit/dbfe54fc432738bcf59ee9179a9089f629d620bf), [`430747c1a`](https://github.com/khoadng/Boorusama/commit/430747c1af0153672863213a03f25c082a29e204), [`402c4eb67`](https://github.com/khoadng/Boorusama/commit/402c4eb67a1052ab1841592c4eeb5a6967de071c), [`a9821d53e`](https://github.com/khoadng/Boorusama/commit/a9821d53eb413ea46374ab09b07668b4ebe766f5), [`914ee5fa5`](https://github.com/khoadng/Boorusama/commit/914ee5fa51d33eeaa69ba8dc8c6dde171fadad58), [`899aabf6a`](https://github.com/khoadng/Boorusama/commit/899aabf6a26c22e438750319b74ac463a4af19ee), [`df4f705d8`](https://github.com/khoadng/Boorusama/commit/df4f705d810f2cdfc2f009c6d6082ab5fb61d2df), [`d1e7c99b4`](https://github.com/khoadng/Boorusama/commit/d1e7c99b4895404548a426274e076b3710d84f79), [`87a4fae44`](https://github.com/khoadng/Boorusama/commit/87a4fae4463529474a9d161fdd45fa2047831986), [`c184be942`](https://github.com/khoadng/Boorusama/commit/c184be94249a3768e4f4d672517230c62acfb7ae), [`db33523ff`](https://github.com/khoadng/Boorusama/commit/db33523ff960712518c3c3482e33f8d9b33048b6), [`c22d22e0d`](https://github.com/khoadng/Boorusama/commit/c22d22e0dfe9f3f521a3e495fafa69ba00d07364), [`f94243dcc`](https://github.com/khoadng/Boorusama/commit/f94243dccad0eace17d674df43934424ca591f39), [`b55d1adde`](https://github.com/khoadng/Boorusama/commit/b55d1addecaf59fb36cd72d5f5e6e5b75b629f84).
- **Affected code paths (examples):** `.github/workflows/github-release.yml`, `packages/boorusama_cli`, `android/gradle.properties`, `scripts/toolchain.sh`.
- **Confirmed merge conflicts in:** `.github/workflows/github-release.yml`, `android/gradle.properties`.

### A15 · APK Signing: Permanent Upstream Key

**Status:** **APPROVED** (2026-10-15; implementation pending). **Risk:** Critical.

- **Approved resolution (summary):** Do not adopt upstream signing key; retain com.timberpile.boorusama, production certificate, flavors and upgrade compatibility.
- **Upstream change:** Uses a new permanent upstream key for GitHub APK signing from v4.6.1.
- **Fork divergence / merge hazard:** The fork has its own certificate, com.timberpile.boorusama application ID, branding/flavors and update manifest.
- **Original review question:** Never adopt upstream key/app ID/credentials; can safe signing CI checks be reused?
- **Binding decision, migration conditions and tests:** [A15](decisions.md#a15--apk-signing-permanent-upstream-key). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`e6511bad5`](https://github.com/khoadng/Boorusama/commit/e6511bad5c6d44f9b574bb08e1eeef4ddaed4d23).
- **Affected code paths (examples):** `.github/workflows/github-release.yml`, `android/app/build.gradle.kts`.
- **Confirmed merge conflicts in:** `.github/workflows/github-release.yml`, `android/app/build.gradle.kts`.

### A16 · Versioning, Changelog and What's New Popup

**Status:** **APPROVED** (2026-10-15; implementation pending). **Risk:** Medium.

- **Approved resolution (summary):** Base version exactly matches merged upstream; reset timberpile.N to .1 per new upstream version, then increment. Keep +buildNumber monotonic. First v4.6.1 candidate is 4.6.1-timberpile.1+190 if no later build exists. Retain fork changelog and fix repeated What's New.
- **Upstream change:** Updates 4.6.0/4.6.1 metadata/changelog and fixes a recurring What's New popup.
- **Fork divergence / merge hazard:** The fork is currently 4.5.0-timberpile.5 and has its own release history and changelog fixes.
- **Original review question:** How should the new fork version be named, and how should upstream release notes be handled?
- **Binding decision, migration conditions and tests:** [A16](decisions.md#a16--versioning-changelog-and-whats-new-popup). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`0adc367df`](https://github.com/khoadng/Boorusama/commit/0adc367df3c9a3862e9663049e1af0d90bf60d21), [`a9c31322b`](https://github.com/khoadng/Boorusama/commit/a9c31322bd4d60761218bedfd317ef18f8b69359), [`ffd7e47c5`](https://github.com/khoadng/Boorusama/commit/ffd7e47c5840a922b1c885d415a28984a6bf978a), [`bc63321ec`](https://github.com/khoadng/Boorusama/commit/bc63321ec125c5d54da165c9977580cdea46448f), [`e44fff71c`](https://github.com/khoadng/Boorusama/commit/e44fff71cd79dc4c581f6b6072a85e999a89df37), [`953fee30b`](https://github.com/khoadng/Boorusama/commit/953fee30bd78245cc9113a1dfc41a7953a7b2c3a), [`2a5818b57`](https://github.com/khoadng/Boorusama/commit/2a5818b570a58071959e9d877aa4d2a3c9c25a17), [`5a2a4e82e`](https://github.com/khoadng/Boorusama/commit/5a2a4e82e827785f0c296b600e44aae2247b90a4), [`5b04bf6a1`](https://github.com/khoadng/Boorusama/commit/5b04bf6a164f028d41701299367d0dde74dde330).
- **Affected code paths (examples):** `CHANGELOG.md`, `pubspec.yaml`, `lib/core/changelogs/repo.dart`.
- **Confirmed merge conflicts in:** `CHANGELOG.md`, `pubspec.yaml`.

### A17 · Formatting, No-op Reverts and Small Cleanups

**Status:** **APPROVED** (2026-10-15; implementation pending). **Risk:** Low.

- **Approved resolution (summary):** Integrate necessary fixes only, avoid unrelated formatting and resurrecting reverted features.
- **Upstream change:** Contains broad formatting and cleanup, whitespace correction and removal of a duplicated @override.
- **Fork divergence / merge hazard:** These commits contain no requested product feature and the fork's touched code diverged heavily.
- **Original review question:** Apply only meaningful maintenance fixes and avoid noise.
- **Binding decision, migration conditions and tests:** [A17](decisions.md#a17--formatting-no-op-reverts-and-small-cleanups). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`cfb231254`](https://github.com/khoadng/Boorusama/commit/cfb231254634c8ef96873847c43f5983a5ea27ed), [`ab78dc3e3`](https://github.com/khoadng/Boorusama/commit/ab78dc3e338514bd39f2ce678ade2abd2c82b133), [`ee38cd592`](https://github.com/khoadng/Boorusama/commit/ee38cd592b4d6960d49025a52de433930b7441e7), [`372dca51c`](https://github.com/khoadng/Boorusama/commit/372dca51c760bb0d070c2d4b54c20c0407648b6c), [`3c72c200e`](https://github.com/khoadng/Boorusama/commit/3c72c200e1ecbf241feb09d1a3c932957720c84a).

### A18 · Web AVIF Decoder Compatibility

**Status:** **APPROVED** (2026-10-15; implementation pending). **Risk:** Medium.

- **Approved resolution (summary):** Adopt AVIF Web/network compatibility changes while retaining fork cache and media pipeline.
- **Upstream change:** Adjusts the flutter_libavif migration for Web and network decoding.
- **Fork divergence / merge hazard:** The fork already adopted AVIF but uses its own ExtendedImage and cache pipeline.
- **Original review question:** Which Web AVIF decoding fallbacks are needed without replacing the cache?
- **Binding decision, migration conditions and tests:** [A18](decisions.md#a18--web-avif-decoder-compatibility). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`72702e711`](https://github.com/khoadng/Boorusama/commit/72702e7110892d046826b53a25a70c39c1e72d56).
- **Affected code paths (examples):** `packages/extended_image/lib/src`.

## Networking and Cloudflare

### N01 · HTTP Retry-After, Rate Limiting and Admission Locks

**Status:** **APPROVED** (2026-10-15; implementation pending). **Risk:** High.

- **Approved resolution (summary):** Keep ApiRequestCoordinator as the sole per-origin admission/priority/429 authority; integrate upstream retries/timeouts/cancellation without a second sliding-window limiter.
- **Upstream change:** Adds configured retry policies, Retry-After cooldowns and serialized sliding-window rate admissions.
- **Fork divergence / merge hazard:** The fork already coordinates browsing versus Following priorities and admission quotas with ApiRequestCoordinator.
- **Original review question:** How can server waits, per-host caps and browsing priority be combined without deadlocks or double queues?
- **Binding decision, migration conditions and tests:** [N01](decisions.md#n01--http-retry-after-rate-limiting-and-admission-locks). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`70b523938`](https://github.com/khoadng/Boorusama/commit/70b5239384cc86fba7c479c7ce688076508575cf), [`deca1064a`](https://github.com/khoadng/Boorusama/commit/deca1064aa68abcbbb1683408f305558bef08ee3).
- **Affected code paths (examples):** `packages/retriable`, `lib/core/http/client/src/interceptors/sliding_window_rate_limit_interceptor.dart`.
- **Confirmed merge conflicts in:** `lib/core/http/client/src/interceptors/sliding_window_rate_limit_interceptor.dart`.

### N02 · Per-Profile Media-Host Overrides

**Status:** **APPROVED** (2026-10-15; implementation pending). **Risk:** High.

- **Approved resolution (summary):** Adopt image/video/download host overrides with strict cookie, Authorization, cache and source-origin safeguards.
- **Upstream change:** Adds per-profile alternate media hosts and security filtering of forwarded headers, with settings UI.
- **Fork divergence / merge hazard:** This feature is new to the fork, which routes media through a shared, source/profile-aware image cache.
- **Original review question:** How should host overrides interact with cache keys, cookies, proxies, media downloads and previews?
- **Binding decision, migration conditions and tests:** [N02](decisions.md#n02--per-profile-media-host-overrides). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`cb5f9fade`](https://github.com/khoadng/Boorusama/commit/cb5f9fade8ed5c7e26d3f0811ef17f7187f73723).
- **Affected code paths (examples):** `lib/core/configs/network/src/types/media_host_override.dart`, `lib/core/images/booru_image.dart`.
- **Confirmed merge conflicts in:** `lib/core/images/booru_image.dart`.

### N03 · Cloudflare: Do Not Blindly Replay State-Changing Requests

**Status:** **APPROVED** (2026-10-15; implementation pending). **Risk:** High.

- **Approved resolution (summary):** Never blindly replay POST/PUT/votes/favorites/comments after Cloudflare unless idempotent; preserve Rule34 safeguards.
- **Upstream change:** Adds request-intent distinctions to HTTP recovery so POST/PUT and other mutations are not blindly replayed.
- **Fork divergence / merge hazard:** The fork has specialized Rule34-403/Cloudflare recovery with its own replay behavior.
- **Original review question:** Which operations are retry-safe, particularly favorites/votes/comments?
- **Binding decision, migration conditions and tests:** [N03](decisions.md#n03--cloudflare-do-not-blindly-replay-state-changing-requests). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`94aa56361`](https://github.com/khoadng/Boorusama/commit/94aa56361ad31a902e7382396e958d27244cda35).
- **Affected code paths (examples):** `lib/core/http/client/src/interceptors/dio_protection_interceptor.dart`, `packages/coreutils/lib/src/request_intent.dart`.
- **Confirmed merge conflicts in:** `lib/core/http/client/src/interceptors/dio_protection_interceptor.dart`.

### N04 · Cloudflare Detection, Block Pages, Redirects and Challenge UX

**Status:** **APPROVED** (2026-10-15; implementation pending). **Risk:** High.

- **Approved resolution (summary):** Integrate block-page/captcha recognition, redirects, loop prevention and UI while preserving fork Rule34 403 recovery.
- **Upstream change:** Recognizes redesigned Cloudflare challenges, confirmation pages and subdomain redirects; reduces loops and dialog flashes.
- **Fork divergence / merge hazard:** The fork has focused Rule34 403 recovery and modified solver/HTTP interceptors.
- **Original review question:** How can challenge detection be adapted without losing Rule34 recovery?
- **Binding decision, migration conditions and tests:** [N04](decisions.md#n04--cloudflare-detection-block-pages-redirects-and-challenge-ux). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`99ee264db`](https://github.com/khoadng/Boorusama/commit/99ee264dbc2f9649d94b8757575e82b885623e0d), [`bcef3b5c1`](https://github.com/khoadng/Boorusama/commit/bcef3b5c1cf620ff3d67bfaef9e6d623391c3442), [`dc7b9cee9`](https://github.com/khoadng/Boorusama/commit/dc7b9cee911f28049333546c56379be8c51d955a), [`f82a62885`](https://github.com/khoadng/Boorusama/commit/f82a6288563d73e8da1943b7fed499d16f3611d7), [`b0a1d65d9`](https://github.com/khoadng/Boorusama/commit/b0a1d65d9e60131f010491f38877cfd5e5df7b60), [`399a4da47`](https://github.com/khoadng/Boorusama/commit/399a4da47587906a73a316f18c089254b58156d5).
- **Affected code paths (examples):** `lib/core/ddos/solver`, `lib/core/ddos/handler/protection_handler.dart`.

### N05 · Clearance Cookies and Native WebView Cookie Bridge

**Status:** **APPROVED** (2026-10-15; implementation pending). **Risk:** High.

- **Approved resolution (summary):** Adopt Android/iOS/macOS WebView-to-HTTP cookie handling with correct origin, Secure, HttpOnly and native bounds.
- **Upstream change:** Reads clearance cookies from WebView/native CookieManager after solved challenges and applies them to HTTP clients on Android/iOS/macOS.
- **Fork divergence / merge hazard:** The fork has different native channel paths and extra export/system native integrations.
- **Original review question:** On which platforms should the bridge run and how are Secure/HttpOnly/domain scopes respected?
- **Binding decision, migration conditions and tests:** [N05](decisions.md#n05--clearance-cookies-and-native-webview-cookie-bridge). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`0b4dcfcc4`](https://github.com/khoadng/Boorusama/commit/0b4dcfcc40d22cff1464b34506a6b836f06d7586), [`0ad2e6465`](https://github.com/khoadng/Boorusama/commit/0ad2e646591aceac0ab726aec1213289e42311ac).
- **Affected code paths (examples):** `android/app/src/main/kotlin`, `ios/Runner/AppDelegate.swift`, `lib/foundation/browser/webview_cookie_channel.dart`.
- **Confirmed merge conflicts in:** `ios/Runner/AppDelegate.swift`.

### N06 · HTTP/2 Window and Automatic Gzip

**Status:** **APPROVED** (2026-10-15; implementation pending). **Risk:** Medium.

- **Approved resolution (summary):** Adopt HTTP/2 flow-control and gzip improvements without regressing fallback transports, priorities or mobile memory use.
- **Upstream change:** Increases HTTP/2 connection/stream flow-control windows and enables compressed responses.
- **Fork divergence / merge hazard:** The fork customizes Dio/HTTP2 for interactive browsing priority and site adapters.
- **Original review question:** Which settings should be global versus selective, considering mobile memory and problematic servers?
- **Binding decision, migration conditions and tests:** [N06](decisions.md#n06--http2-window-and-automatic-gzip). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`86a7ee6bb`](https://github.com/khoadng/Boorusama/commit/86a7ee6bbee7a730f9b8931c01919191bd2ad0c3).
- **Affected code paths (examples):** `lib/core/http/client/src/providers/dio.dart`.

## Downloads, Backups and Export

### D01 · Download Sidecars: TXT Tags and JSON Metadata

**Status:** **APPROVED** (2026-10-16; implementation pending). **Risk:** High.

- **Approved resolution (summary):** Off by default; optional tag-TXT/JSON sidecars with bulk override and safe immutable metadata. Atomic post-completion write, durable independent retry, no secret URLs or sidecar creation for skipped existing media.
- **Upstream change:** Adds optional TXT tags or JSON metadata alongside downloads with post ID, source, quality, filename, atomic sidecar creation and bulk/storage integration.
- **Fork divergence / merge hazard:** The fork has more complex download, sharing and export flows and no existing sidecar module.
- **Original review question:** Should settings be global or per profile, and what happens on duplicate, failure, existing media and backup?
- **Binding decision, migration conditions and tests:** [D01](decisions.md#d01--download-sidecars-txt-tags-and-json-metadata). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`86a16a20e`](https://github.com/khoadng/Boorusama/commit/86a16a20ee1327740316005b7946b8264fa70a19).
- **Affected code paths (examples):** `lib/core/downloads/sidecar`, `lib/core/bulk_downloads/src/providers/bulk_download_notifier.dart`.
- **Confirmed merge conflicts in:** `lib/core/bulk_downloads/src/providers/bulk_download_notifier.dart`.

### D02 · Bulk Download Finalization and Notifications

**Status:** **APPROVED** (2026-10-15; implementation pending). **Risk:** Critical.

- **Approved resolution (summary):** Use final upstream completion logic with serial session checks, tolerant size errors, final stats before cleanup and bounded completion history; preserve fork lifecycle and idempotent recovery.
- **Upstream change:** Temporarily reverts earlier deterministic session finalization and later rebuilds completion and notification handling around Futures.
- **Fork divergence / merge hazard:** The fork contains the earlier fix upstream reverted, plus fork lifecycle guards; implementations differ on race handling/cleanup.
- **Original review question:** Which completion algorithm guarantees correct final statistics and notification visibility through cleanup?
- **Binding decision, migration conditions and tests:** [D02](decisions.md#d02--bulk-download-finalization-and-notifications). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`ebdfb05d9`](https://github.com/khoadng/Boorusama/commit/ebdfb05d9bec5be5c6fd6dd3e5460cea8ce1e1a1), [`54b19cd4c`](https://github.com/khoadng/Boorusama/commit/54b19cd4cf77b3a75579a2b27aeccc1b1dc56ef5).
- **Affected code paths (examples):** `lib/core/bulk_downloads/src/providers/bulk_download_notifier.dart`, `lib/core/download_activity`.
- **Confirmed merge conflicts in:** `lib/core/bulk_downloads/src/providers/bulk_download_notifier.dart`.

### D03 · Background Downloader Plugin Update

**Status:** **APPROVED** (2026-10-16; implementation pending). **Risk:** Low-medium.

- **Approved resolution (summary):** After API/native/Cronet checks, update background_downloader Git ref e8ad9f9 to fd67fff9ee4ad4cdf415dc3285289cad9289cefe, remaining at package version 9.6.1.
- **Upstream change:** Updates the pinned Git revision of the background downloader plugin while retaining package v9.6.1.
- **Fork divergence / merge hazard:** The fork uses Cronet and its own durable download/notification services.
- **Original review question:** Is the new commit compatible with fork Flutter/Cronet/APK configuration?
- **Binding decision, migration conditions and tests:** [D03](decisions.md#d03--background-downloader-plugin-update). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`669b8019f`](https://github.com/khoadng/Boorusama/commit/669b8019f80eaf8d0f40e268bbf8a29dc0808ddf).
- **Affected code paths (examples):** `pubspec.lock`, `pubspec_overrides.yaml`.

### D04 · Download Manager: Injectable Task Client and Snapshot Fix

**Status:** **APPROVED** (2026-10-16; implementation pending). **Risk:** Medium.

- **Approved resolution (summary):** Introduce injectable pause/resume/retry/cancel/file access; copy task group lists before updating state and prevent double-closing the stream controller.
- **Upstream change:** Introduces a testable DownloadTaskClient interface and copies task lists before state updates to prevent mutation of existing snapshots.
- **Fork divergence / merge hazard:** The fork has its own download manager and download activity behavior.
- **Original review question:** Migrate the whole test boundary or only the state-mutation fix?
- **Binding decision, migration conditions and tests:** [D04](decisions.md#d04--download-manager-injectable-task-client-and-snapshot-fix). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`bd2e22c22`](https://github.com/khoadng/Boorusama/commit/bd2e22c221bcfb1a8c8c0675afbab6763a3102c9), [`90657ee4e`](https://github.com/khoadng/Boorusama/commit/90657ee4ed73f9a4bf7f2277ed1750e2f8b5d4ff).
- **Affected code paths (examples):** `lib/core/download_manager`.

### D05 · Anime-Pictures Bulk Downloads and Request Pacing

**Status:** **APPROVED** (2026-10-16; implementation pending). **Risk:** Medium.

- **Approved resolution (summary):** Enable bulk with about 1 req/sec via ApiRequestCoordinator; remove indefinitely cached client links, preserve bounded fork extractor cache and validate expired auth/URLs.
- **Upstream change:** Enables Anime-Pictures bulk downloading with conservative API/download-link request pacing.
- **Fork divergence / merge hazard:** The fork has customized Anime-Pictures clients and download URL extraction.
- **Original review question:** How should the upstream quota model interact with fork-wide rate limits and download behavior?
- **Binding decision, migration conditions and tests:** [D05](decisions.md#d05--anime-pictures-bulk-downloads-and-request-pacing). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`c5b79488c`](https://github.com/khoadng/Boorusama/commit/c5b79488c8d90b624cb17e8452d3b17e099be88f).
- **Affected code paths (examples):** `lib/boorus/anime-pictures/client_provider.dart`, `packages/booru_clients/lib/src/anime-pictures`.

### D06 · Zerochan Bulk Downloads and URL Resolution

**Status:** **APPROVED** (2026-10-16; implementation pending). **Risk:** Medium.

- **Approved resolution (summary):** Enable robust detail-API and HTML fallback, quality selection, request coalescing and ~1.2s pacing via N01. Never silently downgrade explicitly requested Original quality.
- **Upstream change:** Re-enables Zerochan bulk downloads and adds explicit download URL/quality resolution.
- **Fork divergence / merge hazard:** The fork has custom Zerochan parsers/downloads but lacks the new bulk URL extractor modules.
- **Original review question:** Which qualities, redirects and authentication cases must be supported?
- **Binding decision, migration conditions and tests:** [D06](decisions.md#d06--zerochan-bulk-downloads-and-url-resolution). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`50980b8da`](https://github.com/khoadng/Boorusama/commit/50980b8da1368aa39a44051c78dee12dd4dff2ce).
- **Affected code paths (examples):** `lib/boorus/zerochan`, `packages/booru_clients/lib/src/zerochan`.

### D07 · Preserve Original Site Post IDs in Exports Instead of Only Numeric IDs

**Status:** **APPROVED** (2026-10-16; implementation pending). **Risk:** High.

- **Approved resolution (summary):** Use Post.sitePostId in JSON sidecars and links; change {id} filename token to genuine site ID including Sankaku strings. Retain Pixiv {illust_id}_p{page}.{extension} default; no new token, Hive field or bookmark identity.
- **Upstream change:** Preserves genuine sitePostId in exports for non-numeric identifiers, alongside a Sankaku suggestion fix.
- **Fork divergence / merge hazard:** The fork uses separate PostOrigin, stored post snapshots and BookmarkIdentity; the upstream schema cannot be copied unchanged.
- **Original review question:** Where is the genuine source ID derived, persisted and exported?
- **Binding decision, migration conditions and tests:** [D07](decisions.md#d07--preserve-original-site-post-ids-in-exports-instead-of-only-numeric-ids). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`216eb6e6d`](https://github.com/khoadng/Boorusama/commit/216eb6e6d43cef2581a110b66a8f1482d110e7b9).
- **Affected code paths (examples):** `lib/core/posts/post/src/types/post.dart`, `lib/core/bookmarks/src/types/bookmark.dart`.
- **Confirmed merge conflicts in:** `lib/core/bookmarks/src/types/bookmark.dart`, `lib/core/posts/post/src/types/post.dart`.

### D08 · Export Favorite Tags Directly from Storage

**Status:** **APPROVED** (2026-10-16; implementation pending). **Risk:** Medium.

- **Approved resolution (summary):** Read all favorite tags from repository storage, not an uninitialized UI provider; preserve labels, repo.replaceAll imports and simple clipboard export.
- **Upstream change:** Reads all favorite tags directly from persistent repository storage instead of an uninitialized UI provider.
- **Fork divergence / merge hazard:** The fork has extended backup/import/export flows and separate tag repositories.
- **Original review question:** Should all applicable full backup and fork export paths use persistent reads?
- **Binding decision, migration conditions and tests:** [D08](decisions.md#d08--export-favorite-tags-directly-from-storage). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`f93bdf0dd`](https://github.com/khoadng/Boorusama/commit/f93bdf0dd42c5eb0e8165d9070310a2aebfa32c1).
- **Affected code paths (examples):** `lib/core/backups/sources/favorite_tags_source.dart`.

## Booru-Specific Changes

### B01 · Sankaku Metatags, Syntax Highlighting and Typed Suggestions

**Status:** **APPROVED** (2026-10-16; implementation pending). **Risk:** Medium-high.

- **Approved resolution (summary):** Adopt Sankaku-native search filters, parsing and typed suggestions within the fork's unified search-options UX, not a duplicate legacy search bar.
- **Upstream change:** Adds distinct Sankaku metatag categories, suggestions and syntax highlighting.
- **Fork divergence / merge hazard:** The fork is redesigning tag search and site-independent search abstractions and owns search bar code.
- **Original review question:** Which metatags belong in shared Search Options versus Sankaku-specific adapters?
- **Binding decision, migration conditions and tests:** [B01](decisions.md#b01--sankaku-metatags-syntax-highlighting-and-typed-suggestions). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`216eb6e6d`](https://github.com/khoadng/Boorusama/commit/216eb6e6d43cef2581a110b66a8f1482d110e7b9), [`2569eaeeb`](https://github.com/khoadng/Boorusama/commit/2569eaeeb6ea01ea35386ffc8bab858dcbd1d75d).
- **Affected code paths (examples):** `lib/boorus/sankaku/tags/metatags.dart`, `lib/boorus/sankaku/search/tag_query_composer.dart`.

### B02 · Normalize Sankaku Exclusion and Date Filters

**Status:** **APPROVED** (2026-10-16; implementation pending). **Risk:** Medium.

- **Approved resolution (summary):** Normalize only supported single-date input to API day ranges; preserve explicit ranges/operators and source query, with clear exclusion-limit errors.
- **Upstream change:** Improves Sankaku exclusion error messages and converts a single date to an API-compatible day range.
- **Fork divergence / merge hazard:** The fork modifies search syntax parsing/composition.
- **Original review question:** Normalize at the site API boundary or inside the shared search abstraction?
- **Binding decision, migration conditions and tests:** [B02](decisions.md#b02--normalize-sankaku-exclusion-and-date-filters). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`18216f412`](https://github.com/khoadng/Boorusama/commit/18216f4123586634f0756e7d5b20673638711766), [`6ad672075`](https://github.com/khoadng/Boorusama/commit/6ad672075306e5621a4dde519ad124da0b19f8cb).
- **Affected code paths (examples):** `lib/boorus/sankaku`.

### B03 · Preserve All Sankaku Tag Categories and Remove Duplicates

**Status:** **APPROVED** (2026-10-16; implementation pending). **Risk:** Medium.

- **Approved resolution (summary):** Handle site-specific Studio 2, Genre 5, Medium 8 and Meta 9 categories plus unknown values; deduplicate by genuine tag identity.
- **Upstream change:** Parses all Sankaku tag categories and deduplicates tags during post mapping.
- **Fork divergence / merge hazard:** The fork has expanded tag and post data models with only partial parity.
- **Original review question:** How do category values map to the fork's tag colors and groups?
- **Binding decision, migration conditions and tests:** [B03](decisions.md#b03--preserve-all-sankaku-tag-categories-and-remove-duplicates). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`d0fde834a`](https://github.com/khoadng/Boorusama/commit/d0fde834a413658bb50db150636c481c88a88222), [`396ae059e`](https://github.com/khoadng/Boorusama/commit/396ae059e9e5576aa0172df7fabf823963c03e92).
- **Affected code paths (examples):** `lib/boorus/sankaku/posts/parser.dart`, `lib/boorus/sankaku/tags`.
- **Confirmed merge conflicts in:** `lib/boorus/sankaku/posts/parser.dart`.

### B04 · Sankaku Authentication: API Headers, Invalid Credentials, Session Recovery

**Status:** **APPROVED** (2026-10-16; implementation pending). **Risk:** High.

- **Approved resolution (summary):** Preserve headers, validate token responses and coalesce safe GET reauthentication; do not automatically replay mutating favorite requests.
- **Upstream change:** Preserves HTTP options during Sankaku API header merges, validates auth responses and handles expired sessions/login errors.
- **Fork divergence / merge hazard:** The fork has its own profile/auth model and extra favorite integrations.
- **Original review question:** When is automatic recovery safe, and when must the user reauthenticate?
- **Binding decision, migration conditions and tests:** [B04](decisions.md#b04--sankaku-authentication-api-headers-invalid-credentials-session-recovery). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`829ec71fb`](https://github.com/khoadng/Boorusama/commit/829ec71fbaedbc60fff7d98fe1b40c494a130ebe), [`6ad691a6d`](https://github.com/khoadng/Boorusama/commit/6ad691a6de23d8a44c46d02bf3640997dbb618f4), [`6762d00f2`](https://github.com/khoadng/Boorusama/commit/6762d00f2e4ac6efc99bf969bd15a335f6767437), [`8757eb295`](https://github.com/khoadng/Boorusama/commit/8757eb2953d41716bc7c8fb3a028b71fb3f03e2c).
- **Affected code paths (examples):** `packages/booru_clients/lib/src/sankaku/sankaku_client.dart`, `lib/boorus/sankaku/sankaku_repository.dart`.
- **Confirmed merge conflicts in:** `lib/boorus/sankaku/sankaku_repository.dart`, `packages/booru_clients/lib/src/sankaku/sankaku_client.dart`.

### B05 · Explain Sankaku Search Limits

**Status:** **APPROVED** (2026-10-16; implementation pending). **Risk:** Low.

- **Approved resolution (summary):** Surface comprehensible localized anonymous/account tag-limit errors with fallback for unknown cases.
- **Upstream change:** Converts API tag-limit error codes into understandable messages.
- **Fork divergence / merge hazard:** The fork has its own search error and localization layer.
- **Original review question:** How should site errors appear in the fork's error UI?
- **Binding decision, migration conditions and tests:** [B05](decisions.md#b05--explain-sankaku-search-limits). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`5b495f1ad`](https://github.com/khoadng/Boorusama/commit/5b495f1adec13643ee83307bb2b68eb0272766b2).
- **Affected code paths (examples):** `lib/boorus/sankaku/errors/error_translator.dart`.

### B06 · Shimmie2 Media Formats and Favorite Fallback

**Status:** **APPROVED** (2026-10-16; implementation pending). **Risk:** Medium.

- **Approved resolution (summary):** Normalize media formats and load authenticated favorite status only where supported, without blocking post listing or overwriting newer user choices.
- **Upstream change:** Improves Shimmie2 file extension detection and Favorite state resolution while allowing listings when Favorite API fails.
- **Fork divergence / merge hazard:** The fork has customized Shimmie2 client/parsing and favorites.
- **Original review question:** Which errors should be soft failures versus actionable auth errors?
- **Binding decision, migration conditions and tests:** [B06](decisions.md#b06--shimmie2-media-formats-and-favorite-fallback). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`2d4f8484b`](https://github.com/khoadng/Boorusama/commit/2d4f8484ba62db8e5c5386825934b1bcc30455cf), [`d79ef1fcc`](https://github.com/khoadng/Boorusama/commit/d79ef1fcc9f59b07933e76681b6c033e12327460).
- **Affected code paths (examples):** `lib/boorus/shimmie2`, `packages/booru_clients/lib/src/shimmie2`.

### B07 · Gelbooru v2: Comment Upvotes and Cursor Pagination

**Status:** **APPROVED** (2026-10-16; implementation pending). **Risk:** Medium-high.

- **Approved resolution (summary):** Integrate Rule34 comment upvotes only, cursor pagination and score/parser fixes under explicit site capabilities and safe mutation handling.
- **Upstream change:** Adds comment upvotes (no downvotes) and cursor-based comment navigation in Gelbooru v2 clients.
- **Fork divergence / merge hazard:** The fork has custom comment/post context and Rule34-specific Gelbooru v2 behavior.
- **Original review question:** Which sites support authenticated comment voting and how should capability checks work?
- **Binding decision, migration conditions and tests:** [B07](decisions.md#b07--gelbooru-v2-comment-upvotes-and-cursor-pagination). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`f459e9922`](https://github.com/khoadng/Boorusama/commit/f459e99220e4ac5b449c033d1d60a0b672ea2b58).
- **Affected code paths (examples):** `lib/boorus/gelbooru_v2/comments`, `packages/booru_clients/lib/src/gelbooru_v2`.

### B08 · Gelbooru v2: Comment Sorting

**Status:** **APPROVED** (2026-10-16; implementation pending). **Risk:** Medium.

- **Approved resolution (summary):** Expose Newest/Oldest only on supported sites, preserve cookies, reset pagination/cursor and avoid new persisted options.
- **Upstream change:** Adds server/client comment sort options depending on site API variant.
- **Fork divergence / merge hazard:** The fork has its own Gelbooru v2 comment provider.
- **Original review question:** Which modes are displayed, and should the selection persist per profile?
- **Binding decision, migration conditions and tests:** [B08](decisions.md#b08--gelbooru-v2-comment-sorting). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`43619dd49`](https://github.com/khoadng/Boorusama/commit/43619dd495d5cb79425845521f0a0e0de030670d).
- **Affected code paths (examples):** `lib/boorus/gelbooru_v2/comments`, `packages/booru_clients`.

### B09 · Nozomi Tag Counts and HTTP Range Encoding

**Status:** **APPROVED** (2026-10-16; implementation pending). **Risk:** Low-medium.

- **Approved resolution (summary):** Read index size with Accept-Encoding identity, validate Content-Range and 200/206/404/416 responses; throttle counts using ApiRequestCoordinator.
- **Upstream change:** Derives tag counts from Nozomi index sizes rather than search buckets and sends Accept-Encoding: identity on range requests.
- **Fork divergence / merge hazard:** The fork already supports Nozomi with a customized client.
- **Original review question:** Can this change be adapted directly while preserving existing client behavior?
- **Binding decision, migration conditions and tests:** [B09](decisions.md#b09--nozomi-tag-counts-and-http-range-encoding). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`7880a020f`](https://github.com/khoadng/Boorusama/commit/7880a020fc7ba968351ee5256d3685c347d4eca0), [`5a4498f78`](https://github.com/khoadng/Boorusama/commit/5a4498f78dbce67aa43c0d3d01c4fc8d31784a23).
- **Affected code paths (examples):** `packages/booru_clients/lib/src/nozomi`.

### B10 · Rule34 JSON Post API at api.rule34.xxx

**Status:** **APPROVED** (2026-10-16; implementation pending). **Risk:** High.

- **Approved resolution (summary):** Switch to api.rule34.xxx only after live verification; protect pagination, parsing, cookies, Cloudflare and profile/source identity.
- **Upstream change:** Overrides Rule34 post-list requests to https://api.rule34.xxx/index.php?page=dapi&s=post&q=index&json=1.
- **Fork divergence / merge hazard:** The fork still uses rule34.xxx for listings and has specialized 403 challenge handling.
- **Original review question:** Which host is reliable and how do auth cookies, filters, and profile isolation behave?
- **Binding decision, migration conditions and tests:** [B10](decisions.md#b10--rule34-json-post-api-at-apirule34xxx). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`5972548ec`](https://github.com/khoadng/Boorusama/commit/5972548ecd6e32622b8476776490251d61d6a099).
- **Affected code paths (examples):** `packages/booru_clients/boorus.yaml`.
- **Confirmed merge conflicts in:** `packages/booru_clients/boorus.yaml`.

## Posts, Grid, Viewer and Media

### P01 · Two Quick Actions on Post Thumbnails

**Status:** **APPROVED** (2026-10-16; implementation pending). **Risk:** High.

- **Approved resolution (summary):** Migrate the existing primary action and default secondary to none. Preserve per-post origin defaultActionButton, mixed feeds, Danbooru banned-state behavior, selection and Series cards.
- **Upstream change:** Adds primary and secondary per-profile thumbnail actions with adaptive layout.
- **Fork divergence / merge hazard:** The fork supports one quick action and custom overlays, selection and planned Series grouping.
- **Original review question:** Which actions/positions are shown during selection, hover and grouped cards?
- **Binding decision, migration conditions and tests:** [P01](decisions.md#p01--two-quick-actions-on-post-thumbnails). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`26ad35202`](https://github.com/khoadng/Boorusama/commit/26ad352026bb4187e399dfab422c76427aca8655).
- **Affected code paths (examples):** `lib/core/configs/listing`, `lib/core/posts/listing/src/widgets/default_image_quick_actions.dart`.

### P02 · Preserve Profiles with Unknown Thumbnail Actions or Media Host Rules

**Status:** **APPROVED** (2026-10-16; implementation pending). **Risk:** High.

- **Approved resolution (summary):** Do not discard profiles for unknown thumbnail-action or media-host options; preserve UUIDs/data, allow safe fallback and clear import warnings.
- **Upstream change:** Handles unknown action values and invalid media-host rules defensively instead of rejecting entire profiles.
- **Fork divergence / merge hazard:** The fork adds profile UUIDs, import remapping and custom validation.
- **Original review question:** Which option errors can be tolerated, and how should import warnings appear?
- **Binding decision, migration conditions and tests:** [P02](decisions.md#p02--preserve-profiles-with-unknown-thumbnail-actions-or-media-host-rules). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`1d8c879f4`](https://github.com/khoadng/Boorusama/commit/1d8c879f406d54df86c25d334ace0ada98846886).
- **Affected code paths (examples):** `lib/core/configs/config/src/types/booru_config.dart`, `lib/core/configs/listing/src/types/thumbnail_actions.dart`.

### P03 · Retry Failed Images Using Targeted Error Controls

**Status:** **APPROVED** (2026-10-16; implementation pending). **Risk:** Medium.

- **Approved resolution (summary):** Use targeted accessible Retry in error widgets, including ProgressivePostImage staged loads, without replacing valid low-res fallbacks or hijacking tile/selection gestures.
- **Upstream change:** First restored tap-to-retry for custom image errors, then reverted generic implicit retry gestures.
- **Fork divergence / merge hazard:** The fork uses custom error UI and a shared cache/progressive image loader.
- **Original review question:** Should retries use whole-image tapping or a dedicated visible control?
- **Binding decision, migration conditions and tests:** [P03](decisions.md#p03--retry-failed-images-using-targeted-error-controls). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`afdff42e3`](https://github.com/khoadng/Boorusama/commit/afdff42e344a585439bef34893bc2cbaa8e706df), [`58e4a0607`](https://github.com/khoadng/Boorusama/commit/58e4a06075faa8c07d8129dfdfa19156a4981a50).
- **Affected code paths (examples):** `packages/extended_image/lib/src/extended_image.dart`.
- **Confirmed merge conflicts in:** `packages/extended_image/lib/src/extended_image.dart`.

### P04 · Preserve Grid Refresh Requests During Fetches

**Status:** **APPROVED** (2026-10-16; implementation pending). **Risk:** Medium.

- **Approved resolution (summary):** Keep the fork's pending refresh waiters/page/selection semantics and add guard against publishing superseded fetch results or stale errors.
- **Upstream change:** Retains refresh requests while grid data fetches run, then applies the latest results.
- **Fork divergence / merge hazard:** The fork has prefetch, adaptive scheduling and Following feeds with a custom queued controller.
- **Original review question:** How should manual refresh and automatic feeds share the current request scheduler?
- **Binding decision, migration conditions and tests:** [P04](decisions.md#p04--preserve-grid-refresh-requests-during-fetches). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`828ddbdb7`](https://github.com/khoadng/Boorusama/commit/828ddbdb75afd02fe14cf8182774a3ef67c9128f).
- **Affected code paths (examples):** `lib/core/posts/listing/src/widgets/post_grid_controller.dart`.
- **Confirmed merge conflicts in:** `lib/core/posts/listing/src/widgets/post_grid_controller.dart`.

### P05 · Refresh Bookmark Library After Bookmark Mutation

**Status:** **APPROVED** (2026-10-16; implementation pending). **Risk:** Medium.

- **Approved resolution (summary):** Keep BookmarkViewRefreshGate as the only authoritative listener; do not duplicate upstream's refresh trigger.
- **Upstream change:** Adds a listener to refresh the visible bookmark list after mutations.
- **Fork divergence / merge hazard:** The fork already has groups/default group/Undo and asynchronous library services plus its own refresh gate.
- **Original review question:** Reuse existing change/selection events rather than install a duplicate listener?
- **Binding decision, migration conditions and tests:** [P05](decisions.md#p05--refresh-bookmark-library-after-bookmark-mutation). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`3f4ce2bd4`](https://github.com/khoadng/Boorusama/commit/3f4ce2bd4f0f94c116b2262fa9418809710278a8).
- **Affected code paths (examples):** `lib/core/bookmarks/src/widgets/bookmark_scroll_view.dart`.
- **Confirmed merge conflicts in:** `lib/core/bookmarks/src/widgets/bookmark_scroll_view.dart`.

### P06 · GIF Autoplay Respects Quality Settings

**Status:** **APPROVED** (2026-10-16; implementation pending). **Risk:** Low-medium.

- **Approved resolution (summary):** Animate grid GIFs only with autoplay and known original file size >0 and <=5 MiB, otherwise static even at Highest. Retain Danbooru Automatic-versus-manual quality semantics; viewer/download exempt.
- **Upstream change:** Makes GIF autoplay setting apply to alternative image quality selections.
- **Fork divergence / merge hazard:** The fork separates grid and viewer qualities and provides GIF export/trim tools.
- **Original review question:** How should the fix integrate with fork-specific quality resolvers and the 5 MiB cap?
- **Binding decision, migration conditions and tests:** [P06](decisions.md#p06--gif-autoplay-respects-quality-settings). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`e4d645630`](https://github.com/khoadng/Boorusama/commit/e4d6456309c93f050b3a5d311ea4e2a60e0a7663).
- **Affected code paths (examples):** `lib/core/posts`, `lib/boorus`.

### P07 · Keep Video Thumbnail Until First Rendered Frame

**Status:** **APPROVED** (2026-10-16; implementation pending). **Risk:** Medium.

- **Approved resolution (summary):** Show thumbnail until actual first rendered frame, protecting source/engine changes from stale signals and providing fallback errors.
- **Upstream change:** Keeps the video placeholder visible until a frame has been rendered by the player.
- **Fork divergence / merge hazard:** The fork has its own video thumbnails and viewer transitions.
- **Original review question:** Which thumbnail and fade source should be used until the first frame?
- **Binding decision, migration conditions and tests:** [P07](decisions.md#p07--keep-video-thumbnail-until-first-rendered-frame). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`2003c0c1e`](https://github.com/khoadng/Boorusama/commit/2003c0c1eb2cf6b3ef0939b33adf1b575fcae8f9).
- **Affected code paths (examples):** `lib/core/videos/player/src/widgets/video_player.dart`.

### P08 · WebView Video Playback from Cached File and Cleanup Protection

**Status:** **APPROVED** (2026-10-16; implementation pending). **Risk:** High.

- **Approved resolution (summary):** Use a local HTML/video file and cleanup, protect video cache files with active-use leases against expiry, LRU or clear; stream on cache miss.
- **Upstream change:** Plays cached video files directly through WebView and cleans up temporary pages.
- **Fork divergence / merge hazard:** The fork has a separate video cache, shared image cache and custom viewer gesture logic.
- **Original review question:** How are file usage lifetime and eviction coordinated?
- **Binding decision, migration conditions and tests:** [P08](decisions.md#p08--webview-video-playback-from-cached-file-and-cleanup-protection). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`f3d8acaa0`](https://github.com/khoadng/Boorusama/commit/f3d8acaa0a765b6d2957ddd36f68a1aa944fa328), [`0f71409de`](https://github.com/khoadng/Boorusama/commit/0f71409dea3775ae1dd033bcf7fc27bb008888a0).
- **Affected code paths (examples):** `lib/core/videos/engines`, `lib/core/videos/cache`.

### P09 · Kurumi InteractiveViewer: Image Pan vs Page Swipe

**Status:** **APPROVED** (2026-10-16; implementation pending). **Risk:** High.

- **Approved resolution (summary):** At 1x favor PageView swipes, when zoomed favor pan/pinch. Preserve fork 160dp edge-pull, double tap, original-on-zoom and other zoom features.
- **Upstream change:** Vendors a Flutter 3.47.2 InteractiveViewer to avoid capturing page swipes on unzoomed images.
- **Fork divergence / merge hazard:** The fork implements custom zoom, edge-drag, swipe and Original-on-Zoom gestures.
- **Original review question:** Which gesture wins at zoom 1x, zoom >1x, edge-drag and selection?
- **Binding decision, migration conditions and tests:** [P09](decisions.md#p09--kurumi-interactiveviewer-image-pan-vs-page-swipe). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`62e36f7e5`](https://github.com/khoadng/Boorusama/commit/62e36f7e5c7d40a3b5daa383a7c67ca420cb1cd3), [`c6b25213c`](https://github.com/khoadng/Boorusama/commit/c6b25213c3478abedf5c82c41dd9dd92a93a1bbe).
- **Affected code paths (examples):** `packages/kurumi/lib/src/components/interactive_viewer.dart`, `lib/core/posts/details_pageview`.
- **Confirmed merge conflicts in:** `packages/kurumi/lib/src/components/interactive_viewer.dart`.

### P10 · Consume Volume Keys Correctly in the Post Viewer

**Status:** **APPROVED** (2026-10-16; implementation pending). **Risk:** Low-medium.

- **Approved resolution (summary):** Consume volume up/down only when configured and eligible visible non-expanded viewer; handle key lifecycle without repeated navigation or suppressing system volume elsewhere.
- **Upstream change:** Marks volume keys handled while using them for post viewer navigation.
- **Fork divergence / merge hazard:** The fork has its own viewer gestures and volume key setting.
- **Original review question:** Should system volume be affected only when viewer navigation is active?
- **Binding decision, migration conditions and tests:** [P10](decisions.md#p10--consume-volume-keys-correctly-in-the-post-viewer). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`de755c0d2`](https://github.com/khoadng/Boorusama/commit/de755c0d20570d4c9e2c6d4b718517514178af44).
- **Affected code paths (examples):** `lib/core/posts/details/src/widgets/volume_key_page_navigator.dart`.

### P11 · Video Controls: Time Overflow and Media Play/Pause Keys

**Status:** **APPROVED** (2026-10-16; implementation pending). **Risk:** Low-medium.

- **Approved resolution (summary):** Fix time-display width and handle media play/pause only on active visible video, not image/hidden viewer or text input.
- **Upstream change:** Makes video time labels flexible and adds hardware Media Play/Pause handling.
- **Fork divergence / merge hazard:** The fork has custom post toolbar and player engines.
- **Original review question:** How are the upstream controls and keys routed through fork player controls?
- **Binding decision, migration conditions and tests:** [P11](decisions.md#p11--video-controls-time-overflow-and-media-playpause-keys). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`c65a81074`](https://github.com/khoadng/Boorusama/commit/c65a81074f123eed5efbe368a8a44985dd8340cf), [`72bafb43d`](https://github.com/khoadng/Boorusama/commit/72bafb43d3e5063749ce663277201b01ea644a54).
- **Affected code paths (examples):** `lib/core/posts/details/src/widgets/video_controls.dart`, `lib/core/posts/details/src/widgets/post_details_controller.dart`.

### P12 · Hover Preview Opens Only from Info Badge; Preserve Long Press

**Status:** **APPROVED** (2026-10-16; implementation pending). **Risk:** High.

- **Approved resolution (summary):** Open hover previews only through a dedicated info badge; preserve long press, right click, selection/drag, click-through safeguards and keyboard access.
- **Upstream change:** Moves hover preview from whole thumbnail to Info badge, closes it on keypress and repairs long press/right click menus.
- **Fork divergence / merge hazard:** The fork has hold-and-drag selection, context menus and customized grid cards.
- **Original review question:** Where should the badge appear with two quick actions or Series cards?
- **Binding decision, migration conditions and tests:** [P12](decisions.md#p12--hover-preview-opens-only-from-info-badge-preserve-long-press). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`e04b3bfd1`](https://github.com/khoadng/Boorusama/commit/e04b3bfd186e8b5b88ab704189e23178ae26d098), [`5da94c1df`](https://github.com/khoadng/Boorusama/commit/5da94c1dfa6a39ef34c21c6ba1d171267ee06928), [`5feaa3dcf`](https://github.com/khoadng/Boorusama/commit/5feaa3dcf0a5069afab3f95594b3935fe08f7150).
- **Affected code paths (examples):** `lib/core/posts/listing/src/widgets/post_preview.dart`, `lib/core/posts/listing/src/_internal/raw_post_grid.dart`.

### P13 · Migrate Post/Tag Context Menus to Kurumi

**Status:** **APPROVED** (2026-10-16; implementation pending). **Risk:** High.

- **Approved resolution (summary):** Migrate menus while retaining fork favorite, bookmark group, Following, selection, nested menu and dismissal actions with no tap-through.
- **Upstream change:** Replaces old context menus with Kurumi and adjusts popup sizing in the tag cloud.
- **Fork divergence / merge hazard:** The fork extends CustomContextMenuOverlay, bookmark group/Following actions and menu dismiss behavior.
- **Original review question:** How can Kurumi be one menu system without losing fork actions or shortcuts?
- **Binding decision, migration conditions and tests:** [P13](decisions.md#p13--migrate-posttag-context-menus-to-kurumi). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`8ca15fcff`](https://github.com/khoadng/Boorusama/commit/8ca15fcff2e461488bc4ced314700196d421deb5), [`1e480b775`](https://github.com/khoadng/Boorusama/commit/1e480b7751a359931c53057e86a42ff56a1c6672).
- **Affected code paths (examples):** `lib/core/posts/post/src/context_menu.dart`, `lib/core/widgets/custom_context_menu_overlay.dart`, `packages/kurumi/lib/src/components/context_menu.dart`.
- **Confirmed merge conflicts in:** `packages/kurumi/lib/src/components/context_menu.dart`.

### P14 · Keyboard Focus on Quick Favorite/Bookmark Buttons

**Status:** **APPROVED** (2026-10-16; implementation pending). **Risk:** Medium.

- **Approved resolution (summary):** Ensure visible quick favorite/bookmark buttons support focus and Enter/Space; preserve selection precedence and tile controls.
- **Upstream change:** Makes small interactive thumbnail overlays keyboard reachable.
- **Fork divergence / merge hazard:** The fork owns thumbnail actions and post selection behavior.
- **Original review question:** What is the focus order for a tile with up to two quick actions?
- **Binding decision, migration conditions and tests:** [P14](decisions.md#p14--keyboard-focus-on-quick-favoritebookmark-buttons). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`d1047aa89`](https://github.com/khoadng/Boorusama/commit/d1047aa890c64b3baa575e0ca16f50b4724e6826).
- **Affected code paths (examples):** `lib/core/posts/listing`, `packages/kurumi/lib/src/components`.

## Search, Interaction, Desktop and TV

### U01 · Keep Search Usable Above the Software Keyboard

**Status:** **APPROVED** (2026-10-16; implementation pending). **Risk:** High.

- **Approved resolution (summary):** Keep compact tags, single-term Raw Editor and suggestions usable with keyboard open, narrow screens, changing insets and automatic search.
- **Upstream change:** Improves search layout and suggestion overlays when the software keyboard is open.
- **Fork divergence / merge hazard:** The fork is building a compact search bar, per-term Raw Editor and tag suggestions.
- **Original review question:** How should suggestions and Raw Editor behave with very little screen height?
- **Binding decision, migration conditions and tests:** [U01](decisions.md#u01--keep-search-usable-above-the-software-keyboard). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`a00d41f3a`](https://github.com/khoadng/Boorusama/commit/a00d41f3a7a1e81954e718ab1144183426a1ab89).
- **Affected code paths (examples):** `lib/core/search/search/src/widgets/search_page_scaffold.dart`, `lib/core/search/search/src/widgets/booru_search_bar.dart`.
- **Confirmed merge conflicts in:** `lib/core/search/search/src/widgets/search_page_scaffold.dart`.

### U02 · Search History as a Full-Height Sheet and Tests

**Status:** **APPROVED** (2026-10-16; implementation pending). **Risk:** Medium.

- **Approved resolution (summary):** Use scroll-controlled history sheet, preserving search state, keyboard, profile switching and correct query selection.
- **Upstream change:** Allows Search History sheet to use available full height and adds a journey test.
- **Fork divergence / merge hazard:** The fork adds Pinned Searches and Following and is redesigning search.
- **Original review question:** What sheet size/entry point fits the new Search bar?
- **Binding decision, migration conditions and tests:** [U02](decisions.md#u02--search-history-as-a-full-height-sheet-and-tests). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`e53cdf3b3`](https://github.com/khoadng/Boorusama/commit/e53cdf3b31560cd4607431381b316b8e29349b11), [`3726d75c7`](https://github.com/khoadng/Boorusama/commit/3726d75c7eb14ea170e06e497b09198f4a9c4c71).
- **Affected code paths (examples):** `lib/core/search/histories`, `test/application/search_history_flow_test.dart`.

### U03 · Keyboard Highlight and Selection for Tag Suggestions

**Status:** **APPROVED** (2026-10-16; implementation pending). **Risk:** High.

- **Approved resolution (summary):** Up/Down highlights, Enter selects, Escape clears highlight first; keep focus in the input, use listbox semantics and preserve per-term Raw Editor.
- **Upstream change:** Uses one focus ring around search, keyboard highlights suggestions, blocks leaked keys to hidden pages and adds raw-query flow tests.
- **Fork divergence / merge hazard:** The fork plans shared tag/metatag suggestions and individual editable search chips.
- **Original review question:** Should Up/Down/Enter/Escape behavior match on phone and desktop?
- **Binding decision, migration conditions and tests:** [U03](decisions.md#u03--keyboard-highlight-and-selection-for-tag-suggestions). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`f7174bab4`](https://github.com/khoadng/Boorusama/commit/f7174bab405360103c48659b1c5bb72cbcd2bd61), [`e1ad37e1e`](https://github.com/khoadng/Boorusama/commit/e1ad37e1eddbb12106930e2ec983536863b5511b), [`7f5693c84`](https://github.com/khoadng/Boorusama/commit/7f5693c847ea0a88acb1fd12ff05057e0a6e5bb5).
- **Affected code paths (examples):** `lib/core/search/search`, `packages/kurumi/lib/src/components/search_bar.dart`.

### U04 · App-Wide D-Pad and Keyboard Navigation

**Status:** **APPROVED** (2026-10-16; implementation pending). **Risk:** Medium-high.

- **Approved resolution (summary):** Add cross-scope focus movement, keyboard-only focus rings and scroll reveal; touch/mouse unchanged. TV is best-effort only.
- **Upstream change:** Adds directional focus, focus rings, accessible dialogs/menus/layout manager/original viewer and keyboard/TV flow tests.
- **Fork divergence / merge hazard:** The fork targets touch/mobile and has its own pane/sidebar navigation.
- **Original review question:** Official TV support or best effort, and when are focus rings shown?
- **Binding decision, migration conditions and tests:** [U04](decisions.md#u04--app-wide-d-pad-and-keyboard-navigation). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`e80eb1210`](https://github.com/khoadng/Boorusama/commit/e80eb1210a2327dfae4eba4866a1e7cfe472dfd8), [`00feb4d99`](https://github.com/khoadng/Boorusama/commit/00feb4d9923b49a931b7b0a24a9ac6f262214cc0), [`1e3b00c3a`](https://github.com/khoadng/Boorusama/commit/1e3b00c3a8e9c9cc43b947bb42501c2e33b30bf0), [`41d0121ce`](https://github.com/khoadng/Boorusama/commit/41d0121cee07c3533042f86e0b256663a9f7134d), [`7895ce70e`](https://github.com/khoadng/Boorusama/commit/7895ce70e7b520ddd8cefe3ef640de3679ee4fde).
- **Affected code paths (examples):** `packages/kurumi/lib/src/components/focus_ring.dart`, `lib/core/app.dart`.
- **Confirmed merge conflicts in:** `lib/core/app.dart`.

### U05 · Desktop Tab Order and Focus Boundaries

**Status:** **APPROVED** (2026-10-16; implementation pending). **Risk:** Medium.

- **Approved resolution (summary):** Group sidebar, Settings and viewer controls into predictable Tab/Shift-Tab regions, excluding hidden controls and returning focus after dismissal.
- **Upstream change:** Improves pane Tab order, focus-ring input modality, visible Explore/Viewer targets, arrow traversal and mouse focus updates.
- **Fork divergence / merge hazard:** The fork has custom sidebar, settings and viewer navigation.
- **Original review question:** Which FocusScopes make sense around sidebar, profiles, search, posts and dialogs?
- **Binding decision, migration conditions and tests:** [U05](decisions.md#u05--desktop-tab-order-and-focus-boundaries). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`a555bbb3d`](https://github.com/khoadng/Boorusama/commit/a555bbb3db20d9b8c29c3c1b7d87c2b0d8546d20), [`e95a71f85`](https://github.com/khoadng/Boorusama/commit/e95a71f85d7982a797a89b0879a42e1c55d46253), [`5f57df699`](https://github.com/khoadng/Boorusama/commit/5f57df699e940fb8256aa74bdac46d2979246141), [`58254b441`](https://github.com/khoadng/Boorusama/commit/58254b441040ec4c6187018a46c4366511e3e7f0), [`84286ddc1`](https://github.com/khoadng/Boorusama/commit/84286ddc1e3da8e7cae71783c5e21641015635ae), [`d7041c4d4`](https://github.com/khoadng/Boorusama/commit/d7041c4d42b3470c45ab4ed29bbe1e3e73093aa8), [`f31f551be`](https://github.com/khoadng/Boorusama/commit/f31f551bedd31b2c75fcddf354e682b07bae5e69).
- **Affected code paths (examples):** `packages/kurumi`, `lib/core/posts`, `lib/core/settings`.

### U06 · Escape Handling, Menu Selection and Layer Hierarchy

**Status:** **APPROVED** (2026-10-16; implementation pending). **Risk:** Medium-high.

- **Approved resolution (summary):** Close exactly the innermost menu, popover, dialog, search or selection state before routing; preserve modal guards and focus restoration.
- **Upstream change:** Closes anchored menus with Escape, highlights keyboard-selected menu rows and dismisses the innermost Kurumi layer first.
- **Fork divergence / merge hazard:** The fork uses custom context menus, navigation and multiselection.
- **Original review question:** What is the popup → sheet → search → selection → screen priority with Android Back?
- **Binding decision, migration conditions and tests:** [U06](decisions.md#u06--escape-handling-menu-selection-and-layer-hierarchy). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`3ff8b054e`](https://github.com/khoadng/Boorusama/commit/3ff8b054e558c77fd94a0419b33526d7e6d9c829), [`b925a581b`](https://github.com/khoadng/Boorusama/commit/b925a581bd361ca710d27a3e95c1eb315f9be62f), [`2d6d9f6e6`](https://github.com/khoadng/Boorusama/commit/2d6d9f6e6dacf60a52f8d0b62e7d27b8318b707c), [`76a8485de`](https://github.com/khoadng/Boorusama/commit/76a8485de122438d3f70c74de5c69bd1c8ea8987).
- **Affected code paths (examples):** `packages/kurumi/lib/src/components/popup_menu.dart`, `lib/core/router.dart`.
- **Confirmed merge conflicts in:** `packages/kurumi/lib/src/components/popup_menu.dart`.

### U07 · Favorite Tags Editor as Dialog on Large Screens

**Status:** **APPROVED** (2026-10-16; implementation pending). **Risk:** Low-medium.

- **Approved resolution (summary):** Use keyboard-safe bottom sheet on phones and scrollable roughly 520px dialog on large screens; preserve chips, validation and advanced settings.
- **Upstream change:** Uses a dialog for favorite-tag editing on wide screens and a bottom sheet on phones.
- **Fork divergence / merge hazard:** The fork already extends Favorite Tag management with label actions.
- **Original review question:** Which breakpoints/modals fit existing fork design?
- **Binding decision, migration conditions and tests:** [U07](decisions.md#u07--favorite-tags-editor-as-dialog-on-large-screens). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`20e750618`](https://github.com/khoadng/Boorusama/commit/20e750618847bbb0a84391cca0b2440667ab18e7).
- **Affected code paths (examples):** `lib/core/tags/favorites/src/pages/edit_favorite_tag_sheet.dart`.

### U08 · Update Regression Tests and Remove Timing Flakiness

**Status:** **APPROVED** (2026-10-16; implementation pending). **Risk:** Low.

- **Approved resolution (summary):** Update info-badge-hover and bulk-download lifecycle tests with controlled completion rather than fixed sleeps; ship with affected features.
- **Upstream change:** Updates hover-preview tests and removes fragile timing assumptions in bulk dry-run tests.
- **Fork divergence / merge hazard:** The fork already has deterministic test/runner improvements.
- **Original review question:** How should these test intentions fit new UI and controlled clocks?
- **Binding decision, migration conditions and tests:** [U08](decisions.md#u08--update-regression-tests-and-remove-timing-flakiness). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`71b41b8a0`](https://github.com/khoadng/Boorusama/commit/71b41b8a0f5574975f1cae673ac9cedde5b594ed).
- **Affected code paths (examples):** `test/application`, `test/bulk_downloads`.

## Cross-Cutting Fork Safeguards

### X01 · Bookmark Hive Field Index / Original Site Post ID

**Status:** **APPROVED** (2026-10-15; implementation pending). **Risk:** Critical.

- **Approved resolution (summary):** Retain fork Hive fields 15=snapshotSchemaVersion, 16=postSnapshot; derive genuine site IDs rather than adopting upstream's incompatible index-15 string field.
- **Upstream change:** Introduces BookmarkHiveObject.sitePostId at **Hive field index 15**.
- **Fork divergence / merge hazard:** The fork already uses index 15 for snapshotSchemaVersion and index 16 for postSnapshot; upstream's generated adapter cannot be copied unchanged.
- **Original review question:** How can true IDs be exposed without breaking stored bookmark formats?
- **Binding decision, migration conditions and tests:** [X01](decisions.md#x01--bookmark-hive-field-index--original-site-post-id). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`216eb6e6d`](https://github.com/khoadng/Boorusama/commit/216eb6e6d43cef2581a110b66a8f1482d110e7b9).
- **Affected code paths (examples):** `lib/core/bookmarks/src/data/hive/bookmark_hive_object.dart`, `lib/core/hive/hive_adapters.g.yaml`.
- **Confirmed merge conflicts in:** `lib/core/bookmarks/src/data/hive/bookmark_hive_object.dart`, `lib/core/hive/hive_adapters.g.yaml`.

### X02 · Post Identity/Origin versus Upstream sitePostId

**Status:** **APPROVED** (2026-10-15; implementation pending). **Risk:** Critical.

- **Approved resolution (summary):** Provide a nullable genuine Post.sitePostId, including alphanumeric Sankaku and original Pixiv IDs; never confuse synthetic app IDs with site IDs, and preserve fork origin/snapshot/identity.
- **Upstream change:** Adds a source-specific sitePostId getter to Post and exports the value.
- **Fork divergence / merge hazard:** The fork uses PostOrigin, StoredPostSnapshot, BookmarkIdentity, profile UUIDs and one unified post pipeline.
- **Original review question:** How should original site ID interact with persistent identity without conflating different sites?
- **Binding decision, migration conditions and tests:** [X02](decisions.md#x02--post-identityorigin-versus-upstream-sitepostid). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`216eb6e6d`](https://github.com/khoadng/Boorusama/commit/216eb6e6d43cef2581a110b66a8f1482d110e7b9).
- **Affected code paths (examples):** `lib/core/posts/post/src/types/post.dart`, `lib/core/posts/post/src/types/post_origin.dart`.
- **Confirmed merge conflicts in:** `lib/core/posts/post/src/types/post.dart`.

### X03 · Preserve Fork Export/Import, Profile UUIDs and Following

**Status:** **APPROVED** (2026-10-15; implementation pending). **Risk:** Critical.

- **Approved resolution (summary):** Keep fork profiles/UUIDs, backup/import, BookmarkIdentity, post snapshots, nested bookmark/pinned-search folders, Following, refresh and recovery gates; adopt only compatible upstream test seams.
- **Upstream change:** Changes app initialization, backup sources and bookmark providers alongside new tests.
- **Fork divergence / merge hazard:** The fork has redesigned backup/import, UUID profiles, nested bookmark/pinned-search folders and Following feeds.
- **Original review question:** Which upstream resolutions must never replace these fork-only features?
- **Binding decision, migration conditions and tests:** [X03](decisions.md#x03--preserve-fork-exportimport-profile-uuids-and-following). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`a3278c5d2`](https://github.com/khoadng/Boorusama/commit/a3278c5d2ecc3672fea63c68fb21c81a1db2bb07), [`3f4ce2bd4`](https://github.com/khoadng/Boorusama/commit/3f4ce2bd4f0f94c116b2262fa9418809710278a8), [`f93bdf0dd`](https://github.com/khoadng/Boorusama/commit/f93bdf0dd42c5eb0e8165d9070310a2aebfa32c1).
- **Affected code paths (examples):** `lib/core/backups/export_import`, `lib/core/search/subscriptions`, `lib/core/configs`, `lib/core/bookmarks`.

### X04 · Shared Post/Image Cache and Download Lifecycle

**Status:** **APPROVED** (2026-10-15; implementation pending). **Risk:** Critical.

- **Approved resolution (summary):** Remove image-cache generations but retain URL-MD5, origin isolation, LRU, quotas, journal/checkpoints and safe parallel writes; copy images to OS temporary space for sharing.
- **Upstream change:** Changes media hosts, download, video/cache, post refresh and image components.
- **Fork divergence / merge hazard:** The fork has a persistent shared LRU cache, checkpoints, origin isolation and custom download observers.
- **Original review question:** Which subsystem owns cache keys, quotas, lifetime and deduplication after the merge?
- **Binding decision, migration conditions and tests:** [X04](decisions.md#x04--shared-postimage-cache-and-download-lifecycle). This catalog supplements the authoritative English decision log.
- **Upstream commits:** [`1e6a6607d`](https://github.com/khoadng/Boorusama/commit/1e6a6607dc7750a5c1e94d44531f8251fface3c6), [`86a16a20e`](https://github.com/khoadng/Boorusama/commit/86a16a20ee1327740316005b7946b8264fa70a19), [`cb5f9fade`](https://github.com/khoadng/Boorusama/commit/cb5f9fade8ed5c7e26d3f0811ef17f7187f73723), [`2003c0c1e`](https://github.com/khoadng/Boorusama/commit/2003c0c1eb2cf6b3ef0939b33adf1b575fcae8f9), [`828ddbdb7`](https://github.com/khoadng/Boorusama/commit/828ddbdb75afd02fe14cf8182774a3ef67c9128f), [`f3d8acaa0`](https://github.com/khoadng/Boorusama/commit/f3d8acaa0a765b6d2957ddd36f68a1aa944fa328), [`0f71409de`](https://github.com/khoadng/Boorusama/commit/0f71409dea3775ae1dd033bcf7fc27bb008888a0).
- **Affected code paths (examples):** `lib/core/images`, `lib/core/cache`, `lib/core/posts`, `lib/core/downloads`.

## Appendix A — Complete Mapping of 150 Upstream Commits

Every commit is listed in upstream order and mapped to at least one decision item. Commit links support source inspection. Commits assigned to multiple IDs span several subsystems, and subsequent reverts are identified.

| No. | SHA | Commit subject | Related item(s) |
|---:|---|---|---|
| 1 | [`480810b11`](https://github.com/khoadng/Boorusama/commit/480810b11a5a66b24be40bc8a80a2a56e681b90c) | feat: add more logging for ddos solver | A08 |
| 2 | [`1e6a6607d`](https://github.com/khoadng/Boorusama/commit/1e6a6607dc7750a5c1e94d44531f8251fface3c6) | feat(settings): show cache locations and expose Android caches in Files | A09, X04 |
| 3 | [`3bd433423`](https://github.com/khoadng/Boorusama/commit/3bd4334235a091c51e680c28ea852d3d07571a02) | feat(debug): add credential redaction and persistent sensitive log capture | A07 |
| 4 | [`669b8019f`](https://github.com/khoadng/Boorusama/commit/669b8019f80eaf8d0f40e268bbf8a29dc0808ddf) | fix: bump bg downloader version | D03 |
| 5 | [`0def24717`](https://github.com/khoadng/Boorusama/commit/0def247178cedd1a058c3695a09b3c159ec3577d) | feat(debug): add typed protection diagnostics | A08 |
| 6 | [`72702e711`](https://github.com/khoadng/Boorusama/commit/72702e7110892d046826b53a25a70c39c1e72d56) | fix: make libavif web aware | A18 |
| 7 | [`86a16a20e`](https://github.com/khoadng/Boorusama/commit/86a16a20ee1327740316005b7946b8264fa70a19) | feat(downloads): support tags and JSON metadata sidecars | D01, X04 |
| 8 | [`ebdfb05d9`](https://github.com/khoadng/Boorusama/commit/ebdfb05d9bec5be5c6fd6dd3e5460cea8ce1e1a1) | Revert "fix(downloads): finalize bulk activity deterministically" | D02 |
| 9 | [`c2d3b109e`](https://github.com/khoadng/Boorusama/commit/c2d3b109ef0e2124273858b17ed577e8bdaa1add) | fix: default to false for hide app preview | A06 |
| 10 | [`54b19cd4c`](https://github.com/khoadng/Boorusama/commit/54b19cd4cf77b3a75579a2b27aeccc1b1dc56ef5) | fix(downloads): preserve bulk completion notifications after session cleanup | D02 |
| 11 | [`2d4f8484b`](https://github.com/khoadng/Boorusama/commit/2d4f8484ba62db8e5c5386825934b1bcc30455cf) | fix(shimmie2): resolve media formats and restore favorite state | B06 |
| 12 | [`434a2e516`](https://github.com/khoadng/Boorusama/commit/434a2e516ecae2ce236d4c7592af62961e182a87) | fix(debug): capture full logs by default and make credential redaction optional | A07 |
| 13 | [`948af9448`](https://github.com/khoadng/Boorusama/commit/948af94483b7662d1de9a0fbfea7381019cd821a) | feat(debug): highlight log URLs and status codes with readable query parameters | A07 |
| 14 | [`d13fe53a3`](https://github.com/khoadng/Boorusama/commit/d13fe53a3b8cbbba481b4d2d436b124009941b8f) | feat: make log entry copiable | A07 |
| 15 | [`cb5f9fade`](https://github.com/khoadng/Boorusama/commit/cb5f9fade8ed5c7e26d3f0811ef17f7187f73723) | feat: add per-profile media host overrides | N02, X04 |
| 16 | [`afdff42e3`](https://github.com/khoadng/Boorusama/commit/afdff42e344a585439bef34893bc2cbaa8e706df) | fix(images): restore tap-to-retry for custom error widgets | P03 |
| 17 | [`70b523938`](https://github.com/khoadng/Boorusama/commit/70b5239384cc86fba7c479c7ce688076508575cf) | fix(retriable): honor Retry-After and configured retry policies | N01 |
| 18 | [`26ad35202`](https://github.com/khoadng/Boorusama/commit/26ad352026bb4187e399dfab422c76427aca8655) | feat: support two adaptive thumbnail quick actions per profile | P01 |
| 19 | [`216eb6e6d`](https://github.com/khoadng/Boorusama/commit/216eb6e6d43cef2581a110b66a8f1482d110e7b9) | fix: preserve site post IDs in exports and handle Sankaku metatag suggestions | D07, B01, X01, X02 |
| 20 | [`2569eaeeb`](https://github.com/khoadng/Boorusama/commit/2569eaeeb6ea01ea35386ffc8bab858dcbd1d75d) | feat: add Sankaku metatag highlighting and typed search suggestions | B01 |
| 21 | [`deca1064a`](https://github.com/khoadng/Boorusama/commit/deca1064aa68abcbbb1683408f305558bef08ee3) | fix: serialize rate-limit admission and support Retry-After cooldowns | N01 |
| 22 | [`c5b79488c`](https://github.com/khoadng/Boorusama/commit/c5b79488c8d90b624cb17e8452d3b17e099be88f) | feat: enable Anime-Pictures bulk downloads with request pacing | D05 |
| 23 | [`18216f412`](https://github.com/khoadng/Boorusama/commit/18216f4123586634f0756e7d5b20673638711766) | fix: explain Sankaku exclusion search restrictions | B02 |
| 24 | [`6ad672075`](https://github.com/khoadng/Boorusama/commit/6ad672075306e5621a4dde519ad124da0b19f8cb) | fix: normalize Sankaku single-date searches to day ranges | B02 |
| 25 | [`de755c0d2`](https://github.com/khoadng/Boorusama/commit/de755c0d20570d4c9e2c6d4b718517514178af44) | fix: consume volume keys used for viewer navigation | P10 |
| 26 | [`bdec763aa`](https://github.com/khoadng/Boorusama/commit/bdec763aa3e7d36d774b2f64b7963f79329f9bdd) | l10n: translations update from Hosted Weblate (#693) | A11 |
| 27 | [`0adc367df`](https://github.com/khoadng/Boorusama/commit/0adc367df3c9a3862e9663049e1af0d90bf60d21) | docs: update changelog | A16 |
| 28 | [`08088842c`](https://github.com/khoadng/Boorusama/commit/08088842c880bd124715e3d76b73c24945d8ea9a) | ci: update release builds to Flutter 3.44.6 | A14 |
| 29 | [`9ba59d05b`](https://github.com/khoadng/Boorusama/commit/9ba59d05b80c07b03e7e8696ee4c4ed8d068f14b) | fix(l10n): remove unsued keys | A11 |
| 30 | [`0ed1a49df`](https://github.com/khoadng/Boorusama/commit/0ed1a49df6e07787e89366ca931dd2f7b3504eef) | fix: keep widget tree stable | A03 |
| 31 | [`2003c0c1e`](https://github.com/khoadng/Boorusama/commit/2003c0c1eb2cf6b3ef0939b33adf1b575fcae8f9) | fix: keep video thumbnail visible until the first frame renders | P07, X04 |
| 32 | [`dbfe54fc4`](https://github.com/khoadng/Boorusama/commit/dbfe54fc432738bcf59ee9179a9089f629d620bf) | ci: install native build tools for release builds | A14 |
| 33 | [`430747c1a`](https://github.com/khoadng/Boorusama/commit/430747c1af0153672863213a03f25c082a29e204) | ci: enable Git long paths for Windows dependencies | A14 |
| 34 | [`402c4eb67`](https://github.com/khoadng/Boorusama/commit/402c4eb67a1052ab1841592c4eeb5a6967de071c) | ci: support Windows-only runs with native build diagnostics | A14 |
| 35 | [`a9821d53e`](https://github.com/khoadng/Boorusama/commit/a9821d53eb413ea46374ab09b07668b4ebe766f5) | ci: use Visual Studio CMake for Windows native builds | A14 |
| 36 | [`914ee5fa5`](https://github.com/khoadng/Boorusama/commit/914ee5fa51d33eeaa69ba8dc8c6dde171fadad58) | ci: exclude Strawberry compiler tools from Windows builds | A14 |
| 37 | [`899aabf6a`](https://github.com/khoadng/Boorusama/commit/899aabf6a26c22e438750319b74ac463a4af19ee) | ci: expose installed NASM and preserve build tool paths | A14 |
| 38 | [`df4f705d8`](https://github.com/khoadng/Boorusama/commit/df4f705d810f2cdfc2f009c6d6082ab5fb61d2df) | fix: reuse stuff | A14 |
| 39 | [`408666ef5`](https://github.com/khoadng/Boorusama/commit/408666ef55f2b20f2e65d7eee21dcb01b0f018ca) | feat(settings): make app and booru settings searchable | A05 |
| 40 | [`a9c31322b`](https://github.com/khoadng/Boorusama/commit/a9c31322bd4d60761218bedfd317ef18f8b69359) | docs: update changelog | A16 |
| 41 | [`ffd7e47c5`](https://github.com/khoadng/Boorusama/commit/ffd7e47c5840a922b1c885d415a28984a6bf978a) | docs: update changelog | A16 |
| 42 | [`9f8ab7bca`](https://github.com/khoadng/Boorusama/commit/9f8ab7bcab67048be3bb865b98c47203d7b121b2) | chore: migrate to Flutter 3.47 | A02 |
| 43 | [`e7745aca8`](https://github.com/khoadng/Boorusama/commit/e7745aca83af95f38ac1d2e3f58fa23bf0b92234) | refactor(ui): migrate to standalone Material and Cupertino packages | A02 |
| 44 | [`6adb28be9`](https://github.com/khoadng/Boorusama/commit/6adb28be97b67181a1641df28d9b0c490e4e3f47) | refactor(ui): replace legacy UI dependencies with Kurumi components | A02 |
| 45 | [`d13da93a3`](https://github.com/khoadng/Boorusama/commit/d13da93a3a6e2a8d9299d5a0ef91dd00422aa303) | l10n: translated using Weblate (Portuguese (Brazil)) | A11 |
| 46 | [`a891266bb`](https://github.com/khoadng/Boorusama/commit/a891266bb668caa65f846db9ee40f9b35c840c9e) | l10n: translated using Weblate (Indonesian) | A11 |
| 47 | [`a3278c5d2`](https://github.com/khoadng/Boorusama/commit/a3278c5d2ecc3672fea63c68fb21c81a1db2bb07) | refactor: make the app headless friendly | A01, X03 |
| 48 | [`cfb231254`](https://github.com/khoadng/Boorusama/commit/cfb231254634c8ef96873847c43f5983a5ea27ed) | style: format all | A17 |
| 49 | [`ab78dc3e3`](https://github.com/khoadng/Boorusama/commit/ab78dc3e338514bd39f2ce678ade2abd2c82b133) | chore: cleanup | A17 |
| 50 | [`685db1ad5`](https://github.com/khoadng/Boorusama/commit/685db1ad56712e00d4ef8dfe438114948ba6e86e) | Revert "feat(settings): make app and booru settings searchable" | A05 |
| 51 | [`1f2e90060`](https://github.com/khoadng/Boorusama/commit/1f2e90060765be4369a689522c463f740f254197) | feat(settings): add responsive navigation | A04 |
| 52 | [`ee38cd592`](https://github.com/khoadng/Boorusama/commit/ee38cd592b4d6960d49025a52de433930b7441e7) | style: format all | A17 |
| 53 | [`bc63321ec`](https://github.com/khoadng/Boorusama/commit/bc63321ec125c5d54da165c9977580cdea46448f) | docs: update changelog | A16 |
| 54 | [`d3f3a62fa`](https://github.com/khoadng/Boorusama/commit/d3f3a62fa40fc7eadd2a63cd32e145f9cd3d5acd) | build(nix): add NixOS package and development environment | A13 |
| 55 | [`d1e7c99b4`](https://github.com/khoadng/Boorusama/commit/d1e7c99b4895404548a426274e076b3710d84f79) | fix(build): retry Flutter after native asset changes | A14 |
| 56 | [`87a4fae44`](https://github.com/khoadng/Boorusama/commit/87a4fae4463529474a9d161fdd45fa2047831986) | fix(build): retry repeated Flutter native asset changes | A14 |
| 57 | [`038d1287c`](https://github.com/khoadng/Boorusama/commit/038d1287c04a260faea85e360c98f4baffb8fd97) | fix(nix): handle immutable native asset inputs | A13 |
| 58 | [`e16ecd2c3`](https://github.com/khoadng/Boorusama/commit/e16ecd2c35236880eea7be4c27e3f957c6609143) | fix(nix): bundle fonts for Linux runtime | A13 |
| 59 | [`2d621b683`](https://github.com/khoadng/Boorusama/commit/2d621b68335a62337075b53289f1f986f0631fcf) | fix(nix): shorten embedded revision on ARM64 | A13 |
| 60 | [`047a5a09e`](https://github.com/khoadng/Boorusama/commit/047a5a09e5e2ff397f23eee21f1cd54672cc80a2) | fix(nix): preload bundled fonts before startup | A13 |
| 61 | [`50980b8da`](https://github.com/khoadng/Boorusama/commit/50980b8da1368aa39a44051c78dee12dd4dff2ce) | feat(zerochan): reenable bulk download | D06 |
| 62 | [`c184be942`](https://github.com/khoadng/Boorusama/commit/c184be94249a3768e4f4d672517230c62acfb7ae) | fix(build): discard failed Flutter platform output | A14 |
| 63 | [`db33523ff`](https://github.com/khoadng/Boorusama/commit/db33523ff960712518c3c3482e33f8d9b33048b6) | Revert "fix(build): discard failed Flutter platform output" | A14 |
| 64 | [`4c6138377`](https://github.com/khoadng/Boorusama/commit/4c6138377f9d5357b986584b8aee75d0b8d5dd66) | fix(platform): handle unsupported WebView features | A10 |
| 65 | [`02a28fe7d`](https://github.com/khoadng/Boorusama/commit/02a28fe7d7e94c12a94c926442681cc8d569e2d5) | Merge pull request #701 from weblate/weblate-boorusama-app | A11 |
| 66 | [`c22d22e0d`](https://github.com/khoadng/Boorusama/commit/c22d22e0dfe9f3f521a3e495fafa69ba00d07364) | ci: add all-platform smoke run option | A14 |
| 67 | [`f94243dcc`](https://github.com/khoadng/Boorusama/commit/f94243dccad0eace17d674df43934424ca591f39) | ci: centralize release toolchain setup | A14 |
| 68 | [`d0fde834a`](https://github.com/khoadng/Boorusama/commit/d0fde834a413658bb50db150636c481c88a88222) | fix(sankaku): preserve all post tag categories | B03 |
| 69 | [`b55d1adde`](https://github.com/khoadng/Boorusama/commit/b55d1addecaf59fb36cd72d5f5e6e5b75b629f84) | fix(android): enable non-final resource ids | A14 |
| 70 | [`396ae059e`](https://github.com/khoadng/Boorusama/commit/396ae059e9e5576aa0172df7fabf823963c03e92) | fix(sankaku): deduplicate post tags | B03 |
| 71 | [`829ec71fb`](https://github.com/khoadng/Boorusama/commit/829ec71fbaedbc60fff7d98fe1b40c494a130ebe) | fix(sankaku): preserve client options when applying API headers | B04 |
| 72 | [`6ad691a6d`](https://github.com/khoadng/Boorusama/commit/6ad691a6de23d8a44c46d02bf3640997dbb618f4) | fix(sankaku): reject invalid authentication responses | B04 |
| 73 | [`5b495f1ad`](https://github.com/khoadng/Boorusama/commit/5b495f1adec13643ee83307bb2b68eb0272766b2) | fix(sankaku): clarify search tag limit errors | B05 |
| 74 | [`6762d00f2`](https://github.com/khoadng/Boorusama/commit/6762d00f2e4ac6efc99bf969bd15a335f6767437) | fix(sankaku): recover from expired authentication | B04 |
| 75 | [`f459e9922`](https://github.com/khoadng/Boorusama/commit/f459e99220e4ac5b449c033d1d60a0b672ea2b58) | feat(gelv2): add comment voting and cursor pagination | B07 |
| 76 | [`43619dd49`](https://github.com/khoadng/Boorusama/commit/43619dd495d5cb79425845521f0a0e0de030670d) | feat(gelv2): add comment sorting | B08 |
| 77 | [`58e4a0607`](https://github.com/khoadng/Boorusama/commit/58e4a06075faa8c07d8129dfdfa19156a4981a50) | fix: remove tap to retry implicit behavior | P03 |
| 78 | [`8d8ca771b`](https://github.com/khoadng/Boorusama/commit/8d8ca771b393d18f31e21e21881f22f142179397) | feat: add webview support for window | A10 |
| 79 | [`828ddbdb7`](https://github.com/khoadng/Boorusama/commit/828ddbdb75afd02fe14cf8182774a3ef67c9128f) | fix(posts): queue refresh requested during in-flight fetch | P04, X04 |
| 80 | [`485a728c9`](https://github.com/khoadng/Boorusama/commit/485a728c9802680b480ee949123624d6101cb463) | fix(kurumi): prevent side menu title overflow | A03 |
| 81 | [`bd2e22c22`](https://github.com/khoadng/Boorusama/commit/bd2e22c221bcfb1a8c8c0675afbab6763a3102c9) | refactor(download-manager): add injectable task client | D04 |
| 82 | [`90657ee4e`](https://github.com/khoadng/Boorusama/commit/90657ee4ed73f9a4bf7f2277ed1750e2f8b5d4ff) | fix(download-manager): copy task list before updating | D04 |
| 83 | [`3f4ce2bd4`](https://github.com/khoadng/Boorusama/commit/3f4ce2bd4f0f94c116b2262fa9418809710278a8) | fix(bookmarks): refresh library after bookmark changes | P05, X03 |
| 84 | [`c22d12fd6`](https://github.com/khoadng/Boorusama/commit/c22d12fd678db968af1356a21a3957ae3f3eda35) | test: add application flow suites | A12 |
| 85 | [`e4d645630`](https://github.com/khoadng/Boorusama/commit/e4d6456309c93f050b3a5d311ea4e2a60e0a7663) | fix(posts): respect gif autoplay setting at all image qualities | P06 |
| 86 | [`7880a020f`](https://github.com/khoadng/Boorusama/commit/7880a020fc7ba968351ee5256d3685c347d4eca0) | fix(nozomi): get tag counts from index sizes instead of search buckets | B09 |
| 87 | [`5a4498f78`](https://github.com/khoadng/Boorusama/commit/5a4498f78dbce67aa43c0d3d01c4fc8d31784a23) | fix(nozomi): request identity encoding for index range requests | B09 |
| 88 | [`86a7ee6bb`](https://github.com/khoadng/Boorusama/commit/86a7ee6bbee7a730f9b8931c01919191bd2ad0c3) | fix(http): enable larger HTTP/2 windows and gzip | N06 |
| 89 | [`62e36f7e5`](https://github.com/khoadng/Boorusama/commit/62e36f7e5c7d40a3b5daa383a7c67ca420cb1cd3) | chore(kurumi): vendor flutter interactive viewer 3.47.2 | P09 |
| 90 | [`c6b25213c`](https://github.com/khoadng/Boorusama/commit/c6b25213c3478abedf5c82c41dd9dd92a93a1bbe) | fix(kurumi): let page swipes win over unzoomed image pans | P09 |
| 91 | [`f3d8acaa0`](https://github.com/khoadng/Boorusama/commit/f3d8acaa0a765b6d2957ddd36f68a1aa944fa328) | fix(videos): play cached videos from file in webview | P08, X04 |
| 92 | [`889592e57`](https://github.com/khoadng/Boorusama/commit/889592e57f5f22962158c2d9123f1db05f836260) | fix(i18n): preserve full locale when switching languages | A11 |
| 93 | [`94aa56361`](https://github.com/khoadng/Boorusama/commit/94aa56361ad31a902e7382396e958d27244cda35) | fix(ddos): avoid replaying state-changing requests in challenge | N03 |
| 94 | [`99ee264db`](https://github.com/khoadng/Boorusama/commit/99ee264dbc2f9649d94b8757575e82b885623e0d) | fix(ddos): stop reopening challenges that leave the client blocked | N04 |
| 95 | [`e79abb5c0`](https://github.com/khoadng/Boorusama/commit/e79abb5c093aa7e1090653f2adf1b3e68b392328) | l10n: translations update from Hosted Weblate (#705) | A11 |
| 96 | [`72c27ed64`](https://github.com/khoadng/Boorusama/commit/72c27ed64b10290bd5e1877a5fbe342572a3948d) | fix(settings): polish responsive layout and navigation | A04 |
| 97 | [`e80eb1210`](https://github.com/khoadng/Boorusama/commit/e80eb1210a2327dfae4eba4866a1e7cfe472dfd8) | feat(tv): support remote and keyboard navigation | U04 |
| 98 | [`a00d41f3a`](https://github.com/khoadng/Boorusama/commit/a00d41f3a7a1e81954e718ab1144183426a1ab89) | fix(search): keep search usable above the soft keyboard | U01 |
| 99 | [`e53cdf3b3`](https://github.com/khoadng/Boorusama/commit/e53cdf3b31560cd4607431381b316b8e29349b11) | fix(search): open search history as a full-height sheet | U02 |
| 100 | [`3726d75c7`](https://github.com/khoadng/Boorusama/commit/3726d75c7eb14ea170e06e497b09198f4a9c4c71) | test(search): cover search history journeys | U02 |
| 101 | [`bcef3b5c1`](https://github.com/khoadng/Boorusama/commit/bcef3b5c1cf620ff3d67bfaef9e6d623391c3442) | fix(ddos): detect restyled cloudflare challenge pages | N04 |
| 102 | [`372dca51c`](https://github.com/khoadng/Boorusama/commit/372dca51c760bb0d070c2d4b54c20c0407648b6c) | fix: remove the redudant spacing | A17 |
| 103 | [`00feb4d99`](https://github.com/khoadng/Boorusama/commit/00feb4d9923b49a931b7b0a24a9ac6f262214cc0) | fix(tv): make menus, dialogs and layout manager remote friendly | U04 |
| 104 | [`1e3b00c3a`](https://github.com/khoadng/Boorusama/commit/1e3b00c3a8e9c9cc43b947bb42501c2e33b30bf0) | fix(tv): hide focus ring after pointer input and drop duplicate grid ring | U04 |
| 105 | [`41d0121ce`](https://github.com/khoadng/Boorusama/commit/41d0121cee07c3533042f86e0b256663a9f7134d) | fix(tv): make original image viewer reachable by remote | U04 |
| 106 | [`7895ce70e`](https://github.com/khoadng/Boorusama/commit/7895ce70e7b520ddd8cefe3ef640de3679ee4fde) | test(tv): cover blacklist edit, comments, viewer, phone and typed suggestions | U04 |
| 107 | [`f93bdf0dd`](https://github.com/khoadng/Boorusama/commit/f93bdf0dd42c5eb0e8165d9070310a2aebfa32c1) | fix(backup): export favorite tags from storage before UI initialization | D08, X03 |
| 108 | [`0b4dcfcc4`](https://github.com/khoadng/Boorusama/commit/0b4dcfcc40d22cff1464b34506a6b836f06d7586) | fix(ddos): retry with the clearance cookie the server accepts | N05 |
| 109 | [`0ad2e6465`](https://github.com/khoadng/Boorusama/commit/0ad2e646591aceac0ab726aec1213289e42311ac) | fix(ddos): read webview cookies through a native channel | N05 |
| 110 | [`dc7b9cee9`](https://github.com/khoadng/Boorusama/commit/dc7b9cee911f28049333546c56379be8c51d955a) | fix(ddos): accept cleared pages that embed captcha widgets | N04 |
| 111 | [`f82a62885`](https://github.com/khoadng/Boorusama/commit/f82a6288563d73e8da1943b7fed499d16f3611d7) | fix(ddos): accept cleared challenges redirected to a subdomain | N04 |
| 112 | [`3c72c200e`](https://github.com/khoadng/Boorusama/commit/3c72c200e1ecbf241feb09d1a3c932957720c84a) | style(browser): drop duplicate override annotation | A17 |
| 113 | [`a555bbb3d`](https://github.com/khoadng/Boorusama/commit/a555bbb3db20d9b8c29c3c1b7d87c2b0d8546d20) | fix(focus): keep Tab order within each pane on desktop | U05 |
| 114 | [`8ca15fcff`](https://github.com/khoadng/Boorusama/commit/8ca15fcff2e461488bc4ced314700196d421deb5) | refactor(context-menu): replace legacy context menus with kurumi | P13 |
| 115 | [`b0a1d65d9`](https://github.com/khoadng/Boorusama/commit/b0a1d65d9e60131f010491f38877cfd5e5df7b60) | fix(ddos): judge cloudflare pages by structure and explain network blocks | N04 |
| 116 | [`5972548ec`](https://github.com/khoadng/Boorusama/commit/5972548ecd6e32622b8476776490251d61d6a099) | fix: update post endpoint | B10 |
| 117 | [`e95a71f85`](https://github.com/khoadng/Boorusama/commit/e95a71f85d7982a797a89b0879a42e1c55d46253) | fix: hide focus ring until the user presses a key | U05 |
| 118 | [`f7174bab4`](https://github.com/khoadng/Boorusama/commit/f7174bab405360103c48659b1c5bb72cbcd2bd61) | fix(search): draw a single focus ring around the whole search bar | U03 |
| 119 | [`3ff8b054e`](https://github.com/khoadng/Boorusama/commit/3ff8b054e558c77fd94a0419b33526d7e6d9c829) | fix(menu): close anchored menus on Escape | U06 |
| 120 | [`5f57df699`](https://github.com/khoadng/Boorusama/commit/5f57df699e940fb8256aa74bdac46d2979246141) | fix(explore): let keyboard reach explore posts and skip the hidden page | U05 |
| 121 | [`58254b441`](https://github.com/khoadng/Boorusama/commit/58254b441040ec4c6187018a46c4366511e3e7f0) | fix(post-details): move focus out of the page only to controls in view | U05 |
| 122 | [`c65a81074`](https://github.com/khoadng/Boorusama/commit/c65a81074f123eed5efbe368a8a44985dd8340cf) | fix(video): let the time text grow instead of overflowing | P11 |
| 123 | [`72bafb43d`](https://github.com/khoadng/Boorusama/commit/72bafb43d3e5063749ce663277201b01ea644a54) | feat(post-details): support media play/pause keys for videos | P11 |
| 124 | [`84286ddc1`](https://github.com/khoadng/Boorusama/commit/84286ddc1e3da8e7cae71783c5e21641015635ae) | fix(focus): keep Tab in view and arrows continuing from the current control | U05 |
| 125 | [`d7041c4d4`](https://github.com/khoadng/Boorusama/commit/d7041c4d42b3470c45ab4ed29bbe1e3e73093aa8) | fix(focus): focus the control under a mouse click | U05 |
| 126 | [`20e750618`](https://github.com/khoadng/Boorusama/commit/20e750618847bbb0a84391cca0b2440667ab18e7) | feat(favorite-tags): edit favorite tags in a dialog on wide screens | U07 |
| 127 | [`d1047aa89`](https://github.com/khoadng/Boorusama/commit/d1047aa890c64b3baa575e0ca16f50b4724e6826) | fix(posts): let keyboard reach the bookmark and favorite buttons on thumbnails | P14 |
| 128 | [`e04b3bfd1`](https://github.com/khoadng/Boorusama/commit/e04b3bfd186e8b5b88ab704189e23178ae26d098) | fix(posts): close the hover preview on key press | P12 |
| 129 | [`e1ad37e1e`](https://github.com/khoadng/Boorusama/commit/e1ad37e1eddbb12106930e2ec983536863b5511b) | test(search): cover confirming a raw query from the desktop search bar | U03 |
| 130 | [`f31f551be`](https://github.com/khoadng/Boorusama/commit/f31f551bedd31b2c75fcddf354e682b07bae5e69) | fix(focus): skip the focus ring on text fields that draw their own focus border | U05 |
| 131 | [`7f5693c84`](https://github.com/khoadng/Boorusama/commit/7f5693c847ea0a88acb1fd12ff05057e0a6e5bb5) | feat(search): highlight tag suggestions while typing and keep keys off covered pages | U03 |
| 132 | [`b925a581b`](https://github.com/khoadng/Boorusama/commit/b925a581bd361ca710d27a3e95c1eb315f9be62f) | feat(menu): highlight the focused menu row instead of drawing the focus ring | U06 |
| 133 | [`2d6d9f6e6`](https://github.com/khoadng/Boorusama/commit/2d6d9f6e6dacf60a52f8d0b62e7d27b8318b707c) | feat(kurumi): close the innermost open layer on Escape | U06 |
| 134 | [`76a8485de`](https://github.com/khoadng/Boorusama/commit/76a8485de122438d3f70c74de5c69bd1c8ea8987) | feat(keyboard): let Escape close what back closes | U06 |
| 135 | [`5da94c1df`](https://github.com/khoadng/Boorusama/commit/5da94c1dfa6a39ef34c21c6ba1d171267ee06928) | feat(posts): open the post preview from an info badge instead of the whole thumbnail | P12 |
| 136 | [`d79ef1fcc`](https://github.com/khoadng/Boorusama/commit/d79ef1fcc9f59b07933e76681b6c033e12327460) | fix(shimmie2): keep listings working when favorite status fails | B06 |
| 137 | [`8757eb295`](https://github.com/khoadng/Boorusama/commit/8757eb2953d41716bc7c8fb3a028b71fb3f03e2c) | fix(sankaku): show rejected logins as authentication errors | B04 |
| 138 | [`1d8c879f4`](https://github.com/khoadng/Boorusama/commit/1d8c879f406d54df86c25d334ace0ada98846886) | fix(configs): keep profiles with unknown thumbnail actions or invalid media hosts | P02 |
| 139 | [`0f71409de`](https://github.com/khoadng/Boorusama/commit/0f71409dea3775ae1dd033bcf7fc27bb008888a0) | fix(videos): stop cached video cleanup from deleting pages in use | P08, X04 |
| 140 | [`71b41b8a0`](https://github.com/khoadng/Boorusama/commit/71b41b8a0f5574975f1cae673ac9cedde5b594ed) | test: fix stale hover preview test and flaky dry run session wait | U08 |
| 141 | [`e44fff71c`](https://github.com/khoadng/Boorusama/commit/e44fff71cd79dc4c581f6b6072a85e999a89df37) | build: prepare for 4.6.0 | A16 |
| 142 | [`c69b3e824`](https://github.com/khoadng/Boorusama/commit/c69b3e824d4acc4d60922ce78e391594846ff2c0) | fix(kurumi): cancel the pending checkmark animation when deselecting | A03 |
| 143 | [`5feaa3dcf`](https://github.com/khoadng/Boorusama/commit/5feaa3dcf0a5069afab3f95594b3935fe08f7150) | fix(posts): let long press and right click reach the post menu again | P12 |
| 144 | [`1e480b775`](https://github.com/khoadng/Boorusama/commit/1e480b7751a359931c53057e86a42ff56a1c6672) | fix(tags): keep the tag cloud context menu at full size | P13 |
| 145 | [`953fee30b`](https://github.com/khoadng/Boorusama/commit/953fee30bd78245cc9113a1dfc41a7953a7b2c3a) | fix(changelogs): stop the what's new popup from returning on every launch | A16 |
| 146 | [`e6511bad5`](https://github.com/khoadng/Boorusama/commit/e6511bad5c6d44f9b574bb08e1eeef4ddaed4d23) | ci: sign github release apks with a permanent key | A15 |
| 147 | [`399a4da47`](https://github.com/khoadng/Boorusama/commit/399a4da47587906a73a316f18c089254b58156d5) | fix(ddos): answer with the browser page instead of flashing a challenge that never appeared | N04 |
| 148 | [`2a5818b57`](https://github.com/khoadng/Boorusama/commit/2a5818b570a58071959e9d877aa4d2a3c9c25a17) | docs: add 4.6.1 changelog | A16 |
| 149 | [`5a2a4e82e`](https://github.com/khoadng/Boorusama/commit/5a2a4e82e827785f0c296b600e44aae2247b90a4) | docs: keep the 4.6.0 notes for 4.6.1 | A16 |
| 150 | [`5b04bf6a1`](https://github.com/khoadng/Boorusama/commit/5b04bf6a164f028d41701299367d0dde74dde330) | build: prepare for 4.6.1 | A16 |

## Appendix B — 106 Confirmed Git Merge Conflict Paths

Computed directly using `git merge-tree --write-tree --name-only develop v4.6.1` from the original Git bundle. Includes modify/delete and directory rename conflicts. The list does **not** replace semantic acceptance tests.

| Path | |
|---|---|
| `.fvmrc` | |
| `.github/workflows/github-release.yml` | |
| `CHANGELOG.md` | |
| `android/app/build.gradle.kts` | |
| `android/app/src/main/AndroidManifest.xml` | |
| `android/app/src/main/kotlin/com/degenk/boorusama/MainActivity.kt` | |
| `android/app/src/main/kotlin/com/timberpile/boorusama/CacheDocumentsChannel.kt` | |
| `android/app/src/main/kotlin/com/timberpile/boorusama/CacheDocumentsProvider.kt` | |
| `android/app/src/main/kotlin/com/timberpile/boorusama/WebViewCookieChannel.kt` | |
| `android/gradle.properties` | |
| `ios/Runner/AppDelegate.swift` | |
| `lib/boorus/danbooru/artists/artist/src/pages/artist_page.dart` | |
| `lib/boorus/danbooru/danbooru_builder.dart` | |
| `lib/boorus/danbooru/favgroups/details/src/favorite_group_details_page.dart` | |
| `lib/boorus/danbooru/pools/details/src/widgets/danbooru_infinite_post_id_list.dart` | |
| `lib/boorus/danbooru/posts/explores/src/pages/explore_most_viewed_page.dart` | |
| `lib/boorus/danbooru/posts/favorites/src/favorites_page.dart` | |
| `lib/boorus/danbooru/posts/listing/src/default_danbooru_image_grid_item.dart` | |
| `lib/boorus/danbooru/posts/listing/src/grid_thumbnail_url.dart` | |
| `lib/boorus/danbooru/posts/post/src/providers.dart` | |
| `lib/boorus/danbooru/posts/uploads/src/pages/danbooru_my_uploads_page.dart` | |
| `lib/boorus/e621/popular/widgets.dart` | |
| `lib/boorus/eshuushuu/users/widgets.dart` | |
| `lib/boorus/hydrus/posts/types.dart` | |
| `lib/boorus/sankaku/posts/parser.dart` | |
| `lib/boorus/sankaku/posts/types.dart` | |
| `lib/boorus/sankaku/sankaku_builder.dart` | |
| `lib/boorus/sankaku/sankaku_repository.dart` | |
| `lib/boorus/sankaku/tags/providers.dart` | |
| `lib/boorus/zerochan/client_provider.dart` | |
| `lib/boorus/zerochan/posts/parser.dart` | |
| `lib/boorus/zerochan/zerochan_repository.dart` | |
| `lib/core/app.dart` | |
| `lib/core/backups/auto/providers.dart` | |
| `lib/core/backups/auto/widgets.dart` | |
| `lib/core/backups/widgets/backup_restore_tile.dart` | |
| `lib/core/blacklists/src/data/providers.dart` | |
| `lib/core/bookmarks/src/data/bookmark_convert.dart` | |
| `lib/core/bookmarks/src/data/hive/bookmark_hive_object.dart` | |
| `lib/core/bookmarks/src/data/hive/repository.dart` | |
| `lib/core/bookmarks/src/data/providers.dart` | |
| `lib/core/bookmarks/src/pages/bookmark_page.dart` | |
| `lib/core/bookmarks/src/providers/bookmark_provider.dart` | |
| `lib/core/bookmarks/src/types/bookmark.dart` | |
| `lib/core/bookmarks/src/widgets/bookmark_scroll_view.dart` | |
| `lib/core/bookmarks/src/widgets/bookmark_search_bar.dart` | |
| `lib/core/bookmarks/types.dart` | |
| `lib/core/boorusama_app.dart` | |
| `lib/core/bulk_downloads/src/data/repo_io.dart` | |
| `lib/core/bulk_downloads/src/data/repo_web.dart` | |
| `lib/core/bulk_downloads/src/pages/bulk_download_completed_page.dart` | |
| `lib/core/bulk_downloads/src/pages/bulk_download_page.dart` | |
| `lib/core/bulk_downloads/src/pages/bulk_download_saved_task_page.dart` | |
| `lib/core/bulk_downloads/src/providers/bulk_download_notifier.dart` | |
| `lib/core/configs/auth/src/pages/cookie_access_webview_page.dart` | |
| `lib/core/configs/create/src/pages/add_booru_page.dart` | |
| `lib/core/debug/widgets.dart` | |
| `lib/core/developer_options/widgets.dart` | |
| `lib/core/hive/hive_adapters.g.dart` | |
| `lib/core/hive/hive_adapters.g.yaml` | |
| `lib/core/http/client/src/interceptors/dio_image_deduplicate_interceptor.dart` | |
| `lib/core/http/client/src/interceptors/dio_protection_interceptor.dart` | |
| `lib/core/http/client/src/interceptors/sliding_window_rate_limit_interceptor.dart` | |
| `lib/core/images/booru_image.dart` | |
| `lib/core/posts/details_pageview/src/post_details_page_view.dart` | |
| `lib/core/posts/details_parts/src/toolbars/bookmark_post_button.dart` | |
| `lib/core/posts/favorites/src/pages/favorite_page_scaffold.dart` | |
| `lib/core/posts/favorites/src/widgets/quick_favorite_button.dart` | |
| `lib/core/posts/listing/src/types/grid_thumbnail_url_generator_default.dart` | |
| `lib/core/posts/listing/src/widgets/default_image_grid_item.dart` | |
| `lib/core/posts/listing/src/widgets/default_image_quick_action_button.dart` | |
| `lib/core/posts/listing/src/widgets/post_grid_controller.dart` | |
| `lib/core/posts/post/src/types/post.dart` | |
| `lib/core/posts/shares/src/download_and_share.dart` | |
| `lib/core/search/histories/src/data/repo_io.dart` | |
| `lib/core/search/histories/src/data/repo_web.dart` | |
| `lib/core/search/search/src/widgets/search_page_scaffold.dart` | |
| `lib/core/settings/src/pages/appearance/appearance_page.dart` | |
| `lib/core/settings/src/pages/data_and_storage_page.dart` | |
| `lib/core/settings/src/pages/language_page.dart` | |
| `lib/core/settings/src/pages/settings_page.dart` | |
| `lib/core/tags/favorites/src/providers/providers.dart` | |
| `lib/core/tags/show/src/pages/show_tag_list_page_scaffold.dart` | |
| `lib/core/tags/tag/src/widgets/general_tag_context_menu.dart` | |
| `lib/foundation/picker.dart` | |
| `macos/Runner.xcodeproj/project.pbxproj` | |
| `macos/Runner/MainFlutterWindow.swift` | |
| `packages/booru_clients/boorus.yaml` | |
| `packages/booru_clients/lib/src/gelbooru/gelbooru_client_favorites.dart` | |
| `packages/booru_clients/lib/src/gelbooru_v2/parsers/r34_parsers.dart` | |
| `packages/booru_clients/lib/src/sankaku/sankaku_client.dart` | |
| `packages/booru_clients/lib/src/shimmie2/shimmie2_client.dart` | |
| `packages/extended_image/analysis_options.yaml` | |
| `packages/extended_image/lib/src/extended_image.dart` | |
| `packages/i18n/translations/tr-TR.json` | |
| `packages/kurumi/lib/material.dart` | |
| `packages/kurumi/lib/src/components/context_menu.dart` | |
| `packages/kurumi/lib/src/components/interactive_viewer.dart` | |
| `packages/kurumi/lib/src/components/popup_menu.dart` | |
| `packages/kurumi/test/context_menu_test.dart` | |
| `packages/kurumi/test/interactive_viewer_test.dart` | |
| `pubspec.yaml` | |
| `test/bulk_downloads/common.dart` | |
| `test/bulk_downloads/providers/downloads/session_test.dart` | |
| `test/bulk_downloads/providers/downloads/skip_test.dart` | |
| `test/image_url_resolver_test.dart` | |

## Appendix C — Invariants of the Intended Final State

Before integration, verify all of these and preserve them in every conflict resolution:

- **No loss of bookmarks**, including `StoredPostSnapshot`, groups/folders, profiles, local search and Undo.
- **No regression in profile UUIDs, Following/Pinned Searches or Search UI.**
- **Retain shared cache/origin isolation, interactive browser request priority and Android export pipeline.**
- **Preserve Timberpile application ID, package names, signing key, icons and updates.**
- **No silent changes to saved privacy settings or forwarding of authentication data.**
- **An upstream fix counts as integrated only after its behavior has been tested.**
- **Run the complete test suite per `AGENTS.md` before integration; targeted tests for every affected item.**

## Decision Record — All Items Approved

**68/68 items were explicitly approved.** The [authoritative decision log](decisions.md) contains expected behavior, dependencies, migrations and regression criteria; the [compact checklist](boorusama-v4.6.1-checkliste.md) shows the same approved status. The original appendix table of unfilled "open" placeholders was removed because it contradicted completed decisions and is not maintained as a second source of truth.

---

This is a **planning and decision reference**, **not** a claim that all changes have been successfully merged or tested. The old experimental merge patch has not been validated.

