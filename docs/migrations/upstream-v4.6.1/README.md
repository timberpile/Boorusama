# Upstream v4.6.1 — Merge Decisions

**Status: REVIEW REPAIRS IMPLEMENTED; FINAL LOCAL REGRESSION, ANALYSIS AND DEV APK BUILD PASSED.**
The latest R01–R11 regression repairs and three additional independent-review
findings are recorded in [regression repairs and final verification](REGRESSION_FIXES.md),
with the [final manual acceptance checklist](FINAL_ACCEPTANCE.md). Their checked
runtime/test candidate is `bc55de7c2`. Three independent Luna Max reviews and the
bounded emulator/Maestro phase are complete; remaining manual, live and production
upgrade acceptance is listed explicitly. The earlier 21-item remediation report
remains historical evidence for preceding work.

The genuine merge remains in `c08bb851acfe253e65cd307660cdbe465894fe7c`.
[Consolidated remediation](REVIEW_REMEDIATION.md) records 21 validated review
items and the checked candidate. The Rule34 listing-host switch is now activated
after targeted authenticated live API and Android checks. Manual, installed-upgrade,
other-native-platform, integration and publication acceptance remain separate.

## Pinned Comparison Baseline

- Fork `develop`: `d4e15586f06192f0ff4315d36a3f61ae69a752d5`.
- Upstream tag `v4.6.1` (peeled commit): `5b04bf6a164f028d41701299367d0dde74dde330`.
- Merge base: `2c0ac699184854d363833ea4a3205aef0895a92b`.
- Scope at the original baseline: 150 new upstream commits, 68 review items, and 106 conflicting paths in an unchanged trial merge.
- A previous local trial merge was **not** build- or test-verified and **must not** be considered an accepted integration state.

## Documents

1. [Detailed decision catalog](boorusama-v4.6.1-decision-catalog.md) — upstream changes, fork divergences, conflicts, commit SHA references, verification and the original review context.
2. [Compact decision checklist](boorusama-v4.6.1-decision-checklist.md) — stable IDs: X01–X04, A01–A18, N01–N06, D01–D08, B01–B10, P01–P14 and U01–U08.
3. [Decision log](decisions.md) — **authoritative record of all explicitly user-approved decisions** and important follow-up clarifications.
4. [Implementation handoff](IMPLEMENTATION_HANDOFF.md) — **English instructions for the local agent**, including source commits, dependency order, 68-item coverage, conflict traps, A16 versioning policy, verification and integration boundaries.
5. [Manual acceptance checklist](MANUAL_ACCEPTANCE_CHECKLIST.md) — prioritized upgrade, data, network, media, download and responsive-UI checks for the user to perform on the final candidate.
6. [Implementation report](IMPLEMENTATION_REPORT.md) — merge ancestry, implemented scope, verification evidence, remaining acceptance work and authorization boundaries.
7. [Consolidated review remediation](REVIEW_REMEDIATION.md) — all claimed findings, validation, repairs, final verification and remaining limits.
8. [Regression repairs and final verification](REGRESSION_FIXES.md) — R01–R11, three independent-review follow-ups, exact candidate, complete gate, APK and local native evidence.
9. [Final manual acceptance](FINAL_ACCEPTANCE.md) — remaining concrete user-run checks after local verification, with separate automated/native/upgrade limits.

## Decision and Implementation Rules

- IDs are stable. Record decisions in `decisions.md` before considering them approved.
- An `OPEN` item does **not** authorize implementation; historical hypotheses in the catalog must never override an explicit decision.
- For each approved item retain the ID, chosen integration approach, expected behavior, rationale, dependencies, data-migration effects, tests and approval date.
- Keep the checklist consistent with the authoritative log. Do not silently reinterpret user-approved behavior.
- Local implementation of all 68 items was commissioned on 2026-10-16; the task and limits are described in the [implementation handoff](IMPLEMENTATION_HANDOFF.md). This permission does **not** include work on unrelated branches, remote pushes, PR creation, `develop` integration or release publication.
- **Protected invariants:** profile UUIDs, bookmarks and Hive layout, post identity, export/import, Following and Pinned Searches, cache behavior, fork UI, signing and privacy defaults. Persistent-data changes require explicit migration design and regression tests.
- **Do not** fake the upstream merge with `git merge -s ours`. Git ancestry must reflect the upstream code that was genuinely integrated.
- Do not modify or submit PRs to `develop` without separate authorization. The complete test suite required by `AGENTS.md` must pass before integration.

## Decision Status (2026-10-17)

**All 68 decisions remain approved. Review repairs include B10 activation after targeted authenticated live API and Android checks.** See [verification evidence and remaining acceptance limits](REVIEW_REMEDIATION.md). All binding decisions are in [`decisions.md`](decisions.md) and summarized by the catalog and checklist. The task branch contains the genuine upstream merge; integration and publication are not authorized.

