# Coordinate booru API requests across profiles and clients

Priority: High
Affected feature: Booru API transport, rate limiting, automatic refresh

## Problem

The normal non-image client currently has a 10-request/second limiter, while other clients and feature-local gates can use separate budgets. This permits excessive sustained traffic and cannot enforce a shared quota for profiles and features hitting one site. Server cooldowns also need one coherent user-visible outcome.

## Expected behavior

Interactive searches/actions start ahead of automatic checks and preloads for the same API quota. Both can start small bursts while capacity is available. When a site rate-limits requests, affected work shows the remaining wait; unrelated sites continue. A manual Refresh during cooldown reports the wait and is not queued for later execution.

## Decisions and edge cases

- Use one app-lifetime API/data-request coordinator keyed by normalized actual network origin (lowercase scheme/host and effective port) plus any evidenced independent API quota. Separate profiles and clients using one quota share counters; independent origins/quotas stay separate.
- Include API-equivalent HTML data fetching. Do not route image loading, media bytes, or downloads through these new limits. Inventory nonstandard data paths so they do not silently bypass coordination.
- Classify `interactive`, `userInitiated`, `automatic`, `preload`, and `bulkTransfer` requests; preserve FIFO within each class. Active work has priority. Passive work starts only when no active request for the quota is queued or running; running passive work is not preempted and may be deferred during sustained active use.
- Enforce rolling one-second and one-minute start windows, not fixed spacing or wall-clock bucket resets. Fallback source limits are 5/s and 30/min; uniform 80% buffering yields 4/s and 24/min. Passive starts use at most half the effective rolling minute cap (12/min for fallback), rounded down. Both classes share the total windows.
- Allow centrally declared higher or lower site/engine overrides only when reliable limits justify them; apply the same 80% factor. For a low limit rounding to zero, use a longer equivalent conservative window instead of blocking requests forever. No numeric Settings controls.
- At most four API requests per quota are in flight across both classes, with no reserved class slots. Queued cancellation consumes no capacity; in-flight cancellation releases the slot after transport completion/cancel acknowledgement.
- Honor `Retry-After`. Without it, apply quota-scoped jittered cooldown steps of 30 seconds, 2 minutes, 10 minutes, then 30 minutes; success gradually clears the penalty. Long cooldown returns typed `retryAt` instead of holding queued jobs. Safe reads may retry once; favorites and other mutations never replay automatically. Serialize auth refresh per account without deadlock.

## Acceptance criteria

- Two profiles, multiple features, and separate clients on one quota obey one tested budget; separate origins or evidenced independent quotas do not throttle each other.
- Small active and passive batches start promptly when windows permit; full windows delay starts. Tests cover second/minute boundaries, passive half-cap, priority/fairness, and the shared four-in-flight cap.
- Fake-clock tests cover cancellation, refill, overrides, `Retry-After`, fallback cooldown, safe-read retry, and non-retry of mutations.
- A 429 on one client pauses its quota across clients, exposes `retryAt` to UI and feature schedulers, and leaves unrelated sites plus image/download behavior unchanged. Cancelled work leaks no permits or stale refresh completion.
- API-equivalent HTML and other nonstandard data paths are inventoried and either coordinated or explicitly justified as independent.

## Context and dependencies

Feature schedulers decide due work and run budgets; this coordinator admits actual API requests. The item-31 adaptive-refresh work (PS-031) must not execute automatically until this network-safety prerequisite exists. IDEA-010 fetches use it; video/GIF media downloads do not. Validate numerical overrides for known sites before adding them.

- [Pinned Search and Following Feed architecture](../../pinned_searches.md)

## Claim

Claimed 2026-10-05 by coordinator `/root`; implementer `/root/api007`; branch `feature/api-request-coordination`; worktree `/home/timber/code/Boorusama/.worktrees/api-request-coordination`; base freshly fetched origin/develop `46a20296b`. User authorized implementation and continuation in `/tmp/boorusama-priority-program-2026-10-05/order.md`. Outside implementation plan and primary-source limit evidence: `api007-plan.md` and `api007-site-limit-evidence.md` in the program directory. PS-031 activation follows this ticket after review. No publication or develop integration is authorized.


