# Show saved-search-style feed entries with previews, refresh and sorting

Priority: Normal
Affected feature: Following Feed editor

## Problem

Feed members appear as plain rows, making artists and searches harder to
recognize than the cards in the overview.

## Expected behavior and acceptance criteria

- Use saved-search-style card rows with member name/query, NEW/error state,
  localized relative last-checked time and an explicit never-checked state.
- Keep opening, editing and removing a member; add a per-entry Refresh action
  through the existing refresh service and shared request limits. Omit pin-only
  folder/move controls and manual drag reordering.
- Offer Added Date, Newest first and Oldest first sorting. Use the existing
  pinned-search sort presentation where applicable. Newest/Oldest use the
  member’s latest known post date, not its last refresh attempt; Added Date
  reflects addition order. Missing dates and ties have deterministic ordering.
  Sorting changes the displayed order without changing stored feed membership,
  read/NEW state, refresh scope or adding fetches.
- Show representative cached thumbnails using the existing image-quality
  resolver and owning profile authentication; omit previews when no cache exists.
- Keep edit/remove/navigation behavior and accessibility usable at narrow widths
  and enlarged text.
- Opening or rebuilding the editor adds no thumbnail or post-fetch requests.

## Context and dependencies

Reuse the pinned-search/following-feed card visual structure and existing cached
member data. Card rendering and sorting use cached state, separate from overview first-time
initialization. Explicit Refresh reuses the existing fetch path. Establish the
addition-date source and preference persistence during implementation; do not
introduce a manual ordering model.

- [Following Feed architecture](../../pinned_searches.md)
- [Overview cards](../done/IDEA-027-following-feed-cards.md)
- [Feed thumbnail quality](../done/PS-029-respect-feed-thumbnail-image-quality.md)

## Confirmed scope (2026-10-05)

User requested saved-search-style feed entries including relevant cached
information, an individual Refresh action, and Added Date / Newest first /
Oldest first sorting. Manual order does not exist and must not be offered.
Program: `/tmp/boorusama-priority-program-2026-10-05/order.md`.

## Claim and implementation

Claimed 2026-10-06 for the authorized priority program: `/tmp/boorusama-priority-program-2026-10-05/order.md`.

- Coordinator: /root, priority program 2026-10-05.
- Implementer/session: /root/feed001, assigned 2026-10-06.
- Dedicated worktree: /home/timber/code/Boorusama/.worktrees/feed-001-editor-preview-cards.
- Branch: feature/feed-001-editor-preview-cards.
- Base: current local develop46a20296bdd74c5eaf99f8917d1a1d1f69c0d0cd.
- Reviewed prerequisite replay, exactly once in order: IDEA-007 c2a76be6dc487abbe63708b7e880313499f56eb4; PS-031 0af21736b4cb5bd22d36ce441849a9c6008ce173; GH-010 original19ad00d82f77b202f59adc0b71a198dd18abaf8a then correctionf3f19a59708a74b0059c0ac0ca61a4a9e9dbae0c; CACHE-001 own58d06bd81c93d3a5afdc7ae3495643a5cfeb36bc. Final GH docs-only051e9e12422f0d9dbd5a041b20086f8c1f6ba414 is separate evidence, not another source replay. Record all resulting prerequisite SHAs/tree/source equivalence before implementation.
- Requirements: external feed001-plan.md and corrected feed001-final-preflight.md supplement the acceptance criteria above. Owner listing quality selects the actual owner's enabled override or global defaults; the existing active-profile listing provider cannot supply inactive-owner quality. Cached preview bytes only, no media/post requests on mount/rebuild/sort.
- Status: PREPARED for user integration review. Independent source review and exact-artifact populated Android QA passed within the recorded limits. Retain in-progress until explicit user integration approval; no develop integration, publication or branch cleanup authorized.

## Prepared implementation and focused evidence (2026-10-06)

- Reviewed prerequisite HEAD: `ab7d7e3565b6d1865680bcb5b6b2b22db1100e78`; exact base tree `a12ee275487a600e00cbf3aa0debae4d0f8d4111`. Ordered replay commits and all 251 prerequisite blob comparisons are recorded in external `feed001-prerequisite-provenance.json`.
- Member cards share the saved-search visual structure with Refresh, name-only Edit, Remove and existing Open navigation. Cached full engine snapshots resolve actual-owner quality into copied cache bytes and native memory decoders. Missing/corrupt media is omitted.
- Added Date uses member-ID addition order; Newest/Oldest use latest known post dates with stable ties and missing dates last. The persisted feed sort is independent of pin sort. Shared names use serialized current membership/owner/definition validation.
- Focused 16-file test run: 218 passed. Covers owner/global quality, actual native AVIF decoding, corrupt/cold bytes, pending ordinary same-URL transport independence, four matching snapshots, no mount/rebuild/sort HTTP, shared-name runtime preservation, navigation, membership, refresh/request limits, and pin regressions. English/German cards and dialog checks passed at 280px and doubled text.
- Targeted analysis of 16 touched files: no issues. Generated translations include six English/German labels; other locales retain the normal fallback policy.
- Exact commands, RED/GREEN output, fixture investigations, held source patch and hashes are under `/tmp/boorusama-priority-program-2026-10-05/feed001-report.md`.
- Coordinator's independent source review: PASS, zero findings (`feed001-review.md`). The authorized own-branch feature commit records this prepared result; user integration approval remains pending. The program's final combined broader verification is a separate later gate, with no redundant full-suite or JVM/package/native-instrumentation repeat for this Dart ticket.

