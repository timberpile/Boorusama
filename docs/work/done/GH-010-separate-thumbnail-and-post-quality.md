# Separate thumbnail and post-viewer image quality

Priority: Normal
Affected feature: Listing thumbnails, post viewer and image-quality settings
GitHub: https://github.com/timberpile/Boorusama/issues/10

## Problem

The current Image quality setting controls listing thumbnails and post-viewer
images together. A sharp viewer image therefore also raises listing bandwidth
and cache use.

## Acceptance criteria

- Rename Image quality to Thumbnail quality, retaining Automatic as its default.
- Add independent Post quality to image-viewer settings, defaulting to Highest.
- Listing thumbnails use Thumbnail quality; viewer images use Post quality.
- Keep the available lower-quality image visible while the configured viewer
  image loads, then replace it in place without losing viewer position or
  visibly resetting navigation/layout.
- Higher-quality request failure keeps the available lower-quality image.
- Preserve per-booru image-details quality overrides and download-quality behavior.
- Existing Image quality values become Thumbnail quality. Existing installations
  receive Highest for the new Post quality default. Inspect the persisted but
  currently unused imageQualityInFullView field and safely handle its legacy
  values before deciding whether to reuse it.
- Verify meaningful settings/migration, per-booru resolver, loading/failure and
  gesture-position regressions, and visibly validate viewer replacement through
  Maestro on a leased Android emulator.

## Context and authorization

Live issue body read on 2026-10-05. User authorized implementation in the
prioritized program, after API coordination and Adaptive refresh, before cache
unification: `/tmp/boorusama-priority-program-2026-10-05/order.md`.

Follow AGENTS.md, development workflow, engineering guidelines and relevant
post/viewer documentation. Each ticket has a dedicated branch/worktree and an
implementer subagent; coordinator reviews. Integration, publication and cleanup
require their separate approvals. Implementation is prepared in its dedicated worktree; delivery/integration await explicit approval.

## Claim and implementation

- Coordinator: /root, authorized priority program 2026-10-05.
- Implementer/session: /root/gh010, assigned 2026-10-06.
- Dedicated worktree: /home/timber/code/Boorusama/.worktrees/gh-010-separate-image-quality.
- Branch: feature/10-separate-image-quality.
- Base: current local develop 46a20296bdd74c5eaf99f8917d1a1d1f69c0d0cd.
- Reviewed prerequisites: IDEA-007 d25f8a151501bb334fe06d809eb0781e09e35f57 and PS-031 delta 2df7c2c3461c4196a5e56faeeb0ca77241433228; exact original/replay provenance below.
- External implementation plan and preflight: /tmp/boorusama-priority-program-2026-10-05/gh010-plan.md and gh010-preflight.md.

Claim synchronized in primary and dedicated worktree before source implementation.
No develop integration, publication, or branch/worktree cleanup is authorized.

## Prepared implementation and verification evidence