- **A02:** Following the UI migration, the agent must prepare a short prioritized manual acceptance checklist for the user. The **user**, not the agent, performs the manual UI checks.
- **A16 — Versioning:** The numeric base of each fork release must exactly match its integrated upstream release. Restart `timberpile.N` at `.1` on each new upstream base, increment it within the same base, and **never** reset the Android/Flutter `+buildNumber`. Current release: `4.5.0-timberpile.5+189`; expected first release after the v4.6.1 merge: `4.6.1-timberpile.1+190`, provided there is no more recent allocated build number. Recheck shipped codes before release. Update the release skill, changelog, tags, GitHub manifest and updater consistently.
- **X04 + A09:** Remove physical image-cache generations but retain URL-MD5, LRU, checkpoints and origin safety. Use temporary OS-cache copies for sharing and the existing cleanup after 24 hours. Adopt the upstream read-only DocumentsProvider.
- **N01:** Retain `ApiRequestCoordinator` and upstream retry fixes without adding a second sliding-window rate limiter.
- **X03:** Protect fork profile UUIDs, exports/imports, bookmark and pinned-search folder trees, and Following. Incorporate compatible test and factory boundaries from A01/A12; apply the favorite-tags persistent-storage fix under D08.
- **D02:** Adapt upstream download completion fixes while preserving fork lifecycle guards. Verify crash/cleanup recovery and notification deduplication.
- **B01–B05:** Integrate Sankaku metatags into the shared search experience; adapt date parsing, error handling, tag categories and safe authentication recovery.
- **B06:** Integrate Shimmie2 format and favorite-state improvements without delaying the post list while fetching favorite status.
- **B07–B08:** Adopt Rule34 comment upvotes (**not** downvotes), cursor pagination and capability-based comment ordering.
- **B09–B10:** Fix Nozomi index and byte-range handling with centralized request coordination; change the Rule34 API host only after live verification.
- **P01–P14:** All 14 post-grid/viewer topics are approved. P01 adds two configurable thumbnail actions while retaining the origin-specific fork `defaultActionButton` and legacy migration. P06 preserves animated Danbooru Highest-quality sample GIFs only when autoplay is enabled and the size limit permits playback; Automatic + Large currently uses a separate 720-variant path. P04 keeps the existing refresh queue and rejects stale results; P08 protects cached videos and temporary pages during playback; P09 preserves fork zoom features when resolving page swipe versus pan; P10 consumes volume keys only in eligible viewer modes.
- **U01–U03:** Make search usable above the soft keyboard, use scroll-controlled history sheets and keyboard-operated suggestion lists in the compact unified fork search UI.
- **U04–U06:** Integrate keyboard/D-pad focus navigation, focus panes and a consistent Escape/Back dismissal hierarchy. TV is best-effort, not a newly supported platform.
- **U07–U08:** Show the favorite-tag editor in a dialog at tablet sizes, retaining all fork labels; adapt upstream regression tests with the associated features and deterministic timing controls.
- **D01:** Add optional TXT/JSON download sidecars (Off by default, optional bulk override), durable completion, standalone metadata retry and no retroactive sidecar when an existing media file is skipped. D07 supplies the genuine source ID for JSON sidecars and the `{id}` filename token.
- **D03/D04:** Update the pinned background-downloader commit only after compatibility checks. Integrate an injectable task client, immutable notifier state snapshots and single ownership of the stream controller.
- **D05/D06:** Enable Anime-Pictures/Zerochan bulk downloads with site-specific pacing through **one** `ApiRequestCoordinator`. Validate URL lifetime, coalescing, retries and original-quality resolution; never silently downgrade an explicit Zerochan Original request.
- **D08:** Export all favorite tags from the persistent repository, preserving `replaceAll` import semantics and all fork backup paths.
- **D07 + X01/X02:** Provide one common `Post.sitePostId` getter for genuine site identifiers. The download `{id}` token adopts the upstream's real-ID semantics, including alphanumeric Sankaku IDs. Do not add a `{site_post_id}` token. Preserve Pixiv's page-distinguishing default format `{illust_id}_p{page}.{extension}`. Do not add a Hive field or change bookmark identity/snapshots.
- **P06 playback cap:** Automatically load animated grid GIFs, including Danbooru samples, only with autoplay enabled and a known original `fileSize` of at most 5 MiB. Otherwise display a static image, even at Highest. Explicit post viewers and downloads are unaffected.

## Progress

- [x] Pin baseline SHAs, catalog and checklist.
- [x] X01: Retain fork Hive indices 15/16; derive genuine source IDs when available.
- [x] X02: Common `sitePostId` getter; no Hive or identity changes.
- [x] X03: Protect fork data/identity invariants and headless/backup/refresh behavior.
- [x] X04: Simplified URL-MD5 image cache without physical generations; temporary share copies.
- [x] A01–A18: Approve architecture and platform behavior.
- [x] N01–N06: Approve network behavior.
- [x] D02: Decide download completion and notification safeguards.
- [x] D01, D03–D06, D08: Implement the approved download and backup topics.
- [x] D07: Switch download `{id}` to genuine site ID; retain Pixiv default filename, Hive and bookmark identity.
- [x] B01–B09: Implement the approved site compatibility topics.
- [x] B10: Activate the new Rule34 listing host after targeted live verification; broader platform acceptance limits are recorded in the remediation report.
- [x] P01–P14: Implement all approved grid and viewer topics.
- [x] U01–U08: Implement the approved search, keyboard, desktop/TV and regression test topics.
- [x] Approve all 68 migration decisions.
- [x] Implement the true upstream merge and resolve all conflicts according to the binding decisions.
- [x] Pass targeted checks and the complete local regression suite.
- [ ] Complete the user-run manual checklist and device/native/live acceptance checks.
- [ ] Obtain separate approval to integrate into `develop`.
