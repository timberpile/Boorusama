# Bookmark review remediation before continuing the rollout


## Active continuation (supersedes paused cache/icon and stage-order instructions)

The user resumed the existing branch at `5a73ae623`, also verified as the remote
head. The explicit accepted cache decision is URL/custom-key reuse; the paused
opaque generation and policy-snapshot store are rejected and being removed.
The separate offline patch `2fbcc64e6` is selectively integrated, not blindly
cherry-picked. Its actual Flutter tests were previously unexecuted.

Family A is approved, with group modes Structure and Unified. Internal persisted
`allBookmarks` values stay compatible; the global All Bookmarks destination is
unchanged. Separate #140/#141 and independent #157 work may begin before #156
acceptance, but no PR, develop integration, push or issue closure is authorized.
Penpot currently has no connected instance; selected editable SVGs and exact
component names are preserved in the design README.

The paused checkpoint below is historical evidence, not the active cache or icon
contract. Its failed/interrupted checks must be superseded by final-candidate
verification, Android restoration and independent Sol High approval.

### Combined implementation checkpoint

The underlying image manager now preserves ordinary URL/custom keys, separate
renditions and existing quota/lease ownership. Removed the paused generation
allocator, config fields, namespace provider and duplicate policy store. Runtime
actor epochs, presentation/transport guards and late-result rejection remain.
The imported Danbooru tests needed their local blacklist fixture corrected to
the existing JSON-list representation; their decoded-cache/outage paths pass.

The native refresh failure also exposed a test fixture that bypassed the normal
origin-aware repository. Corrected that seam without weakening the page-level
assertions. The corrected test fails against the old production scope/cache
implementation and passes with refreshed title, description and member IDs.
Danbooru descriptions now use the refreshed native envelope's DText for both
public and saved actors instead of retaining separately cached HTML.

Cover decoding needed completion-driven test pumping, not a broader candidate
scan. Independent Sol High review additionally found skipped Pool covers when
Posts occupy earlier slots. Sequential remaining-Pool allocation now has cached
1+1 and 2+2 regressions. Empty mosaic cells are decorative; exhausted candidates
expose one foreground Retry, with bounded reattempt coverage. Browser root Back
and child ancestor navigation are tested under the accepted depth contract.

Durable evidence is under `.worktrees/_artifacts/156-resume/`. Focused actor,
policy, preload, cover and refresh checks passed 16 tests; outage/details and
translation consumers passed 27. The first broad run completed with 2,584 passes
and three failures: the obsolete root-popup expectation and two keyboard audits
of decorative empty-cover Retry buttons. The latter audits now pass; the
corrected hierarchy scenario also passes. These partial runs do not establish a
final-candidate complete regression pass. Full regression, ordinary-main Android
acceptance/restoration and the exact-head independent review remain pending.

The first complete runner on `83c808143` reproduced a card-title hit-test
regression introduced by wrapping its label in IgnorePointer. That run was
stopped after the failure and is not a pass. Retaining title hit testing while
letting only the decorative gradient ignore pointers fixes the existing drag
selection test. The corrected selection, hierarchy and actual cover Retry batch
passes 18 tests (`selection-covers-final.log`). A fresh complete run and APK are
required for this correction.

Serial host probes retain the before/after attribution limit: 9,000 synthetic
rows took 764.6–935.3 ms for first tag-index construction and 0.282–0.601 ms on
reuse; 1,000 real Hive rows wrote in 719.2 ms and cold-loaded in 197.6 ms. These
do not measure Android opening, mode-switch frames or decoded-media latency.

Fresh Realbooru DAPI still returns HTTP 200 with `success=false`. Existing HTML
listing/detail parsing and guarded thumbnail/sample GET/decode succeed on the
host with the app's ordinary first-party Referer. No profile or extra CDN was
introduced. Real Android public-reader acceptance is still pending. Szurubooru
advertises anonymous Pool viewing but restricts listing to registered users;
the preserved app contains no Szurubooru profile. A bounded 100-Post discovery
found no Pool, so a known existing Pool ID is requested rather than bypassing
listing permissions or treating the listing 403 as a view denial.

Separate reviewed foundations are committed at #140 `308463b1d`, #141
`1167f6dbf`, and #157 `7a621b304`. Their own handoffs retain production UI,
combined/full-regression and Android gates. Sol High's Pixiv tag-omission P2 was
reproduced, corrected and independently re-reviewed; no remaining actionable
foundation finding was reported. This does not complete those issues.

