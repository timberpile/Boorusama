# AA01-A01 independent audit — final summary and remediation handoff

**Disposition (2026-10-30):** This review task is **closed at the user's explicit request** after eleven documented static source passes over each of five implementation branches. All **12 canonical findings remain open in the reviewed snapshots**. The required one hour of genuine active review could not be independently verified. This is an *administrative closure with an unmet/unverified duration condition*, **not** proof that all original completion criteria were satisfied, and **not** an authorization to merge any implementation branch.

## Scope, identity and source revisions

- Repository: timberpile/Boorusama; batch AA01; agent 01.
- Report branch: review/AA01/agent-01; report root: docs/reviews/AA01/agent-01.
- Protocol: version 2; role: independent audit; exactly five assigned branches; configured minimum: 1 active review hour (unverified).
- Instructions used for source review: AGENTS.md, docs/development_workflow.md, docs/issue_workflow.md and .agents/skills/verify-change/SKILL.md on develop at 422aeae087c1108e655d85d1a3dac25120456cd6. Current develop instructions were checked again for this documentation-only closure.
- All source-head SHAs below were still observed unchanged on 2026-10-30. The original develop and merge-base SHA was 422aeae087c1108e655d85d1a3dac25120456cd6. Current develop had advanced to **894ab270693cdb054a5d527c96182e21e2b14ffc** (12 commits ahead); the new combined code candidate has **not** been audited or tested.

| Target | GitHub issue and exact branch | Pinned head | Static passes | Canonical findings |
| --- | --- | --- | --- | --- |
| [T001](branches/T001.md) | #113 — bug/113-collection-pagination | a1bc1d42903861a46e7230349515946bae678357 | 11 | F0004, F0005, F0006 |
| [T002](branches/T002.md) | #114 — feature/114-timeline-toolbar | 5bb52794468b172b7d6878fb825b42b00d654675 | 11 | F0007, F0009, F0012 |
| [T003](branches/T003.md) | #116 — feature/116-compact-follow-button | 5ac3ad9bc5f852f000012499c19468151c73734b | 11 | None |
| [T004](branches/T004.md) | #117 — feature/117-pixiv-favorites | e2929259b7725c484d11483d6ea48270079eb2f4 | 11 | F0001, F0008 (cross), F0010 |
| [T005](branches/T005.md) | #118 — feature/118-pixiv-following-artists | 1d02bef637966999fbd0b72ecb9c6f0e1eedce8a | 11 | F0002, F0003, F0011 |

The reviewed first cycle accounted for each substantive changed source, test, configuration, and handoff file. Later cycles traced consumers, paging/result semantics across all 16 booru engines, async races, blacklist state, local media safety, Pixiv authentication/cursor validation, navigation, settings persistence, and cross-branch compatibility. Review coverage refers **only to the pinned heads**, not future commits or the newer develop tree.

## Canonical findings — 12 unique records

**Classification:** seven defects and five risks. Two high and ten medium severity. Eight static-confirmed and four high-confidence; no runtime-reproduced finding is claimed. Twelve findings open, none resolved or withdrawn. The confidence label static-confirmed means a reachable source path was established, not that Flutter or a device reproduced the outcome.

