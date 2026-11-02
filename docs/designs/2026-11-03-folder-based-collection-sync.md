# Folder-based collection synchronization

Design specification for [#144](https://github.com/timberpile/Boorusama/issues/144). **Specification only; no app implementation has been performed.**

[Interactive HTML reference](mockups/2026-11-03-folder-sync.html) (desktop/mobile, existing navigation, context menus, Publish, Receive, Sync activity). This text is authoritative if the mockup's illustrative data or behavior differs.

## 1. Goal, prerequisites, and exclusions

Provide **optional serverless synchronization of selected Bookmark Groups, Bookmark folders, Following Topics, and Following folders/feeds** through a user-chosen shared directory. Syncthing or a mounted SMB share may transport the files; Boorusama knows only a directory, not Syncthing, SMB, WebDAV, or a central service.

- Each device independently chooses what it **publishes** and which other devices' collections it **receives**. For example, device A publishes Favorites to B while B publishes different Groups to A.
- Automatic change detection, publication, and verified import work when the app is active and on startup/resume; missed/offline changes are retried. No promise of instant notifications when an app is terminated.
- Received content is mirrored **read-only**, while its local name and placement remain editable. A later explicit detach/copy creates a writable independent collection.
- Reuse existing `.bsexport` packages and transactional import facilities. No new general export format or direct sharing of Hive databases.

**Dependencies:** [#142](https://github.com/timberpile/Boorusama/issues/142) for retaining valid Bookmarks/Pool references without local profiles; [#143](https://github.com/timberpile/Boorusama/issues/143) for anonymous public-site display and the unavailable-Bookmark counter. [#43](https://github.com/timberpile/Boorusama/issues/43) defines verified alias identities; use the resulting canonicalization rather than duplicate it. Source-level Finding: current manual import profile dependency checks would otherwise block Bookmarks; do not reintroduce that requirement through sync. Following search execution may still require a compatible profile; pause unresolved Following subscriptions safely. The prior unified export/import design listed continuous sync as a non-goal; this is a separate, opt-in consumer of that system, not a change to manual import actions.

**Not in v1:** editing the same mirrored membership on both devices, user accounts/servers, live media transfer, sync of full backups/settings/credentials, cached feed posts/previews, and independent legacy Topic Feed publication.

## 2. Identity, names, folder layout, and content ownership

| Field | Source/receiver contract |
| --- | --- |
| Publisher identity | Random installation ID plus pinned signing public key; never identify by device name alone. |
| Collection identity | `(publisherId, collectionKind, sourceUuid)` maps persistently to one **local** UUID. Never match by display name. |
| Bookmark Group membership | Mirror portable Post identities and saved snapshots plus typed Pool/Series references; preserve local memberships in other Groups. |
| Bookmark Group name | **Never synchronized after initial subscription.** Source name is shown for discovery and suggested on first import; receiver can rename freely. |
| Bookmark Group placement/order | **Always local**. Moving a received Group into any folder never changes its subscription or makes it a conflict. |
| Published source folder | Defines discoverability and subscription scope, **not** mandatory local placement. |
| Received folder name | Initially source name; optionally track subsequent source renames **until** the receiver locally renames it. Local rename creates an override. |
| Received folder hierarchy | Optionally recreate **once** on first subscription; subsequent source moves/reparenting never reorganize receiver folders. |
| Following Topic/feed | Mirror query, portable site/profile identity, feed/folder configuration; keep previews, caches, checkpoints, post-NEW/unread locally. Locally overridden display names/placement persist. |
| Credentials, user profiles, private settings, files | Never synchronized. |

A source UUID collision with an existing unrelated local item must create/retain a distinct mapping, not overwrite it. Do not copy the reserved **Default** group over a receiving device's reserved Default: a remotely published Default becomes a regular locally named Group. **All Bookmarks** is a view, not a publishable collection. A publisher's source-group rename changes its discovery label only: do not overwrite receiver's local Group name, increment its unread additions, or force a membership revision solely for the label.

Read-only means **membership and mirrored definitions only**. Received Groups remain viewable, movable, renamable, sortable, searchable, and may contribute Posts to other writable Groups. Guard membership mutations at the repository/service boundary, not just in widgets: context menus, viewer bookmark picker, bulk operations, Favorites Sync target selection, manual imports, group moves, and All-Bookmarks deletions must not accidentally mutate a mirror. Unsubscribe should keep a retained local copy by default; Detach/Create editable copy creates new independent identities and re-enables editing. Underlying Post snapshots remain deduplicated by portable identity; removal from one mirror never removes other membership.

## 3. Publishing and overlapping selections

A Group/Topic may be published **directly**. Publishing a folder selects its existing descendants and publishes its source hierarchy; an explicit **Include future children** option defaults **off**. A folder has optional exclusions for individual current children and nested subtrees.

Effective publication is the union of (a) a direct item rule and (b) at least one non-excluded inherited folder rule. **One source item produces exactly one payload/revision history** even if selected directly and through several ancestors. Display provenance in the management tree as `Direct`, `Via folder`, `Direct + via folder`, or `Excluded`. Removing the parent rule does not remove an independent direct rule; excluding a child from its parent's scope does not override an independent direct rule. Moving a published item to a different local source folder can update inherited scope without changing its collection identity or duplicating the export. No name-based deduplication.

Following currently models enabled feeds using Topic folders. The RSS/Feed view's **Publish** action targets that **same** Topic folder/Feed definition, not a second parallel publication. Individual Following Topics can also be published directly. Old Topic Feed codecs remain import compatibility facilities only.

**Stop publishing** changes the source catalog to `withdrawn`; **deleting** the source emits a distinct `deleted` tombstone. Neither disappearance of an SMB/Syncthing directory nor missing files imply deletion. Existing receivers preserve local data by default and may explicitly choose to remove it after confirmation; stopping a direct publication while a parent still publishes the same Group should leave it published.

## 4. Receiving and subscription semantics

The Receive view lists trusted and untrusted published devices, their source labels, folders, and published Groups/Topics/feeds. First-time receiving requires explicit publisher approval with key fingerprint; a device name alone is not authentication. A publisher reinstallation with a new identity/key requires new approval.

Subscribing to an item prompts for its **local name** and **local destination folder** (Home, existing folder, or new `Shared from [device]` folder). Subscribing to a full folder also offers:

- **Copy source structure once** (on by default for a complete folder): creates an initial local hierarchy; does **not** impose later source placement.
- **Automatically receive newly published children** (off by default): receiver-specific and independent of the publisher's **Include future children** switch. Both ends must opt in for automatic new subscriptions.

A Group already directly subscribed and then selected through its remote parent is **still one local Group**. Store direct subscription and inherited folder references separately. Removing either route preserves the other. Users can locally relocate any received Group afterward; source folder rename/reparent changes never undo that choice. A locally renamed received folder stops following remote folder renames. Where remote source structure changes and a subscription depends on scope inclusion, update the set of subscribed source identities without moving existing local items.

A removed subscription or withdrawn publication retains local data. If the user wants to continue editing, offer **Detach as editable** explicitly. Never auto-publish a received mirror back to its origin.

## 5. Folder protocol, automatic changes, and safe import

Use immutable revision snapshots per **changed** collection, with a separate versioned sync envelope and discovery catalog. One plausible v1 layout:

    BoorusamaSync/v1/
      devices/<publisher-id>/identity.json
      devices/<publisher-id>/catalog/<sequence>.json
      devices/<publisher-id>/collections/<kind>/<source-uuid>/
        <revision>.bsexport
        <revision>.json

The catalog lists source kind/UUID, safe source label, parent source IDs, publication scope, active/withdrawn/deleted state, latest committed revision, and schema capabilities. Revision descriptors include protocol version, publisher identity, source UUID/kind, monotonic revision, package length, SHA-256, schema versions, and a signature. Each device writes **only its own namespace**; no shared mutable group JSON, and two devices never write the same file. No plaintext credentials or full personal export may enter the sync folder.

Capture a consistent scoped `.bsexport` from existing repositories. Persist a dirty signal after completed relevant Bookmark/Following mutations; coalesce bursts with a short debounce. Calculate a deterministic **semantic hash** excluding package timestamps, local Hive keys, Group names, purely local folder placement, read/cached state and other nondeterministic fields. If content is unchanged, skip payload publication; a source-name-only edit updates discovery metadata, not Group content/unread. Perform a full selected-collection reconciliation at startup/resume in case a process died before recording dirty state.

Write a complete immutable payload to temporary storage on the **same destination**, flush, then publish final bytes; publish the signed revision descriptor **last** as a commit marker, and finally the new immutable discovery catalog revision. Ignore temporary paths. Readers check trust, schema, complete byte length/hash, and source identity before applying. On SAF document providers, atomic rename is not guaranteed: unique immutable names plus descriptor-last verification must still be safe. Desktop may use a mounted SMB path, but Boorusama does not implement a native SMB client. Android needs a persisted SAF tree permission/storage adapter rather than turning `content://` into a filesystem path. Avoid excessive directory scans and unbounded archives; keep the latest complete revision plus sufficient historical retention for offline receivers. Delta/event streams are a later optimization only if full changed-collection snapshots prove too expensive.

**Incoming scan:** at app start, resume, while active (watcher plus periodic reconciliation fallback), and via **Sync now**, inspect only subscribed, approved publishers and newer committed revisions. Use existing package validation, preflight, transaction journal/rollback, mutation serialization, stale-revision checks and provider reload. Apply a source revision and persist its last-applied marker **only after successful commit**; retry on errors without partial overwrites. A received import cannot trigger an outgoing publication echo. Keep identity mapping, trust, subscription rules, revision hashes and per-device seen state in app-local versioned metadata, not in the shared Hive boxes.

For Bookmark Group updates, mirror membership and typed references but **not local labels/placement**. Compare stable identities to find new/removed members. Removing a Group membership never removes a Post that still belongs to another Group; never manufacture unwanted Default membership. Following sync updates definitions/settings but does not import cache, NEW counts, checkpoints or remote post data. If some other mutation path has modified a mirror's membership, show **Conflict** and pause rather than overwriting unexpected local edits. V1 deliberately does not merge simultaneous author edits.

**Version compatibility:** independently check sync protocol, `.bsexport` container version, each source schema and entry types. App version is informative, not the compatibility gate. An older reader can accept newer exports only if all contained source schemas and entry kinds are supported. On unsupported/newer protocol or Bookmark/Following schema, mark only the affected subscription **Update required**, retain last valid content and last-applied revision, and retry after an app update. Never silently drop unknown future types such as newer Pool/Work entries. Distinguish offline, missing source, missing profile for Following, permission revoked, invalid payload, untrusted device and incompatible version. Missing data never means delete.

**Security:** the folder is untrusted input. Pin publisher public keys at approval and verify signed catalogs/descriptors plus payload hashes; reject replayed/suspicious revisions and path traversal, excessive ZIP entries, invalid snapshots and unsafe URLs. Never forward credentials from one host to another or probe arbitrary untrusted endpoints as part of file discovery. Reuse existing trusted import limits and isolate errors by source.

## 6. UI implementation contract

The existing app chrome is mandatory: **mobile Browse / Following / Bookmarks / Menu** (`lib/core/navigation/app_navigation_shell.dart`) and the existing **desktop sidebar**. **Do not create a second bottom navigation bar, new top-level Sync destination, or permanent Sync toolbar.** A temporary selection-action bar is fine when the current selection mode already uses one. Use KurumiAppBar, Kurumi menu conventions, current card spacing, existing navigation/back semantics and `context.t` localization.

### 6.1 Settings and management

Place a **Folder Sync** entry at **Settings → Export & Import**, alongside current Export/Import controls; the current Settings/menu structure is retained. Selecting it pushes a standard settings page (not a new shell). The page contains:

1. One **Shared folder** row with readable, truncated path/document-tree label and **Choose/Change**; show permission errors. Unconfigured state asks for a folder. Sync is disabled until access is valid.
2. Compact **Last sync / status** line with **Sync now**. Show Ready, scanning, offline, blocked, incompatible and failed states without excessive permanent banners.
3. Standard **Publish** and **Receive** navigation rows with relevant counts.
4. A **Sync activity** entry and optional local notification preference.

**Publish page:** reuse current recursive selection-tree presentation for Bookmark Groups/folders and Following Topics/folders. Two compact category sections. Each row has the existing folder/group/Topic icon, label, direct-selection control, and inline state (`Direct`, `Via folder`, `Direct + via folder`, `Excluded`) as needed **within that row**, never an extra badge row on the ordinary card. Expand folders to select/exclude descendants. In folder details: future children switch **off** by default and nested exceptions. A repeated direct+inherited selection yields one published collection.

**Receive page:** list discoverable publishers as device cards/list rows, expand their published tree and preview the source label/type/revision. Trust prompt precedes automatic import. Tap **Subscribe** to set local name and destination; folder subscriptions additionally offer Copy structure once and Include new children. Subscribed entries show local target and **Manage/Unsubscribe**, not a duplicate copy or second Subscribe action. Disabled/unavailable publisher, empty folder, unsupported schema and missing permissions require distinct compact states. No implicit subscription merely because a file exists.

Collection context-menu actions work even before folder setup: route to Choose folder and return to the intended Publish/Receive action. Multi-selection may provide Publish for selected writable items using the existing selection toolbar.

### 6.2 Bookmark Groups: exact placement

Compare with `lib/core/bookmarks/src/pages/bookmark_group_browser_page.dart` (existing square `_GroupCard`: 2-column mobile grid, thumbnail mosaic, title top-left, overflow top-right, folder glyph bottom-left) and `lib/core/bookmarks/src/widgets/bookmark_appbar.dart` / bookmark list controls.

- On a **received Group card**, show a small **white sync+lock** icon **at bottom-left**, in the indicator corner, with screen-reader meaning "Synced; content read-only". Do not add text or height. An **own published Group card** uses a subdued **upload** glyph in the same corner; no `Published` or `Mirrored` row, label or pill.
- On a **Bookmark folder card**, preserve its existing white bottom-left **folder icon**. When it has publication/subscription status, overlay a miniature upload/sync marker on that glyph rather than create another row. Keep title, preview and menu positions unchanged.
- A **received Group** with unseen incoming additions shows a compact bottom-right numeric badge such as **`+4`**. **No `NEW` text inside this badge**, no update banner or separate Mark as Seen control. If there were only unseen removals/other membership changes, a tiny dot can be used instead. Never overlap selection checkmark or card overflow on narrow screens.
- A **local parent folder** may aggregate its descendants' unseen additions (deduplicated by portable member identity). Opening a folder **does not** clear child Group unread counts.
- **Opening a Group** (card, deep link or Sync activity), after its content is displayed, automatically marks **all** received changes for that Group seen and clears its `+N`/dot. No per-post seen model. Other Groups retain their counts. If the Group is visibly open when a new revision arrives, acknowledge once that revision is actually rendered. Persist seen state across restarts separately from last-applied revision.
- **Group and folder overflow:** writable item: one **Publish** action; if already published, **Manage publication** (scope/direct vs inherited, Stop publishing if direct). Received item: **Manage subscription**, **Unsubscribe**, **Detach/Create editable copy**; retain **Rename locally** and **Move**. Do not expose membership-edit actions for mirrors. Keep menu rows consistent with the surrounding Kurumi style.
- **Opened Group page:** retain existing AppBar and listing controls; place a tiny upload/sync-lock glyph adjacent to the title where appropriate and a normal More action for publication/subscription. **No extra horizontal row** announcing content changes. For unavailable imported Bookmarks, reuse #143's compact blacklisted-post-style count indicator and detailed popup; no duplicate widget.

### 6.3 Following Topics / feed: exact placement

Compare with `lib/core/search/following_topics/src/pages/following_topics_page.dart`, `src/widgets/following_topic_folder_card.dart` and `src/widgets/following_topic_card.dart`: existing title row with folder glyph, feed RSS action, **post NEW**, previews, and metadata/last post. Retain these proportions.

- Small **published upload** or **received sync-lock** icon appears **inline beside existing title/folder glyph**, not in a new status row, not as a large text badge, and not below previews.
- The current Following **NEW** badge and feed post-unread behavior remain **exclusively** for new remote Posts. **Definition changes received from a device** use a visually distinct **small outlined sync icon with a dot** immediately beside the affected Topic/Folder title (or same header slot on Feed view). This must not resemble a post NEW badge or consume a separate row.
- Tapping that sync-change glyph shows a compact description of the definition change and acknowledges **definition changes only**. It must not mark feed posts seen. Do not add change-announcement rows inside Following or an open Feed.
- The **Feed view overflow** exposes **Publish / Manage publication** for its owning Topic folder/Feed. It must refer to the same publication as the Folder card's menu. Respect existing feedEnabled behavior and legacy imports.
- Received Following queries/feed definitions are read-only, but local display name/placement, cache, refresh state and ordinary post unread remain local. A Folder may show both an existing post NEW badge and the separate outlined sync-change glyph simultaneously.

### 6.4 Navigation, activity, responsiveness

- Optionally put a **tiny navigation dot** on Bookmarks when some received Group has unread additions; **do not change** the current four destinations. Following's current nav NEW/dot continues to represent **post updates**, not sync definitions.
- Sync activity shows per-device, per-collection applied additions/removals and definition changes. Opening an affected Bookmark Group from this list clears its seen count through the same Group-open action; opening a definition-change detail acknowledges its separate dot.
- Local device notifications can summarize received updates when permitted; they are not a mandatory instant push mechanism.
- Ensure small widths (320/390 dp), large text, keyboard, pointer/hover, desktop sidebar, selection mode, accessible 48-dp targets and tooltips/semantics. No icons or meaning may depend solely on color; do not mix Material/Kurumi popup row styles.

## 7. Unread calculations and acceptance scenarios

**Bookmark unread** = newly added stable member identities received since the last successful opening of *that specific* mirror. Accumulate across multiple imported revisions, subtract additions that have since been removed, and don't increment on renamed source labels, snapshot metadata refreshes, cache updates or exports. For unchanged membership but unseen removals, show the small dot until Group open. Unread is not equivalent to the applied-revision marker. Folder aggregates must use unique member identities and not accidentally mark children read. Do not use the literal string `NEW` in a synced Bookmark numeric badge. **Following unread Posts and sync-definition acknowledgements are separate state machines.**

Representative required checks for a later implementation:

1. Group A is subscribed on device B under a different **local name and folder**; later source renames/moves do not overwrite either. All new/removed Posts reconcile correctly, including Pool/Series references.
2. Direct publication + parent publication + nested exclusion produces one source file/history; disabling only one route preserves the other; newly created children are not exposed unless explicitly allowed.
3. A Group directly subscribed and again through a folder remains one local collection; moving it to any other local folder and locally renaming it never break subscription.
4. Devices A/B publish **different** collections in opposite directions; offline/resume/repeated import works without duplicate collections or import/export feedback loops.
5. Mirrored membership cannot be edited through viewer, context, selection, Favorites Sync, All-bookmarks deletion or import; rename, move, view and detach work. Unrelated Group memberships remain intact.
6. Multiple arrivals produce a **numeric-only** `+N` badge; opening only the affected Group clears only its unread, not other Groups. A folder aggregate and non-additive dot behave correctly.
7. Existing Following post NEW is unchanged; a definition-sync dot can coexist on the same folder and is acknowledged without consuming post unread.
8. Missing Bookmark profiles reuse #142/#143 and don't lose saved data. Missing Following profile pauses only its own unsupported subscription.
9. An older app rejects a newer schema or unknown typed entry **without losing existing content**, records Update required and retries after upgrading; unaffected subscriptions still apply.
10. Untrusted publisher, missing file, half-written file, hash/signature mismatch, duplicate/replay, rollback failure, withdrawn publication, lost SAF access and disconnected SMB share never silently modify/delete local data.
11. Android SAF permissions and provider behavior tested on a device; desktop filesystem; widget tests at compact widths and enlarged text, both navigation shells and normal Group/Feed menu entry points.

## 8. Implementation touchpoints and verification

Build on existing infrastructure, not a second state-management stack:

- `lib/core/backups/export_import/export/export_service.dart`, `models/export_selection.dart`, `package/export_package_writer.dart`: selective consistent snapshots.
- `lib/core/backups/export_import/import/import_flow_notifier.dart`, `import_coordinator.dart`, `import_transaction.dart`, `import_preflight.dart`: a reusable *headless, approved-subscription* transactional apply API; avoid widget-bound manual import steps during automatic sync.
- `lib/core/bookmarks/src/providers/bookmark_provider.dart`, Bookmark Group repositories, portable Post/Pool snapshots and shared mutation coordination: detect committed mutations, enforce mirror read-only, update after import.
- `lib/core/search/following_topics/src/providers/following_topics_notifier.dart` and existing Topic folder/feed organization: definitions only, no independent duplicate feed store.
- `lib/foundation/filesystem.dart`: desktop directory operations and suitable Android SAF document-tree adapter with persisted permissions.
- `lib/core/navigation/app_navigation_shell.dart`, existing Group and Following card widgets: reuse current navigation, Kurumi styling and responsive layouts.

The implementation agent must reread `AGENTS.md`, `docs/issue_workflow.md`, the design skill and current code before implementation, use `fvm`, manual Riverpod providers and `context.t`, preserve all existing profile/site security boundaries, and run scope-appropriate tests. This document is the feature contract; any material design changes require reconciliation with #144 rather than silently replacing agreed behavior.