# Verified Android Baseline Design

## Purpose

Rebuild Timberpile's development baseline on `develop_new_2` from the current
canonical `upstream/master`. The baseline updates the toolchain to Flutter
3.47.2 and produces reproducible, persistently signed Android releases. JakeDev
commits are behavioral references only; their patches and intermediate states
are not imported.

This design covers the baseline only. Plus unlocking, Pixiv, Pawchive, existing
Timberpile product features, JakeDev version bumps, and JakeDev-specific
documentation remain excluded.

## Branch and Commit Boundaries

`develop_new_2` remains the integration branch and must start at the latest
fetched `upstream/master`. Work is divided into three conventional commits:

1. `chore: migrate to Flutter 3.47.2`
2. `fix(release): package built Android split APKs`
3. `ci(release): verify persistently signed Android releases`

Generated dependency files belong to the toolchain commit. CLI tests belong to
the packaging commit. Workflow, Gradle cache configuration, and release signing
checks belong to the CI commit. No unrelated documentation or application
features are included.

## Flutter 3.47.2 Migration

The repository declares Flutter 3.47.2 in `.fvmrc`, and the release workflow
installs that exact version. Root SDK constraints and analysis configuration are
updated only where Flutter 3.47.2 requires it.

Dependency resolution is regenerated from the current upstream manifests using
Flutter 3.47.2. The old JakeDev lockfile is not copied. This preserves upstream's
newer `flutter_libavif`/`libavif` and native-assets dependency decisions while
allowing the new SDK to select compatible transitive versions. Any lockfile
change must be attributable to current manifests plus the toolchain change.

## Split-APK Build and Packaging

GitHub Android releases invoke Flutter with `--split-per-abi` and no narrowing
`--target-platform`, producing these three ABIs:

- `arm64-v8a`
- `armeabi-v7a`
- `x86_64`

The Android packager derives the expected APK set from the Flutter arguments.
With no `--target-platform`, it packages all three ABIs. It supports both
`--target-platform value` and `--target-platform=value`, comma-separated values,
and repeated flags. Known Android targets are emitted in stable canonical order.
If the arguments do not contain a recognized Android target, packaging falls
back to all three ABIs instead of silently producing an empty release.

Packaging fails if any expected split APK is absent. Tests cover the default
all-ABI case, each accepted target-platform syntax, subsets, ordering,
whitespace, and malformed or unknown target values.

The GitHub publisher requires only the APK receipt. The receipt continues to
record and checksum every packaged split APK, so publishing cannot silently
drop an ABI.

## Android-Only Release Workflow

The GitHub release workflow has one Ubuntu build target: `apk`. Build and
publish jobs use `github.actor == github.repository_owner`, preserving the
manual owner-only guard without hardcoding an account name.

The workflow installs Flutter 3.47.2, the pinned Android SDK/NDK requirements,
and native build prerequisites required by the current AVIF stack, including
Meson and NASM. Flutter's action cache remains enabled. Explicit caches retain
Gradle wrapper/dependency/build-cache data and Cargo registry/git data, with
keys derived from the files that affect those dependency graphs.
`org.gradle.caching=true` enables Gradle task-output reuse.

Only APK artifacts and the APK receipt are uploaded and passed to publishing.
Desktop and Apple matrix entries, setup steps, receipts, and publish
requirements are removed from this workflow.

The dispatch interface includes independent `draft` and `verify_upgrade`
Boolean inputs. `draft` defaults to true, preserving a safe routine-release
default, while `verify_upgrade` defaults to false. The publish command receives
`--no-draft` when `draft=false`. Normal releases still run published-asset
metadata and signer checks; the baseline gate dispatches with `prerelease=true`,
`draft=false`, and `verify_upgrade=true` so it creates a genuinely published
prerelease and adds the emulator upgrade test with its verification-only
lower-version build.

## Persistent Release Signing

The build job reads exactly these GitHub Secrets:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

Before compilation, the workflow rejects any empty secret, decodes the
keystore to a workspace-local ignored file, and writes `android/key.properties`
with an absolute `storeFile` path. `keytool` validates the configured alias and
credentials. Failure at any step terminates the release before an APK can be
published.

The workflow also obtains the permanent certificate's SHA-256 digest directly
from the configured keystore. This expected digest is held only as transient
job state and is never committed or printed alongside secret material.

After packaging, the workflow discovers every produced APK and requires exactly
the three expected ABI artifacts. For each file it runs
`apksigner verify --print-certs`, rejects verification errors, missing signer
certificates, and an Android debug certificate, and extracts the signer's
SHA-256 certificate digest. All three digests must be identical and must equal
the digest derived from the permanent keystore. Only verified files are
uploaded for publication.

## Verification Strategy

### Local gate

Verification starts from a clean checkout and uses Flutter 3.47.2 to run:

1. `./init.sh`, including dependency bootstrap and required code generation.
2. `./gen.sh` independently to prove generation is repeatable.
3. `flutter analyze`.
4. Root `flutter test`.
5. Tests for every changed workspace package, including
   `packages/boorusama_cli`.
6. A production release split-APK build through `boorusama_cli`.
7. Artifact inspection proving all three ABI APKs exist and report the expected
   application ID, version name, and version code.

Local signing may use an isolated verification keystore, but it cannot satisfy
the permanent-key gate. Permanent-key verification happens in GitHub Actions.

### Published prerelease gate

A dedicated verification tag is pushed without changing the product version.
The real GitHub release workflow is dispatched with `prerelease=true`,
`draft=false`, and `verify_upgrade=true`. The workflow builds and signs the
three production APKs, verifies their signer digests, publishes a non-draft
prerelease, and succeeds only after the post-publish verification job completes.

After publishing, a dependent verification job downloads APKs from the GitHub
prerelease assets with `gh release download`, not from the Actions artifact
store. It decodes the same protected keystore long enough to derive the expected
certificate digest and checks:

- exactly one asset for each expected ABI;
- application ID `com.degenk.boorusama`;
- version name and version code against the tagged source;
- cryptographic APK validity;
- identical SHA-256 signer certificate digests across all assets;
- equality between that digest and the configured permanent keystore digest.

The successful prerelease and tag are retained.

### In-place update gate

When `verify_upgrade=true`, the post-publish verification job additionally
creates a lower-versionCode `x86_64` APK from the same tagged source using the
same permanent key. It starts an Android emulator, installs that APK, then
installs the downloaded published `x86_64` APK with Android's replace/update
operation. The second install must succeed without uninstalling the first
package, and package-manager metadata must report the final application ID,
version name, and higher version code. This proves that the actual release asset
can update an existing installation made with the permanent key.

The lower-version artifact is verification-only and is never uploaded to the
GitHub release. The final published APK must have a strictly greater versionCode;
if the tagged versionCode cannot be decremented safely, the verification job
fails with an explicit diagnostic instead of weakening the check.

## Failure and Security Behavior

No signing-related fallback is accepted for GitHub releases. Pre-publication
signing, artifact, ABI, and metadata failures fail before publication.
Post-publication asset-integrity and in-place-update failures fail the workflow
after publication and leave the prerelease and tag intact for inspection.

Secret values, passwords, keystore bytes, and key properties are not uploaded.
Generated signing files remain ignored and ephemeral on the runner.

## Completion Boundary

The baseline is complete only when all local checks and the real published
prerelease checks pass. Until then, no Plus or Pixiv branch is created. The
successful verification prerelease/tag remains available for audit unless the
user later requests its removal.
