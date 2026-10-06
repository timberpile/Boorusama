# Reintroduce conservative automatic search refresh

Priority: High
Affected feature: Pinned Searches and Following Feeds

## Problem

Automatic search refresh is disabled because the previous five-minute
foreground scheduler could make requests too aggressively across configured
sites. Users may still benefit from infrequent background maintenance once its
site-level traffic is bounded.

## Expected behavior

Enable conservative automatic refresh by default with an Adaptive interval
starting at one day (24 hours), adjusting over time according to source activity. Coordinate it with site-level request throttling so pinned searches,
feeds, and other requests cannot collectively exceed a site's limits.

## Acceptance criteria

- [x] Automatic refresh defaults to enabled, with an Adaptive interval starting
      at 24 hours. Keep an explicit user control to disable it.
- [x] Recover and review the existing Adaptive preparation before implementing:
      `.worktrees/idea-31-adaptive-refresh-settings`, branch
      `feature/31-adaptive-refresh-settings`. Its documented six-hour/seven-day
      bounds and settings/planner are prior design context, not integrated proof.
      Preserve explicit existing disabled choices; interpret legacy minute-based
      settings safely without restoring aggressive refresh intervals.
- [x] Scheduling is daily-scale rather than minute-scale and limits work per
      site and per run.
- [x] Automatic and manual work share site-level throttling and coalesce
      duplicate refreshes.
- [x] Offline, lifecycle, retry, and rate-limit behavior is deterministic and
      covered with fake-clock tests.
- [x] Existing stored `searchRefresh` settings are migrated or interpreted
      explicitly.
- [x] Manual refresh remains available when scheduling is disabled.

## Relevant context

`SearchRefreshScheduler`, `SearchRefreshCoordinator`, and
`SearchRefreshSettings` preserve the previous implementation and schema as
reference. Reusing them requires a fresh design review; their old five-minute
defaults are not acceptance criteria for this task.

## Dependencies

Depends on a central per-site request scheduling or throttling decision.

## Confirmed priority and policy (2026-10-05)

User explicitly places activation immediately after IDEA-007 API coordination.
Automatic refresh is on by default with conservative limits; its interval is
Adaptive, starting at one day. The earlier preparation is retained for review
and reuse, rather than replaced with a fixed interval. Coordinate its historical
claim before resuming or transferring ownership; do not modify its worktree
without coordination. Foreground scope remains distinct from PS-020 OS-background
refresh. User-authorized program: `/tmp/boorusama-priority-program-2026-10-05/order.md`.

## Continuation claim (2026-10-06)

Coordinator: /root, authorized priority program 2026-10-05/06
Implementer: /root/ps031
Branch: feature/conservative-adaptive-refresh
Worktree: /home/timber/code/Boorusama/.worktrees/conservative-adaptive-refresh
Base: local develop 46a20296bdd74c5eaf99f8917d1a1d1f69c0d0cd

Ownership transferred from historical /root/implement_31_adaptive_refresh for
user-authorized continuation. Historical feature/31-adaptive-refresh-settings
and its worktree remain unchanged; their four preparation commits will be
recovered with explicit provenance. No historical agent is active in this
program. Reviewed IDEA-007 dependency may be replayed only into this isolated
continuation branch; local develop integration is still awaiting approval.

Implementation brief and progress live outside repository:
`/tmp/boorusama-priority-program-2026-10-05/ps031-dispatch.md` and
`ps031-preflight.md`. Initial assignment is setup/read-only plan until final
IDEA-007 serial verification and committed dependency are available. No
automatic activation or product edits before that gate.

## Continuation evidence

The source gate was released after root independently verified IDEA-007. Its
reviewed commit `d25f8a151501bb334fe06d809eb0781e09e35f57` was replayed here as
`bd5e679c9344b892611335fa8e9d80b54f6c69e5`. Historical preparation commits
`e77d118db`, `5be71738a`, `935ab1f0a`, and `395a0f2a5` were recovered with
mechanical reconstruction of the current serialized settings seam; the old
worktree and claim were preserved.