| Finding | Affected work | Kind / severity / confidence | Origin and supported conclusion |
| --- | --- | --- | --- |
| [F0001](cross-branch-findings.md) | #117; #113 corrective dependency | Defect / medium / static-confirmed | Inherited: the existing Grid ignores Pixiv's explicit hasMore; an empty-but-continuing source page stops too early, and a full final page leaves redundant Load More until #113 is integrated. |
| [F0002](branches/T005.md) | #118 | Defect / **high** / static-confirmed | Introduced: direct artist-card BooruImage previews bypass the user's ExplicitContentBlockOverlay/media-blur preference when Pixiv permits adult content. |
| [F0003](branches/T005.md) | #118 | Risk / medium / high-confidence | Introduced: unknown x_restrict is treated as 0, and sanity_level is ignored. Existing Pixiv rating logic explicitly treats x_restrict=0 plus sanity_level=6 as explicit; live DTO occurrence remains unverified. |
| [F0004](branches/T001.md) | #113 | Defect / medium / static-confirmed | Test fixture interaction: legacy multi-page tests and FakeBooruBackend report per-page total and maxPage=1, incompatible with #113's authoritative boundaries; FakeBooruBackend also discards hasMore when rebinding origin. |
| [F0005](branches/T001.md) | #113 | Defect / medium / static-confirmed | Pre-existing unresolved: paginated mode clears cumulative items, so total-only sources cannot establish their last page by comparing the current page's item count with global total. |
| [F0006](branches/T001.md) | #113 | Defect / medium / static-confirmed | Existing symptom/newly worsened case: Gelbooru maxPage is an accessible search-depth *cap*, not a true last populated page; giving it priority over an empty result or total:0 creates redundant Load More even on empty results. |
| [F0007](branches/T002.md) | #114 | Defect / medium / static-confirmed | Inherited mismatch: mixed-case live blacklist rule updates store raw active-filter keys but normalized tag-count keys, so actual filtering, hidden count, and popup toggles disagree. |
| [F0008](cross-branch-findings.md) | #117 with shared #113 Grid | Risk / medium / high-confidence | Inherited async race: stale cancelled page-2 fetch during refresh can decrement the newly reset page 1 to page 0 and publish a stale error; runtime interleaving not tested. |
| [F0009](branches/T002.md) | #114 | Defect / medium / static-confirmed | Inherited shared paging state: BlacklistControls retains an out-of-range tag page after a rule reduction or popup/profile switch; matching rules can exist while no chips render. |
| [F0010](branches/T004.md) | #117; existing Pixiv media transport | Risk / **high** / static-confirmed | Inherited conditional security path: Pixiv image URLs can be supplied without an origin check and fetched via a Dio that adds an API Bearer to requests. A foreign URL could receive the short-lived access token; no live exfiltration was observed. |
| [F0011](branches/T005.md) | #118 | Risk / medium / high-confidence | Introduced model omission: user_previews-level is_muted is dropped; muted artists could still show supplied previews if artwork-level mute is unset. Current API shape and intended UI policy need confirmation. |
| [F0012](branches/T002.md) | #114 | Risk / medium / high-confidence | Inherited concurrency: successive blacklist rule changes can complete isolate-based counts out of order; stale results may replace the newest filtering/count state. |

Full source-pinned file/symbol/line evidence, disproof attempts, triggers, fixes, verification scenarios, and histories live in the canonical linked files. F0001 and F0008 are deliberately counted once across branches in [cross-branch findings](cross-branch-findings.md).

## Recommended remediation order and concrete acceptance

1. **Security and user content protection:** Address F0010 at the Pixiv API-vs-media HTTP boundary: permit Bearer credentials only to trusted API destinations or use a separate credential-free media Dio. Add a foreign-absolute-image-URL fixture asserting no Authorization header escapes, then retest Pixiv API refresh and CDN thumbnails/downloads. Fix F0002 in #118 by preserving preview artwork rating alongside each URL and applying the existing explicit-media cover, with blur on/off and account-level restricted-content widget checks. Both are high priority; F0010 is conditional, and F0002 is a direct content-preference omission.
2. **#113 and #117 pagination:** Repair F0004's shared fake transport and authoritative pagination fixtures (including preservation of hasMore), correct total-only paginated last-page handling F0005, and distinguish a Gelbooru accessible-depth ceiling from actual exhaustion F0006. Preserve explicit hasMore=true for an empty-but-continuing source page. Once #113's fixes are integrated into an approved combined candidate, recheck #117's F0001 and add a gated fetchMore-then-refresh concurrency test for F0008, ensuring page remains 1 and stale cancellation is suppressed.
3. **#114 blacklist toolbar:** Normalize one stable blacklist rule identity across tagCounts, activeFilters, filtering, popup, and count (F0007), scope/clamp rule pagination after live changes (F0009), and add generation checks around asynchronous rule recounting (F0012). Test uppercase CAT added after posts load, rules page 3 shrinking to 31–60 tags, and two overlapping changes with controlled completion order. Include a real popup/controller widget test; existing new toolbar tests use static Text placeholders.
4. **#118 remaining preview safety and semantics:** Use the established Pixiv rating classifier or conservative handling for unknown/high sanity levels (F0003). Preserve and test artist-level is_muted (F0011) with a verified API contract and chosen directory UX, without introducing extra preview requests. Test Public/Private, account switching, missing previews and origin-profile user:<numeric-id> Search navigation.
5. **#116 acceptance:** No actionable newly introduced source-level defect was identified. Still run the new compact-pill tests and existing full SearchPageScaffold tests at 240/320dp with 2x text; manually check Android touch area >=48 logical pixels, spinner geometry, modification badge, keyboard/pointer access and screen-reader semantics. No test pass is implied.

