# #144 MiteMite v5 — source audit and remediation plan

> Naming normalization (2026-11-17): Historical paths and symbol references below use current MiteMite names. Recorded commit IDs and verification results are unchanged; consult the original commits for exact historical commands and artifact locations. These reference edits do not requalify earlier evidence.

**Status:** Historical audit and executed implementation plan. Runtime `99a3b71b2` and its exact verification/limitations are recorded in the [final handoff](../handoffs/144-interrupted-web-remediation-2026-11-14.md). The [later owner UX contract](../handoffs/144-final-owner-ux-implementation-2026-11-14.md) supersedes this audit's original presentation requirements; the corrected Task 7 and acceptance row below reflect that decision. The original audit findings remain pinned historical evidence, not descriptions of the final runtime.

**Continue:** `feature/144-folder-based-collection-sync` in `timberpile/Boorusama`.
**Audited HEAD:** `ca22205513195bc3ee310b9b58d9bd14128a6cb9`.
**Runtime beneath that documentation commit:** `8bdfdb26bb5d92730a300e8b4063db008145b7ed`.
**Compared develop:** `f77ca1f6841e076afdd48b57e62f2124d1099739`; the audited branch contains it.
**Date:** 2026-11-14.

## 1. Scope, evidence and authority

Finish the approved MiteMite behavior, beginning with the owner's newly reported failures. Preserve the existing signed transport, anti-rollback, typed Bookmark storage and journaled mirror work. Do not restart the implementation, replace mirrors with ordinary imports, or broaden this task into the paused Collection/Viewer mockup work.

This audit inspected the pinned source, affected production call paths, tests, v5 specification, HTML interaction reference and implementation handoff. It did not execute Flutter, Android, SAF, or a two-device reproduction. The Back-stack mechanism below is a hypothesis requiring a production-router regression; the mirror-state loss is a directly traceable source defect. Further findings discovered during implementation belong in #144 and the normal handoff.

The existing handoff reports 7,300 application, 1,706 package/CLI and 76 Python tests plus shell suites passing on `8bdfdb26b`, Kotlin compilation, and incomplete platform/UI acceptance. The comparison to `ca2220551` changes documentation only. Those reports are not rerun evidence from this audit. Large passing counts do not establish that the actual Receive-to-provider-to-screen path was exercised.

Authority, in descending order:

1. The owner's latest requirements recorded in section 2 below.
2. The current [v5 specification](../designs/2026-11-03-folder-based-collection-sync.md), including approved read-only Following, folder relocation and signed deletion decisions.
3. The [v5 HTML reference](../designs/mockups/2026-11-03-mitemite.html) for unchanged UI behavior; illustrative mockup behavior does not override the specification or later decisions.
4. The [implementation handoff](../handoffs/144-mitemite-v5-local-integration.md) as evidence and a gap list, not permission to omit accepted functionality.

Read current `AGENTS.md` and the applicable development/verification guidance before implementation. Reuse the existing worktree/branch and preserve later or unrelated changes. No develop merge, unsolicited PR, issue closure, or operation on a protected physical phone is authorized by this plan.

## 2. Latest owner requirements: reconcile the specification first

These requirements must be explicit in the specification and tests, rather than remaining only in chat:

| ID | Required behavior | Relationship to the older text |
| --- | --- | --- |
| U1 | Android system Back leaves exactly one MiteMite subpage; successive Back steps restore its real callers. | Existing navigation intent; current owner reports failure. |
| U2 | Publish on a specific Bookmark Group confirms and publishes that exact Group and its complete present/future subtree, without opening a generic selection page. | Consistent with direct contextual publication; existing implementation loses the target. |
| U3 | The Publish management page lists already published roots, not all unpublished local Groups. It is for managing/stopping existing publication. | Supersedes the old broad publication-checklist description in section 6.1. |
| U4 | Receive lists the explicitly published root, not every inherited subgroup as a separate subscription offer. Descendants remain in its synchronized subtree. | Clarifies discovery presentation; does not remove recursive data or independently published roots. |
| U5 | Before device trust, show device identity and the trust action only, not its published collection names, hierarchy or previews. | Supersedes the old permission to preview untrusted publishers' collections in sections 4/6.1. |
| U6 | Label the device identifier `ID:` and distinguish it from the signing-key fingerprint. | Current screen prints an unlabeled fingerprint, not a clearly identified UUID. |
| U7 | Notify the user when a new device is detected. | Makes discovery notification required; not a promise of scanning while the app is terminated. |
| U8 | Successful Subscribe immediately changes the row to a subscribed/manage/unsubscribe state and creates the correct mirrors in the current UI. | Existing intent; current owner reports failure. |
| U9 | Received Groups are visibly synced/read-only in separate device sections, never ordinary Local groups with normal source-edit actions. | Core v5 contract, not a new cosmetic request. |

