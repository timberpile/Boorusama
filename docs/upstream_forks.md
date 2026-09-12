# Boorusama fork survey

Surveyed the public fork network of `khoadng/Boorusama` in September 2026 and compared fork default branches against upstream.

Most forks do not contain reusable product work. They are primarily stale snapshots, translation-only forks, or CI/build experiments. The following forks contain non-obvious changes worth knowing about before implementing similar features.

## Notable forks

### `jakedev796/Boorusama`

This is the most substantial active fork found and is based directly on the current upstream tip rather than an old snapshot.

Important additions:

- Full Pixiv integration.
- Pixiv OAuth PKCE authentication and token refresh.
- Pixiv rankings with historical date navigation.
- Pixiv Following and Recommended feeds.
- R-18 ranking modes.
- Multi-page Pixiv works and downloads.
- Pawchive support with creator-first browsing.
- Significant tests for the Pixiv client, authentication and feed behavior.
- Android release/signing improvements.

This fork is especially relevant as a reference when implementing a general followed-artists feed. Its Pixiv implementation already models a feed sourced from followed creators and integrates it into Boorusama's Explore/navigation architecture.

It also unlocks Plus features in its own builds. Treat that as fork-specific behavior rather than an architectural recommendation.

### `eob2000/Boorusama`

Contains a small but useful image-loading robustness patch, originally motivated by Gelbooru image-server failures.

Changes include:

- Limit concurrent image requests to 5 to avoid request bursts and HTTP 503 responses.
- Respect `Retry-After`.
- Exponential retry/backoff behavior.
- Fall back to thumbnails when the high-resolution image fails.
- Tap-to-retry for failed images.
- Automatically retry failed images when swiping back to them in the viewer.
- Additional image-loading diagnostics.

This is a useful reference if image requests become unreliable under fast grid/viewer navigation. Prefer adapting the isolated ideas rather than merging the entire fork.

### `Dev-Atom42/Boorusama`

Adds support for download paths containing subdirectories, followed by a security fix that sanitizes path components and prevents directory traversal.

Relevant if download filename templates are expanded to support structures such as:

`artist/site/filename.jpg`

Any equivalent implementation must sanitize user/template-derived path components and prevent `..` escaping the configured download root.

### `restartxx/Boorusama`

Implements double-tap zoom on the original-image page using a `TransformationController`.

The implementation went through several iterations and the fork is significantly behind upstream, so use it as a design reference rather than attempting to merge the fork wholesale.

This may complement the existing Timberpile behavior that loads the original image when zooming.

### `Michiflank/Boorusama-upstream`

Adds Sizebooru as a complete Boorusama engine rather than as site-specific special-case logic.

It includes the normal engine layers:

- builder
- repository
- API client
- post parser/providers
- tag providers
- engine registration

This is a useful reference when implementing support for another service.

A later fix is particularly important: persisted booru engine IDs must remain stable. Reassigning an existing engine ID to a new engine can silently reinterpret stored configurations after an upgrade.

The fork also had to use Sizebooru's `/Home` endpoint for empty-query pagination because `/Search` only paginates correctly when a search query exists.

### `auraliedawn/Boorusama`

Contains work around slideshow navigation and paginated post lists.

One important fix makes `fetchMore` awaitable to avoid a race between revealing/navigating to an item and fetching additional pages.

Useful reference if slideshow or post-detail PageView navigation behaves incorrectly near the end of currently loaded data.

### `LuminarLeaf/Boorusama`

Archived FOSS-oriented fork.

Notable work:

- Removes Firebase analytics/crash reporting.
- Adds Nix flake tooling.
- Contains assorted historical e621 and bookmark fixes.

The fork is now far behind upstream, so individual historical patches may be useful but it should not be used as a merge base.

### `TudorHH3000/Boorusama`

Contains extensive workarounds for Android `flutter_avif` build problems:

- Android stub plugin.
- custom `FlutterAvifPlugin.kt`
- `fix_avif.py`
- custom APK workflow

This confirms that AVIF dependency/build issues affected other Boorusama forks as well.

Do not copy this workaround into the current codebase without re-evaluating it. It targets the older AVIF dependency setup and is likely obsolete after upstream's later image-stack changes.

## General fork-network observations

Many forks with numerous commits ahead of their historical merge base contain only CI workflow changes. Commit count alone is therefore not a useful indicator of reusable functionality.

Common fork-only work includes:

- GitHub Actions APK builds
- Windows build workflows
- iOS build adjustments
- translation updates
- release automation

Before implementing a substantial Boorusama feature from scratch, the most useful forks to check first are currently:

- `jakedev796/Boorusama` for new services, feeds and Pixiv-style followed creators.
- `eob2000/Boorusama` for image-loading resilience.
- `Dev-Atom42/Boorusama` for hierarchical download paths.
- `Michiflank/Boorusama-upstream` for adding a new booru engine.
- `auraliedawn/Boorusama` for paginated slideshow/navigation behavior.