Implementation includes persistent adaptive outcomes, foreground admission
limits, live manual/automatic ownership, conservative native environment
signals, migrated settings, and visible status. Corrected focused subscription,
API guard and runtime-compensation suite: 474 passed, exit 0
(`ps031-focused-combined-current.log` in the external program directory).
Independent review required two fixes: revoke queued automatic owners when their
current source scope is disabled, and use coherent native transport/metering
proof with conservative transition guards. Scoped re-review passed after both
fixes; no Critical or Important findings remain.

Validation: full serial app suite 2,346 passed, exit 0; scoped analysis of 54 Dart
files reported no issues; formatting and diff checks passed. Android Dev profile
APK build and signature verification exited 0. Frozen product/native source
hashes remained unchanged through verification.

Root accepted bounded Maestro QA on emulator-5558: actual native unmetered Wi-Fi
ready status, battery-saver pause/recovery, controls and disabled-choice
preservation, both shared settings entry points, and successful manual refresh
with automatic checks off. QA restored all six refresh settings and original
power/profile state, removed its own pin, and preserved signed-in data. Legitimate
automatic runtime/cache updates during interval checks were retained.

Live first-time feed initialization, iOS runtime, mobile-network transitions,
and real 24-hour timing were not demonstrated by device QA. Reviewed deterministic
initialization/session/lifecycle, network-transition and adaptive timing tests
provide their separate bounded evidence. The raw logs and acceptance report are
in `/tmp/boorusama-priority-program-2026-10-05/`: `ps031-full-app.log`,
`ps031-round1-analysis-clean.log`, `ps031-profile-dev-build.log`,
`ps031-qa-report.md`, and `ps031-report.md`.

Prepared on the dedicated branch; ticket remains in progress pending delivery
approval. No local develop integration, publication, or worktree cleanup has
occurred.

## User review correction (2026-10-06)

Coordinator: /root. Correction implementer: /root/refresh_feedback_plan,
reassigned from the completed historical /root/ps031 assignment. Keep the
existing dedicated feature/conservative-adaptive-refresh branch/worktree.

- [ ] Remove the Pinned Searches and Feeds shortcut from both the pinned-search
  and Following Feeds overflow menus; retain the normal Settings destination.
- [ ] Folder refresh status shows remaining searches, including finite planned
  queued and running work, deduplicated across joined/overlapping operations.
  Success, failure, cancellation, skipped work and ended passes settle their
  own reservations; physical work remains visible until it settles.
- [ ] Localize the remaining-count label and verify sequential/multi-profile
  batches, finite automatic passes, cancellation and overlapping ownership.

Reviewed correction plan:
`/tmp/boorusama-priority-program-2026-10-05/refresh-feedback-plan.md`.
These additional criteria reopen source review. Earlier evidence remains
evidence of the earlier source only. DEV-003 owns the debug monitor separately.
No develop integration or publication is authorized.

## Review correction source verification (2026-10-06)

The pinned-search root/open-folder shortcut and the Following Feeds overview
shortcut are removed; the ordinary Settings destination remains intact. Folder
status counts distinct remaining searches across transient finite planned work
and live source operations, with English and German labels. Root Refresh All
includes later profiles; automatic passes expose only their bounded candidate
slice. Reservations do not change stored NEW state or backup formats.

Independent round-one review identified stale root reservations when a later
profile's membership changed or its read failed before workers. R1 captures each
profile's original slice and settles it in the notifier on every profile exit,
without clearing other reservations or coalesced live work. Two meaningful
regressions reproduced the defect and then passed. Root accepted the scoped
re-review with no Critical or Important findings.

Verified source evidence in the external program directory: 169 earlier affected
tests passed; the final progress run passed 53; standalone localized folder
widgets passed 21, including 280dp with 2x text and no rendering-triggered fetch.
R1's five affected files passed 131 tests, and the final two omission/failure
regressions passed with explicit coalesced callers. Production analysis reported
no issues; formatting and diff checks passed. Exact frozen inventories, patches,
commands and observed exits are in `ps031-feedback-r1-freeze.json`,
`ps031-feedback-r1-command-evidence.json`, and
`ps031-refresh-feedback-r1-report.md`.