Keep the distinction between **publication roots**, **effective published descendants**, **subscription roots**, and **canonical mirrors**. For A containing B and C: publishing only A offers A in Receive; subscribing A still receives A, B and C. If B is separately published directly, it remains an independently offered root. If B was separately subscribed before A, preserve its existing virtual root and shared canonical state. Do not infer direct publication solely from `parent == null`.

Update the old specification paragraphs and mockup notes that conflict with U3/U5 before treating them as acceptance references. Retain the unchanged rules for independent child subscriptions, source ownership, signed withdrawals, local copies, local-only All Bookmarks and separate read/arrival state.

## 3. Confirmed root cause: mirror ownership disappears in the UI reload

The highest-priority defect is not the absence of ownership storage. The production receive path already commits ownership. Its subsequent library refresh discards that ownership from the published UI snapshot:

```text
MiteMiteService operation completes / onApplied
  -> BookmarkLibraryNotifier.refresh()
  -> _serialize(_reload)
  -> _serializeLocally creates BookmarkMutationRepository
  -> _reload invalidates that wrapper, then uses _service
  -> _service still passes the mutation wrapper to BookmarkLibraryService
  -> BookmarkLibraryService._load checks: store is BookmarkMirrorStore
  -> false: wrapper implements UnifiedBookmarkStore, not BookmarkMirrorStore
  -> BookmarkLibraryState(... mirrors: BookmarkMirrorState.empty())
```

Relevant source: [notifier refresh/serialization][notifier], [mutation wrapper][wrapper], [library load][library], [service/provider wiring][providers]. Invalidating the wrapper's indexed reads does not change the interfaces it implements.

Consequences of the empty snapshot, even if durable mirror ownership remains correct:

- Receive reads `library.mirrors.subscriptions` and therefore continues to display **Subscribe**.
- Bookmark Home classifies the same Group IDs as Local; device sections and sync indicators disappear.
- Menus and selection/destination eligibility use the wrong read-only classification.
- `BookmarkLibraryState.localBookmarkIds` treats an empty owner map as all records local, allowing received-only content to appear in All Bookmarks.
- Read/arrival UI hooks cannot find their owner and do nothing.

Storage guards still reject many actual mirror edits; inspect [organization guards][guards]. Therefore this audit does **not** establish that all displayed edits succeed, that ownership was deleted on disk, or that received data must be reimported. Fix the reload boundary and verify existing data in place. A restart is not an adequate repair: another refresh can reproduce the loss.

### Why the current tests do not catch this

The real-Hive two-library tests construct `MiteMiteService` without the production `onApplied: bookmarkProvider.refresh` callback and read `BookmarkLibraryService` directly. The narrow-screen widget test overrides the notifier with `_SnapshotLibrary` and mounts `MiteMitePage` as a standalone `MaterialApp` home. That verifies storage and limited layout, but bypasses both the broken refresh integration and the app's actual route hierarchy. See [existing integration/widget tests][engine-tests].

## 4. Additional discrepancy inventory

