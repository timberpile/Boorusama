# Combined branch review and test handoff

## Candidate, scope and limits

Requested by the user: review the published task branches, assemble a separate combined test branch, and provide a German manual checklist. This repository handoff is English; the user-facing German checklist accompanies the chat delivery.

- Test branch: `maintenance/combined-testing-2026-11-08`.
- Combined runtime/source candidate: `68c4635b9790e73acc01467874fcdac9fb44ac97`.
- Main architecture/remediation baseline: `8672cf2ba235fbc810bbcf3296efef1eb4410a37` from `maintenance/156-shared-source-groups`.
- Exact inputs and ancestry evidence: [assembly manifest](combined-testing-2026-11-08.json).
- Assembly verification: [GitHub Actions run 42523832788](https://github.com/timberpile/Boorusama/actions/runs/42523832788), completed successfully.
- No task branch, `develop`, release or issue status was changed by this assembly. No PR was created.

The source review covered the changed contracts and their consumers, the latest handoffs and tests, cache/access/outage and cover rendering, selection actor capture, Group refresh/restoration, the Pixiv Work/Page foundation, nhentai DTO/client/catalog persistence, and the overlapping pagination/prefetch branches. It is not a proof of every execution path. Findings below are source-supported unless explicitly marked as a translated control-flow reproduction. No new Flutter/Dart build, Flutter regression or Android run was performed by this review. The newly combined candidate has **not** inherited a passing full regression merely because individual inputs passed.

## What is included

| Input | Frozen commit | User-visible status |
| --- | --- | --- |
| `develop` | `266a14c0f` | Includes the accepted Classic double-tap zoom and 2x comic-detail behavior. |
| #156 architecture/remediation stack | `8672cf2ba` | Unified local storage/hierarchy, profile-independent import/access, existing source groups, URL-cache/outage and picker/browser fixes. |
| #140 Pixiv Work foundation | `d7298c5a0` | Source, mapper and provider foundation; new listing/viewer integration is incomplete. |
| #141 Pixiv Work/Page Bookmark foundation | `01fa08584` | Draft targets, codec/storage tests; generic picker/share and production UI integration are incomplete. |
| #157 nhentai foundation | `cf71fb22e` | Package client, DTOs, media policy and tag-cache coordination; app engine/route/viewer integration is incomplete. |
| #160 viewport thumbnail prefetch | `d13e06592` | One-viewport thumbnail layout cache; runtime changes also inherited by #162. |
| #162 unified page prefetch | `dfe1c4690` | Shared bounded automatic continuation and dispatch-time activity checks. |
| #161 Pixiv Explore pagination | `db54e43bb` | Preserves source pagination metadata through the mapped result. |
| #144 collection sync | `4dbc9f08a` | Design and HTML mockup only, not a functioning folder-sync feature. |
| #136 design system | `1cb65e313` | Design/reference documents; not blanket implementation of all proposed timeline changes. |
| Architecture planning | `fdb68f657` | Approved decisions, plans and historical design material. |

The #132, #154, #155 and #158 predecessor heads and #55 branch head were confirmed ancestors. Their content is not replayed a second time. #142/#143 implementation is already part of the #156 stack.

Not resurrected: explicitly abandoned #163 masonry-ratio correction, the deferred #112 toolbar and old Android-Maestro experiment, already completed #53/#76 branch histories, historical review/publication-note branches, or the superseded standalone #156 offline-cache patch. The latter's accepted behavior is already incorporated into the newer #156 candidate. Default grid padding 4 is already present in `develop`.

## Assembly verification actually performed

Native Git merges were performed on an isolated GitHub runner, retaining each input as merge ancestry. All runtime/code merges completed automatically, including the shared PostGrid/controller, Pixiv Favorites tests and develop's viewer test changes. A clean merge is not a behavioral test.

Only the old #136 `AGENTS.md`, `docs/ui_style_guide.md` and `docs/handoffs/136-timeline-contract-20261103.md` conflicted. The newer #156 versions were retained. After the historical planning merge, the current #156 `AGENTS.md` was restored deliberately. One trailing-whitespace line in the imported historical `2026-11-05-work-page-action-options.md` was cleaned.

The assembly asserted that every selected input is an ancestor, checked `git diff --check`, and verified these files remained exactly equal to #156:

- `lib/core/content/content_media_access.dart`
- `lib/core/content/content_access_provider.dart`
- `lib/core/bookmarks/src/widgets/bookmark_local_group_card.dart`

The temporary assembly workflow was removed from the final tree. The first assembly attempt stopped at the historical whitespace check and published no combined result; the second completed and published the candidate. This is **Git assembly verification only**, not application CI approval. Later edits adding this report do not change runtime code.

## New review findings

These findings were not silently fixed in the assembly. Keep reproductions and canonical fixes on the owning task branch, then bring verified changes into this disposable test branch. Do not merge this omnibus branch into `develop` wholesale.

### C1. P2: a cached sample is ignored when the cover selects an uncached thumbnail

Source: `lib/core/bookmarks/src/widgets/bookmark_local_group_card.dart`, especially `bookmarkGroupPreviewUrl` and `_BookmarkGroupPreviewImage`; [pinned source](https://github.com/timberpile/Boorusama/blob/68c4635b9790e73acc01467874fcdac9fb44ac97/lib/core/bookmarks/src/widgets/bookmark_local_group_card.dart#L340-L447).

For a static image the selector now chooses a nonempty thumbnail URL ahead of the sample URL. The renderer passes only that URL to `BooruImage`, plus a custom terminal `_CoverFailure`. It does not try an already cached sample for the same record. During an outage a previously cached sample can therefore be ignored: the uncached thumbnail fails and the cover advances to another record or leaves a placeholder.

This is distinct from the fixed session-salted-cache bug. The normal URL cache works; the renderer asks it for a different rendition and never tries the available one. It also explains why passing the existing cached-fifth-candidate test is insufficient for this case.

**Fix direction:** prefer a thumbnail for normal loading, but check a bounded set of permitted, known cached static renditions before abandoning the record. Reuse a cached sample without downloading an original solely for a small mosaic. Preserve video-poster and GIF-static rules. Integrate terminal failure reporting after the fallback sequence, not before it.

**Important:** `BooruRawImage` selects `errorWidget` before `fallbackWidget`/`fallbackUrl`. Merely adding `fallbackUrls` while retaining the current outer terminal `errorWidget` does not make that fallback execute.

**Regression:** seed only the saved record's sample URL in the real cache, leave its thumbnail uncached, fail all HTTP requests, and mount the actual group card. Require decoded sample pixels, preserved card interaction and no premature candidate eviction. Also cover thumbnail-only cache, neither cached, and a GIF with no approved static poster.

Confidence: source-confirmed uncovered failure path; not reproduced in Flutter by this review. Owner: #156 cover remediation.

### C2. P2: cover cache probe and renderer disagree after media-host rewriting

Sources: `lib/core/bookmarks/src/providers/bookmark_cover_failures.dart`, `lib/core/images/booru_image.dart`, and `lib/core/configs/network/src/types/media_request.dart`.

After the per-source failure budget is exhausted, `bookmarkCoverCachedProvider` checks `manager.generateCacheKey(request.url)`. The actual image loader first applies `network.resolveMedia(...)` and uses `imageRequest.url`. A configured media-host override changes the URL. A valid cached rewritten URL therefore looks absent to the cover probe, and the renderer is never allowed to consume it.

**Fix direction:** use the same resolved media request and cache-key path for probing and loading. Keep URL validation, source context and current network overrides consistent. This does not require a new cache namespace or account-generation mechanism.

**Regression:** configure a media-host override, cache only the resulting URL, exhaust four earlier cover candidates, then expose a fifth cached candidate. Require actual decoding without an extra media request. Repeat after the override changes; the probe must not return stale eligibility for the previous resolved URL.

Confidence: source-confirmed key mismatch, conditional on an override and the cover backoff path; not device-reproduced here. Owner: #156.

### C3. P2: cancelled nhentai catalog writes can outlive the serialization queue

Source: `packages/booru_clients/lib/src/nhentai/tag_cache.dart`, `_wait`, `warmCatalog` and `_warm`; [pinned source](https://github.com/timberpile/Boorusama/blob/cf71fb22e142564d96a1f25cce85a48898ec52fc/packages/booru_clients/lib/src/nhentai/tag_cache.dart).

`_catalogTail` serializes `_warm` operations, but `_warm` awaits store mutations through `_wait`, which races the mutation against cancellation using `Future.any`. Cancellation completes that operation and its queue tail while the underlying `writeCheckpoint` or `upsertTags` Future can still run. The storage interface does not require a compare-and-swap or ordered completion contract.

An admissible sequence is: older checkpoint write starts and stalls; its caller cancels; a new catalog operation writes a newer checkpoint; the old write finishes last. Persistent progress can move backwards. A cancellation after source disposal has the same late-write concern when another coordinator shares the store.

**Fix direction:** once a storage mutation has started, keep the internal serialization barrier pending until that mutation settles, even if the caller has already been notified of cancellation. The simpler alternative is to await the bounded local write before returning cancellation. Separate cancellation of network reads from ownership of an in-flight durable mutation. Do not add a transaction/generation layer unless the chosen store actually needs one.

**Regression:** use controllable store completion gates, cancel during `writeCheckpoint`, schedule another sweep, and release writes in the adversarial order. The newer durable checkpoint must win; also check late upserts and disposal. Existing cancellation-during-upsert coverage does not establish this checkpoint ordering guarantee.

A Python translation of this control flow was executed during review: persistent `nextPage` changed from 3 back to 2 when the delayed old write completed. This is a deterministic control-flow reproduction, **not an execution of the Dart implementation**. Add the regression to the real Dart suite before fixing.

Confidence: source-supported concurrency defect, dependent on asynchronous store completion behavior. Current end-user exposure is limited because the nhentai foundation is not wired into the app. Owner: #157.

### C4. P3: nhentai tag DTO collapses absent observations into an empty list

Source: `packages/booru_clients/lib/src/nhentai/models.dart`, `NhentaiGalleryDetails.fromJson`; [pinned source](https://github.com/timberpile/Boorusama/blob/cf71fb22e142564d96a1f25cce85a48898ec52fc/packages/booru_clients/lib/src/nhentai/models.dart#L180-L220).

The `tags` list comprehension yields `[]` for absent, null or non-list input, just as for an explicit `tags: []`. The model cannot tell a future shared-Group mapper whether a source omitted a fact or authoritatively cleared it. A malformed individual entry also rejects the whole details DTO instead of preserving a usable subset.

**Fix direction:** retain observation presence/coverage in the DTO, as the corrected Pixiv foundation already does. Unknown must not become authoritative empty. Explicit empty can remain authoritative. For malformed subsets, either retain partial coverage or explicitly reject the observation without clearing previous tags; document the chosen behavior.

**Regression:** absent/null/non-list/explicit-empty/partial-malformed tag fixtures, followed by a shared-details merge test once the mapper is connected. Previously known native tags must survive an omitted refresh.

Confidence: confirmed information-loss boundary in the DTO. No actual Bookmark data loss is claimed, because the production nhentai mapper/persistence integration does not yet exist. Owner: #157 foundation completion.

## Previous review findings and progress

The latest #156 source/handoff addresses the earlier four findings: captured actor checks for public selections, one-time deletion fallback, indexed checkpoint restoration including offset zero, and coordinated metadata/member refresh with stale-seed rejection. These are not re-listed as unresolved defects merely because their Android matrix is incomplete.

[The #156 handoff](156-bookmark-review-remediation.md) reports a full regression on runtime/test candidate `6af367354ef8c7e09dd939543b1cbf9403f2da35`: 6,743 app tests, 1,671 package/CLI tests, 76 Python tests, two skips. Analysis has zero errors/warnings but 3,780 informational findings and exit code 1. Treat these as reported local evidence, not checks rerun by this review or a pass for this combined branch.

Pixiv #140/#141 have their own foundation test/re-review evidence, including the corrected omitted-tag behavior. They still lack production listing/viewer/picker wiring. nhentai similarly remains a package-level foundation. Combining these branches does not complete those issues or expose their proposed UI.

Realbooru has progressed beyond the previous failed DAPI probe: the latest handoff records native HTML-reader and image-decode success without a saved profile. Do not repeat the obsolete claim that anonymous Realbooru support is absent.

For Szurubooru, the latest handoff distinguishes anonymous `pools:view` from account-required `pools:list`; an anonymous list 403 is not evidence that reading a known Pool is forbidden. The remaining gate needs a known existing Pool ID/link with usable members, not a fabricated saved profile. Preserve all credentials and private fixture details locally.

The original latency/mosaic attribution remains open. Host before/after timing ranges do not establish an improvement, and scoped Android operations are not a matched measurement of tap-to-first-render or mode-to-decoded-frame latency. Stable exercised geometry is evidence for that path, not proof of the original symptom's cause. Penpot publication remains unperformed even though family-A icons and Structure/Unified labels are implemented in the app.

## Local checkout and verification before installing

Read the current `AGENTS.md`. Use a separate worktree; do not disturb the task worktrees or primary checkout. From the repository root, after checking that the destination does not already exist:

```bash
branch=maintenance/combined-testing-2026-11-08
path=.worktrees/combined-testing-2026-11-08
git fetch origin
# For a new local branch/worktree only. If it already exists, inspect and reuse it.
git worktree add -b "$branch" "$path" "origin/$branch"
cd "$path"
git status --short --branch
git rev-parse HEAD
```

Resolve dependencies with the pinned FVM SDK. Follow repository bootstrap instructions and use `./gen.sh` only when generated outputs are absent/stale. Do not upgrade SDK/dependencies to make the merge pass.

```bash
workers="$(python3 scripts/physical_core_count.py)"
fvm flutter pub get
fvm flutter test --no-pub "--concurrency=$workers" \
  test/core/content test/core/bookmarks test/core/posts/pools \
  test/core/posts/details test/core/posts/listing test/application \
  test/boorus/pixiv/works \
  test/boorus/pixiv_explore_pagination_test.dart
(cd packages/booru_clients && fvm flutter test --no-pub "--concurrency=$workers")
fvm dart analyze
./scripts/run_regression_tests.sh
git diff --check
```

These are requested next checks, not commands already passed on this combined tree. Prefer the normal project Android build/main entry point after compilation and regressions. Preserve signing/install compatibility and existing data. Use an emulator lease and complete backup/restoration if an agent performs device work. Do not clear cache before testing offline reuse.

## Manual acceptance matrix

Use a disposable nested local group with direct records, two children, a shared Bookmark in both children, a Pool and a Related reference. Use known harmless test images and disposable test accounts for mutation tests. Record build SHA, device, text scale and results. A failure should include minimal steps, expected/actual behavior and a redacted screenshot/log where useful.

| ID | Check | Expected |
| --- | --- | --- |
| M01 | Cache Danbooru images, force-stop, disconnect network and reopen Bookmarks. | Real decoded cached images, not only placeholders; no cache reset or invisible occupied cells. |
| M02 | Fail only Danbooru/API or its image requests in a mixed-site group. | Other sites remain usable; misses show explicit state/retry; local data and memberships remain intact. |
| M03 | Reopen and switch Structure/Unified repeatedly on a large warm group. | Correct deduplication and prompt local feedback; measure end-to-end time separately from image downloading. |
| M04 | Seed sample-only cover cache, then test a host-overridden cached cover after four failed candidates. | Both should reuse available bytes. C1/C2 are known review failure paths, not certified passes. |
| M05 | Compare Structure and Unified, including a record saved in two descendants. | Direct children/direct records versus deduplicated subtree; remote Pool/Work references stay individual records. |
| M06 | Search for a tag present only in a descendant; switch modes. | Structure searches direct records only; Unified finds descendant content; navigation/search state is coherent. |
| M07 | Save different modes for two groups, restart, rename/move them. | Per-group preferences survive; approved family-A icons and Structure/Unified terminology remain consistent. |
| M08 | Open a children-only group, an empty leaf and a search-empty direct list. | No fake empty timeline under children; genuine and query-empty states remain distinct. |
| M09 | Open titles at Home, depth 1 and depth 2; use Back. | Ancestor popup only from depth 2; normal Back goes one level up. |
| M10 | Exercise normal anchored Bookmark picker and batch Add/Remove dialog. | Compact rows/wider surface; parent body selects, trailing region navigates; leaves have no arrow/self-only page. |
| M11 | Picker Home/child system Back, Recent, creation cancellation; narrow width/large text/keyboard. | No visible Home Back; native Back goes up then closes; no clipped controls or unintended membership changes. |
| M12 | Scroll/overscroll many group cards and tap their labels. | Four cover tiles stay attached, labels remain interactive, no inner scrolling motion. |
| M13 | Remove one of two memberships, then Undo; move/delete a nested group. | Unrelated membership persists; Undo restores intended state; no hierarchy cycles or lost records. |
| M14 | Delete the currently opened depth-3 group, then trigger more rebuilds. | Stays at the immediate surviving parent, not repeated upward jumps. |
| M15 | Export/import nested v10 Bookmarks into a test profile-less installation, restart and merge again. | Identity, dates, hierarchy and memberships preserved; no artificial profiles or duplicate content. |
| M16 | Assign a prefilled group as Favorites Sync target and fetch explicitly. | Assignment does not delete/fetch; explicit additive fetch preserves manual members. |
| M17 | Pool/Related ordering, unavailable members and repeated occurrences. | Source order and stable member positions; Related preference persists without changing unrelated groups. |
| M18 | Pool page 3 at offset zero and positive offset; evict/reopen through mixed viewer. | Same page/occurrence position restored with bounded requests. |
| M19 | Refresh a controlled changed Pool on a nonfirst page. | New metadata and members agree; old route seed cannot overwrite the refresh. |
| M20 | Public gallery with another same-site account present; select content and inspect actions. | No silent account borrowing. Use test accounts; avoid unnecessary real Favorite writes. |
| M21 | Delete a disposable Realbooru profile and open retained content; separately use a known Szurubooru Pool ID. | Realbooru remains readable where supported; Szurubooru gate requires actual Pool/member success. |
| M22 | Double-tap normal, square, portrait, panorama and comic images. | Accepted Classic behavior, no Fit Cycle setting, no upward auto-snap; comic detail 2x and return to reading transform. |
| M23 | Browse Gelbooru/Realbooru/Pixiv and scroll by about one viewport. | Thumbnail preloading is bounded and reduces pop-in; no all-results eager fetch. |
| M24 | Infinite/short/filtered-empty pages, paginated mode, route/tab switch and app background during queued prefetch. | Continuation progresses without loops; no hidden/background automatic dispatch; manual continuation remains usable. |
| M25 | Pixiv Explore following pages and Pixiv Favorites; then Following feeds. | Explore pagination does not stop solely because mapped visible results are empty; Favorites/source isolation and cached-only feeds are preserved. |

New Pixiv Work Image View/Overview, whole-Work picker actions and native nhentai Gallery browsing are **not yet manual acceptance items for the current app**, because production integration remains incomplete. Their source, identity, tag and storage tests can be run now. Likewise #144's HTML mockup is a design artifact, not a functioning sync workflow.

## Follow-up ownership

Reproduce C1/C2 on the #156 branch, and C3/C4 in #157, before applying the smallest fixes with focused tests. Preserve independent reviews already performed, but obtain new review of the changed candidate and full combined regression as required. No fixes, independent re-review or Android acceptance for these new findings is claimed by this report.

Continue #140 production integration, then #141 UI integration, with #157 foundation work parallel where interfaces are stable. Keep each canonical task branch and its handoff authoritative. Historical planning documents in the combined tree do not override later user-approved URL-cache behavior, selected icons, Structure/Unified labels, hierarchy decisions or current AGENTS.md.

The combined branch is for testing interactions across active work. It is not a request to squash every task into a single develop integration, close incomplete issues, publish a release or bypass the remaining #156 gates.
