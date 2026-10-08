# Preserve website capabilities across equivalent profile URLs

Priority: Normal
Affected feature: Website capability lookup and credential-free profile import

## Problem

Realbooru's registered preset URL ends in `/`, but generated `GelbooruV2Config.siteCapabilities` matches it by exact string. `https://realbooru.com` falls back to generic Gelbooru behavior, losing Realbooru's HTML search, post and tag parsers. A regular Realbooru profile exported without credentials has its URL normalized without that slash by `ProfileExportSanitizer`; importing it as a new profile preserves the slashless URL. This can break search and bookmark metadata recovery even after dependency auto-creation is removed under DATA-010/DATA-012.

## Expected behavior and acceptance criteria

- Equivalent spellings of a registered website URL retain that website's capabilities, including a trailing slash difference, while distinct hosts and installation paths remain separate.
- A credential-free Realbooru profile export imported as a new profile uses the same search and post-recovery parsers as the regular Realbooru preset.
- Preserve profile UUIDs, credentials, account choices, and canonical bookmark identity. Do not add engine-only website fallback or restore automatic dependency profile creation.
- Cover configured and unconfigured website lookup plus the real credential-free export/import path, and verify Realbooru search and bookmark recovery through the UI.

## Context and scope

Relevant code: `packages/booru_clients/tools/templates/site_capabilities.mustache`, generated `packages/booru_clients/lib/src/generated/booru_config.dart`, `ProfileExportSanitizer`, `ProfileImportProjector`, and `gelbooruV2ClientProvider`. Update generator inputs/templates rather than editing generated output directly. Coordinate with [DATA-010](../done/DATA-010-require-site-profiles-for-bookmark-import.md) and [DATA-012](../done/DATA-012-default-and-edit-import-profile-mappings.md). Use public synthetic data and preserve emulator app data. This is a separate follow-up; no implementation is authorized by the DATA-010 review revision.

## Claim

Claimed 2026-10-05 by coordinator `/root`; implementer `/root/profile003`; branch `fix/profile-003-website-capabilities`; worktree `/home/timber/code/Boorusama/.worktrees/profile-003-website-capabilities`. User authorized implementation through subagents in the prioritized program `/tmp/boorusama-priority-program-2026-10-05/order.md`. Local integration and publication remain separate approval steps.

## Review status (2026-10-05)

Implementation is committed on the assigned isolated branch and independently reviewed. Visible Realbooru search and bookmark recovery acceptance remains pending: after a preserving-data Dev APK installation, Maestro launch reported success but the recorded screenshot showed the Android launcher. No synthetic profile or bookmark was created and no existing app data was reset or deleted. Keep this ticket in progress. Evidence: `/tmp/boorusama-priority-program-2026-10-05/profile003-report.md`.

Follow-up read-only launch diagnostics confirmed the exact enabled Dev package and correct MainActivity launcher resolution. Android recorded a process-startup ANR and killed the earlier launch. A normal retry kept MainActivity/process alive but still showed a blank white app screen; a bounded readiness wait failed. Flutter native loading succeeded, and the underlying startup delay remains unconfirmed. No source/system setting or stored-data change was made; lease released. The visible acceptance gate stays pending, without assuming a permanent emulator failure.

## Additional UI QA · 2026-10-05

Coordinator independently viewed `/tmp/boorusama-priority-program-2026-10-05/profile003-qa2-readiness.png`: the Dev app has finished loading and shows its search grid. The previous blank screen is no longer its current state; startup-delay cause remains unconfirmed. Two bounded Maestro attempts (inspection and menu flow) failed before control because its Android driver did not start on emulator-5554 port7001. The specific imported Realbooru search and incomplete-bookmark recovery criteria remain unverified. No profiles/bookmarks were created, credentials read, or existing data reset. Raw report: `/tmp/boorusama-priority-program-2026-10-05/profile003-qa2-report.md`. Source remains unchanged after passed tests/review.

## Additional UI QA · 2026-10-06

A supported process-only longer Maestro startup timeout returned a valid UI hierarchy on emulator-5554; a later session lost Android services and was cleaned up without resetting data. On a separately leased emulator-5556, the reviewed Dev APK installed preserving data and the same owned Maestro session remained responsive. Both initial launch and the single authorized warm retry ended in Android startup ANRs before product readiness. The imported Realbooru search and bookmark-recovery criteria remain unverified; no credentials were read or synthetic app data created. Both leases were released. Evidence: `/tmp/boorusama-priority-program-2026-10-05/profile003-qa3-report.md` and `profile003-qa4-report.md`.

An optimized Dev profile APK is being built from the same source for a later bounded acceptance attempt; no product/native/system changes or publication. Build configuration uses the same Dev application ID and debug-derived signing, with repository entrypoint `lib/main.dart`. This does not establish the cause of the debug startup ANRs or complete UI acceptance.


## Dev profile-mode UI QA · 2026-10-06

Same-source optimized Dev profile build passed, retaining the Dev application ID/version and verified debug signer. Its preserving-data installation on exclusively leased emulator-5556 succeeded on the one authorized longer retry; actual installed APK hash matches the profile artifact. Owned Maestro inspection/control remained usable. The single profile launch ended in Android `failed to complete startup` ANR and process termination. An independently observed Digital Wellbeing ANR dialog was dismissed normally through Maestro; no causal diagnosis is established. No second launch, data reset, system change or credentials read. Final actual Maestro screenshot shows launcher; owned MCP closed and lease released. Credential-free Realbooru export/import search and incomplete-bookmark recovery remain unverified; no synthetic app data was created. Evidence: `/tmp/boorusama-priority-program-2026-10-05/profile003-profile-build-report.md` and `profile003-qa5-report.md`.