| Finding | Source evidence | Required repair |
| --- | --- | --- |
| Contextual Publish loses the selected Group. | `_syncActions` pushes `MiteMitePage(section: 'publish')` without a Group ID. [Browser][browser] | Captured, source-specific command and confirmation; resume that same intent after setup. |
| Publish is an all-local-Groups checklist; stopping publication has no dedicated impact confirmation. | Flat checkbox loop in [Sync page][page]. | Published-root management projection; preserve inherited coverage and confirm destructive remote consequences. |
| Receive is flat and pre-trust. | Every active Bookmark catalog entry is rendered; trust only disables its action. [Page][page] | Trust gate before collection presentation; explicit-root projection. |
| Direct publication reasons are absent from the signed catalog. | `SyncCatalogEntry` has parent/position/state/revision, but no direct-root/rule metadata. [Catalog][catalog] | Versioned authenticated root metadata; retain descendant entries for transport/apply. |
| Publication state does not consistently rebuild Bookmark UI. | Browser watches a `FutureProvider<MiteMiteService>` but not subsequent service `ChangeNotifier` events; Sync page uses `ListenableBuilder`. [Browser][browser], [providers][providers] | One reactive derived view state for all consumers, with no second persisted authority. |
| Discovery lacks a persistent notification/inventory flow. | `devices` is transient; discovery requires a catalog; first publication skips an empty initial catalog. [Service][service] | Deduplicated new-device events, including configured devices with no publications. |
| Some intended device/Group UI is still absent. | No own-fingerprint view, alias editor, proper activity history or open-Group sync status; parent arrival aggregation is not implemented. [Page][page], [browser][browser] | Complete the established compact v5 surfaces, not added status rows. |
| Reading is incomplete. | Display callback depends on `ExtendedImageController`; Bookmark callback only handles a direct Group source view. [Media hook][media], [Bookmark viewer][bookmark-viewer] | Validate actual image/video display and explicit source-Group provenance; no prefetch or blanket Page-read side effects. |
| Error isolation is too coarse. | `_publish` precedes discovery; one outgoing failure aborts the scan. Receive prepares a publisher's covered data together, so one invalid package blocks unrelated subscriptions. [Service][service], [mirror engine][engine] | Separate independent work outcomes without weakening atomic overlapping subtrees or freshness checks. |
| Automation is incomplete. | In-memory revision debounce and foreground polling; no durable dirty intent or watcher. Busy/applying changes skip scheduling. [Providers][providers], [handoff][handoff] | Durable local-source dirtiness, catch-up after in-flight work, bounded reconciliation and appropriate watcher fallback. |
| Following is not implemented end to end. | Explicitly outstanding in [handoff][handoff]; production mirror orchestration is Bookmark-only. | Complete accepted read-only Following definitions, local runtime state and UI before declaring #144 complete. |
| SAF, fault recovery and retention lack final acceptance. | Native adapter compiles, but no real document-provider/two-device acceptance; retention is disabled. [SAF][saf], [handoff][handoff] | Real grants/restart/revocation/partial-write tests and bounded owned-file retention or an explicitly documented release blocker. |
| Android Back needs a true app-level reproduction. | Export/Import and Sync subpages use imperative `MaterialPageRoute` pushes inside the retained GoRouter app. [Export page][export-page], [page][page], [router][router] | Verify the actual route owner and dispatcher; a router/imperative-stack mismatch is a hypothesis, not yet a runtime-proven cause. |

## 5. Implementation sequence

Each task starts with a focused regression that exposes its defect or missing contract, then the smallest coherent fix, then its tests and a scoped commit. Keep the existing safety tests; do not replace them with UI-only checks. Tasks 1–6 address the reported usability failures. Tasks 7–10 close the remaining accepted v5 work. None of the latter is silently waived by finishing the visible bug list.

### Task 1 — Preserve authoritative mirror metadata through every library reload

**Modify:** `bookmark_provider.dart`, `bookmark_library_service.dart`, and only the necessary repository read boundary. Inspect `bookmark_mutation_repository.dart`, `bookmark_library_state.dart`, and existing hydration/delta reload paths.

**Add regression:** `test/core/bookmarks/bookmark_mirror_provider_refresh_test.dart` (proposed new file).

Initialize real unified Hive storage and the production Bookmark notifier first. Receive a signed subtree through a service using the real `onApplied` callback. Assert that durable owners/subscriptions and the notifier's owners/subscriptions agree after receive, explicit refresh, a no-op sync, local membership mutation, reading acknowledgement, provider reconstruction and restart. Include a received-only record and a mixed local/received record; All Bookmarks must exclude the first and contain the second once.

Load ownership from the actual pinned storage session under the existing coordinator, or introduce a narrow read-only capability that the wrapper deliberately forwards. Do not grant a generic mutation wrapper the privileged mirror-commit interface merely to satisfy an `is` check. Do not copy the old snapshot's mirror map into new state: it is stale on first receive, unsubscribe or Forget. A failed ownership read must not silently classify existing groups as local.

**Exit:** The production refresh path retains fresh ownership, subscriptions, names, aliases and reading state without changing Group IDs or reimporting data. Ordinary local mutation performance and delta behavior remain covered. All storage-level mirror guards remain intact.

### Task 2 — Make commands and UI state reactive, explicit and idempotent

**Modify:** `mitemite/providers.dart`, `service.dart`, `page.dart`, and consumers in `bookmark_group_browser_page.dart`. A small `mitemite/view_state.dart` is a possible new boundary, not a required second store.

Expose a reactive immutable projection of configured location, trust/discovery state, direct publication rules, effective coverage, subscriptions, per-operation progress and typed errors. The existing service can remain the orchestrator; bridge its changes into the project's manual Riverpod pattern and dispose listeners correctly. Do not rely on incidental Bookmark revisions to update publication icons.

