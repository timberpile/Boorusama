# Require matching website profiles before bookmark import

Priority: Normal
Affected feature: Bookmark import preflight and profile dependencies

## Problem

Realbooru bookmarks imported without a Realbooru profile cannot load media correctly. Bookmark cards resolve a source profile, then use its engine and HTTP headers. If resolution fails, they use `BooruConfig.empty`, losing the Gelbooru V2 website Referer. Post recovery and native site presentation also require a resolvable profile. Import profile dependencies currently cover searches and feeds, but not bookmarks.

## Expected behavior and acceptance criteria

- Before applying any bookmark import, require a usable matching profile for every website represented by the selected bookmarks. This applies generally, including complete snapshots and non-AnimeBoxes packages.
- Match both website and engine. A profile for another website using the same engine does not satisfy the requirement. Use canonical source identity and compatible profile matching rather than display names.
- Consider the planned resulting profiles, including profiles imported or created in the same transaction and profiles removed by replacement. Existing compatible profiles satisfy the requirement without redundant creation.
- If a required profile is missing, explain the affected website and let the user resolve it through the existing profile selection/creation flow or skip the affected import selection. Block Apply before any application-data writes while the requirement remains unresolved.
- When multiple accounts would leave post-origin resolution ambiguous, resolve and preserve the chosen profile association without changing canonical bookmark identity or group membership. Automatically use a sole valid profile consistently with DATA-007.
- Replan and rerun preflight after selection, mapping, or profile-action changes; skipped bookmarks do not create dependencies.
- Cover missing, matching, wrong-site, same-engine, multiple-account, newly imported/created, and removed-profile cases with focused tests. Verify imported Realbooru media and post recovery through the UI.

## Investigation evidence (2026-10-05)

Read-only inspection of the current AnimeBoxes package found 46 Realbooru bookmarks; none lacked thumbnail, sample, or original URLs, and all those URLs were absolute. Live requests tested three image bookmarks and three video bookmarks without account credentials. All six thumbnail requests returned HTML without a website Referer and JPEG with `Referer: https://realbooru.com/`; image sample requests similarly changed from HTML to JPEG. This demonstrates the missing-header failure independently of URL availability. No before/after app UI comparison was performed during this investigation.

A persisted profile is not intrinsically necessary for a public media request: its Referer could be derived from bookmark origin. Requiring profiles is the approved product rule for consistent viewing, recovery, and site functionality in the current architecture; this ticket does not redesign profile-free browsing.

## Context and dependencies

User requested investigation first and approved a general per-website profile requirement if the dependency was confirmed. Relevant code: `bookmark_scroll_view.dart`, `PostOriginResolver`, `PostPagePresentationScope`, `httpHeadersProvider`, `GelbooruV2Repository.extraHttpHeaders`, and `ImportFlowNotifier._profileDependencies`.

Coordinate with [DATA-012](../in-progress/DATA-012-default-and-edit-import-profile-mappings.md), [DATA-013](DATA-013-improve-import-profile-mapping-layout.md), and [DATA-009](DATA-009-identify-unresolved-import-profile-messages.md). Silent recovery after opening is [POST-008](POST-008-silently-recover-incomplete-bookmarks-on-open.md).

Relevant documentation: [bookmark groups](../../bookmark_groups.md), [unified post design](../../superpowers/specs/2026-09-22-unified-post-model-and-viewer-design.md), and [unified import design](../../superpowers/specs/2026-10-01-unified-export-import-design.md). Follow [development workflow](../../development_workflow.md) and [engineering guidelines](../../engineering_guidelines.md).

This ticket is unclaimed; implementation must be delegated in its own branch/worktree. Private source data and media URLs must remain outside committed fixtures and reports.

## Claim

Claimed 2026-10-05 by coordinator `/root`; implementer `/root/data010_profiles`; branch `fix/data-010-bookmark-profile-preflight`; dedicated worktree `/home/timber/code/Boorusama/.worktrees/data-010-bookmark-profile-preflight`. Implementation queued for the next available slot; review pending.
