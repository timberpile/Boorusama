# Boorusama Timber Identity Design

## Purpose

Give the Timberpile fork a distinct installed and distributed identity while
keeping it recognizably Boorusama and minimizing divergence from upstream. The
product is named **Boorusama Timber**. Operating systems and release tooling
identify it as `com.timberpile.boorusama`, so it can coexist with the upstream
application and cannot accidentally consume an upstream-signed update.

Historical commits `cfeb6bea4e52f20fb37bf486321a9335ccbf2ec0` and
`0879d41b605fd21bd6509991471c305554168dab` are behavioral references only.
The changes are reimplemented against the current `develop_new_2` baseline.

## Identity Boundary

The rebrand applies to public distribution identity and user-visible product
names, not to internal source architecture. The canonical values are:

- production display name: `Boorusama Timber`;
- development display name: `Boorusama Timber Dev`;
- production application ID: `com.timberpile.boorusama`;
- development application ID: `com.timberpile.boorusama.dev`;
- Apple share-extension IDs: the corresponding application ID followed by
  `.ShareExtension`;
- fork version: `4.5.0-timberpile.1+185`;
- release tag derived by the CLI: `v4.5.0-timberpile.1`.

Internal names such as the Dart package `boorusama`, `BoorusamaApp`, the
`boorusama_cli` package and executable, source directories unrelated to native
namespaces, update-manifest filename, logs, and internal constants remain
unchanged. This avoids widespread mechanical churn and reduces future upstream
merge conflicts.

Release APK filenames retain the existing `boorusama-<full-version>-...apk`
shape. The fork prerelease in the full version already distinguishes an asset,
for example:

`boorusama-4.5.0-timberpile.1+185-android-arm64.apk`

## Platform Identity

### Android

The Android namespace and production `applicationId` become
`com.timberpile.boorusama`. The existing development suffix produces
`com.timberpile.boorusama.dev`. Product-flavor resources expose `Boorusama
Timber` and `Boorusama Timber Dev` as the launcher names.

Native Kotlin sources move from `com/degenk/boorusama` to
`com/timberpile/boorusama`, and their package declarations change with the
namespace. Manifest authorities already derive from `${applicationId}` and do
not need a hardcoded replacement.

This identity change deliberately makes Boorusama Timber a separate Android
application. It has separate application data, can coexist with upstream
Boorusama, and cannot update or be updated by an APK using the upstream ID.

### Apple platforms

iOS and macOS product names become `Boorusama Timber` for production and
`Boorusama Timber Dev` for development configurations. Bundle identifiers use
the canonical production/development IDs, including every share-extension
configuration. Shared app-group entitlements change to
`group.com.timberpile.boorusama` so the app and its extension continue to share
data within the fork without colliding with upstream.

The upstream Apple development-team ID is removed because it does not belong to
Timberpile. No replacement team is configured until Timberpile performs an
Apple-signed distribution.

### Linux, Flatpak, Windows, and web

Linux application IDs and the Flatpak ID become
`com.timberpile.boorusama`. Linux and Windows window titles become `Boorusama
Timber`. Windows product metadata names Timberpile as the company and
`Boorusama Timber` as the product while retaining the internal executable name
where changing it has no identity benefit.

The web manifest, browser title, and Apple mobile web-app title become
`Boorusama Timber`. Existing internal binary, CMake project, and Dart package
names remain unchanged.

## Compatible Protocols and Existing Services

The `boorusama://` custom URL scheme and `_boorusama._tcp` local-network
service name remain unchanged for compatibility with existing links and device
transfer behavior. If both upstream and fork builds are installed, Android may
ask the user to select a handler; custom-scheme routing can be less predictable
on Apple platforms. That coexistence trade-off is accepted in favor of link
compatibility.

Private-use support, privacy-policy, terms-of-service, upstream Play Store, and
upstream announcement-service references remain unchanged. They are outside
the distribution-identity change. In particular, no unowned replacement legal
entity or service endpoint is invented.

The announcement endpoints remain an explicit future consideration: they can
show upstream messaging inside the fork. They should change only when
Timberpile has a replacement service or decides to disable announcements.

