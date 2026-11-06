# Stage 07: independent Pixiv Work and Page bookmarks

**Issue:** #141. **Branch:** `feature/141-pixiv-work-page-bookmarks`.
**Base:** reviewed #140 viewer plus #155 storage and #142/#143 access.
**Goal:** all local Bookmark operations distinguish a whole Work from its individual Page without creating a second persistence or picker path.
**Final reviewer:** independent Sol High for an adapter-only implementation; Astra High if any shared persistence, identity, access, migration or viewer-state contract changes.

Read the [approved contract](approved-contract.md) and the accepted action table/chevron geometry in `docs/designs/2026-11-05-decision-02-work-page-ux-and-actions.md`. #124 server bookmark writes remain out of scope.

## Files and responsibilities

Use current `lib/core/bookmarks/src/types/bookmark_picker_request.dart`, generic saved-target adapters from #155, membership providers/services, shared Kurumi picker contents/host, `lib/boorus/pixiv/works/` presentation from #140, existing Post toolbar actions, `lib/core/posts/shares/src/unified_post_share_sheet.dart`, and `lib/core/posts/links/boorusama_post_link.dart` plus the actual .bslink codec/router beside it.

New tests: `test/boorus/pixiv/works/work_bookmark_actions_test.dart`, `work_bookmark_roundtrip_test.dart`, `work_page_share_test.dart`; extend existing shared picker, icon geometry, deferred-write and bookmark Undo tests. Keep helper files beside their owning feature instead of adding a generic command bus.

## Task 1: generic storage entry points and identity independence

1. Supply a Group target with Summary and any already loaded export-safe Details to #155's saveGroup. Use actual Work ID in `group/work:<id>` and the real current Page Post in `post/work-page:<id>:<index>`.
2. Saving a Work creates one local record and zero implicit Page records. Saving Page 2 creates only that PostBookmark and does not create the Work. Repeated save adds missing memberships without changing existing IDs/dates.
3. Test Work 120 and Page index 2 in separate groups, then both in the same group; remove/Undo either target without changing the other. A single-page Work and its sole Page remain distinct identities without duplicate default controls.
4. Test membership indicators/counts independently: a saved Page does not make the Work button saved, and a saved Work does not mark every Page as individually bookmarked. Preserve the existing synced-group exclusion preference for appropriate local status calculations.
5. Bookmarking from a Summary-only card must not fetch Details, enumerate members or download media. Available Details survive offline; unavailable source/profile does not delete membership.

## Task 2: captured targets through one existing picker

1. Normal Bookmark tap opens the existing Kurumi picker for the whole Work. Hold opens the compact Work/Current Page choice; equivalent overflow and semantic actions must exist. Reuse existing folders, Recent groups, default membership and create-group flows.
2. Capture immutable Work/Page identity and original source binding before opening the choice/picker. The picker must not read a later `currentPost` to decide what to save. Preserve the existing request-cancellation/changed-source policy: after auth/source revocation reject the write; after an unrelated visible-page change either retain the captured valid target or cancel according to the existing picker contract, never redirect it.
3. Hold must not trigger normal tap when released. Use a shared decorative chevron inside fixed button bounds; no new Row that shifts/shrinks the main icon, no second hit region, unchanged touch/padding/spacing/splash.
4. Group creation handoff, dismissed anchors, rapid repeated tap and Back/Escape must not produce duplicate or late writes. Keep immediate picker opening while optional metadata loads.
5. Do not intercept image long-press gestures or introduce a new global Bookmark action framework. At the end of this stage the #140 placeholder/capability gate is replaced by working Work actions, not left disabled.

## Task 3: share exactly the distinct targets

1. Preserve all existing Post/Page URI grammar and .bslink version-1 envelope. Add strict Group URI support with `boorusama://group/open`, `v=1`, and the existing named engine/site/key parameter rules. The URI host selects `ContentKind.group`; key validation remains engine-owned. Reject duplicate fields, credentials, unknown versions and malformed kinds before navigation.
2. Use #154's codec for construction/parsing. Group Work key is `work:<illustId>`; Page key remains deployed `work-page:<illustId>:<pageIndex>`. No local Bookmark IDs, profile/account IDs, tokens, membership or private metadata appear in either link.
3. The existing Share Sheet keeps Media and Links. Show one native Pixiv Work URL, Page-specific image/media options and a compact Boorusama Work/Page pair for portable URI and file sharing. On narrow screens use rows rather than squeezing two unusable columns.
4. Do not duplicate the native source URL or media actions just to fill both scopes. Do not expose synthetic page numeric Post.id as the real illustration ID or fabricate a Pixiv Page URL.
5. Old readers may reject a new Group URI explicitly. New readers must still accept old Post/Page .bslink files and retain their origin scope. Incoming link resolution uses #143 access policy; a link is not permission to probe arbitrary hosts.
6. Test both copy and file-share paths, cancellation, Work/Page differences, source/profile changes while the sheet is open and unknown Group grammar. Preserve share resource cleanup/leases.

## Task 4: mixed library and v10 regression

1. Build a library containing Danbooru Post/Pool/Related, Pixiv Work/Page and an inaccessible supported Group. Test filtering/sorting, mixed selection, moving/duplicating groups, bulk local remove and Undo.
2. Export/reimport with no Pixiv profile; record identities, local ID remapping, memberships/dates, offline Summary/Details and Page snapshots remain intact. Adding a matching profile resolves the same records.
3. Group media operations dispatch only to real selected Page Posts; no Group-to-Post casts. Bulk selection must never silently apply a Page-only action to just a compatible subset unless the existing UI explicitly supports and reports that behavior.
4. Verify no call to remote Pixiv bookmark add/remove endpoints occurs from local Work/Page save/remove. Server Favorite state must not be changed or fabricated.

## Verification and review

Run the new tests plus all shared picker/membership/Undo/share/link/backup suites and Pixiv viewer consumers, formatting and affected analysis. If shared contracts change, run full regression immediately; the final integration candidate always requires `./scripts/run_regression_tests.sh`.

Android acceptance on a leased emulator: save Work and a non-first Page to different groups, reopen each, remove/Undo each, toggle Overview, open/dismiss picker while paging, rotate, use narrow/large-text layouts, exercise long-press and overflow, copy/share/reopen both links, and repeat after profile removal/recreation. Do not mutate remote favorites.

Lower-cost agents may add localized labels and safe fixture variants or adapt simple picker scope bindings after signatures are fixed. The lead owns async target capture and verifies generated changes. A fresh Sol High reviewer is sufficient only if this is genuinely a narrow consumer stage; any shared identity/storage/auth/gesture change automatically escalates final review to Astra High. Review the final commit after fixes, not an earlier version.

Deliver the #141 handoff with actual tests/review evidence and remaining integration limits. Do not close #141 before its verified authorized publication.
