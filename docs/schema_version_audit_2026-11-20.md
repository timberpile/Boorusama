# Schema progression audit — 2026-11-20

This is a **source audit**, not proof of successful data migration.
Published baseline: [v4.6.1-timberpile.3](https://github.com/timberpile/Boorusama/releases/tag/v4.6.1-timberpile.3), resolved/recorded release commit `422aeae087c1108e655d85d1a3dac25120456cd6`.
Current develop inspected: [`d9203ae62dcbc5ff81e0bd70702607fb24070787`](https://github.com/timberpile/Boorusama/tree/d9203ae62dcbc5ff81e0bd70702607fb24070787).
Work continues on `maintenance/release-compatibility-policy`; its earlier preparation is retained. No protected branch is updated.

## Owner decision

For a particular persisted/file/protocol contract, the next public release may
keep the published version or advance it **once**, not once per development task.
A genuinely new independent contract starts at 1. Keep the final unreleased shape
under that next version and remove development-only intermediate readers/writers
when the real released upgrade path is proven. Do not rewrite Git history.
Published formats and fields are not renumbered or silently retired.

Version namespaces must be distinguished. A MiteMite package using the existing
Following export schema 2 is not a new protocol v2. Hive field numbers, record
revisions, sync sequence counters, build numbers and third-party API versions
are not schema bumps and must not be reset to satisfy this rule.

## Findings and concrete targets

| Contract | Last release | Inspected develop | Required final target / disposition |
| --- | --- | --- | --- |
| Bookmark export | 5; reader supports 4/5 | Writer 10; reader 4–10 and transitional v10 | Final nested-Group export **6**; retain published 4/5 readers, remove unreleased 6–9 and transitional-v10 interpretations. Old development v6 must not be mistaken for final v6: require the final shape discriminator. |
| Bookmark local organization | 1, folders plus local Groups | Conversion creates unified-v2, then hierarchy-v3 | One direct released layout → final **organization 2** conversion; one durable activation, crash recovery and folder/Group ID mapping retained. |
| New unified Bookmark repository metadata | Absent | Initializes `repositorySchema` 1; mirror operations promote it to 2 | One initial **schema 1** that includes the final mirror-ownership contract. Preserve the missing-ownership corruption check; do not make every missing state an empty mirror set. |
| New unified mutation journal | Absent | Writer chooses 1/2/3/4 depending on operation; reader recognizes all four | One **journal schema 1**, with an explicit operation discriminator if needed. Preserve ordinary/organization/restore/mirror validation and authority; format versions must not stand in for operation kinds. |
| MiteMite Bookmark package | Absent | Reuses Bookmark source schema 10 | Track final Bookmark source schema **6**, not an independently invented protocol version. |
| MiteMite Following package | Absent | Reuses published Following source schema 2 | Keep **2** as the source-payload alias. Not a violation. |
| MiteMite protocol/root | Absent | Protocol 1, root `v1` | Keep **1**. No pre-release protocol migration layer. |
| Stored native Group snapshot / Bookmark mirror state | Absent | 1 / 1 | Keep **1**. |
| Profiles / Settings / favorite tags / blacklist export | 1 / 1 / 1 / 1 | Unchanged | No bump needed merely for an additive compatible field. Semantic preservation still needs tests. |
| Following / feed export | 2 / 1 | Unchanged | Preserve actual published wire names and supported readers. |
| `.bsexport` container / `.bslink` document | 1 / 1 | Unchanged | Source schema numbers remain independent from container/document versions. |
| Downloads / search-history SQLite target | 2 / 0 | Unchanged | Retain real published SQL migration history. Zero is a real baseline, not proof of no data. |
| Shared Post snapshot common schema | 2 | 2 | Keep **2**; engine payload codec versions are separate. |

Primary code locations at the inspected develop commit:
- `lib/core/backups/sources/bookmarks_source.dart`, `bookmark_backup_codec.dart`.
- `lib/core/bookmarks/src/services/bookmark_storage_migration.dart`, especially `open`, `_openLegacy`, `_upgradeHierarchy`.
- `lib/core/bookmarks/src/data/hive/unified_bookmark_repository.dart`: `_initialize`, `_mutate` journal construction, `_recover`, `_apply`, `_mirrors`.
- `lib/core/backups/mitemite/{limits,bookmark_package,following_package}.dart`.
- `lib/core/posts/post/src/data/stored_post_codec.dart`.

The four root problems above create six failing registered checks: Bookmark
writer, its reader and MiteMite alias, organization, repository metadata, journal.
This is not six independent public format changes.

**Additional classification work:** the new `ListedPostData` branch in
`stored_post_codec.dart` emits `codecVersion: 3` together with `snapshotKind:
listed`. This is not the shared common schema (which remains 2). Inspect the
engine-codec/discriminator namespace and released producers before deciding
whether 3 is an operation/kind discriminator or a schema progression to collapse.
Do not blindly replace every literal 3 or every field named version. The source
inventory also covers changed engine/native codec markers for this review.

## Implemented guard

`scripts/audit_schema_versions.py` reads committed Git blobs, never the dirty
worktree or an app database. `scripts/schema_contracts.json` contains **21 reviewed
source locators**, their published baseline and explicit source-schema aliases.
It computes version ceilings from the baseline; it has no grandfathered ceiling
of 10 and no automatic waiver for known violations. It preserves released reader
versions, rejects multiple current writer versions, and handles the journal's
literal ternary without pretending its maximum is its only version.

```bash
python3 scripts/audit_schema_versions.py \
  --baseline v4.6.1-timberpile.3 --candidate origin/develop --inventory
# Machine-readable report (nonzero exit remains intentional while violations exist):
python3 scripts/audit_schema_versions.py \
  --baseline v4.6.1-timberpile.3 --candidate HEAD --inventory --json
```

Exit 0: registered numeric checks pass. Exit 1: policy violations. Exit 2:
missing/ambiguous source evidence, a stale catalog baseline or a Git/input error.
A missing marker is not silently treated as a new contract. After a new public
release, review/update baseline-specific locators as well as the baseline commit.

`--inventory` reports changed version/schema/protocol-bearing app-owned source
lines, including paths not represented in the catalog. Review these manually;
this lexical aid is not a complete Dart parser or a proof that implicit/unversioned
formats are compatible. A numeric pass does not prove migration, shape validation,
engine codec compatibility or coverage of every third-party persisted store.

The release-validation workflow now obtains the actual latest public tag using
a read-only GitHub call, resolves it from a full checkout and runs the audit
before Flutter setup. A changed release baseline blocks until its provenance is
reviewed. **Current violations are not waived: release validation is expected to
block until the local consolidation is completed.** No workflow was dispatched.

## Verification and limits

The new helper/workflow source tests run against synthetic isolated Git histories
and fake source snippets, not real application data. They exercise +0/+1, excessive
jumps, regressions, new contracts, operation-version sets, aliases, reader support,
missing locators/refs, duplicate keys, invalid encodings, symlinks, dirty-worktree
isolation and the read-only published-release workflow contract.

GitHub source inspection supplied the actual findings. A full repository clone,
FVM/Flutter/Dart and Android tools were not available here; therefore the audit CLI
has not been executed against a complete production Git checkout, and no actual
released-data fixture, app migration, native build or full app regression is
claimed. Run the command on the complete checkout before accepting the inventory.
Runtime schemas have **not** been renumbered in this preparation. Their coordinated
reader/writer/journal changes require the production tests in the [handoff](handoffs/schema-version-consolidation.md).
