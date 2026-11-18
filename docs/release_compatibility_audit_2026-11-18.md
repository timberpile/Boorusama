# Released data contracts — source audit, 2026-11-18

**Status:** source audit and preparation; not a runtime migration qualification.
**Public baseline:** [v4.6.1-timberpile.3](https://github.com/timberpile/Boorusama/releases/tag/v4.6.1-timberpile.3), published 2026-10-28, release target `422aeae087c1108e655d85d1a3dac25120456cd6`.
**Candidate inspected:** `a9ce9de09e4a9d8c994c24804d7c65ef8cefe270` (develop when this work started).
**Work branch:** `maintenance/release-compatibility-policy`; no develop integration.

The previous discussion used develop `4542aaa`; it is not this audit's current
candidate. The GitHub release listing still identifies `.3` as the latest public
release. No installed-population or external-distribution inventory was supplied.
Download counters do not establish unique users, installed versions or data age.

## 1. Published Bookmark formats, checked against actual tagged writers

| Release tags | Bookmark writer version | Evidence |
| --- | --- | --- |
| `v4.5.0-timberpile.3`, `.4` | 4 | [`bookmarks_source.dart` at `.3`](https://github.com/timberpile/Boorusama/blob/v4.5.0-timberpile.3/lib/core/backups/sources/bookmarks_source.dart), [at `.4`](https://github.com/timberpile/Boorusama/blob/v4.5.0-timberpile.4/lib/core/backups/sources/bookmarks_source.dart); same source blob `7c89a5166cd0891be061050fe7f9a1eafdd00e82` |
| `v4.5.0-timberpile.5`, `v4.6.1-timberpile.1`, `.2`, `.3` | 5 | [writer at `.5`](https://github.com/timberpile/Boorusama/blob/v4.5.0-timberpile.5/lib/core/backups/sources/bookmarks_source.dart), [at `.1`](https://github.com/timberpile/Boorusama/blob/v4.6.1-timberpile.1/lib/core/backups/sources/bookmarks_source.dart), [at `.2`](https://github.com/timberpile/Boorusama/blob/v4.6.1-timberpile.2/lib/core/backups/sources/bookmarks_source.dart), [at public baseline](https://github.com/timberpile/Boorusama/blob/422aeae087c1108e655d85d1a3dac25120456cd6/lib/core/backups/sources/bookmarks_source.dart); blob `c50af89f1330518e2c86839fb8c05d84c22a30c4` |
| Candidate develop | 10 | [current writer](https://github.com/timberpile/Boorusama/blob/a9ce9de09e4a9d8c994c24804d7c65ef8cefe270/lib/core/backups/sources/bookmarks_source.dart) |

The baseline Bookmark decoder accepts 4 and 5; current code additionally accepts
6–10 and a transitional v10 folder representation. Those extra development
shapes are not public support obligations based on the checked releases. Do not
confuse a reader accepting an old number with proof that a public writer emitted
it. Earlier than `v4.5.0-timberpile.3`, the fork published an explicit data-format
break; this preparation does not revive formats already unsupported by `.3`.

## 2. Persistent-domain inventory and disposition

Paths in this table are relative to the repository; compare the baseline and
candidate SHAs above. The complete registered export-source inventory is in
`lib/core/backups/sources/providers.dart`. Equal wrapper schema numbers do not
by themselves prove semantic compatibility of their model decoders.

| Domain | Released contract/evidence | Candidate / preservation decision |
| --- | --- | --- |
| Post Bookmarks and local Groups/folders | Baseline `bookmarks_source.dart` writes v5; `bookmark_backup_codec.dart` reads v4/v5. `bookmark_group_repository_hive.dart` has organization version 1, `folderId` and existing Group UUIDs. | Unified records and parent-Group hierarchy are new; preserve released Post IDs/snapshots, Group IDs, folder structure and existing membership. New dates unavailable in old data need deterministic documented fallback, not invented historical precision. |
| Saved Pool/Series, Related, native Content Groups | Their new unified models and `pool_bookmark.dart` were absent from the released baseline. | Development-only `LegacyGroupBookmark`/Collection forms and #155's intermediate storage are cleanup candidates, not permanent public guarantees. They currently participate in migration code: not removed in this preparation. |
| Profiles | Released `booru_configs_source.dart`: source `profiles`, schema 1. `configs/config/src/data/bootstrap.dart` opens `booru_configs` as Hive JSON strings. | Candidate wrapper still schema 1. Preserve UUIDs, source URLs, saved order, credentials and optional settings under production decoders. No profile replacement/reset based on old field names. Tests must distinguish empty/new storage from unreadable existing rows. |
| Settings | Released `settings_source.dart`: schema 1, `Settings.fromJson/toJson`. | Preserve explicitly saved choices; new fields/defaults need separate cases. App version alone must not decide whether settings are obsolete. Include current-profile/order and refresh-disabled choices. |
| Following Topics | Released source `pinned_searches`, schema 2; candidate still schema 2. Hive names retained in `topic_storage_contract.dart`. | Preserve IDs, profile bindings, queries, placement/order and runtime state. `pinned_search_*` naming is shipped compatibility, not disposable terminology. New local sources/mirror fields need missing-field/default tests. |
| Topic Feeds | Released source `following_feeds`, schema 1 (`topic_feeds_source.dart`). | Source remains conditionally exported for non-folder-derived feeds. Existing user-created feeds must not disappear when new folder-derived feeds are available. Verify source membership/placements and runtime independence. |
| Favorite tags | Released `favorite_tags_source.dart`, schema 1; exporter reads the persistent repository. | Preserve tag records and cold-export coverage; do not rely on an initialized editor provider. |
| Blacklisted tags | Released `blacklisted_tags_source.dart`, schema 1. | Preserve expressions and explicit restrictions; migration must not silently widen visibility. |
| Bulk downloads | Released and candidate `bulk_downloads/src/data/repo_sqlite.dart` are blob-identical (`30e11645b360c5b2b96c12a33c076f6190fb5932`), target SQLite version 2. | Real shipped migrations 1/2 remain necessary. Preserve tasks/sessions/records, sidecars and relationships; do not touch downloaded media in fixture runs. |
| Search history | Released SQLite backup source `search_histories`; candidate repository target version 0. | Exercise the real database initializer and preserve queries/types/sites/dates/counts. No assumption that a zero version means no user data. |
| `.bsexport` envelope / auto backup | Baseline `package_manifest.dart`: `boorusama-export`, container format 1 with independently versioned sources and part hashes. | Source schema and envelope version are separate. Test a genuine released multi-source package, not just individual current source JSON. Android SAF permission state is not a portable backup and needs native acceptance. |
| MiteMite | No MiteMite directory/feature in public baseline. | Pre-release protocol and private-storage generations may change without public backward-compatibility chains. Keep live signature, ownership, monotonic revision and crash-safety invariants. No destructive reset of the owner's QA data. |
| Device-local security/state | App lock, secure credentials, URI grants, cookie/session state and platform-managed data are outside complete `.bsexport` coverage. | Test their preservation in an isolated native install where affected. Never export actual private keys/PINs/cookies into tracked fixtures; an exported backup alone cannot prove this domain. |
| Rebuildable caches / temporary files | Image cache, temporary share files and derived indexes are not the same as authoritative user data. | Cache invalidation may be appropriate, but prove the state is reconstructible. Do not classify Following read/unread state or sync trust as cache merely because of a storage location. |

Additional primary references:
[released source registry](https://github.com/timberpile/Boorusama/blob/422aeae087c1108e655d85d1a3dac25120456cd6/lib/core/backups/sources/providers.dart),
[current source registry](https://github.com/timberpile/Boorusama/blob/a9ce9de09e4a9d8c994c24804d7c65ef8cefe270/lib/core/backups/sources/providers.dart),
[current bootstrap](https://github.com/timberpile/Boorusama/blob/a9ce9de09e4a9d8c994c24804d7c65ef8cefe270/lib/core/bootstrap/production_boorusama_bootstrap.dart),
[stable Following contracts](https://github.com/timberpile/Boorusama/blob/a9ce9de09e4a9d8c994c24804d7c65ef8cefe270/lib/core/search/following_topics/src/compatibility/topic_storage_contract.dart).

## 3. Concrete problems and preparation changes

### A. Development history is being treated as public compatibility history

Current `docs/bookmark_groups.md` promises v4–v9 and transitional #155-v10 readers,
and migration support for active unified-v2. Historical #155 handoffs describe
that intermediate state as a preservation target. Neither is evidence of a
published release. The new policy requires a released writer/tag before adding
permanent compatibility obligations. Historical handoffs are not rewritten as
if their old acceptance results applied to a new implementation.

### B. Removing v2 is not a one-line cleanup

`BookmarkStorageMigration.open()` calls `_openLegacy()` then `_upgradeHierarchy()`.
`_openLegacy()` can write and activate a `_unified_v2` generation before the v3
conversion. Thus even an upgrade from the released folder layout currently uses
this intermediate stage. A direct released-layout → final-hierarchy conversion
must preserve the journal, ID reservations and every durable-boundary recovery
case before the intermediate code is removed. No deletion is made here.

### C. The Android "upgrade" workflow proves installation, not data preservation

`github-release.yml` builds its lower-version APK from the checked-out **candidate**
with `--build-number final_code-1`. `verify-android-upgrade.sh` installs it, installs
the final APK with `-r`, and checks version metadata. It does not start old code,
seed representative old data or compare post-migration state. The smoke test is
useful for installer/signature/version behavior, but not the released-data gate.
This branch labels the output accordingly and documents the separate data gate.
No release workflow is dispatched or rewritten to publish anything.

### D. Existing tests are useful but not release-produced fixture evidence

`bookmark_storage_migration_test.dart` constructs old-looking Hive rows and Pool
fixtures; `bookmark_hierarchy_migration_test.dart` covers intermediate shapes.
Those tests protect algorithm behavior and fault recovery. Their names or a
passing full suite do not establish that the last release produced their input.
Add old-writer provenance and fixture tests; do not delete useful fault tests.

### E. Evidence limitations are explicit

No Flutter/FVM/Dart/Android SDK/device exists in the remote preparation runtime.
The GitHub connector supplied source; a direct clone failed because the runtime
could not resolve github.com. Therefore no actual release-produced fixture was
captured and no Hive/app/native migration was executed here. Python helper tests
use synthetic inputs and fake `adb`/`apkanalyzer`, not actual app data or Android.

## 4. Ordered cleanup after the missing evidence is supplied

1. Capture public v4 and v5 exports with their pinned released writers; capture
   the latest release's populated Hive/SQLite state and independent expectations.
2. Exercise production upgrade/import and cold restart, including fault cases.
3. Introduce a direct released-to-final Bookmark migration only if it reduces
   complexity; retain the staged activation and recovery guarantees.
4. Remove development-only v6–v9/transitional-v10 decoding and obsolete separate
   Pool storage only after proving no released path/needed owner fixture relies
   on them. Remove obsolete tests/docs with the code, not public v4/v5 coverage.
5. Keep MiteMite's first-public-protocol contract simple; establish peer-version
   support when it actually ships, not a speculative forever-compatibility layer.

Steps 1–2 and the final complete regression pass remain prerequisites for 3–4.
An arbitrary universal support window (for example "only N releases") and data
loss from public support retirement remain owner decisions; no such retirement
is silently adopted by this branch.