## Verified Realbooru UI acceptance · 2026-10-06

This verified acceptance supersedes the earlier environment-blocked UI status. On separately leased emulator-5558, the same-source Dev profile APK installed preserving data and loaded normally. Tested APK SHA256: `2b8ceab917f526b270531fdbe3eb87fdfbb41107d67bae2c64f6255ba8da7b4b`; source HEAD: `436a7b88b005c96e76cdd777644aa31a6b6bc50b`. Actual Maestro UI created a regular public Realbooru QA profile, exported only it without credentials, imported that actual slashless-URL export as Copy, and successfully searched for `id:588549` through the imported profile. Scoped re-export verified distinct UUIDs, retained type 23/hint 23 and `https://realbooru.com`, absent credentials, and an unchanged original QA profile.

An owned incomplete bookmark fixture was explicitly mapped to the imported profile. Opening it recovered media and 12 real tags, persisting codec 99→2, sample/original URLs and the imported profile hint while preserving canonical `realbooru.com/id:588549` and group identity. The coordinator independently checked archive manifests/projection and raw UI metadata. Only owned fixtures, the added history entry and device files were removed; the existing Default profile and history remained. Owned MCP exited and the emulator-5558 lease was released. Phone_4 remains running for later QA. Evidence: `/tmp/boorusama-priority-program-2026-10-05/profile003-qa6-report.md`, `profile003-qa6-verification.json`, input/after-recovery archives and raw per-step UI traces. Earlier emulator-5554/5556 startup ANRs remain undiagnosed and are not attributed to this patch. Product source is unchanged; integration and publication remain separate review boundaries.

## Combined verification phase (2026-10-06)

Coordinator assigns `/root/current_items_fixture_preparation` to combine reviewed own changes and resolve necessary integration seams in separate `.worktrees/current-items-review`, branch `chore/current-items-review`, based on current local develop7c1f6c40. Original ticket worktree/branch remains preserved. Debug Monitor is excluded at user request. This is verification preparation only; pending user delivery approval, no develop merge/publication. Requirements: `/tmp/boorusama-priority-program-2026-10-05/current-items-assembly-brief.md`.


## Final combined automated verification (2026-10-06)

Review-only branch `chore/current-items-review`, HEAD `83924ab4873acbea015baeaa9f63a31807eaa7b2`, tree `26575676bb6094764f3969afe82ac0d5be8ed070`, based on BM-inclusive local develop `7c1f6c40`. Final complete app suite: 2,590 passed; affected packages cache_manager 23, extended_image 47, booru_clients 76 passed, each exit 0. Coordinator independently verified raw command records/logs and all 294 changed-path, 27 generated and 7 dependency records against final freeze. Production analysis had no issues; formatting had zero changes. Initial four stale CACHE test expectations for the agreed GH quality migration were corrected in exactly one test file, independently reviewed, then the full suite rerun; both original and final evidence are retained. No product fix was needed for that failure.

Independent final cumulative review is assigned to `/root/review_final_current_items`. New visible behavior remains for user manual review per their instruction; no blanket new emulator/APK/live-service checks. Debug Monitor remains paused and excluded. Originals are preserved; this record does not authorize integration/publication. Ticket stays in-progress/prepared pending applicable acceptance and approval. CACHE approval remains held for prerequisite review. Evidence outside the repo: `/tmp/boorusama-priority-program-2026-10-05/current-items-final-verification-report.md`, `current-items-final-root-verification.json`, `current-items-assembly/final-verification.json`, and `manual-review.md`.


## Final review handoff (2026-10-06)

Final shared review HEAD `6c98936235fa725205f06dd4d1c82e7cc3a97334` (tree `776fead6536d2d3428f4ddba16689e7126572c71`). Independent whole-source review found only a small PS cooldown retention defect; dedicated PS correction `5e13615370e6879b7a0ff725a40d5e2bd7baefc7` was root-reviewed and replayed once. Independent scoped re-review PASS, no remaining identified findings. Exact final six refresh suites 75 passed; changed production analysis clean, formatting unchanged, diff check successful. Root and reviewer matched 294 cumulative paths, 27 generated files, seven dependencies and 721 preserved historical evidence files. Earlier full app 2,590 and package 23/47/76 runs remain explicitly attributed to pre-correction `83924ab4`; no blanket full rerun was needed for the narrow correction.

Prepared for user manual visual review via `/tmp/boorusama-priority-program-2026-10-05/manual-review.md` and `review-ready.md`; final independent reports `final-current-items-review.md` and `final-current-items-r1-review.md`. Ticket remains in-progress/prepared, not newly delivered. Monitor paused; unstarted tickets skipped. CACHE approval retained pending prerequisite review; local develop clean at7c1f6c40 (only prior BM delivery), no further merge/push/cleanup. Original own branches preserved; PS latest own tip5e136153.


## Approved local delivery (2026-10-06)

The user explicitly approved all completed active items for local develop. This ticket is prepared as one summary-only delivery commit in `chore/current-items-develop-integration`, from reviewed combined source `d9fd84816211e137b180d022b0fa4fc68b1589cd`. All earlier pending-approval notes are superseded by this approval. Debug Monitor remains paused and excluded. Source verification and final serial app evidence are recorded in `/tmp/boorusama-priority-program-2026-10-05/local-develop-integration-report.md`; the exact delivery commit mapping is external. The coordinator will update local develop after its final gate. Publication and cleanup remain separate.