## Release and Update Behavior

The default GitHub release update endpoint moves from
`khoadng/Boorusama` to `timberpile/Boorusama`. An upstream APK has a different
application ID and signing certificate, so presenting it as an applicable
update would be misleading and installation would fail.

The Android-only workflow, signing verifier, published-asset verifier, upgrade
verifier, and their contract tests use `com.timberpile.boorusama`. Release
filenames and the update manifest naturally include the full fork version.

The release CLI must accept a semantic version containing both a prerelease
component and build metadata. Its validation accepts
`4.5.0-timberpile.1+185`, preserves `4.5.0-timberpile.1` as the version name,
preserves `185` as the build number, and derives tag
`v4.5.0-timberpile.1`. Regression tests cover this behavior.

The in-app GitHub release checker continues using `pub_semver`. Tests cover
comparison between Timberpile prerelease versions and confirm the fork update
endpoint. Changelog resolution may use its existing generic fallback when an
exact fork-version heading does not exist.

### Known Google Play release-preparation limitation

The GitHub release path supports Timberpile versions such as
`4.5.0-timberpile.1+185`, but the Google Play-oriented
`boorusama release prepare <version>` path does not. Its release-name input and
`VersionName` comparison model currently accept only stable `X.Y.Z` values, so
an input such as `4.5.0-timberpile.2` is rejected.

This does not affect the Android-only GitHub release workflow because that
workflow does not invoke `release prepare`. Until Google Play publishing is in
scope, prepare a subsequent Timberpile GitHub release by updating the version
in `pubspec.yaml` directly and adding the corresponding version heading to
`CHANGELOG.md`.

If Google Play publishing is added later, extend the prepare path as a separate
change. That work must define prerelease ordering and Play release-name parsing
and add regression tests for successive Timberpile prereleases; merely
loosening the input regular expression is insufficient.

## Attribution

Upstream authorship is preserved. Platform-visible notices become:

- macOS: `Copyright © 2023 Nguyen Duc Khoa. Modifications © 2026 Timberpile.`
- Windows: `Copyright © 2024 Nguyen Duc Khoa. Modifications © 2026 Timberpile.`

The README adds a concise statement that Boorusama Timber is a fork of
Boorusama by Nguyen Duc Khoa. GPL text, dependency licenses, upstream legal
documents, and existing third-party copyright data are not rewritten.

## Documentation Boundary

Current project documentation and tests that prescribe the active application
ID or version are updated so they do not instruct maintainers to verify the
obsolete upstream identity. Historical Git commits are untouched. No wholesale
documentation import from the reference commit is included.

## Verification

Implementation follows test-driven development where behavior is executable:

1. Add failing release-version tests for prerelease plus build metadata.
2. Update app-update tests for the fork endpoint and prerelease comparisons.
3. Update Android release contract tests to require the Timberpile ID and fork
   version while retaining signer and ABI checks.
4. Run clean dependency bootstrap and required code generation.
5. Run `flutter analyze`, root tests, and all affected workspace-package tests.
6. Run shell syntax checks, Android release-script contracts, and workflow
   linting.
7. Build locally signed production split APKs and inspect all three artifacts
   for the new package ID, `Boorusama Timber` label, fork version, ABI version
   codes, and one shared non-debug certificate.
8. Validate Apple project configuration and desktop/web identity files with
   targeted static checks on hosts where those platform toolchains are not
   available.

A new published verification release is not required solely for this identity
change. The existing release workflow has already passed its end-to-end signer
and in-place-update gate; this change updates its asserted identity and version
without altering that architecture. A future Timberpile release can opt into
the retained `verify_upgrade` workflow input.

## Explicit Exclusions and Follow-ups

This work does not rename internal Dart APIs, packages, CLI commands, CMake
projects, executables, logs, or the repository itself. It does not change the
icon, support contacts, legal-service ownership, Play Store listing,
announcement infrastructure, or custom URL/local-network protocols.

The unchanged icon is worth revisiting if upstream and fork builds are commonly
installed together: labels distinguish them, but a small Timber-specific icon
badge would improve visual recognition. That should be a separate visual-design
change rather than part of this identity migration.