Use item commands that re-read current rules inside serialization rather than replacing the entire root set from a stale screen. Capture Group/source IDs, not labels. Duplicate taps must coalesce or be disabled while pending. Display **Subscribe → Subscribing… → Subscribed/Manage** only after the authoritative subscription/mirror commit is observed; failure restores a truthful retry state and preserves existing data. Unsubscribe/Copy/Forget and direct publication must update all mounted consumers immediately.

**Tests:** rapid repeated taps, two open screens, queued operations from stale snapshots, failure before/after durable commit, offline management, service replacement, disposed route and subsequent re-entry. A UI-refresh error after a successful commit must not be presented as an uncommitted subscription that invites duplicate data creation.

### Task 3 — Repair navigation in the production app, not a standalone page test

**Inspect/modify:** `mitemite/page.dart`, `export_import/export_import_page.dart`, the existing route catalog/facade integration, and Settings entry routing only where the reproduction proves necessary. A dedicated `mitemite/routes.dart` is appropriate if consistent with nearby routes.

Add `test/application/mitemite_navigation_flow_test.dart` using the real retained shell/router and existing app harness patterns. Enter through **Settings → Export & Import → MiteMite → Receive/Publish/Activity**. Use the system-pop dispatcher (`handlePopRoute` or the project's equivalent), not only `Navigator.pop` or the AppBar arrow. Assert one pop per request, dialog-first dismissal, then Sync Home, Export & Import, Settings. Exercise the Bookmark contextual path, notification/deep-link entry, keyboard open, tab switching and state restoration.

Trace which Navigator owns each route and which dispatcher receives Android Back. Register the pages in the existing route ownership model or use its proven imperative-route bridge. Do not mask the issue with a global Back interception, a second shell/history stack, repeated `popUntil`, or hardcoded navigation to Settings. Make toolbar Back and system Back agree.

**Exit:** Headless production-router tests pass and the affected Android Back sequence is reproduced successfully on an authorized emulator/device. Report native verification separately from widget tests.

### Task 4 — Direct Publish and published-only management

**Modify:** browser `_syncActions`, shared Group context actions, `mitemite/page.dart`, `service.dart`; reuse Kurumi confirmation surfaces and localization.

For a writable Group, Publish opens a confirmation naming that Group and explaining that all current/future descendants are included. On confirmation publish that captured ID, remain in/return to the originating Group UI, and display truthful pending/success/failure feedback. Cancel changes nothing. If no folder is configured, retain the specific pending intent through folder setup and return to its confirmation; cancelling setup must not publish anything or open an all-Groups checklist.

Publish management lists direct published roots only, with optional inline coverage information for their inherited descendants. Unpublished Groups are not rows. Already-published Groups expose Manage publication/Stop publishing, not a misleading fresh Publish action. Distinguish Direct, Via parent and Direct + via parent. Removing a direct rule must not withdraw a Group still published through an ancestor; inherited-only content directs the user to the covering publication. Confirm Stop Publishing with the effective affected scope because verified withdrawal removes uncovered mirrors on receivers.

**Tests:** A→B/C, explicit B plus A, removing A while B survives, removing B's direct rule while A covers it, newly created/reparented children, saved-name changes while a confirmation is open, missing/deleted target, unconfigured/offline storage, and cancel at each step. Multi-selection publication must have an explicit deduplicated scope rather than open generic management.

### Task 5 — Signed publication roots and correct Receive hierarchy

**Modify:** `catalog.dart`, `publication.dart`, `service.dart`, Receive projection, protocol fixtures/compatibility tests. Do not change source UUIDs or infer root identities from names.

Add a bounded, validated, signed representation of direct publication roots/rules by source kind. Existing `parent` describes hierarchy, not publication intent. Keep one active catalog entry and payload history per effective source Group. Require each advertised root to resolve coherently to the authenticated catalog; validate duplicates, wrong kind/publisher and cycles.

Render only explicitly offered roots as top-level subscription choices. Inherited B/C are received through A and visible under A in Bookmark browsing, not duplicated as independent Receive offers. Separately published B remains independently available. Existing direct B subscriptions and the A/B virtual entry-link behavior must survive later publication changes. A presentation change is not withdrawal authority.

Version this addition explicitly. Do not reset pins, OBSERVED/APPLIED checkpoints, revision counters, identities or subscriptions to accommodate the new field. Old metadata must have a safe, documented compatibility result; ambiguous directness must not cause silent unsubscription or cleanup. Preserve old independently subscribed roots while obtaining updated source metadata.

**Tests:** exact Receive row sets for parent-only/direct child/overlap; source reparenting; root no longer direct but still covered; old-format catalogs; unsupported future catalogs; root metadata tampering; unchanged membership after projection changes; identical local child IDs/read state via both virtual links.

### Task 6 — Trust-first discovery, labeled identity and new-device notification

**Modify:** `service.dart`, `page.dart`, provider projections; add bounded durable discovery/notification state where appropriate. Reuse the existing notification/permission infrastructure.

Discover a well-formed device identity independently of whether it already publishes a Group. The current first-publication shortcut emits no initial empty catalog and discovery skips identity-only namespaces. Support an identity-only discovery state and/or an authenticated empty initial catalog; keep the immutable identity document immutable. Do not fabricate a trusted display name.

Before trust, show a compact untrusted-device row and approval action only. No collection labels, counts revealing private contents, hierarchy, previews or subscription controls. Do not resolve Post media from untrusted metadata. Show separate copyable **ID: <publisher UUID>** and **Key fingerprint: <fingerprint>** labels; add the local device's own identity/fingerprint view for comparison. Device names are labels, not authentication. A same-ID/different-key observation is a security state, not silent trust replacement.

Deduplicate discovered-device notifications durably across scans and restarts. Provide an in-app notice/inbox indication with a Receive deep link; use OS local notifications according to permission/preference and retain an in-app fallback. Batch simultaneous discoveries and avoid repeating every 30 seconds. Do not include collection data before trust. Detection runs under the existing enabled foreground/start/resume lifecycle; do not promise immediate detection while terminated or add a new OS background scheduler.

**Tests:** no publications, new key, malformed/half-written identity, self-device exclusion, repeated scans/restarts, discovery after temporary offline state, permission denial, changed signing key, notification deep-link Back, and no pre-trust package/media fetch. Forget/reapproval must remain explicit and must not create a notification loop.

### Task 7 — Complete read-only Bookmark presentation and Unseen/read behavior

**Modify:** `bookmark_group_browser_page.dart`, `bookmark_local_group_card.dart`, `bookmark_scroll_view.dart`, `bookmark_multi_selection.dart`, picker/Favorites Sync eligibility, `bookmark_details_page.dart`, media display callbacks and mirror reading operations.

After Task 1, verify existing home sections using the real application flow, not a pre-seeded snapshot. Preserve ordinary local cards first without a Local heading, then publisher-device divider sections, virtual subscription-root links and canonical nested hierarchy. Use the approved compact incoming-tray glyph for received cards/titles, without a Folder or sync-lock glyph. The device-section Edit pencil opens its receiver-local alias editor directly. No redundant status row or `NEW` word in the plain numeric Unseen badge.

Audit every edit entry point: touch, context menu, keyboard selection/select-all, mixed selection, Group creation/move/reorder, bulk import, Bookmark destination picker and Favorites Sync. Received source data must not be editable or republished. Viewing, saving a Post into a local Group and independent Create Local Copy remain available. Keep storage guards as the final authority even when a UI path is missed. Test that existing received groups recover their correct presentation without deletion/reimport.

The later owner decision replaces Group-open arrival acknowledgement: opening/rendering a Group never changes its badge. Derive plain `N` from persistent Group-specific Unseen members, hiding zero. Parent aggregates deduplicate portable Unseen identities and repeated virtual links without merging independent Group read flags. Historical arrival fields remain private compatibility data. Received member thumbnails use a 20dp top-right Unseen marker, hidden for selection Preview, and the conditional All / Unseen / Seen filter retains a reachable reset.

Read state changes only for the correctly scoped entry actually displayed in the full Viewer or explicitly selected for Mark Read. Complete still-image, animation/video and Group/Page cases without treating covers, prefetch, offscreen neighbors or failed media as viewed. A still requires the accepted full-rendition decode, not the shared progressive thumbnail controller's completed state. Showing a Work must not mark every saved Page read. Mark Read is absent for empty/all-read selections and updates only the selected Group-specific Unseen memberships. Subtree views need explicit originating-Group provenance; never mark the same Post read across every Group just because memberships overlap. Do not add the paused Viewer redesign to solve this.

Also verify received-only snapshot recovery/media hydration: ordinary snapshot upgrades meet repository read-only guards. A needed local display refresh must not rewrite publisher-owned memberships or silently convert a mirror into local data; use the established transient access/cache boundary or an explicitly authorized local observation path.

**Tests:** production receive→Home→Group→Viewer→Back; same Post in two Groups; A/B virtual roots; delayed rendering/newer revision while open; hidden route, failed media, video frame, Page vs Work; readonly keyboard/bulk paths; local-copy independence; All Bookmarks; missing profile followed by compatible profile; source withdrawal preserving local/other-publisher memberships.

### Task 8 — Durable automation, activity, error isolation and bounded work

**Modify:** `providers.dart`, `service.dart`, the existing mutation hooks/coordinator, `bookmark_mirror_engine.dart`, activity/state presentation and relevant tests. Avoid a second task tracker or parallel domain store.

Record outgoing dirty intent durably with or recoverably after committed local source changes; coalesce without losing changes made while a scan/publication is busy. Maintain a follow-up-needed signal and reconcile after settlement. Keep incoming apply, local reading/arrival acknowledgement and cache-only updates from producing publication echoes or unnecessary archives. Preserve full startup/resume reconciliation as crash recovery. Use a watcher for supported mounted directories plus bounded periodic fallback; SAF need not pretend to support filesystem events.

Separate outgoing publication and incoming discovery/receive outcomes. A failed publication must not block unrelated trusted incoming work. Isolate invalid/unsupported subscriptions at the smallest safe coverage unit: overlapping roots and their canonical descendants must be reconciled together where necessary, but one independent bad subtree must not block all healthy subscriptions of the same publisher. Revalidate catalog freshness and ownership immediately before each authorized transaction; do not fall back to older signed catalogs or turn missing payloads into empty snapshots.

Expose distinguishable states: untrusted, disconnected/offline, permission revoked, missing source/revision, incompatible schema, invalid signature/key change, rollback rejected, conflict and retryable I/O. Keep last valid content. Distinguish last attempted sync from last successful apply and partial success. A generic toast alone is insufficient.

Implement a bounded durable activity history of applied additions/removals/definition changes, subscription changes, discovery and failures with safe device/collection links. A list of current owners is not a history. Group deep links must acknowledge only the rendered Group's arrival; definition activity must not consume Following Post NEW.

**Tests:** a change during busy/applying, process death around dirty/checkpoint writes, no-op polling, reading-only mutation without archive rebuild, broken outgoing storage with healthy incoming device, two independent subscribed roots with one invalid package, overlapping roots with partial failure, preparation limits, retry after upgrade/permission restoration and event deduplication. Do not remove bounds or make all work unbounded to pass a large-data fixture.

### Task 9 — Complete accepted Following synchronization

**Inspect/modify:** `lib/core/search/following_topics/src/{data,providers,types,pages,widgets}/`, existing Following export/import codecs and `mitemite` orchestration. New source-specific `following_package.dart` / `following_mirror_engine.dart` are possible if they fit the existing boundaries; do not duplicate trust/transport/journal infrastructure.

Support published Topics and folder/Feed definitions. A Feed and its owning Topic folder are the same publication target, not duplicate stores. Match compatible local profiles safely; do not synchronize credentials or create arbitrary saved profiles. Preserve kind in canonical identities so Bookmark and Following source UUIDs cannot collide.

Apply source-owned query, name, hierarchy, membership, order and Feed definition through protected repository APIs. Display Local and per-device divider sections and reject rename/move/edit/mix/republish of received definitions. Only device alias and operational state remain local: profile binding, auto/manual refresh, scheduler/rate limits, previews/cache, checkpoints and Post NEW/read. Implement independent local copies, explicit-root unsubscribe and Forget safely.

Do not import the publisher's auto-refresh settings or cached Posts. Name/order changes retain the receiver's baseline/read state. Material query changes must deliberately invalidate incompatible query execution state without resetting unrelated Topics or presenting historical results as newly published Posts. Definition-change indicators and acknowledgements remain separate from Post NEW. Reuse existing execution/initial-baseline behavior rather than a separate polling engine.

Following's publication/subscription scope remains its own approved definition contract; this task must not silently impose Bookmark Groups' unconditional recursive-subtree policy. If a required Following scope choice is still absent from the canonical contract, isolate and document that decision rather than inventing destructive semantics or declaring Following complete.

**Tests:** two real libraries exchanging Topics/folder Feeds, local profile mismatch/recovery, definition rename/query edit, local auto-refresh disabled surviving incoming changes, read-only repository/UI paths, no duplicate Feed, local copies and other owners surviving unsubscribe, independent NEW/definition indicators, no outgoing echoes, backup/restart and unsupported schema retention.

### Task 10 — Finish platform/durability qualification and document actual limits

**Inspect/modify:** `mitemite/android_storage.dart`, `storage.dart`, publication/checkpoint recovery and `android/app/src/main/kotlin/com/timberpile/boorusama/MiteMiteChannel.kt`; retain existing safety tests.

Exercise persisted SAF tree grants, app restart, revoked permission, provider I/O failures, duplicate document names, missing files, partial payload/descriptor/catalog/identity writes, concurrent writes and termination/restart at transaction boundaries. Native compilation and mocked MethodChannel tests do not prove these behaviors. Keep descriptor-last verification, immutable winners and path/owner bounds. Failed or missing reads must never delete mirrors.

Identity-file partial writes require an actionable safe recovery path. Do not silently rotate the publisher key, reset revision high-water marks or overwrite a conflicting identity. If automatic repair cannot prove ownership, offer explicit repair/relocation with preserved local state and report the limitation; do not leave only a permanent generic failure.

Keep folder relocation non-destructive: validate access, preserve identity/trust/subscriptions/checkpoints/reading, safely republish owned current state, avoid deleting/withdrawing the old namespace, and reject stale data when switching back. Test interruption at each step and display pending relocation/publication truthfully.

Implement and validate bounded owned-file retention as required by v5, or keep it explicitly release-blocking. With immutable catalogs and no retention, native directory-entry limits eventually matter. Never prune foreign namespaces, latest complete catalogs, revisions referenced by retained catalogs, in-flight intents or necessary withdrawal/replay evidence. Test offline receivers catching up after pruning. Missing historical files still never prove withdrawal.

Finally exercise two authorized Android instances with actual shared-folder propagation and restore their test state. Do not use connected personal phones as a substitute without permission. Record unavailable device work as pending, not passed.

## 6. Acceptance matrix and delivery gates

Use real production wiring for the central acceptance scenarios. Keep lower-level fixtures for signatures, codec validation and fault injection, but do not override the Bookmark notifier with a static snapshot in the tests intended to qualify subscription UI.

| Scenario | Required observable result |
| --- | --- |
| Native Back from each subpage and from a modal | Exactly one route/dialog closes; expected callers and state remain. |
| Publish from A, with B/C descendants | Specific confirmation; no generic chooser; management lists A; receiver sees A only as offer. |
| B explicitly published as well | B can be independently offered/subscribed; one canonical B mirror and payload history. |
| Untrusted device | Labeled identity/fingerprint and trust action only; no collection presentation or media fetch. |
| New device, no publications | Discoverable; one durable notification; subsequent polls/restart do not repeat it. |
| Subscribe, then refresh/poll/restart | Row becomes subscribed; same mirror IDs, device sections, read-only actions and local-only All Bookmarks persist. |
| Unsubscribe A while B remains directly subscribed | Only uncovered mirrors disappear; B's identity/read state and local copies survive. |
| Stop publication / signed source deletion | Safe covered-union cleanup; missing/offline/corrupt files never trigger deletion. |
| Open Group and display one Post | Opening leaves persistent Unseen `N` unchanged; only that actually displayed typed entry is read in its originating Group. |
| Local copy / save received Post locally | Writable local destination independent of the mirror; deduplicated shared records survive later cleanup. |
| Rename/reparent/source membership changes | Correct hierarchy and counts, without duplicate virtual-link data or local read resets. |
| Received Following definitions | Separate read-only device sections; local refresh/profile/cache/NEW settings preserved. |
| Partial failures and concurrency | Healthy independent work continues; overlapping ownership and freshness remain atomic/safe. |
| SAF and folder relocation | Grants/recovery behave correctly; trust/history preserved; no stale replay, foreign cleanup or source-identity reset. |

Run targeted tests as each task lands, followed by the complete exact-final-candidate repository suite under the existing `fvm` workflow. Include app, all package/CLI and tooling/shell suites. Run affected analysis and formatting; distinguish baseline findings from newly introduced ones rather than calling an analyzer exit of 1 clean. Use controlled clocks/completion signals, not larger arbitrary sleeps to hide race failures.

Inspect compact 320/390 layouts, enlarged text, keyboard, narrow/wide navigation, offline management and accessible focus/labels. Validate 48-dp action targets and no overflow. Source trust, ownership and transaction correctness need code review in addition to UI checks; report any independent review only if it actually occurred.

Required final handoff content:

- Exact final runtime/integration candidate and commands/results, including failed or unavailable checks.
- A U1–U9 traceability table linking fixes to regression tests and device evidence where relevant.
- Status of Tasks 7–10 and every remaining v5 requirement; do not label a Bookmark-only subset complete #144.
- Screenshots or redacted UI evidence for Local/device sections, trust-before-collections, published-only management, subscribed state and direct confirmation.
- Recovery/compatibility notes for existing test installations; no reset/reinstall requirement as the normal fix.
- Commits pushed only to the existing feature branch; no PR, develop merge or issue closure without approval.

## 7. Local-agent starting instruction

Continue #144 on its existing branch/worktree. Read this plan and the current v5 contract before changing code. First reproduce and fix Task 1 using the production notifier callback; then complete the owner-reported flows with Tasks 2–6. Close the remaining accepted v5 gaps with Tasks 7–10, preserving the existing safety foundations. Keep exact-source evidence and update the implementation handoff. Treat the current Android Back root-cause explanation as a hypothesis until the real app-router test reproduces it. Do not solve UI state problems by deleting mirrors, replacing them with normal imports, weakening repository guards or reverting the approved design. Keep the Collection mockup work paused. Do not merge, create a PR or close #144.

## Source references (pinned audit baseline)

[notifier]: https://github.com/timberpile/Boorusama/blob/ca22205513195bc3ee310b9b58d9bd14128a6cb9/lib/core/bookmarks/src/providers/bookmark_provider.dart
[wrapper]: https://github.com/timberpile/Boorusama/blob/ca22205513195bc3ee310b9b58d9bd14128a6cb9/lib/core/bookmarks/src/services/bookmark_mutation_repository.dart
[library]: https://github.com/timberpile/Boorusama/blob/ca22205513195bc3ee310b9b58d9bd14128a6cb9/lib/core/bookmarks/src/services/bookmark_library_service.dart
[providers]: https://github.com/timberpile/Boorusama/blob/ca22205513195bc3ee310b9b58d9bd14128a6cb9/lib/core/backups/mitemite/providers.dart
[page]: https://github.com/timberpile/Boorusama/blob/ca22205513195bc3ee310b9b58d9bd14128a6cb9/lib/core/backups/mitemite/page.dart
[service]: https://github.com/timberpile/Boorusama/blob/ca22205513195bc3ee310b9b58d9bd14128a6cb9/lib/core/backups/mitemite/service.dart
[catalog]: https://github.com/timberpile/Boorusama/blob/ca22205513195bc3ee310b9b58d9bd14128a6cb9/lib/core/backups/mitemite/catalog.dart
[engine]: https://github.com/timberpile/Boorusama/blob/ca22205513195bc3ee310b9b58d9bd14128a6cb9/lib/core/backups/mitemite/bookmark_mirror_engine.dart
[guards]: https://github.com/timberpile/Boorusama/blob/ca22205513195bc3ee310b9b58d9bd14128a6cb9/lib/core/bookmarks/src/data/hive/unified_bookmark_organization.dart
[browser]: https://github.com/timberpile/Boorusama/blob/ca22205513195bc3ee310b9b58d9bd14128a6cb9/lib/core/bookmarks/src/pages/bookmark_group_browser_page.dart
[media]: https://github.com/timberpile/Boorusama/blob/ca22205513195bc3ee310b9b58d9bd14128a6cb9/lib/core/posts/details/src/widgets/post_details_item.dart
[bookmark-viewer]: https://github.com/timberpile/Boorusama/blob/ca22205513195bc3ee310b9b58d9bd14128a6cb9/lib/core/bookmarks/src/pages/bookmark_details_page.dart
[engine-tests]: https://github.com/timberpile/Boorusama/blob/ca22205513195bc3ee310b9b58d9bd14128a6cb9/test/core/backups/mitemite/bookmark_mirror_engine_test.dart
[saf]: https://github.com/timberpile/Boorusama/blob/ca22205513195bc3ee310b9b58d9bd14128a6cb9/android/app/src/main/kotlin/com/timberpile/boorusama/MiteMiteChannel.kt
[handoff]: https://github.com/timberpile/Boorusama/blob/ca22205513195bc3ee310b9b58d9bd14128a6cb9/docs/handoffs/144-mitemite-v5-local-integration.md
[export-page]: https://github.com/timberpile/Boorusama/blob/ca22205513195bc3ee310b9b58d9bd14128a6cb9/lib/core/backups/export_import/export_import_page.dart
[router]: https://github.com/timberpile/Boorusama/blob/ca22205513195bc3ee310b9b58d9bd14128a6cb9/lib/core/navigation/production_navigation_router.dart
