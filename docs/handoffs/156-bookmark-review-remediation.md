# Bookmark review remediation before continuing the rollout

## Mandate and starting point

Continue the existing `maintenance/156-shared-source-groups` task in its owned isolated worktree. The user requested investigation and a handoff for the local implementation agent, covering both the latest device findings and the four earlier review findings. This delivery adds requirements/design assets only, not runtime fixes or a new passing review.

Audited remote head: `0812367722defc59d36063ee9d4a631cf263b010`; inherited runtime/test candidate: `2074d452a4d715ebd1b15ed9d1fea8446471a4d2`. Read current `AGENTS.md`, the applicable repository skills, [the original #156 handoff](156-shared-source-groups.md), and [the diagnosis and remediation contract](../designs/2026-11-08-bookmark-review-remediation.md) before editing. Refresh branch refs, inspect worktree ownership and preserve newer changes. Do not reset to these SHAs or recreate completed #132/#154/#155/#158/#142/#143 work.

The latest user corrections override older #158 decisions about navigable leaves, the repeated current-group row, root Back visibility, picker density and ancestor-menu depth. They do not remove direct memberships, per-group mode persistence, hierarchical system Back, or the single scrolling timeline contract. Backup output remains version 10.

Do not proceed to #140 until the in-scope correctness fixes, required checks and independent review are complete. Retain the existing real Szurubooru Android gate from the original handoff. An unavailable test instance is an explicit remaining gate, not a reason to invent evidence or silently remove coverage. No PR, develop integration, release, issue closure or runtime push is authorized by this documentation delivery; honor any additional authorization in the local session.

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
| N8 | Ancestor menu only from depth 2; icon alternatives are supplied for selection, not silently chosen for production. |
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

Implement N1/N2 with R1 as the security regression gate. Preserve exact engine/site/installation/account isolation, cancellation and late-result guards. A temporary transport failure must not become a permanent missing-profile classification. A stored record remains locally manageable and exportable even when remote access fails.

Use a durable opaque cache generation and current authorization checks as separate concerns. Do not simply delete session IDs from the current cache key, fall back globally to URL-only cache entries, bypass blacklist checks, reuse a different account, or serialize credentials into cache identities. Cover both image and video users of the shared namespace.

Resolve N3 through the existing cover renderer and media pipeline with bounded candidate loading. Do not eagerly fetch every member or remote Group to manufacture a cover. Preserve legitimate GIF playback settings while removing unintended geometric motion.

### 3. Apply the approved UI corrections and local performance changes

Apply N5/N6/N8 in the shared Bookmark picker/browser components, covering single Post, saved-record, batch add/remove, Recent and sync-target callers. Do not turn an add-only batch action into a membership toggle. Move destinations must retain their cycle checks and distinct selection semantics.

Replace the four-image cover's inner scrolling layout with a fixed mosaic if the controlled N7 test confirms the suspected geometry path; otherwise fix the demonstrated image transition/identity issue. Keep the outer browser lazy. Do not disable scrolling or animation globally.

Profile N4 before broad optimization. Reuse existing indexed records and performance spans. Keep query, source, order, shuffle and availability invalidation correct. Do not cache whole libraries independently for every mode or apply stale results after profile changes.

### 4. Complete source and Group-state corrections

Implement the verified Realbooru policy/transport additions in N9. Preserve unsupported/custom-source denial, HTTPS/redirect/header restrictions and public read-only behavior. Do not advertise support based solely on a help page or successful HEAD request.

Fix R2/R3/R4 with focused production-path regressions. Preserve the previous #156 occurrence-selection, raw pagination and profile-isolation fixes. Do not mix in the deferred global Header redesign (#146-148), destructive Favorites Mirror Sync, new Pixiv UX, or nhentai implementation.

## Delegation and independent review

The lead owns account/action binding, durable cache generations, cached policy provenance, revocation, migration implications and the Group refresh/restoration logic. Bounded low-cost subagents may prepare deterministic fixtures, localized strings, fixed mosaic/picker geometry changes, SVG/import checks and narrow tests in disjoint files. Review their diffs before integrating. Avoid concurrent edits to shared access/cache files.

The final independent reviewer must be an actual **Sol High** agent, following the later user instruction recorded in the #143/#156 handoffs. It must not have authored the canonical implementation/tests/fixes. Provide base/head, the complete remediation delta, this contract, actual failed and passing commands, and device evidence. Require adversarial coverage of account borrowing, persistent cache reuse versus revocation, outage placeholders, mode invalidation and both picker presenters. Fix findings, rerun checks and obtain final re-review of the corrected candidate. Do not relabel self-review, a weaker model, or old approval as this review.

## Verification matrix

Use FVM and the repository's pinned dependencies. Keep runtime tests behavioral; use controlled clocks, completion gates and generously bounded I/O guards rather than fragile performance assertions. Suggested new filenames below are proposals, not claims that tests already exist.

| Area | Minimum regression cases |
| --- | --- |
| Access/outage | Delayed remote policy, policy failure, valid last-known same-actor policy, no prior policy, 503/timeout/DNS failure, explicit 401/403, deleted profile, blocked URL and unrelated healthy source. No invisible occupied cells, silent policy bypass or row reindexing under an open action. |
| Durable cache | Seed real disk cache, fully recreate the provider container/process with unchanged profile/policy, disable network and render/decode. Then change credentials, source path, blacklist, delete/recreate profile, revoke in flight, change anonymous policy and retry. Verify permitted reuse and denied cross-scope reads separately. |
| Cover fallback | First four candidates fail, a later candidate is healthy/cached; bounded request count, stable positions, no forbidden thumbnail, no full-library crawl, empty/all-denied fallback and recovery after explicit retry. |
| Performance | Large known fixture; cold migration versus later startup; warm Structure/All switching; unrelated library publication; profile change during computation; no content-detail requests merely to open/switch. Reuse existing benchmark harness and record same-host before/after results. |
| Empty/browser | Children-only group, truly empty leaf, direct records filtered to zero, all unavailable, All Bookmarks genuinely empty, root and Default. Ancestor menu depth 0/1/2/3, deleted current group and repeated rebuilds. |
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
5. Toggle Structure/All repeatedly on a large warm group. Record shell/projection/media timings separately and verify scoped results, deduplication, query and per-group mode persistence.
6. Open normal and batch pickers. Leaf body selects without an arrow/self-only page. Parent body selects directly; its trailing zone opens children. No Home Back row. System Back still moves up, then closes at root. Test 320dp, enlarged text and keyboard.
7. In Home and a root-level group the title is plain. In a subgroup the title opens Home/ancestor navigation. No extra breadcrumb row.
8. Delete only a disposable Realbooru test profile, open its saved group and decode a real image without creating another profile. Remote account actions remain unavailable.
9. Exercise R1-R4 and the real Szurubooru check as detailed above. Use test accounts/content; do not send unnecessary remote Favorite mutations merely to verify button visibility.

## Completion and continuation

Commit coherent fixes with the owning issue references, preserving #143/#158/#156 context where appropriate. Update the normal #156 completion handoff with exact commits, source-supported causes, actual timings/tests, independent review and remaining limits; retain historical evidence rather than rewriting it as a pass. Report any product deviation before shipping it. Icon choice is still a user decision and does not block correctness work: keep alternatives out of runtime until chosen.

After remediation, the required source/device gate and final independent approval, resume the existing order #140 -> #141 -> #157, subject to the existing integration/publication restrictions. Nothing here authorizes bypassing a gate, deleting a user's cache, changing backup version, or merging develop.
