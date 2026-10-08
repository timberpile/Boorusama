# Require matching website profiles before bookmark import

Priority: Normal
Affected feature: Bookmark import preflight and profile dependencies

## Problem

Realbooru bookmarks imported without a Realbooru profile cannot load media correctly. Bookmark cards resolve a source profile, then use its engine and HTTP headers. If resolution fails, they use `BooruConfig.empty`, losing the Gelbooru V2 website Referer. Post recovery and native site presentation also require a resolvable profile. Import profile dependencies currently cover searches and feeds, but not bookmarks.

## Expected behavior and acceptance criteria

- Before applying any bookmark import, require a usable matching profile for every website represented by the selected bookmarks. This applies generally, including complete snapshots and non-AnimeBoxes packages.
- Match both website and engine. A profile for another website using the same engine does not satisfy the requirement. Use canonical source identity and compatible profile matching rather than display names.
- Consider the planned resulting profiles, including profiles explicitly imported in the same transaction and profiles removed by replacement. Existing compatible profiles satisfy the requirement without redundant creation.
- If a required profile is missing, explain the affected website and direct the user to create it through the regular profile flow or resolve an existing shared mapping or skip the affected import selection. Block Apply before any application-data writes while the requirement remains unresolved.
- When multiple accounts would leave post-origin resolution ambiguous, resolve and preserve the chosen profile association without changing canonical bookmark identity or group membership. Automatically use a sole valid profile consistently with DATA-012, hiding its selection control.
- Replan and rerun preflight after selection, mapping, or profile-action changes; skipped bookmarks do not create dependencies.
- Cover missing, matching, wrong-site, same-engine, multiple-account, newly imported/created, and removed-profile cases with focused tests. Verify imported Realbooru media and post recovery through the UI.

## Investigation evidence (2026-10-05)

Read-only inspection of the current AnimeBoxes package found 46 Realbooru bookmarks; none lacked thumbnail, sample, or original URLs, and all those URLs were absolute. Live requests tested three image bookmarks and three video bookmarks without account credentials. All six thumbnail requests returned HTML without a website Referer and JPEG with `Referer: https://realbooru.com/`; image sample requests similarly changed from HTML to JPEG. This demonstrates the missing-header failure independently of URL availability. No before/after app UI comparison was performed during this investigation.

A persisted profile is not intrinsically necessary for a public media request: its Referer could be derived from bookmark origin. Requiring profiles is the approved product rule for consistent viewing, recovery, and site functionality in the current architecture; this ticket does not redesign profile-free browsing.

## Context and dependencies

User requested investigation first and approved a general per-website profile requirement if the dependency was confirmed. Relevant code: `bookmark_scroll_view.dart`, `PostOriginResolver`, `PostPagePresentationScope`, `httpHeadersProvider`, `GelbooruV2Repository.extraHttpHeaders`, and `ImportFlowNotifier._profileDependencies`.

Coordinate with [DATA-012](DATA-012-default-and-edit-import-profile-mappings.md), [DATA-013](../done/DATA-013-improve-import-profile-mapping-layout.md), and [DATA-009](../done/DATA-009-identify-unresolved-import-profile-messages.md). Silent recovery after opening is [POST-008](../done/POST-008-silently-recover-incomplete-bookmarks-on-open.md).

Relevant documentation: [bookmark groups](../../bookmark_groups.md), [unified post design](../../superpowers/specs/2026-09-22-unified-post-model-and-viewer-design.md), and [unified import design](../../superpowers/specs/2026-10-01-unified-export-import-design.md). Follow [development workflow](../../development_workflow.md) and [engineering guidelines](../../engineering_guidelines.md).

This ticket is unclaimed; implementation must be delegated in its own branch/worktree. Private source data and media URLs must remain outside committed fixtures and reports.

## Claim

Claimed 2026-10-05 by coordinator `/root`; implementer `/root/data010_profiles`; branch `fix/data-010-bookmark-profile-preflight`; dedicated worktree `/home/timber/code/Boorusama/.worktrees/data-010-bookmark-profile-preflight`. Implementation queued for the next available slot; review pending.

## Coordinated review status (2026-10-05)

Implementation: `a52d97474 + 26488c02c`. Independent review approved after rollback correction; 53 focused tests pass, including real late-failure and mapping-free restoration. Actual Realbooru media/recovery UI acceptance remains pending.