## Paused implementation checkpoint (2026-11-08)

The user explicitly requested committing the current state and pausing. This
checkpoint is **incomplete and not approved**. The original runtime approval in
`156-shared-source-groups.md` does not cover this remediation delta. Fetched and
fast-forwarded the existing clean task worktree to `363ab8672` before editing.
No runtime push, PR, develop integration, #140 work, issue closure or icon-family
selection occurred. Backup output remains version 10.

Implemented work in progress includes captured-actor selection snapshots and
execution guards; repository-owned opaque local media generations (excluded from
transfer codecs); policy snapshots and visible outage slots; shared compact
picker corrections; children-only browser emptiness and ancestor-menu depth;
optimistic serialized mode preferences; bounded cover candidates with fixed
mosaic slots and source backoff; deletion navigation normalization; indexed
checkpoint restoration; and Group metadata invalidation/stale-seed rejection.
These changes still require debugging, adversarial review and complete validation.

Controlled baseline regressions reproduced public selection borrowing another
saved actor, repeated deletion fallback, page-3 checkpoint loss at offsets zero
and 20, children-only empty UI, and stale route-seed acceptance after invalidation.
The deterministic original mosaic geometry remained stable after allowing for
floating-point rounding; no confirmed attribution of the reported geometric
motion has been established. The fixed mosaic is not evidence that the reported
animation was reproduced or resolved on Android.

Durable local evidence and recovery scripts are under
`.worktrees/_artifacts/156-remediation/` in the primary workspace. Logs retain
failed setup/compile attempts as well as later results; filenames do not imply
passing checks. In particular:

- `core-targeted-first.log`: 12 focused tests passed on an earlier intermediate
  state (selection, checkpoint, envelope cache and original mosaic geometry).
- `action-profile-targeted.log`: 21 tests passed on an earlier intermediate
  state (profile-generation lifecycle, action parity and mode preferences).
- `ui-targeted-corrected.log`: 81 passes and two old root-path assertions failed;
  subsequent assertion updates have not received a complete final rerun.
- `focused-corrections.log`: cover-fallback decode and native ContentGroupPage
  metadata/member refresh tests still failed. Diagnose these production-path
  cases before claiming N3/R4 complete; avoid weakening their intended behavior.
- `targeted-matrix.log`: the requested broad affected-suite run reported failures
  and was interrupted at the user's pause request. Some earlier failures have
  subsequent edits, but this log is **not a completed pass**. Revalidate profile
  write-error behavior, backup replacement rollback, hierarchy navigation,
  no-poster GIF autoplay, preload revocation and all updated picker consumers.
  Cancellation-time failures must be separated from completed test failures.
- `geometry-performance-before.log`: the original local workload probes completed
  within a run whose geometry fixture failed. The 9,000-row tag-index first-entry
  samples were approximately 750-889 ms, later entries 0.28-0.62 ms. The separate
  1,000-record Hive probe reported about 796 ms write and 202 ms cold load. These
  host probes do not measure Android opening/mode latency or explain the user's
  10/2-second observations. No matched final after-run has been recorded.
- Changed Dart files were formatted and `git diff --check` passed at checkpoint.
  Earlier scoped analysis reported errors/warnings on intermediate states; no
  clean analysis of the entire checkpoint is claimed.

The anonymous Realbooru DAPI GET returned HTTP 200 XML with `success=false` and
an explicit site response that the API is offline indefinitely. No anonymous
Realbooru permission was added. A Szurubooru URL is now present in the ignored
primary credential file: `/api/info` returned 200 and anonymous `/api/pools`
returned 403. Check the existing app profile or obtain the needed authorized test
actor before declaring the real Szurubooru gate satisfied. Never print credential
values or private payloads. Redacted probe results are retained locally.

Android preparation used an exclusive `emulator-5554` lease, a fresh original APK
and full nine-root archive, verified pre-isolation equivalence, and inventoried
parking plus a working clone. No remediation APK was built/installed and no
Maestro acceptance test ran before the pause. Restoration evidence is recorded
in `android/restoration.json` and the associated archive comparison results.
All nine original roots, APK, permissions and settings were restored. Both the
restored archive and complete post-cleanup archive comparisons passed. Window
size/density match the baseline; the original app was resumed because it had
been running before this campaign. `final-system-check.json` passed and the
exact emulator lease was released (`lease-release-result.json`). The sole Maestro
flow resumed the restored original app; it is not remediation acceptance evidence.
Check these durable results, not historical campaign reports, when resuming.
The original APK hash for this campaign is
`a6c31bf518d151fec6d8100b4623ee24d6845d5953540425a3e2b1e275e559ce`.