- Dedicated implementation remains on feature/10-separate-image-quality; no integration, publication or cleanup of branch/worktree performed. Reviewed prerequisite replay: IDEA-007 d25f8a151501bb334fe06d809eb0781e09e35f57 → c2a76be6dc487abbe63708b7e880313499f56eb4; PS-031 delta 2df7c2c3461c4196a5e56faeeb0ca77241433228 → 0af21736b4cb5bd22d36ce441849a9c6008ce173.
- Thumbnail quality retains existing listing values and Automatic default. Additive viewer Post quality defaults to Highest, preserves explicit Automatic/Original and safely ignores the dormant legacy full-view value for migration. A unique enabled profile matching the post auth supplies its viewer override; otherwise global viewer quality applies. Engine overrides and download/preload policies remain independent.
- Progressive still media stages the existing provider through real decode and retains lower/previous pixels during transport or decoder failure. Distinct fallback/placeholder candidates are eligible even when the listing primary is empty or equals the target. Controller, known post layout, route and matrix remain stable. Actual decoded geometry controls contain/readiness, tall cropped AutoComic previews remain visible, representation/compatibility transitions cancel held edge drags, and ordinary animated frames retain their behavior.
- Production image deduplication now shares typed success/error completion data so single failures have no orphan error future and failed duplicates receive their original DioException through their own request handlers across Dio error zones. Shared successful byte data and original DioException identity, physical request count and pending-key cleanup are covered; retry/timeout/cache/API admission policies retain their prior behavior.
- Behavioral RED/GREEN includes Hive reload, ViewerConfigs/backup, delayed queued latest-state edits, explicit auth and engine resolution, actual decoded PNG retention/success/failure, cropped geometry, stable controller/matrix/AutoComic, original-on-zoom, held drags/animated frames, mixed duplicate origins, media-marker bypass, download and preload policy. Preserved original interceptor reproduces four single/duplicate404/timeout failures while concurrent success passes.
- Final exact-source checks: 151 focused tests across ten files passed (exit0); full serial expanded-reporter app suite passed2400tests (exit0 once); all26changed Dart files analyzed without issues (exit0); formatting and diff checks passed. Unchanged package-client76/media8 evidence reused only after matching source/dependencies. Independent initial review plus both scoped amendment reviews passed without remaining Critical/Important findings.
- Android native broad acceptance used leased emulator5558 and the preceding GH010round2APK: visible independent global/shared-profile quality labels/default, grid-to-viewer independence, real delayed success preserving pan/zoom landmarks,404/decoder failure retention, original-on-zoom, cropped tall AutoComic and typed Philomena engine override. Final amendedAPK failure recheck proved actual settled404 and deliberate30s receive-timeout with identical retained pixels and PID13470 logs reporting0UnhandledException; root independently verified installed APK SHA and socket closure before fixture release. Root accepted final cleanup: only the temporary QA profile/history were removed; original settings, history and60-post grid restored; owned fixture/MCP/reverse/lease resources released. No credentials or unrelated account data were read or changed.
- Final DevProfile native build passed (exit0 once). APK: build/app/outputs/flutter-apk/app-dev-profile.apk; SHA2563ff7d46505f5abc886f07b533a01d0263a9780b4dbc41b10405f681cd456a70b;320083723bytes; packagecom.timberpile.boorusama.dev/version187; v2AndroidDebugRSA2048 signer certificateSHA256671016e734ba672bead2493ba9b6c9e26a5edbcc5d565c32a52228793d2f3d2a. All34reviewed file hashes remained unchanged through final tests/build. Final preparation changes only this ticket's evidence; it remains in-progress/prepared pending explicit delivery/integration approval. Production/tests/fixtures retain their compiled hashes.
- Evidence: /tmp/boorusama-priority-program-2026-10-05/gh010-report.md, gh010-round3-freeze.json, gh010-error-owner-review.md, gh010-round3-focused.log, gh010-final-full-app.log/.exit, gh010-final-dev-profile-build.log/.exit, gh010-final-apk-provenance.json, gh010-qa-report.md, gh010-error-owner-qa-report.md and gh010-root-error-owner-verification.json.
- Explicitly unverified live: iOS compile/runtime, authenticated engines, mixed-origin adjacency, download quality, grid View Options menu and serialized legacy Original selection. Their applicable source/resolver/behavioral coverage is recorded separately; public Android QA did not read credentials or create downloads/bookmarks/pins/feeds.

## Follow-up: media resolver provider ownership

CACHE debug QA exposed a GH-introduced CircularDependencyError when an owned
Philomena profile was deleted after viewer media use. Repository media access
had subscribed the engine initializer's retained Ref to the new post-quality
profile family. Earlier profile-mode native QA elided this debug assertion;
its passing deletion does not verify this provider graph.

Actual app registry/initializer/production repositories plus isolated real
Hive profile/settings/search storage reproduced the same deletion stack:
Philomena and generic/default media cases failed after resolution; both
no-media deletion controls passed. Reactive global/own-auth URL updates passed.
The scoped fix makes repository media hooks provider lookups and watches them
on the media consumer's Ref. Profile deletion/login/registry, quality policies,
cache/download/API code and progressive presentation remain unchanged.

The first six real-graph cases pass after the fix; expanded nine-case coverage
also protects Danbooru/E621/Hydrus policy and deletion through their real hooks.
Necessary nine-file focused checks passed143tests (exit0). After test-only
style cleanup, the final real-graph fixture passed9tests (exit0) and all8
changed Dart files analyzed without issues (exit0); format/diff checks passed.
Independent scoped source review passed with zero findings; coordinator and
reviewer verified all40 frozen hashes, patches, inventory and prepared HEAD.
Prior full2400/native evidence above belongs to prepared19ad00d82; the new
correction now has combined validation and actual debug native confirmation
recorded below. Ticket remains in-progress/PREPARED pending explicit user
delivery/integration approval.
External plan/evidence: gh010-provider-cycle-fix-plan.md and
cache001-cleanup-diagnosis.md in the program report directory.

