# Boorusama ticket investigation handoff

**Repository:** `timberpile/Boorusama`

**Published branch:** `maintenance/2026-11-11-ticket-triage`

**Inspected develop baseline:** `22348b2fb20049088705ce38f5b261e191b148af` (2026-11-11, shared Viewer #164). The remote develop head was checked again after the investigations and still matched this baseline.

**Research snapshot:** `9511e80e40814605f0c29a3eeeba7c5c09fe89bc`, containing 18 individual findings commits. This handoff is an additional documentation-only commit. No runtime implementation, PR, merge or issue mutation was performed.

## How to use this material

These documents answer the supplied reports and propose implementation boundaries. They are not a second task tracker or evidence that the proposed features are approved, implemented or device-tested. Each contains pinned source references, a proposed correction/design and focused verification cases. Re-read current AGENTS.md and relevant code before implementation; preserve any newer local-agent work.

The user withdrew the Selection Manager bottom-gap report during the investigation. The original thumbnail-prefetch request is already covered by #160. The newly reported fast-scroll failure and broken Retry interaction are distinct and must not be closed as that old duplicate.

## Complete subject coverage

| Supplied subject | Finding and proposed direction | Detailed investigation |
| --- | --- | --- |
| Collection upload-date sorting | Oldest Upload falls back to newestUpload for Collection cards. Remove that misleading fallback. Opened Pool member Latest/Oldest is numeric-ID ordering, not timestamp comparison; verify the advertised contract per engine. | [Collection sorting](../designs/2026-11-11-collection-upload-sorting.md) |
| Viewer Overlay Hide after each swipe | Confirmed: _onPageChanged reapplies initialHideOverlay. Initialize once per route and preserve live Post-overlay state; keep required Group Back navigation independent. | [Overlay lifecycle](../designs/2026-11-11-viewer-overlay-lifecycle.md) |
| Selection Manager bottom gap | User says it no longer appears. Retain current layout and do not open/reopen a bug from the superseded report. | [Withdrawn inset report](../designs/2026-11-11-selection-insets.md) |
| Share a directly viewable Post collection | Extend strict .bslink navigation documents with a versioned ordered-reference collection. Open an ephemeral shared timeline; persist only through an explicit Save action. Not a backup import or remote Group type. | [Portable collection](../designs/2026-11-11-portable-post-collection.md) |
| Thumbnail prefetch / two viewports | One viewport is implemented; API page prefetch separately triggers within two. Fix recovery first, then measure a shared two-thumbnail-viewport experiment. | [Prefetch distance](../designs/2026-11-11-timeline-prefetch-distance.md) |
| Realbooru new-Post tracking | Disabled for thumbnail-only sites because the current scanner needs reliable createdAt. A verified identity-based strategy is possible, but removing the flag alone is incorrect. | [Tracking prerequisites](../designs/2026-11-11-realbooru-tracking.md) |
| Realbooru parent-folder thumbnails | Confirmed mismatch: Topic cards use an untracked-preview provider; folders only read stored tracking previews. Share an effective-preview provider with bounded mosaic loading. | [Folder previews](../designs/2026-11-11-following-folder-previews.md) |
| Gelbooru rate limit | No explicit Gelbooru RPS rule: four in-flight API requests, passive 12/minute, bulk one/1250 ms. Media bypasses this coordinator. Add the supplied ten-RPS API ceiling narrowly; it is not an independently verified universal account/CDN limit. | [Rate policy](../designs/2026-11-11-gelbooru-rate-policy.md) |
| Rule34 favorites fail | Write-session cookies differ from read API credentials; strict response parsing and unvalidated remove success are concrete risks. The actual authenticated failure remains unobserved. | [Favorite mutations](../designs/2026-11-11-rule34-favorite-mutations.md) |
| Clipboard export with credentials | Service intentionally blocks it. Permit only an explicit artifact-bound sensitive-copy confirmation while preserving size limits and native privacy handling. | [Credential clipboard export](../designs/2026-11-11-credential-clipboard-export.md) |
| Import BASE64 with clipboard/manual input | One input form and one bounded decoder feeding the existing import preview/preflight/transaction; preserve legacy prefixed data and permit raw BASE64 package input. | [BASE64 import](../designs/2026-11-11-base64-import-entry.md) |
| Gelbooru Pools / Related | Pool search is documented; metadata/order adapter still needs verification. Current Related support is not established by legacy docs or DTO fields. Enable these separately through shared Group contracts. | [Gelbooru groups](../designs/2026-11-11-gelbooru-groups.md) |
| Pixiv Ugoira | Recognition, metadata endpoint and frame DTO already exist; the inspected Viewer path has no frame playback. Add bounded, access-scoped animation media inside the shared Viewer. | [Ugoira playback](../designs/2026-11-11-pixiv-ugoira-playback.md) |
| Bulk Find on Other Profiles | Reuse exact/Pixiv lookup services in a bounded cancellable job. Review and atomically save an ordinary hierarchy with Source plus target-profile subgroups. Preserve exact-file versus artwork-source match meaning. | [Bulk lookup](../designs/2026-11-11-bulk-cross-profile-collections.md) |
| Remove folder-access guidance | Located unconditional Android folder_access_hint and its padding. Remove that persistent presentation, not actual permissions, destination selection or access errors. | [Folder hint](../designs/2026-11-11-remove-folder-access-hint.md) |
| e-shuushuu favicon | Shared resolution falls back to Google S2; no first-party override exists. Validate the current official icon and add an exact-host shared mapping. Exact failed response/icon bytes remain unverified. | [Favicon](../designs/2026-11-11-eshuushuu-favicon.md) |
| Viewer icon shadows / similar surfaces | Trial transparent top triggers with glyph shadows, including the custom-painted Info icon. Inventory covers side arrows, optional More, video feedback/strips and thumbnail badges; keep ordinary opaque chrome unchanged. | [Overlay treatment](../designs/2026-11-11-media-overlay-icon-treatment.md) |
| NEW: fast-scroll thumbnails stay at Retry | Confirmed hit-test defect: full-tile InkWell covers the image's Retry control. Initial network failure is not established; typed cancellation errors are erased and 429 is absent from image retry eligibility. Repair hit testing and bounded recovery separately. | [Thumbnail Retry](../designs/2026-11-11-thumbnail-retry.md) |

## Recommended implementation order, subject to authorization

Start with the thumbnail Retry hit-test regression and sanitized failure classification, then the Viewer initial-hide lifecycle and shared folder-preview mismatch. They have concrete source mechanisms and small testable boundaries. Keep the two-viewport experiment separate so it cannot hide or amplify the recovery failure. The Collection oldest-date fallback and persistent folder hint are also scoped corrections.

Before changing Rule34 mutations, capture one authorized sanitized add/remove round trip and distinguish authentication, request contract and response parsing. Before enabling Gelbooru Groups, verify current metadata, membership, order and access semantics. Before enabling Realbooru tracking, verify a trustworthy ordering/checkpoint strategy. Ugoira, collection files, bulk lookup and visual treatment require their documented compatibility/security and product decisions, not blind implementation of every proposal.

Existing related issues include #65, #68, #107, #119, #123, #136, #158, #159, #160, #162 and #164. These references indicate overlap or prerequisites, not an exhaustive new backlog. Recheck current open/closed issues and active branches before writing or claiming implementation work, using the repository's issue-writing rules.

## Verification actually performed

Source inspection used the pinned baseline, including relevant callers, models, parsers, shared widgets, access boundaries and existing issue descriptions. Public primary documentation was checked where external site semantics mattered. No account mutation or load test was issued.

GitHub compare for `22348b2fb20049088705ce38f5b261e191b148af...9511e80e40814605f0c29a3eeeba7c5c09fe89bc` reported **ahead by 18, behind by 0**, with exactly the 18 new Markdown investigation files listed above and no runtime, test, settings, dependency or generated-code changes. Each topic was committed separately. This handoff's relative destinations match that changed-file manifest.

No Flutter/Dart tests, analyzer, application build, Android/Maestro scenario, native clipboard test, live authenticated Rule34/Pixiv acceptance, performance measurement or rendered visual review was executed. These are research documents, not tested fixes. No complete integration regression or merge readiness is claimed. No full Markdown build/link crawler was run; verification is source-reference inspection and remote diff/coverage checking.

The requested three Astra XHigh agents were **not run**: this chat exposed no subagent launch tool. Investigation and review were performed directly by one assistant, not independent reviewers. GitHub writes succeeded through the connector; no local repository/worktree or local fvm/emulator environment was used. A future implementation must use the required isolated worktree and current repository verification workflow.

## Local-agent starting prompt

Read current AGENTS.md and docs/handoffs/2026-11-11-ticket-triage.md from origin/maintenance/2026-11-11-ticket-triage. Treat this branch as source-linked research, not implemented fixes or blanket feature approval. Preserve current work and recheck newer develop changes. For the next explicitly authorized implementation, start from the relevant investigation, reproduce its failure with focused tests, use the existing task branch/worktree when applicable, fix and review the scoped behavior, then record actual tests and remaining device checks. Do not merge this research branch, create a PR, reopen the withdrawn selection-gap report, or reinterpret completed #160 as the new Retry bug without explicit authorization.