Combined verification is isolated in `.worktrees/nine-release-fixes-review` on `review/nine-release-fixes`. The final combined serial Flutter suite passed all 2,206 tests (exit 0); the unchanged current CLI implementation passed all 239 tests. The final Dev APK built successfully. Analysis of 29 changed Dart files found no errors or warnings; two unchanged baseline const-style informational lints remain. Development integration, publication, and cleanup have not been performed. Keep this ticket in progress pending final combined checks and its remaining acceptance evidence.

## Revised user feedback (2026-10-05)

Remove the inline import auto-create profile action. Missing-profile warnings direct regular profile creation or skipping affected selection. DATA-012 owns one global canonical website/engine mapping and shared planner/notifier/page changes; DATA-010 coordinates dependency/application tests and investigates why an import-created Realbooru profile behaved differently from a regular profile.



The user reported that dependency-created Realbooru profiles return no search posts and fail to recover bookmark metadata, while deleting that profile and creating Realbooru through the regular profile flow works. DATA-010 has no delivery approval. Revised behavior: remove automatic dependency profile creation; a missing compatible website profile must show an actionable warning directing the user to regular profile creation and keep Apply blocked. Automatically select a sole compatible profile without a selector; retain editable choices for multiple compatible accounts. Preserve selected bookmark origin hints and the verified rollback correction.

Shared page, mapping, localization, and planner/notifier changes are coordinated under DATA-012 by `/root/import_coordinator`. DATA-010 owns bookmark dependency/application tests and investigation evidence; no shared source changes have been made for this review revision.

The concrete source-level cause is the trailing slash in website URLs. Dependency creation copies the portable/bookmark URL, which is `https://realbooru.com`; regular Quick Profile creation copies the YAML preset `https://realbooru.com/`, and normal URL entry appends a slash. Generated `GelbooruV2Config.siteCapabilities` uses exact-string lookup. The slashless profile falls through to generic Gelbooru capabilities, losing Realbooru's HTML posts endpoint, `parseRbPostsHtml`, `parseRbPostHtml`, `parseRbTagsHtml`, and thumbnail-only/offset/fixed-limit behavior. The engine ID and absence of credentials are the same for both construction paths; copying empty defaults is not what selects the wrong parser.

A transient synthetic comparison test outside Git passed when the coordinator ran it: profile differences were only `id`, `url`, and `name`; automatic capabilities had zero website overrides and regular Realbooru capabilities had three. Initial execution attempts failed in automatic approval review because of model capacity, before any command ran. No application profile data or private migration input was read. Source inspection also shows a reachable independent case: credential-free profile export normalizes URLs and strips the slash before explicit profile import. That broader registry/export compatibility issue is tracked separately in [PROFILE-003](../done/PROFILE-003-canonicalize-website-capability-lookup.md); this revision does not change the registry or exporter.

Bookmark-owned tests now match DATA-012's shared canonical website/engine API. Fourteen focused tests pass, with no analyzer issues in the two changed test files. The real notifier scenario groups bookmark, pinned search, and feed references with three different exported UUIDs; changing the shared account invalidates preflight without writing repositories, and Apply persists that choice to bookmark origins, the imported pin, the feed, and its owned searches. Missing profiles remain blocked until a regular profile is added and the package is reloaded. Wrong-site UUID conflicts, skipped bookmarks, imported profiles, removal, and the late-failure/empty-mapping rollback cases remain covered. Shared source files were copied temporarily for verification and restored afterward; only the two owned test files are included in the test adaptation patch. Visible UI acceptance remains pending on the combined revised build.

## Approved local delivery (2026-10-05)

User verified the combined flow and explicitly approved develop integration and removal of both ticket branches/worktrees. DATA010 and DATA012 share the final implementation and are delivered together in one descriptive single-parent local commit. Independent final review approved `8c0623b137dc46c584e59a3ed976073027c7e720` after canonical HTTP-port and IPv6 corrections. Final full suite passed all 2,219 Flutter tests (exit 0); all staged application/test/translation source files match that tested tree byte-for-byte. Changed-file analysis and whitespace checks passed. Sole/missing/multiple profile UI states and editing were verified with Maestro; the user confirmed the flow works well. Local wording edits in en-US.json were preserved and excluded from this integration. No remote publication is authorized.