This correction is source-reviewed and committed only on its isolated branch.
New native acceptance remains pending the coordinator's final combined Dev DEBUG
build and UI gate. Earlier native evidence applies to earlier source; it does
not establish these new remaining-count criteria. No corrective APK build,
device validation, local develop integration, publication, or cleanup occurred.


## Additional Info schedule feedback (2026-10-06)

User requests current refresh interval and next scheduled refresh in the pinned-search Info dialog. Coordinator /root assigns correction to /root/refresh_feedback_plan on the same dedicated PS-031 branch/worktree, starting at c76f066554.

- [ ] Display actual effective adaptive or fixed interval, including mixed duration units.
- [ ] Display next scheduling eligibility using the same timing calculation as the planner; overdue shows Due now. Disabled, unsupported or missing-owner states do not promise a scheduled check.
- [ ] React to cached source/settings outcomes while open; show known pauses/delays honestly. Opening Info starts no requests and causes no persistent writes.
- [ ] Preserve existing Info details, local date/time formatting and narrow English/German accessibility.

Reviewed implementation plan: `/tmp/boorusama-priority-program-2026-10-05/ps031-info-schedule-feedback-plan.md`. Root opened the scoped source gate; source review and final combined native acceptance remain pending. No develop integration or publication authorized.


## Info schedule source review (2026-10-06)

The effective Adaptive/Fixed interval and next scheduling eligibility are implemented in a reactive cached Info dialog using the planner's shared timing helper. Disabled/scope/unsupported/missing-owner, Due now, known cooldown and temporary pause states are localized; existing check/attempt details remain. Opening Info starts no coordinator, requests or persistent writes.

Root verified fourteen frozen owned paths and the complete patch against c76. Independent scoped review passed with no findings (`ps031-info-review.md`). Raw evidence: 116 affected tests, ten new Info cases, and a final named cooldown case passed; final five-file analysis and eleven-file format check passed. English/German 280dp at 2x text retained a reachable OK action. Source-only correction commit is authorized on this isolated branch. Final combined native acceptance remains pending; earlier device evidence applies to earlier source. No integration, publication or cleanup is authorized. Full packet: `/tmp/boorusama-priority-program-2026-10-05/ps031-info-report.md`.

## Combined verification phase (2026-10-06)

Coordinator assigns `/root/current_items_fixture_preparation` to combine reviewed own changes and resolve necessary integration seams in separate `.worktrees/current-items-review`, branch `chore/current-items-review`, based on current local develop7c1f6c40. Original ticket worktree/branch remains preserved. Debug Monitor is excluded at user request. This is verification preparation only; pending user delivery approval, no develop merge/publication. Requirements: `/tmp/boorusama-priority-program-2026-10-05/current-items-assembly-brief.md`.


## Final combined automated verification (2026-10-06)

Review-only branch `chore/current-items-review`, HEAD `83924ab4873acbea015baeaa9f63a31807eaa7b2`, tree `26575676bb6094764f3969afe82ac0d5be8ed070`, based on BM-inclusive local develop `7c1f6c40`. Final complete app suite: 2,590 passed; affected packages cache_manager 23, extended_image 47, booru_clients 76 passed, each exit 0. Coordinator independently verified raw command records/logs and all 294 changed-path, 27 generated and 7 dependency records against final freeze. Production analysis had no issues; formatting had zero changes. Initial four stale CACHE test expectations for the agreed GH quality migration were corrected in exactly one test file, independently reviewed, then the full suite rerun; both original and final evidence are retained. No product fix was needed for that failure.

Independent final cumulative review is assigned to `/root/review_final_current_items`. New visible behavior remains for user manual review per their instruction; no blanket new emulator/APK/live-service checks. Debug Monitor remains paused and excluded. Originals are preserved; this record does not authorize integration/publication. Ticket stays in-progress/prepared pending applicable acceptance and approval. CACHE approval remains held for prerequisite review. Evidence outside the repo: `/tmp/boorusama-priority-program-2026-10-05/current-items-final-verification-report.md`, `current-items-final-root-verification.json`, `current-items-assembly/final-verification.json`, and `manual-review.md`.


## Final review R1 corrective assignment (2026-10-06)

