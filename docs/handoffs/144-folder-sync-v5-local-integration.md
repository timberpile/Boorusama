# #144 — Folder Sync v5 implementation and verification

Updated 2026-11-14. **Issue #144 remains open/in-progress. Do not merge into
`develop`, create a PR or close it without owner approval. The branch is not yet
ready for final owner acceptance.** This current-source report replaces obsolete
foundation-only, temporary-workflow and #141-branch instructions.

## Source and approved decisions

Continue `feature/144-folder-based-collection-sync` in its existing worktree.
The runtime candidate is `8bdfdb26b` (after implementation `dc6d40ae2`,
tombstone fix `fbe4d1bd9` and Pixiv reconciliation `29f0c5045`).

- `720a8bc96` reconciled `origin/develop` at `f77ca1f68`, including the accepted
  #141 implementation integrated as `1a3f74b`. #141 is closed; do not resurrect
  its old feature branch. Conflicting Pixiv tests/localizations use accepted
  develop versions.
- `314805e03` reconciled the latest feature remote, including `da009882b` and
  `b404893b5`. The owner has **approved fully source-owned, read-only Following
  Topics/folders/Feeds under Local and separate publisher-device sections**.
  This UI decision is settled, not an outstanding approval question.
- [Canonical v5 specification](../designs/2026-11-03-folder-based-collection-sync.md)
  and [HTML reference](../designs/mockups/2026-11-03-folder-sync.html) remain the
  product contract. The text supersedes illustrative mockup differences.
- Folder relocation preserves identities, trust, subscriptions, mirrors,
  checkpoints and revision history. Missing/offline files never mean deletion.