Remaining work includes the unresolved regressions, complete targeted reruns,
final-candidate full regression, current-source normal-app Android/Maestro
verification and restoration, measured cold/warm behavior, and the independent
actual Sol High final review/re-review. No reviewer has been spawned for this
checkpoint. The SVG family remains awaiting the user's selection. Keep #140
and develop integration gated.

## Mandate and starting point

Continue the existing `maintenance/156-shared-source-groups` task in its owned isolated worktree. The user requested investigation and a handoff for the local implementation agent, covering both the latest device findings and the four earlier review findings. This delivery adds requirements/design assets only, not runtime fixes or a new passing review.

Audited remote head: `0812367722defc59d36063ee9d4a631cf263b010`; inherited runtime/test candidate: `2074d452a4d715ebd1b15ed9d1fea8446471a4d2`. Read current `AGENTS.md`, the applicable repository skills, [the original #156 handoff](156-shared-source-groups.md), and [the diagnosis and remediation contract](../designs/2026-11-08-bookmark-review-remediation.md) before editing. Refresh branch refs, inspect worktree ownership and preserve newer changes. Do not reset to these SHAs or recreate completed #132/#154/#155/#158/#142/#143 work.

The latest user corrections override older #158 decisions about navigable leaves, the repeated current-group row, root Back visibility, picker density and ancestor-menu depth. They do not remove direct memberships, per-group mode persistence, hierarchical system Back, or the single scrolling timeline contract. Backup output remains version 10.

The resumed user request permits separate #140/#141 and independent #157 foundation work during this remediation. Develop integration still requires every applicable acceptance gate. Retain the existing real Szurubooru Android gate from the original handoff. An unavailable test instance is an explicit remaining gate, not a reason to invent evidence or silently remove coverage. No PR, develop integration, release, issue closure or runtime push is authorized by this documentation delivery; honor any additional authorization in the local session.

## Delivery scope

The specification contains source evidence, confidence levels and implementation instructions. Treat its finding identifiers as review references, not a separate task tracker. Continue using the existing GitHub issues for task status.

| Reference | Required result |
| --- | --- |
| N1 | No invisible Bookmark cells while source policy is loading or failing; a source outage cannot block unrelated sources. |
| N2 | Reuse correctly authorized persistent media across ordinary restarts and mode changes, without weakening revocation or account isolation. |
| N3 | Group covers recover from unavailable first candidates using bounded, policy-safe alternatives. |
| N4 | Measure cold opening and mode switching, then remove confirmed local/remote bottlenecks; do not assume all saved Posts must be fetched again. |
| N5 | Groups containing only subgroups show neither a trailing divider nor a misleading No bookmarks section. |
| N6 | Compact, wider, consistent modal and anchored pickers; right-aligned glyph within a generous navigation target; no navigation for leaves or repeated self row; no visible Home Back action. |
| N7 | Four cover tiles stay fixed relative to their group card during scrolling and overscroll. |
| N8 | Ancestor menu only from depth 2; approved family-A icons for Structure/Unified. |
| N9 | Add verified exact-source anonymous Realbooru reads, or report the concrete live transport blocker without fabricating a profile. |
| R1 | Public/source-bound selections cannot borrow another saved account for actions. |
| R2 | Deleting the currently open group normalizes navigation once, without cascading upward. |
| R3 | Paginated Group checkpoints restore the saved page even at offset zero. |
| R4 | Group refresh updates visible metadata and members coherently, without reseeding stale initial data. |

## Execution order

### 1. Establish reproducible evidence and protect data

Read the current source/test boundaries named in the specification. Preserve the user's cache and Bookmark database; do not clear app data to make the symptoms disappear. Record build SHA, normal app entry point, device/viewport/text scale and fixture sizes. Collect redacted counters/timings, not credentials, private tags, full URLs with query secrets, or screenshots exposing unrelated content.

Use controlled delayed/failing requests to reproduce a source-policy outage separately from a CDN outage. Differentiate first startup migration, warm local library load, first visible tiles and final media decode. Device reports of approximately 10 seconds and 2 seconds are observations, not measured attribution.

Reproduce R1 first through the actual production selection toolbar, not merely a resolver unit test. Revalidate the other earlier findings against the current candidate. If a claimed path is disproved, preserve the counterexample/test and explain why; do not manufacture a fix for a nondefect.

### 2. Resolve access, cache and source failures together

Implement N1/N2 with R1 as the actor-binding regression gate. Preserve exact engine/site/installation/account isolation, cancellation and late-result guards. A temporary transport failure must not become a permanent missing-profile classification. A stored record remains locally manageable and exportable even when remote access fails.

Use ordinary URL/custom-key media storage, with current authorization checks at presentation/transport and late-publication boundaries. Remove the rejected generation allocator and duplicate policy store. Preserve global/profile local rules and reactively available server preferences, actor identity, redirect/header restrictions and cancellation; test image/video consumers separately.

Resolve N3 through the existing cover renderer and media pipeline with bounded candidate loading. Do not eagerly fetch every member or remote Group to manufacture a cover. Preserve legitimate GIF playback settings while removing unintended geometric motion.

### 3. Apply the approved UI corrections and local performance changes

Apply N5/N6/N8 in the shared Bookmark picker/browser components, covering single Post, saved-record, batch add/remove, Recent and sync-target callers. Do not turn an add-only batch action into a membership toggle. Move destinations must retain their cycle checks and distinct selection semantics.

Replace the four-image cover's inner scrolling layout with a fixed mosaic if the controlled N7 test confirms the suspected geometry path; otherwise fix the demonstrated image transition/identity issue. Keep the outer browser lazy. Do not disable scrolling or animation globally.

Profile N4 before broad optimization. Reuse existing indexed records and performance spans. Keep query, source, order, shuffle and availability invalidation correct. Do not cache whole libraries independently for every mode or apply stale results after profile changes.

### 4. Complete source and Group-state corrections

Implement the verified Realbooru policy/transport additions in N9. Preserve unsupported/custom-source denial, HTTPS/redirect/header restrictions and public read-only behavior. Do not advertise support based solely on a help page or successful HEAD request.

Fix R2/R3/R4 with focused production-path regressions. Preserve the previous #156 occurrence-selection, raw pagination and profile-isolation fixes. Do not mix in the deferred global Header redesign (#146-148), destructive Favorites Mirror Sync, new Pixiv UX, or nhentai implementation.

## Delegation and independent review

The lead owns account/action binding, selective URL-cache integration, revocation, local/server policy composition and Group refresh/restoration logic. Bounded low-cost subagents may prepare deterministic fixtures, localized strings, fixed mosaic/picker geometry changes, SVG/import checks and narrow tests in disjoint files. Review their diffs before integrating. Avoid concurrent edits to shared access/cache files.

The final independent reviewer must be an actual **Sol High** agent, following the later user instruction recorded in the #143/#156 handoffs. It must not have authored the canonical implementation/tests/fixes. Provide base/head, the complete remediation delta, this contract, actual failed and passing commands, and device evidence. Require adversarial coverage of account borrowing, persistent cache reuse versus revocation, outage placeholders, mode invalidation and both picker presenters. Fix findings, rerun checks and obtain final re-review of the corrected candidate. Do not relabel self-review, a weaker model, or old approval as this review.

## Verification matrix

Use FVM and the repository's pinned dependencies. Keep runtime tests behavioral; use controlled clocks, completion gates and generously bounded I/O guards rather than fragile performance assertions. Suggested new filenames below are proposals, not claims that tests already exist.

| Area | Minimum regression cases |
| --- | --- |
| Access/outage | Delayed remote policy, policy failure, valid last-known same-actor policy, no prior policy, 503/timeout/DNS failure, explicit 401/403, deleted profile, blocked URL and unrelated healthy source. No invisible occupied cells, silent policy bypass or row reindexing under an open action. |
| URL cache | Seed ordinary URL/custom-key disk entries, recreate providers/process/cache manager and decode offline. Preserve distinct renditions. Change actor/policy and verify presentation/transport and in-flight publication revocation independently of shared storage identity. No generation database or cache clearing. |
| Cover fallback | First four candidates fail, a later candidate is healthy/cached; bounded request count, stable positions, no forbidden thumbnail, no full-library crawl, empty/all-denied fallback and recovery after explicit retry. |
| Performance | Large known fixture; cold migration versus later startup; warm Structure/Unified switching; unrelated library publication; profile change during computation; no content-detail requests merely to open/switch. Reuse existing benchmark harness and record same-host before/after results. |
| Empty/browser | Children-only group, truly empty leaf, direct records filtered to zero, all unavailable, global All Bookmarks genuinely empty, root and Default. Ancestor menu depth 0/1/2/3, deleted current group and repeated rebuilds. |
| Picker | Modal + anchor + context + batch + Recent; leaf versus parent, hidden Home Back, direct-membership indicators, full-row hit coverage, split boundary, keyboard focus, RTL, large text, small height and naming-dialog Back ownership. |
| Mosaic | Deterministic decoded images, fast drags and top/bottom overscroll; tile-to-card relative rects invariant, no inner Scrollable, no reentry animation or Hero. Test scrolling from a thumbnail as well as the card label. |
| Realbooru | Existing parser/engine, bodyless anonymous API GET, media GET and decode, permitted redirects, forbidden host/scheme/path/query, no Cookie/Authorization/account proxy inheritance, profile deletion, reboot and unavailable recovery. |
| Earlier R1-R4 | Production public selection with another matching profile; delete-current fallback; paginated page 3 at offset 0 after eviction; metadata + manifest changes on refresh with repeated Group occurrences and stale seed. |

Run affected existing bookmark/content/backup/viewer tests and the complete suite for the final candidate because cache/access/shared UI are cross-cutting. Any Kurumi change requires its complete package suite and affected app consumers.

```bash
workers="$(python3 scripts/physical_core_count.py)"
# Format changed Dart files only; analyze affected scope/full project as required.
fvm flutter test --no-pub "--concurrency=$workers" test/core/bookmarks test/core/content test/core/posts/pools test/core/posts/links test/core/backups test/application
./scripts/run_regression_tests.sh
git diff --check
```

Use Maestro with an exclusive emulator lease and a complete fresh backup inventory. Preserve original APK, all data roots, permissions, settings and cache. Verify restoration before releasing the lease. Do not repeat the original #156 fixed-directory restoration mistake. Test ordinary `lib/main.dart` UI; synthetic storage helpers do not prove this screen.

## Short device acceptance script

1. Open an existing cached mixed-site group with Danbooru API stalled, then with only CDN stalled. Healthy-source records remain immediately usable; cached authorized images render; other records show explicit state, never invisible holes.
2. Load several images, force-stop, disable network and reopen the same group. Confirm actual decoded thumbnails after a true restart. Repeat after a scope-changing profile edit to verify isolation.
3. Use a group whose earliest four cover candidates fail. Its title/card stays usable; an allowed later candidate can supply a cover without a request storm. Repeat Home scrolling/overscroll: mosaic tiles stay attached.
4. A children-only group has just child cards. An empty leaf still has an appropriate empty state; searching existing direct content to zero keeps search controls.
5. Toggle Structure/Unified repeatedly on a large warm group. Record shell/projection/media timings separately and verify scoped results, deduplication, query and per-group mode persistence.
6. Open normal and batch pickers. Leaf body selects without an arrow/self-only page. Parent body selects directly; its trailing zone opens children. No Home Back row. System Back still moves up, then closes at root. Test 320dp, enlarged text and keyboard.
7. In Home and a root-level group the title is plain. In a subgroup the title opens Home/ancestor navigation. No extra breadcrumb row.
8. With no saved Realbooru profile, open its saved group and decode a real image through the public reader. Remote account actions remain unavailable.
9. Exercise R1-R4 and the real Szurubooru check as detailed above. Use test accounts/content; do not send unnecessary remote Favorite mutations merely to verify button visibility.

## Completion and continuation

Commit coherent fixes with the owning issue references, preserving #143/#158/#156 context where appropriate. Update the normal #156 completion handoff with exact commits, source-supported causes, actual timings/tests, independent review and remaining limits; retain historical evidence rather than rewriting it as a pass. Report any product deviation before shipping it. Family A is approved and used for Structure/Unified; family B is archived.

Separate #140 work and independent #157 foundation work may proceed now; #141 follows a stable #140 contract. Keep each owning branch and evidence separate, with final integration of #157 dependent on #140/#141. Nothing here authorizes bypassing a gate, deleting a user's cache, changing backup version, or merging develop.
