# MiteMite (#144)

MiteMite is Boorusama's optional, **one-way publication/subscription** feature for
Bookmark Groups and Following Topics/folders/Feeds. Each device can publish its own
collections and receive another device's collections through a user-selected shared
directory. Received definitions are source-owned and read-only; this is **not**
bidirectional editing. MiteMite naming applies to source paths, feature-specific
symbols, localization, native channels and persisted identifiers. This feature
has not shipped; the owner approved renaming all identifiers without a naming
migration, compatibility aliases or fallback to the previous development state.

**Status:** Integrated into `develop` after owner approval for #144. See the
[canonical v5 specification](../../../../docs/designs/2026-11-03-folder-based-collection-sync.md),
[final owner UX contract](../../../../docs/handoffs/144-final-owner-ux-implementation-2026-11-14.md),
[current notification contract](../../../../docs/handoffs/144-mitemite-notification-routing-2026-11-16.md),
[current owner presentation corrections](../../../../docs/handoffs/144-open-items-2026-11-16.md),
and [verification handoff](../../../../docs/handoffs/144-interrupted-web-remediation-2026-11-14.md).
Those documents supersede historical implementation notes. This README describes
the current integration, not an independent test or release approval.

## Application and management flow

- **Settings → Export & Import → MiteMite** opens the existing Kurumi-based
  management UI. Opening the page alone does not activate transport. Selecting a
  **Storage Location** enables startup/resume and foreground reconciliation,
  one-minute polling, and coalescing of local changes. A filesystem watcher is used
  where supported; Android SAF relies on polling. A terminated app does not
  perform ongoing discovery or send instant remote-change notifications.
- Android uses a persisted SAF document-tree grant; desktop uses an accessible
  local or mounted directory. Syncthing or SMB may propagate files externally;
  Boorusama does **not** implement either transport. Changing Storage Location
  preserves signing identity, trust, subscription/mirror IDs, read state and
  anti-rollback checkpoints. The display-only path uses Auto Backup's directory
  label helper; an opaque `content://` URI is never shown as a fallback or
  substituted for the stored access URI.
- **Published** lists directly published roots only. The contextual **Publish to
  MiteMite** action targets the chosen local Group; **Stop Publishing** is an
  overflow action with confirmation. Bookmark Group and published Following
  folder/Feed scopes include current and future descendants. Additional direct
  child publications can overlap parent scopes without duplicating canonical
  content or losing separately retained coverage.