## Final acceptance and artifact evidence (2026-10-06)

- Single Dev DEBUG build: `fvm flutter build apk --debug --flavor dev -t lib/main.dart`, exit 0, Gradle 190.2s. Existing native-hook warnings were nonfatal; no blind rerun. APK SHA256 `830925f289d433a97f350f8c038d36c06a47ae10fe448cad26652c5fc84c8c01`, 326459081 bytes. Package `com.timberpile.boorusama.dev`, version 187 / `4.5.0-timberpile.3-dev`, min SDK 24 / target 36, debuggable. Raw signature verification matched required debug certificate; Gradle/Flutter output bytes matched. All frozen source hashes stayed unchanged before/during/after build. See external `feed001-build-report.md`, `feed001-apk-artifacts.json` and `feed001-root-artifact-verification.json`.
- Actual populated Android QA on exclusively leased emulator-5558/Phone_4 installed that exact APK. All 183 sequential targeted MCP results were nonerror and within the operation limit. Root independently verified raw views, screenshots, the selected definitions archive checksums/memberships, and scoped cleanup: PASS (`feed001-root-device-verification.json`). Full evidence and limits: external `feed001-qa-report.md`.
- Actual cards showed inactive-owner High cached blue A/B previews, cold C/D omission, NEW/error/relative successful checks and Never checked. Added/Newest/Oldest, equal-date ties, missing dates last, sort persistence through preserving process restart, shared name-only edit/cancel, per-source Refresh activity, exact-query Open/read/owner activation, and scoped Remove/last-member exit were exercised. English/German at about 280dp and font scale 2.0 kept card/dialog/menu actions reachable.
- Three live fixture-server windows measured 82.060s / 70.713s / 42.739s with zero post, media or tag request deltas across editor mount/reopen/sort/menu/edit-cancel/scroll/relative pulses and enlarged English/German layouts. These are actual live-ledger measurements, separate from permitted setup and explicit Refresh requests.
- Runtime limits: device evidence proves visible runtime preservation and request silence; sharing export stores definitions, not internal source UUID/checkpoint/cache bytes. Internal byte invariants, corrupt AVIF, owner removal races and concurrency are established by reviewed production repository/widget tests. Authenticated media was unavailable; no credentials read. Disabled Refresh-menu semantics were not separately captured on device. Existing upstream German fallback strings remain outside the six new translated labels. No live AVIF/corruption/24h scheduler or native-instrumentation suite rerun is claimed.
- QA cleanup independently verified: only disposable feeds/profile/history/export/four owned cache files/reverse/server resources removed, original profile/pin/history retained, English/density/font/Added sort restored, device lease released and phone retained. No ticket/source mutation by QA.
- Delivery state: one authorized descriptive Conventional feature commit on the dedicated branch only. This ticket remains in-progress/PREPARED pending user integration approval; no primary checkout writes, local develop integration, publication or branch cleanup. Exact commit/parent/tree/path and non-ticket blob/hash provenance is in external `feed001-final-commit-provenance.json`.

## Scoped review correction (2026-10-06)

- Implementer/session: `/root/feed001_rounded_previews`, assigned by coordinator
  `/root` for the user-authorized thumbnail corner correction only. Retains this
  ticket's dedicated worktree and `feature/feed-001-editor-preview-cards` branch
  at `15981cf7ff0e95c5beb3916ee99fa546e4bfeefc`; no other work is included.
- Existing overview thumbnails use an 8px radius and antialiased image clipping.
  Apply matching clipping to the editor's actual cached-byte image without
  changing preview selection, decoding, omission or request behavior.
- Corrected only `FollowingFeedMemberCard` by wrapping each cached-byte `Image`
  in an 8px `ClipRRect`, whose default is antialiased clipping. The image
  provider, cover fit, error omission and surrounding layout remain unchanged.
- Existing focused preview/regression/management suite: 26 passed, exit 0.
  Targeted widget analysis: no issues. Formatting: one file, zero changes.
  `git diff --check` passes. Exact commands, raw logs and frozen patch/hashes are
  in external `feed001-rounded-previews-report.md` and its manifest.
- Status: correction PREPARED, uncommitted for independent review; retain
  in-progress until explicit user integration approval. No native build,
  full-suite or device checks were repeated; earlier APK/device evidence
  predates this correction. No integration, remote action or cleanup occurred.

Independent rounded-preview source review passed with zero findings; coordinator verified frozen hashes, exact two-path scope, raw 26 passed widget checks, clean analysis and formatting. Own-branch correction commit authorized; final combined APK acceptance and user integration approval remain pending. Earlier APK evidence predates corners. Evidence: external feed001-rounded-previews-review.md and feed001-rounded-previews-root-verification.json.

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