- Following query/name/hierarchy/order/membership/Feed definitions are source-owned.
  Receiver-compatible profile binding, auto/manual Post refresh preferences,
  scheduling/rate limits, cache/previews, NEW/read and checkpoints stay local.
  Create Local Copy must produce independently writable fresh local IDs. Do not
  reuse obsolete local name/placement overrides or Bookmark's recursive scope
  semantics for Following. [Owner decision](https://github.com/timberpile/Boorusama/issues/144#issuecomment-6877212547).

## Implemented application behavior

`dc6d40ae2` connects the existing signed protocol/publication/validation foundations
to **real Bookmark repositories**, not an in-memory replacement domain:

- Consistent local Group/direct-membership snapshots, recursive publication roots,
  semantic no-op payload reuse and catalog-only source rename/hierarchy changes.
  Explicit folder configuration, signed device discovery, fingerprint approval,
  additive subscriptions, foreground startup/resume reconciliation, periodic scans
  and coalesced Bookmark library changes are connected to the application lifecycle.
- Canonical publisher/source → fresh local Group UUID mapping. Overlapping
  subscriptions share one mirror, with direct-root virtual links and independent
  subscribed descendants. Received and local hierarchy cannot mix.
- Unified Hive journal version 4 includes mirror ownership, applied revision,
  hierarchy/memberships and receiver reading state in one transaction. Interrupted
  application is recovered before ordinary repository access. Last-applied source
  descriptor history survives removal, Forget and reapproval.
- Repository enforcement protects names, members, parents, order, ownership and
  received-only saved snapshots. Receive cannot rewrite an existing local snapshot
  or claim a local Group. Mixed local/received identities stay deduplicated and
  preserve local observations; incompatible foreign-publisher snapshot changes
  conflict instead of silently choosing a new owner.
- Signed withdrawal/deletion removes only uncovered received mirrors. Explicit
  offline Unsubscribe/Forget and independent Create Local Copy use safe domain
  transactions. Outside local/received memberships preserve shared records; no
  automatic Default membership is added. Forget revokes trust without erasing
  anti-replay history.
- All Bookmarks, its counts/tag/source selectors and previews use local membership.
  Received Groups are excluded from ordinary Bookmark/bulk/Favorites Sync targets,
  with repository guards behind the menu restrictions.
- Settings → Export/Import → Folder Sync provides explicit setup and management.
  Publish/Receive, Sync now, trust fingerprint, offline management, overlap-aware
  removal counts and device naming use existing Kurumi surfaces. Bookmark Home
  shows Local and publisher-device sections, canonical direct roots, compact
  upload/sync-lock indicators and direct Group arrival badges. App shell and
  existing card geometry remain in use.
- Opening a received Group acknowledges only its rendered membership revision's
  arrival notification. Selection Mark Read is conditional on unread selected
  members. A decoded image in the settled, active full Viewer marks that saved
  occurrence read; preloads, adjacent entries and covered routes do not. A saved
  Work visit does not mark all separately saved Pages read.
- Android SAF method channel is registered and disposed with MainActivity.
  Persisted tree grants, bounded worker I/O, path/owner checks and exact document
  name/URI verification are implemented. New-document creation replaces unsafe
  rename-over-publication. Partial final files cannot validate and are retained;
  no incomplete-file overwrite or automatic broad cleanup is activated.

Critical source review found and resolved additive-subscription deletion,
unauthenticated publication-cache reuse, descriptor/schema skip, received-only
snapshot edits, pre-expansion resource limits, cached failed-durability retries,
post-disposal work and cleanup revision-history gaps. Sync-specific authority
writes flush and synchronize the Hive file and parent directory before use.

`fbe4d1bd9` adds the final tombstone boundary: validate inactive descriptors against
retained source history before deletion, retire at the supplied higher revision,
and reject revival of skipped pre-deletion payloads. It also places the Folder
Sync settings row after Advanced Backup so the existing backup flow remains
reachable at its original position.

`29f0c5045` removes a residual old #141 Artist Info Parent Work button left by
three-way reconciliation. The accepted configurable Details section remains the
only Parent Work UI. Pixiv source/tests and navigation match `origin/develop` after this correction;
all 97 Pixiv Work/Page tests pass. The later Kurumi difference is the optional
popup focus-node parameter described below.

`8bdfdb26b` fixes the new Default-card Publish menu's arrow-key reachability.
Cards own and dispose their trigger/menu focus, retain canonical identity keys,
and use an optional focus node on the existing Kurumi popup component. The exact
remote-navigation regression, 55 Bookmark card tests and the full 222-test Kurumi
suite pass, including both popup-trigger variants and Escape focus restoration.

## Verification

Runtime candidate: `8bdfdb26b` (accepted Pixiv source and keyboard fix included). Documentation-only updates after it do not change
runtime/test inputs. Durable local logs are under
`.worktrees/_artifacts/144-production-20261114/` (ignored, not committed).

- `fvm flutter test --no-pub --concurrency=6 test/core/backups/folder_sync
  test/application/backup_restore_flow_test.dart --reporter expanded`:
  **112 passed** (108 Sync tests and 4 real backup application-flow tests).
  Covers signed packages, journal fault/reopen, ownership/read-only enforcement,
  trust/checkpoint retries, missing payloads, offline management, overlap, local
  copies, relocation, schema/equivocation rejection and tombstone rollback.
- The two-library scenario uses independent Hive libraries, signing identities,
  preferences and mutation coordinators over one host directory. Opposite-direction
  publication/subscription, stable identity, local-only All Bookmarks, source rename,
  local reading preservation and no publication echoes pass. This is a **host
  simulation**, not two physical devices or real Syncthing/SMB acceptance.
- Headless UI checks cover 320 px width, 170% text, keyboard-open device naming,
  opt-in setup, safe received device-card menus and Bookmark/Favorites consumers.
  Image/preload reading and the Viewer rebuild regression pass in affected Viewer
  suites. The complete suite below includes their final candidate versions.
- Native SAF compile: installed Gradle 8.14,
  `:app:compileDevDebugKotlin`: **BUILD SUCCESSFUL**, 506 actionable tasks.
  This proves native compilation only. No install or physical-device interaction
  was performed. Dart channel-contract tests are included in Sync tests.
- Final scoped `fvm flutter analyze --no-pub` over Sync, Bookmarks, changed Viewer
  files and affected tests: **0 errors, 6 existing warnings, 224 informational findings; exit 1**.
  The warnings are four unnecessary null assertions in `media_group_page.dart`,
  an unnecessary cast in `mixed_post_details_page.dart`, and the existing unused
  `coverUrl` test variable. Informational findings include both existing lint and
  implementation-style notices; this is not a clean analyzer result. A separate
  analysis of the reconciled `work_information.dart` reports **no issues**.
- `./scripts/run_regression_tests.sh` on `8bdfdb26b`: **exit 0**. **7,300
  application tests, 1,706 package/CLI tests across all 13 tested packages, and
  76 Python tooling tests passed**. Both pull-request-policy and Android-release
  shell suites passed. Two existing `go_router` tests were skipped. Detected
  physical concurrency was 6. Durable complete log: `full-regression-qualified.log`.
  This is the final candidate's complete pass, including the corrected keyboard,
  Pixiv reconciliation, Sync, journal and backup application-flow regressions.
- `git diff --check`: clean before committing the runtime candidate. Localization
  generated using `./gen.sh i18n`. Temporary #144 diagnostic workflow is absent;
  it was removed in prior foundation work. No replacement diagnostic workflow added.

Earlier affected/full attempts exposed a viewer rebuild, a real/fake scheduler
boundary in the new Hive/widget harness and backup-row reachability. These were
fixed and rerun. The first complete attempt on `dc6d40ae2` was stopped after the
final source review required the tombstone fix; it is **not** a complete pass.
The second complete attempt on `fbe4d1bd9` exposed two duplicate Parent Work
finders due to the residual old button; it was stopped and superseded by
`29f0c5045`. Its complete application run then reached **7,299 passed / 1 failed**:
only the new Default-card menu was unreachable by arrow keys. That failure is
fixed in `8bdfdb26b`; the complete final runner above passed on that candidate.
No failed or interrupted attempt is counted as a pass. Independent source review
confirmed the tombstone and other reported safety fixes. A further read-only
review confirmed focus ownership/disposal, canonical keys, arrow routing and
popup focus restoration in `8bdfdb26b`. Neither review establishes device acceptance.

## Remaining production work and limits

1. **Following integration is not implemented.** Build scoped definition packages,
   actual repository publication/receive, canonical ownership and journaled apply/
   cleanup, repository guards, Create Local Copy and approved Local/device UI.
   Its definition-change glyph must remain separate from Post NEW. Preserve local
   profile/refresh/cache/read state and rate limits. No Following receive or
   destructive path is enabled in this candidate.
2. Complete automatic change detection: durable mutation dirty signals and a
   filesystem watcher with periodic fallback. Current foreground polling,
   coalescing and full startup/resume reconciliation are connected, but no
   terminated/background delivery guarantee exists.
3. Complete v5 UI: actual activity history/deep links, device-alias editing,
   sender-side fingerprint display, hierarchy/reason details in Publish/Receive, parent arrival aggregates,
   complete per-entry unread presentation and operational error classification.
   A missing/invalid collection currently pauses its publisher's combined receive
   operation; isolate unaffected subscriptions without weakening overlap cleanup.
4. Complete Viewer reading for videos and all alternative entry paths. Current
   new read hook proves decoded-image display only, with no preload/neighbor credit.
5. Validate Android providers and crash boundaries: persisted grants across restart,
   revoked/offline trees, concurrent writers/name collisions, partial-document
   recovery UX, directory/identity publication failures and real process death.
   Some SAF providers rename new files or expose ambiguous names; they fail closed.
   An incomplete immutable identity file currently requires transport repair or
   relocation; it is not silently overwritten. Retention scheduling is disabled.
6. Run actual two-device Android/Syncthing-or-mounted-share acceptance, upgrades
   and larger collection/performance/UI checks. The owner explicitly said to
   **leave the CPH2769 phone alone**; device acceptance remains pending. Final
   ADB/Maestro discovery found CPH2769 and Pixel 4a physical devices, with **no
   connected emulator**. Discovery only was performed; neither phone was operated.

Runtime commits `dc6d40ae2`, `fbe4d1bd9`, `29f0c5045` and `8bdfdb26b` were
pushed to `origin/feature/144-folder-based-collection-sync`; remote runtime SHA
`8bdfdb26bb5d92730a300e8b4063db008145b7ed` was verified. This documentation-only
report does not change the tested runtime. Keep the feature branch and issue open.
This candidate
is **not ready for final owner acceptance or develop integration** because the
Following implementation and remaining platform/UI acceptance above are unfinished.
No merge, PR or closure has been requested.