- **Subscriptions** lists the publisher's explicitly offered roots after trust,
  not all inherited descendants. Before trust only device identity, labeled
  **ID**/**Key Fingerprint**, and **Trust Device** are available. Each subscribed
  root is a virtual link to one canonical mirror; independent direct child roots
  remain accessible when a parent subscription is removed. **Unsubscribe** and
  **Forget Device** require appropriate confirmation and preserve unrelated
  memberships and independently created local copies.
- **Devices**, **Activity**, **Update Now**, the local device name and
  **Device Details** use the same live service state. The UI tracks reconciliation
  separately from pending actions so navigation, alias editing and local
  preferences remain responsive during slow transport; conflicting writes still
  serialize safely. A compact **This Device** panel keeps ID and fingerprint
  copyable behind the details disclosure.
- Bookmark Home retains local Groups and All Bookmarks **without a `Local`
  heading**, then shows received roots in publisher-device sections. Each section
  has one MiteMite SVG, a device name, an expanding divider and a rightmost
  **Edit** pencil for the receiver-local alias. Received cards do not repeat
  redundant sync/lock icons. Published local Groups use the same approved SVG.

Received Bookmark and Following structures cannot be renamed, moved, reordered,
republished, mixed into Local, or edited by receiver actions. Local copies have
fresh writable identities and do not unsubscribe the original. Following Post
refresh, compatible local profile, cached results, NEW/read state and scheduling
remain receiver-controlled; only publisher-owned Following definitions synchronize.
Independent Following copies preserve a local-only, credential-free source
reference. A compatible chosen local profile or the current explicit anonymous
source policy must resolve every copied Topic before any subtree is committed.
Unsupported/private or ambiguous sources fail visibly without partial copies.
Public copies remain usable after unsubscribe/Forget and restart; policy, site/CDN
and blacklist checks still apply to every preview, refresh and opened source.
Portable exports use the existing source-reference schema and imports retain
explicit profile binding. Received folder sibling names use the original source
parent namespace, even when unreceived parents project their children at Home.
Only new writable copies receive case-insensitively allocated name suffixes.

All Bookmarks and ordinary Bookmark destination pickers remain local-membership-only.
The repository and mutation boundaries enforce these rules beyond the UI.

## Protocol, authority and storage

- `providers.dart` and `service.dart` connect the production unified Bookmark
  repository, Following mirror repository, shared mutation coordinator, post
  codecs, and reactive library reload. The publisher captures consistent local
  snapshots; a failed outgoing publication does not prevent independent
  incoming updates. Receive errors are isolated by domain/source where possible,
  and last valid content is retained on failure.
- `protocol.dart`, `catalog.dart`, `catalog_gate.dart`,
  `revision_transport.dart` and `publication.dart` implement signed Ed25519
  catalogs and descriptors, pinned publisher keys, monotonic sequence checks,
  separate OBSERVED/APPLIED checkpoints, immutable content and bounded
  validation. The producer writes complete package data before the descriptor
  and signed catalog; no incomplete or absent file authorizes deletion.
- `bookmark_package.dart` and `following_package.dart` build scoped,
  credential-free `.bsexport` content. `receive_preparation.dart` and the mirror
  engines validate hashes, schema versions, source identity, typed members,
  resource bounds and ownership before journaled application. One
  (publisher, kind, source) identity maps to one canonical receiver mirror.
- `bookmark_mirror_engine.dart` and `following_mirror_engine.dart` preserve
  source hierarchy, memberships/definitions, subscriptions and independent
  receiver-local state. Repository write guards protect mirrors against ordinary
  edits. Verified signed `withdrawn`/`deleted` records or confirmed local
  unsubscribe/forget may remove uncovered mirrors; offline, missing, invalid or
  untrusted files may **not**. Unrelated records and local memberships survive.
- `private_preferences.dart` keeps the complete `mitemite.v1.*` authority
  namespace (identity, trust/replay floors, reservations, settings, notification
  receipts and outbox) outside disposable cache. On Android it uses
  `noBackupFilesDir/mitemite_private/state_v1.hive`; desktop uses app data.
  Migration from the former cache namespace commits one durably synchronized
  snapshot before key/transport use. An incomplete existing private authority
  fails closed rather than silently recreating an identity. `durable_preferences.dart`
  maintains the required sync barriers.
- `android_storage.dart` and native `MiteMiteChannel.kt` use persisted SAF
  grants and bounded background worker I/O. SAF documents are immutable and
  verified after creation; atomic rename is not assumed. `storage.dart` handles
  mounted-directory access and safe paths. `retention.dart` performs bounded,
  owned-history maintenance without deleting another publisher's content.

## Bookmark reading and Timeline

- A received Group card displays **`N` = number of still-Unseen saved members**,
  deduplicated by portable identity across its received subtree. It shows no
  `+N` arrival badge or removal dot. **Opening a Group does not mark any member
  Seen or clear the count.** Historic arrival fields may remain in receiver-local
  storage for compatibility but do not drive the visible badge.
- Individual Group viewing and explicit Mark Read affect only that Group's
  receiver-local reading state. In a **combined/subtree** timeline a member is
  Unseen if **any** covered canonical Group considers it Unseen; actual full
  Viewer display or explicit Mark Read from that combined view marks it Seen
  in every corresponding covered Group in the same publisher subtree. Other
  publishers, source Groups outside the viewed subtree and local copies are
  unaffected. Captured ownership/source identities are revalidated before
  a delayed write.
- Reading a Post or media Work requires a settled, active, foreground Viewer
  occurrence and decoded still media or the current video's first rendered frame.
  Opening a saved Pool gallery marks that saved Group record Seen once its
  details are loaded and visible; it does not read its individual member Posts.
  Thumbnails, preload, failed media, covered routes and opening a Bookmark Group
  do not mark content Seen. Viewing a saved Work does not implicitly read its
  separately bookmarked Pages.
- Received member thumbnails use a **14dp borderless Unseen dot** at the
  **tile's top-right corner, 6dp inset**; it hides during selection to leave the existing Preview control
  usable. The **outlined Eye Read Status** selector shows All / Unseen / Seen
  only for mixed state or while a non-All filter is active. Counts remain
  independent of search, filtering and viewport.
- The Bookmark Timeline's **`...` / View Options** menu remains the ordinary
  Timeline toolbar menu, including for native-only mixed content. It is
  separate from the Group AppBar action menu: **Create Local Copy,
  Unsubscribe and other Group commands must never be added to Timeline
  options**. Standard Pixiv Work long-press selection saves selected Works,
  not arbitrary Pages. Following Post NEW and definition-change indicators
  are separate from Bookmark read state.

## Notifications, activity and verification

- One global **Notifications** preference governs five **Android OS** categories:

  | Category | Tap destination |
  | --- | --- |
  | New Posts in already subscribed Bookmark Groups | Bookmarks Home |
  | New direct Bookmark Group offers | MiteMite Subscriptions |
  | Newly introduced Topics in subscribed Following Folders | Following Home |
  | New direct Following collection offers | MiteMite Subscriptions |
  | Newly discovered devices | MiteMite Devices |

  New-Post notices aggregate across Groups/devices per incoming update/batch.
  Persistent receipts and a bounded local outbox suppress replay and deduplicate
  canonical Groups and portable Post identities. Initial subscriptions do not
  generate historical notification floods. Offers retain NEW until the displayed
  Subscriptions snapshot is acknowledged on leaving that page; later offers stay
  new. Native child/summary taps have compatible, validated destinations.
- Before trust, notifications reveal no collection labels or media data.
  Permission denial or unavailable delivery leaves in-app discovery and Activity
  accessible. Warm/cold taps wait for navigation readiness, without granting trust,
  subscribing or consuming Post/Topic read state. Discovery requires a running
  application scan; there is no terminated-app push service.
- `local_events.dart` maintains bounded, durable Activity and delivery
  receipts; failures remain visible with retry paths. Notification reporting
  does not replace authoritative, committed source/mirror state.

**Verification:** See the [remediation handoff](../../../../docs/handoffs/144-code-review-remediation-2026-11-17.md)
for the current candidate's reproduced findings, independent review and complete
host-suite evidence. The [implementation handoff](../../../../docs/handoffs/144-interrupted-web-remediation-2026-11-14.md)
retains dated historical results at their actual runtime commits. Its latest
pre-remediation qualification is `8b840e9706d6`: 7,574 application tests, 1,711
package/CLI tests, 52 JVM tests and a debug APK build. Those historical native/build
results do not qualify later runtime changes. Current Android instrumentation,
SAF, actual Syncthing/SMB deployment, two-device acceptance and physical-device
performance remain separate acceptance items. Owner approval authorizes publication and closure of #144; the integration
record is in the remediation handoff.