## Review preparation

Implementation is isolated on the claimed branch. Architecture and actual
transport/media exclusions are documented in [HTTP request coordination](../../http_request_coordination.md).
The outside execution report is `/tmp/boorusama-priority-program-2026-10-05/api007-report.md`,
with raw test logs and the full changed-file manifest beside it. Source review
and acceptance remain pending; no automatic PS-031 activation, publication or
develop integration has occurred.


## Verification evidence

- Final frozen app serial suite:2,289 passed, exit0 (`api007-app-frozen-final.log`).
- Booru clients package:76 passed; ExtendedImage package:8 passed.
- Final favorites/preload/presentation regressions:26 passed.
- Changed-file analysis:98 Dart files, no issues. Format check:0 changed; diff check clean.
- Independent source review:PASS with no Critical/Important findings; original review findings closed (`api007-review.md`).

All logs, final source fingerprint and105-path inventory are in the outside
program directory linked above. The final reviewed branch commit is recorded in
`api007-report.md`. Device/live-site checks and full app native/web builds were
not performed; coordination barrel JavaScript compilation and deterministic
widget feedback/lifecycle checks passed. Ticket remains in-progress for the
coordinator's acceptance/status transition.

## Active-browsing review correction (2026-10-06)

User reported Danbooru pagination pauses with small thumbnails. Source tracing
identifies a sufficient cause: the invented shared 24/minute budget can block
active pages after earlier page and passive status requests consume it. This
has not yet been reproduced on the user's device.

The current correction supersedes the earlier fallback-window and passive
occupancy decisions above. Keep this ticket's original dedicated branch and
implementer /root/api007. Reviewed concrete plan and primary-site evidence:
`/tmp/boorusama-priority-program-2026-10-05/api007-active-browsing-feedback-plan.md`
and `rate-limit-research.md` in that directory.

- [x] Remove invented active fallback windows; retain shared concurrency,
  documented origin-specific server pacing and server-confirmed cooldowns.
- [x] Separate passive local 12/minute conservation from server budgets and
  cap passive occupancy at two of four shared physical transports.
- [x] Bound detached Danbooru status-preload backlog: unavailable speculative
  preloads defer immediately and leave status unknown; manual work/mutations
  retain their normal semantics.
- [x] Verify realistic pagination with batched metadata, known-site windows,
  cancellation, queued manual/auth promotion, transport lifetimes, cooldowns
  and unchanged credential/redirect/media protections.

The correction source and test-only refund followup reviews passed with all
findings closed. Later combined prepared-pipeline validation remains required;
prior broad-suite evidence covers the earlier source, not this correction. DEV-003 owns the requested debug
overlay separately. Do not infer ambiguous 500/501/503 responses are limiter
signals without a positive site-specific signature; record this limitation.

Correction source and focused evidence are recorded in
`/tmp/boorusama-priority-program-2026-10-05/api007-active-browsing-feedback-report.md`.
The admission-to-dispatch owner-loss race has a named RED→GREEN regression;
only undispatched active/passive reservations are reconsidered. Root accepted
the main source and test-only refund reviews and authorized this isolated
corrective commit. Final focused HTTP/favorite checks passed91, then14 affected
tests after info cleanup; refund followup passed25 coordinator/site tests.
Changed Dart analysis has no issues; format and diff checks passed. All16
non-ticket files retain reviewed freeze hashes from manifest
`b0a17685c6f00e938c78773e3724149bfd5e58cb5475862caaddeefe22c8a49e`.

Native/device reproduction and live policy/load checks were not performed.
Ambiguous non429 limiter recognition remains deferred without affirmative
signatures. PS031 replay must preserve its canAdmit/lifecycle/cooldown guards
and place physical transport callbacks after classification reconsideration.
Later combined prepared-pipeline validation and coordinator acceptance remain
gates; this ticket stays in-progress. No publication/develop integration,
full-suite repeat, APK or device run accompanies this correction. Commit/parent/
tree and frozen Git-blob proof are recorded outside in
`api007-correction-final-commit-provenance.json`.

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