/root reassigns existing claim to /root/ps031_final_cooldown_fix in the same dedicated conservative-adaptive-refresh worktree/branch. Fix only valid cooldown loss caused by pruning against a partial automatic plan, retain authoritative removal/identity cleanup, verify scheduler/coordinator/Info integration deterministically. Exact brief and finding: /tmp/boorusama-priority-program-2026-10-05/final-refresh-cooldown-fix-brief.md and final-current-items-review.md. No device/new-ticket/develop/remote scope; freeze for root source gate before commit/replay.


## Final review handoff (2026-10-06)

Final shared review HEAD `6c98936235fa725205f06dd4d1c82e7cc3a97334` (tree `776fead6536d2d3428f4ddba16689e7126572c71`). Independent whole-source review found only a small PS cooldown retention defect; dedicated PS correction `5e13615370e6879b7a0ff725a40d5e2bd7baefc7` was root-reviewed and replayed once. Independent scoped re-review PASS, no remaining identified findings. Exact final six refresh suites 75 passed; changed production analysis clean, formatting unchanged, diff check successful. Root and reviewer matched 294 cumulative paths, 27 generated files, seven dependencies and 721 preserved historical evidence files. Earlier full app 2,590 and package 23/47/76 runs remain explicitly attributed to pre-correction `83924ab4`; no blanket full rerun was needed for the narrow correction.

Prepared for user manual visual review via `/tmp/boorusama-priority-program-2026-10-05/manual-review.md` and `review-ready.md`; final independent reports `final-current-items-review.md` and `final-current-items-r1-review.md`. Ticket remains in-progress/prepared, not newly delivered. Monitor paused; unstarted tickets skipped. CACHE approval retained pending prerequisite review; local develop clean at7c1f6c40 (only prior BM delivery), no further merge/push/cleanup. Original own branches preserved; PS latest own tip5e136153.


## User review feedback (2026-10-06)

User reports image quality, API refreshes and feed entries appear to work. Positive feedback for the shared manual review recorded; no additional issue reported. Existing source/focused/full evidence retains exact attribution. Local integration is still pending explicit approval; this message does not authorize publication or cleanup.


## Info presentation feedback (2026-10-06)

/root reassigns existing claim to /root/ps031_final_cooldown_fix in the same PS branch/worktree. User requests relative future time for Next scheduled refresh, shorter label Next refresh, and complete removal of the automatic-checks explanatory note. Scope: Info presentation/EN-DE localization and existing affected tests only; existing timing/cooldown/passive behavior retained. Focused automated checks, no emulator/full suite/develop/remote. Commit and cumulative review replay after root source review.


## Info presentation final handoff (2026-10-06)

User feedback implemented on own commit a02c9c8abf2ec3d1e22c01e49c8eaa254c524c25; correction-only review replay d9fd84816211e137b180d022b0fa4fc68b1589cd. Next refresh uses registered locale-relative future time, shorter EN/DE label; automatic-checks explanatory note and obsolete translations removed. Runtime timing/cooldown/status and passive Info behavior retained. Root exact six-path source/commit/doc conflict/strict two-key translation gates verified. Own and combined Info file13 passed; production analysis no issues, format2 zero changes, JSON/i18n-only generation/diff exit0. Independent scoped review PASS/no findings; reports ps031-info-relative-combined-report.md and ps031-info-relative-review.md under external priority-program directory. Original whole/75-test evidence retains earlier source attribution; no other suites/emulator rerun. Prepared for user review; no develop integration, publication, cleanup or monitor change.


## Approved local delivery (2026-10-06)

The user explicitly approved all completed active items for local develop. This ticket is prepared as one summary-only delivery commit in `chore/current-items-develop-integration`, from reviewed combined source `d9fd84816211e137b180d022b0fa4fc68b1589cd`. All earlier pending-approval notes are superseded by this approval. Debug Monitor remains paused and excluded. Source verification and final serial app evidence are recorded in `/tmp/boorusama-priority-program-2026-10-05/local-develop-integration-report.md`; the exact delivery commit mapping is external. The coordinator will update local develop after its final gate. Publication and cleanup remain separate.