Current amendment snapshot: gh010-provider-cycle-fix.patch is the exact10-path
delta against19ad00d82; gh010-provider-cycle-review.patch and freeze JSON record
the reviewed GH40-path snapshot. Correction commit:
f3f19a59708a74b0059c0ac0ca61a4a9e9dbae0c (parent19ad00d82).
Review evidence: gh010-provider-cycle-review.md.

## Corrected provider ownership: combined verification

Reviewed GH correction f3f19a59708a74b0059c0ac0ca61a4a9e9dbae0c was replayed once into the CACHE worktree as 62cdf9f310e41c3fd60d2f184604a31be425655d; its committed tree equals the corrected GH tree dbb721430924339757bedb06954d87d2d9168cc0. The combined CACHE working tree retained its independently reviewed 72-path freeze. Full serial expanded app validation passed 2430 tests (exit0), followed by a successful Dev DEBUG build (exit0); all frozen hashes remained unchanged. This is combined-tree evidence, separate from the prior standalone GH full2400/profile APK evidence belonging to 19ad00d82.

Corrected combined Dev DEBUG APK SHA256833ebdafacbeafdf08532614dd1860c1335427629300e5c4b74de267436b9f8a was used for normal native viewer/Share/profile-deletion confirmation. Screenshot07 shows decoded blue fixture pixels; Share hierarchy09 shows Image400×800/11.5KB and Original800×1600/35.6KB before the normal named profile Delete22/24. Fresh drawer25 contains only Default profile/safebooru; the residual QA profile is absent, and original history id12321001 survives in hierarchy20. Fresh PID20162 bounded sanitized log has16 rows and no CircularDependencyError, UnhandledException or fatal entries. Coordinator independently verified these raw artifacts. Final QA report and coordinator accepted cleanup: the owned fresh-nonce cache files were removed, original history/settings preserved, fixture server and MCP stopped, reverse rule removed and exact emulator lease released. No residual QA profile or active owned QA resources remain.

Evidence under /tmp/boorusama-priority-program-2026-10-05/: cache001-post-cycle-report.md, cache001-post-cycle-root-full-verification.json, cache001-post-cycle-root-artifact-verification.json, cache001-cycle-qa-fresh-pid-log-summary.json/.txt, cache001-cycleqa1-step-07/09/20/22/24/25, and the final cache001-cycle-qa-report.md. Source remains the reviewed correction; ticket remains in-progress/prepared pending explicit delivery/integration approval. No new standalone GH suite/build/device execution, integration, publication or worktree cleanup.


## Quality preset review feedback (2026-10-06)

Coordinator: /root. Correction implementer: /root/gh010_quality_feedback, reassigned from completed /root/gh010; same dedicated branch/worktree starting at 051e9e124.

- [ ] Thumbnail options: Auto, Low, Medium, High. Rename existing explicit Low/High/Highest to Low/Medium/High while safely retaining stored choices. Keep the highest non-original thumbnail choice available.
- [ ] Thumbnail Auto: Large uses High (previous Highest); Medium/Small use Medium (previous High); Tiny/Micro use Low/thumbnail. Apply consistently through existing engine/shared card resolvers.
- [ ] Post options: Medium (previous High) and High (previous Highest), default High. No Auto or Original choice in this first version. Preserve existing progressive loading/failure/gesture behavior.
- [ ] Duplicate results between presets are acceptable when a site/post offers fewer variants. Do not invent variants or introduce original-file fetching through the new presets.
- [ ] Verify global/profile persistence and migration, engine/site overrides, shared cached thumbnails, viewer/share and narrow English/German labels. Existing download behavior remains independent.

Correction source review passed, including the scoped German localization R1. Current frozen source contains 34 own paths; 295 focused checks passed before the two-file localization fix, followed by all 7 English/German selector checks. Coordinator and independent reviewers verified actual hashes, raw exits and scope. Generic High thumbnails select Sample, Post choices serialize explicit 2/4 with migration, and bookmark cards/tap use the shared listing resolver. Preserved explicit Original actions and Auto GIF compatibility are documented in the external preflight/report. Final combined replay, full-suite and native acceptance remain pending; earlier APK evidence does not prove these new choices. Source corrective commit authorized on this branch only, not develop integration/publication. Reports: gh010-quality-feedback-report.md, gh010-quality-feedback-review.md and gh010-quality-feedback-r1-review.md under `/tmp/boorusama-priority-program-2026-10-05/`.

