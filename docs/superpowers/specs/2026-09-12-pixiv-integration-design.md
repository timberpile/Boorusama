# Pixiv Integration Design

## Purpose

Add the final Pixiv integration from JakeDev's Boorusama fork to Boorusama
Timber. JakeDev is the behavioral reference: this work preserves its intended
Pixiv behavior while adapting shared integration points to Timber's current
`develop` baseline.

The reference is the ten Pixiv commits on `jakedev/master` from
`c2694e0c1` through `c663270d9`. Intermediate ranking-only behavior is not a
target; the completed multi-feed Explore experience is.

## Integration Strategy

Port the final Pixiv-specific source and tests, then reimplement the small
shared-file changes against the current files. Do not cherry-pick the series
blindly and do not replace shared files wholesale. This preserves upstream
changes made after JakeDev's branch point, including app-lock, download-network,
native-asset, release, and Timber identity work.

The implementation must not import JakeDev's Pawchive, Plus-unlock, release,
version-bump, or documentation changes. The application remains
`Boorusama Timber`, version `4.5.0-timberpile.1+185`.

## Pixiv Client

Add the Pixiv App API client and its DTO model to `booru_clients`. The client
supports:

- OAuth token exchange and refresh;
- illustration search and detail retrieval;
- ranking feeds with ranking mode and date parameters;
- followed-artist feeds with public/private filtering;
- personalized recommended feeds;
- Pixiv user details and ugoira metadata;
- pagination through Pixiv's returned next-page URLs;
- Pixiv's required request headers and error conversion.

External response data remains nullable and parsing follows the reference's
defensive behavior. Client tests use the reference mock server and cover
requests, DTO parsing, token responses, pagination, and error conversion.

## Authentication and Configuration

Register Pixiv as a single-site booru at `https://pixiv.net/`. Its configuration
screen provides OAuth PKCE login on Android and iOS through the existing webview
dependencies. Platforms without the in-app webview can accept a refresh token
manually.

The refresh token is stored in the existing `BooruConfig.apiKey` field.
Non-secret account metadata is stored as JSON in `BooruConfig.passHash`,
including the user ID, display name, Pixiv Premium flag, content restriction,
and access-token expiry. This deliberately matches JakeDev, including its
warning that profile backup and local profile transfer expose the long-lived
refresh token. Secure-storage redesign is outside this port.

Authenticated requests receive access tokens through the Pixiv interceptor.
Refreshes are serialized so concurrent expired requests do not perform
independent refreshes. A successful refresh updates the saved configuration;
an unrecoverable refresh failure presents the session-expired path and directs
the user back to the Pixiv authentication tab.

## Booru Engine and Post Pipeline

Add a Pixiv `BaseBooruBuilder`, repository, providers, query model, link
generator, and post parser. The engine integrates with the existing config,
listing, details, tag, download, and routing abstractions rather than creating
parallel app infrastructure.

Pixiv works map into Boorusama posts with their creator, tags, dimensions,
rating, statistics, and page data. Multi-page works expose every page and
download correctly. Listing thumbnails use the appropriate preview variant;
post details use Pixiv's large image variant, matching JakeDev's final media
fix. Pixiv tags remain visible in the details layout.

## Home, Navigation, and Explore

Pixiv's home page adds an Explore destination and retains the normal Pixiv
listing/search experience. Explore is the final multi-feed page, replacing the
earlier ranking-only page. It contains:

- Ranking, Following, and Recommended feed selection;
- Pixiv ranking-mode selection;
- historical ranking date stepping from Pixiv's launch date (2007-09-13) to
  the newest available ranking snapshot (yesterday in Japan Standard Time);
- public/private/all filtering for followed artists;
- an account-setting warning when R-18 works are disabled;
- the final floating Explore header behavior from `c663270d9`.

Ranking dates are interpreted in Pixiv's expected Japan-time calendar terms.
Changing feed parameters invalidates and reloads the associated listing while
keeping parameters isolated by feed type.

## Shared Integration Points

Shared changes are limited to:

- adding only the Pixiv entry to `packages/booru_clients/boorus.yaml` with
  JakeDev's stable ID `37`; ID `36` remains unused because it belongs to the
  excluded Pawchive integration, preserving config compatibility and avoiding
  a future ID collision;
- adding Pixiv routes to the existing core router;
- adding the English Pixiv authentication and Explore strings without
  replacing newer translation content;
- retaining any dependency and generated-file changes actually required by
  code generation on the current Flutter 3.47.2 toolchain.

Generated booru configuration and localization output must come from the
project generators, not from stale JakeDev generated files.

## Error and Security Behavior

Network and authentication failures surface through the existing provider and
configuration UI patterns. Malformed stored Pixiv metadata falls back to empty
metadata rather than breaking app startup. Token refresh failures cannot loop
indefinitely; they invalidate the session and prompt reauthentication.

The implementation does not claim that refresh tokens are encrypted. The UI
keeps JakeDev's explicit credential-export warning. Changing the shared config
storage and backup format would affect all engines and is excluded.

## Verification

Verification protects both the imported behavior and the newer Timber
baseline:

1. Regenerate booru configuration and localization output with `./gen.sh`.
2. Format changed Dart files with FVM-managed Dart.
3. Run `fvm flutter analyze`.
4. Run the root Flutter test suite, including the Pixiv authentication,
   engine, parser, Explore, and site-registration tests.
5. Run the complete `packages/booru_clients` test suite.
6. Run every other workspace-package test suite affected by generated or
   localization changes.
7. Confirm the resulting diff contains no Pawchive, Plus, JakeDev release,
   version, or documentation changes.

No live Pixiv credentials are required for automated tests. A manual login and
feed smoke test is useful after implementation but is not an automated gate
because it would require placing a real account credential into the test
environment.

## Commit Structure

Prefer three logical implementation commits after this design and plan:

1. Pixiv App API client, DTOs, and client tests.
2. Pixiv engine, OAuth configuration, post pipeline, and integration tests.
3. Final Pixiv Explore/navigation behavior, generated output, and feed tests.

The commits represent the final intended architecture rather than preserving
JakeDev's obsolete intermediate ranking-page state.
