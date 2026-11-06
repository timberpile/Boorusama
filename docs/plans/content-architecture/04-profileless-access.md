# Stage 04: profileless display and safe anonymous access

**Issue:** #143. **Branch:** `feature/143-profileless-bookmark-access`.
**Base:** reviewed #142 candidate.
**Goal:** imported saved content remains useful without creating user profiles, while authorization and unavailable-state reporting stay accurate.
**Final reviewer:** independent Astra High. Follow the [approved contract](approved-contract.md), live issue and common review loop.

## Source map and produced boundary

Inspect existing `PostOriginResolver` and `PostPresentationContext` under `lib/core/posts/post/` and `lib/core/posts/details/`, `ViewerSourceBinding` near `lib/core/posts/details/src/types/viewer_entry.dart`, profile repository/providers under `lib/core/configs/`, engine registry and HTTP factories under `lib/core/boorus/engine/` and `lib/core/http/`, and existing bookmark grid filters/blacklist count indicators under `lib/core/bookmarks/` and `lib/core/posts/`.

Use the exact source-resolution files discovered from those symbols; do not build a second profile resolver. New helpers may live in `lib/core/content/content_access_resolver.dart` and `lib/core/content/anonymous_source_policy.dart`; keep only the minimal source trust policy and context factory there. Use #154's ContentAccessKey/Context with transient base URL/config and no persisted credentials. Extend existing reason-specific availability/presentation types rather than introduce another general error hierarchy.

New tests: `test/core/content/profileless_content_access_test.dart`, `anonymous_source_policy_test.dart`, `access_scope_invalidation_test.dart`, and `test/core/bookmarks/unavailable_bookmark_indicator_test.dart`.

## Task 1: make the resolution matrix explicit

1. Add tests for exact valid originating profile; one compatible profile without a valid hint; multiple ambiguous profiles; removed profile; changed credentials; unrelated selected profile; supported public source without a profile; unsupported source; unknown private installation; offline network.
2. Prefer valid originating/compatible user profiles using current matching rules. Never resolve ambiguity by choosing the first account or by global Browse selection. Revocation cannot silently switch an in-flight request to another account.
3. If no profile resolves, permit an internal read-only anonymous context only under an explicit engine/site public-read policy. It must not create or persist a visible profile, invent login capability or mutate current global selection.
4. Configure trusted built-in source origins/paths from existing verified engine configuration. Unknown imported custom hosts, arbitrary CDN URLs, localhost/private-network addresses or installation paths are not automatic probe targets. A user-configured custom source continues to use that explicit configured access. Do not broaden trust from a redirect, alias, matching engine or image hash.
5. Return explicit reasons for unavailable network access while retaining saved data. Offline/timeout is retryable and does not become permanent unsupported/deleted. Existing cached media may remain usable under saved-content policy without falsely enabling remote actions.

## Task 2: pooled anonymous contexts and request safety

1. Reuse the engine's existing HTTP/media resolver factory with anonymous credentials and read-only capabilities. One bounded context/client per compatible engine/site/policy scope, not one Dio instance per bookmark.
2. Validate the effective base URL and every adapter-owned continuation/redirect destination. Never forward authenticated headers to an anonymous/foreign host. Media CDN exceptions must be explicit source policy and use appropriate headers, not blanket host suffix matching.
3. Runtime authEpoch/policyEpoch revisions invalidate metadata/member/media bindings and pending results. Reuse request coordination cancellation and late-result rejection. Cache keys contain no credential hashes or tokens and cannot mix public, private or differently filtered results.
4. Remove subscriptions on profile/context disposal. Do not make the retained engine-registry Ref reactively watch scoped media/profile state; consuming providers own those watches and dependency chains. Preserve the existing protection against registry/profile deletion cycles.
5. Disabled/missing account mutation capabilities stay disabled in every toolbar, context menu, selection action and background projection. Public read support is never evidence of server-favorite write support.
6. Tests with two profiles on one host and an anonymous context must prove isolation, bounded client count, no cross-account cache reuse and no stale response publication after account/policy changes.

## Task 3: one compact unavailable indicator

1. Reuse the existing blacklisted-post count indicator's visual pattern in affected Bookmark grids, not a new row on every Bookmark Group or a permanent verbose banner.
2. Count saved entries currently excluded/unusable due to source-access reasons separately from blacklist-only exclusions. Do not count loading requests as permanent failures or count the same saved record twice.
3. Tapping opens a compact existing Kurumi explanation surface with localized reason groups such as account required, unsupported public reader or temporarily offline. No private title, secret URL or unavailable metadata may leak through the summary.
4. Keep the underlying records selectable only where the operation is safe (e.g. local management/export); media/source actions require actual resolved capability. Group membership counts and exports include retained unavailable entries.
5. Recompute after profile creation/removal/credential and policy changes without reimport or duplicate records. Preserve source filters, selection reconciliation and existing loaded/total count semantics.
6. Widget tests cover 320dp width, text scale 2, no unavailable entries, multiple reason categories, Back/Escape, count refresh and no duplicated blacklist count. Use context.t and Kurumi rather than a new Material dialog.

## Task 4: network failure and recovery tests

1. Mock only network/storage boundaries; use controlled completers for an auth/policy switch mid-flight. Verify old requests cannot publish into the new key.
2. Exercise denied/expired credentials, HTTP failures, removed profile, disposed route and failed image decode. Keep stored metadata and safe cached media; disable source actions and offer retry only with a valid recovery path.
3. Prove merely opening a Bookmark Group does not probe all unknown hosts or resolve every offscreen member. Use existing bounded visible/preload windows.
4. A newly configured compatible profile must resolve the same local Bookmark and dates. An incompatible source remains separate. Do not implement #43 aliases in this stage.

## Verification and exit

Run content/access, bookmark indicator, profile/presentation, mixed-media and backup profileless suites, formatting and analysis. Run the complete repository regression because source resolution is shared. On an exclusively leased Android emulator, use real public supported sources to check public read without a saved profile, cached/offline behavior, profile creation/removal and mixed source navigation. Never change real account favorites for this acceptance.

Lower-cost agents may produce source-policy fixture tables, reason-string localization and indicator layout tests. The main implementer owns host trust, anonymous client construction, auth/cache scope and revocation. Independent Astra High must review those paths plus the UI's non-leaking unavailable states. If the required service/device checks cannot be performed, record that blocker rather than declaring the policy verified.

Deliver a stage-specific handoff. Do not mark #143 completed before authorized publication in origin/develop, and do not touch the active #144 folder-sync branch.