## Combined verification phase (2026-10-06)

Coordinator assigns `/root/current_items_fixture_preparation` to combine reviewed own changes and resolve necessary integration seams in separate `.worktrees/current-items-review`, branch `chore/current-items-review`, based on current local develop7c1f6c40. Original ticket worktree/branch remains preserved. Debug Monitor is excluded at user request. This is verification preparation only; pending user delivery approval, no develop merge/publication. Requirements: `/tmp/boorusama-priority-program-2026-10-05/current-items-assembly-brief.md`.


## Final combined automated verification (2026-10-06)

Review-only branch `chore/current-items-review`, HEAD `83924ab4873acbea015baeaa9f63a31807eaa7b2`, tree `26575676bb6094764f3969afe82ac0d5be8ed070`, based on BM-inclusive local develop `7c1f6c40`. Final complete app suite: 2,590 passed; affected packages cache_manager 23, extended_image 47, booru_clients 76 passed, each exit 0. Coordinator independently verified raw command records/logs and all 294 changed-path, 27 generated and 7 dependency records against final freeze. Production analysis had no issues; formatting had zero changes. Initial four stale CACHE test expectations for the agreed GH quality migration were corrected in exactly one test file, independently reviewed, then the full suite rerun; both original and final evidence are retained. No product fix was needed for that failure.

Independent final cumulative review is assigned to `/root/review_final_current_items`. New visible behavior remains for user manual review per their instruction; no blanket new emulator/APK/live-service checks. Debug Monitor remains paused and excluded. Originals are preserved; this record does not authorize integration/publication. Ticket stays in-progress/prepared pending applicable acceptance and approval. CACHE approval remains held for prerequisite review. Evidence outside the repo: `/tmp/boorusama-priority-program-2026-10-05/current-items-final-verification-report.md`, `current-items-final-root-verification.json`, `current-items-assembly/final-verification.json`, and `manual-review.md`.


## Final review handoff (2026-10-06)

Final shared review HEAD `6c98936235fa725205f06dd4d1c82e7cc3a97334` (tree `776fead6536d2d3428f4ddba16689e7126572c71`). Independent whole-source review found only a small PS cooldown retention defect; dedicated PS correction `5e13615370e6879b7a0ff725a40d5e2bd7baefc7` was root-reviewed and replayed once. Independent scoped re-review PASS, no remaining identified findings. Exact final six refresh suites 75 passed; changed production analysis clean, formatting unchanged, diff check successful. Root and reviewer matched 294 cumulative paths, 27 generated files, seven dependencies and 721 preserved historical evidence files. Earlier full app 2,590 and package 23/47/76 runs remain explicitly attributed to pre-correction `83924ab4`; no blanket full rerun was needed for the narrow correction.

Prepared for user manual visual review via `/tmp/boorusama-priority-program-2026-10-05/manual-review.md` and `review-ready.md`; final independent reports `final-current-items-review.md` and `final-current-items-r1-review.md`. Ticket remains in-progress/prepared, not newly delivered. Monitor paused; unstarted tickets skipped. CACHE approval retained pending prerequisite review; local develop clean at7c1f6c40 (only prior BM delivery), no further merge/push/cleanup. Original own branches preserved; PS latest own tip5e136153.


## User review feedback (2026-10-06)

User reports image quality, API refreshes and feed entries appear to work. Positive feedback for the shared manual review recorded; no additional issue reported. Existing source/focused/full evidence retains exact attribution. Local integration is still pending explicit approval; this message does not authorize publication or cleanup.


## Approved local delivery (2026-10-06)

The user explicitly approved all completed active items for local develop. This ticket is prepared as one summary-only delivery commit in `chore/current-items-develop-integration`, from reviewed combined source `d9fd84816211e137b180d022b0fa4fc68b1589cd`. All earlier pending-approval notes are superseded by this approval. Debug Monitor remains paused and excluded. Source verification and final serial app evidence are recorded in `/tmp/boorusama-priority-program-2026-10-05/local-develop-integration-report.md`; the exact delivery commit mapping is external. The coordinator will update local develop after its final gate. Publication and cleanup remain separate.