## Cross-branch integration constraints

- **#117 + #118** independently modify packages/booru_clients/lib/src/pixiv/pixiv_client.dart and lib/boorus/navigation_capabilities.dart. Retain both client part directives (pixiv_client_bookmarks.dart and pixiv_client_following.dart), apply the identical optional _get(cancelToken, followRedirects) change only once, and preserve both Pixiv Favorites eligibility and Following Artists tool registration. Update the shared pagination comment to describe both mechanisms. This is a predicted merge-edit overlap based on the exact patches, **not** an executed merge or conflict resolution.
- **#113 + #114 + #116:** Their source diffs are in distinct files but share Grid/Search/UI consumers. Verify combined pagination, floating toolbar, blacklist action, narrow Search row and compact Follow after authorized integration. The new #114 setting keepTimelineToolbarVisible is intentionally separate from the legacy showPostListConfigHeader backup field; preserve that interpretation.
- Dependent work must retain the established gates: #115 waits for #114 merge; #119 waits for #117 merge; #120 waits for #118 and #100 merges. Do not silently pull unmerged task-branch commits into a sibling.
- **Current develop changed** by 12 commits after the common audited base. Future implementers must refresh references and inspect each relevant delta before deciding applicability of a source finding; no audit statement here certifies the current develop integration candidate.

## Actual verification, limits and closure meaning

**Performed:** GitHub source inspections, complete changed-file inventory on pinned targets, review of issues/requirements/tests/consumers, source diff and commit comparisons, engine result-contract comparison, media/auth request-path tracing, and publication of a separate documentation commit per completed branch pass. Eleven static passes are documented for each target in [review-log.md](review-log.md). The previous check at all five target SHAs found zero commit-status contexts and zero GitHub check runs: this is **no CI evidence**, not a passing or failing build.

**Not performed:** No FVM/Flutter/Dart formatting, analyzer, test execution, package regression, complete integration regression, build, emulator, physical Android/Maestro test, authenticated current Pixiv API response, or actual merge. No application source code was changed and no fixes were implemented. The audit did not change GitHub issue status, create PRs, modify implementation branches, or touch develop/master.

**Closure:** User explicitly requested that the audit summary be written and this task closed on 2026-10-30. Source-snapshot coverage is recorded; the independent **MIN_REVIEW_HOURS=1** active-time requirement is **not verified** and must not be retrospectively claimed satisfied. This administrative closure is distinct from fixing findings or declaring any implementation branch safe to merge.

**Future implementation handoff:** Start with current AGENTS.md and workflow/verify-change skill, continue each exact preexisting task branch in isolation, use FVM and scope-relevant tests, preserve unrelated work, and record actual test results. Before any authorized develop integration, run the complete suite on the final combined candidate via ./scripts/run_regression_tests.sh under the repository guidance. Follow Android emulator leases and Maestro procedure for device acceptance. GitHub Issues remain the only task tracker; these finding IDs are audit evidence references, not new issue numbers.
