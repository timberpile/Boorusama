# Release and data compatibility

This policy distinguishes **released user data**, **portable files**, and
**cross-version protocols**. It does not authorize a release, deleting data,
merging a branch, or retiring a supported public format. See
[the initial source audit](release_compatibility_audit_2026-11-18.md) and
[released-upgrade verification](testing/released_upgrade_verification.md).

## Establish the real baseline before designing a migration

Use the actual published release and its resolved Git tag/commit. Inspect that
commit's writer and reader, not just a current schema constant, commit title,
closed issue, merge into develop, handoff, APK filename, or pubspec version.
A develop build may still carry the previous release's version number.

For each changed persistent contract, record in the normal task report:

- What data/format is affected, and which released writer first/last produced it.
- Its source path and release tag/resolved commit, and the candidate commit.
- Whether the proposed change affects local storage, import/export, or a protocol.
- The required preservation behavior and tests, or evidence that it never shipped.

A distributed prerelease or owner test build may contain real data, but does not
automatically create a permanent public compatibility guarantee. Identify the
actual distribution and intended preservation scope. Do not infer an installed
user count from release downloads, stars, analytics availability or the absence
of bug reports. When release evidence is uncertain, do not delete data or declare
compatibility unnecessary; resolve the uncertainty in the task report.

## Three independent contracts

| Contract | Default obligation | What does not prove it |
| --- | --- | --- |
| In-place app upgrade | Preserve data produced by supported released installations, including a skipped-version upgrade where supported | Installing a new APK, or rebuilding the candidate with a lower versionCode |
| Import/export | Continue reading supported published file formats; never silently drop records or manufacture identities | Opening current-format exports with current code |
| Sync/protocol | Once shipped, explicitly validate supported peer/schema versions and preserve trust/replay boundaries | Matching app version strings or accepting unknown payloads |

The current mandatory regression baseline is the last public release. This is a
**minimum test requirement, not permission to drop older installed data**. Keep
already supported public readers until an explicit retirement decision. Test
representative earlier released storage generations when the candidate affects
their upgrade path; do not require users to install every intermediate release
unless that limitation has been explicitly approved and documented.

For the November 2026 preparation, the verified baseline is
`v4.6.1-timberpile.3` at `422aeae087c1108e655d85d1a3dac25120456cd6`.
Published Bookmark export v4/v5 readers remain protected. Refresh this evidence
before the next release; this paragraph is not a substitute for live release
verification. No general historical support sunset is established here.

## Unreleased features and intermediate schemas

MiteMite, native saved Pool/Related/Work records and the current unified Bookmark
storage were absent from that public baseline. Their development-only formats
may be changed directly before their first release. Do not build production
migration chains, duplicate old/new models, forced re-publications or perpetual
compatibility adapters merely for an earlier commit on a task/develop branch.

However, **unreleased does not mean safe to delete blindly**:

- An intermediate representation may still be used by the actual released-to-new
  migration. Replace that path and prove preservation before removing the stage.
- Retained QA/owner data must not be silently wiped. A scoped backup/conversion or
  explicitly authorized reset is separate from permanent production support.
- Crash journals, reservation high-water marks, transaction recovery and source
  authorization protect current data too. They are not disposable legacy code.
- A published wire name can look obsolete: `pinned_searches`, `following_feeds`
  and existing Hive keys are independent of current UI terminology.

For MiteMite before its first public release, stripping publisher-local profile
hints need not force a semantic revision or add an old-protocol migration. This
does not permit changing signed stored bytes in place or bypassing replay checks.
The #166 read/cover task remains separate from this policy work.

## Versioning and retirement

Local storage generations, per-source backup schemas, the export container and
sync protocols have separate version meanings. A public incompatible format
change needs an explicit version/feature discriminator and a tested upgrade or
clear unsupported-version response. Never reuse a published version number for
an incompatible shape. Optional additive fields need no gratuitous version bump
when old readers/writers demonstrably handle them correctly.

Before first publication, simplify unstable formats without treating every
internal version as a supported user contract. Still reject unrecognized or
ambiguous stored shapes safely; never reinterpret them as empty collections.

Retiring public support requires an explicit owner decision naming the affected
release/data generation, backup/recovery route and user-visible consequence.
Release notes document that decision; they do not authorize it retroactively.
This preparation neither resets user data nor removes any public decoder.

## Required release evidence

For changes affecting persistence/import or startup compatibility:

1. Use synthetic data **written by the pinned released code** as immutable raw
   fixtures. Record tag, resolved commit and generation command next to them.
   A hand-authored JSON object resembling an old payload is only a unit fixture.
2. Run production migration/import paths against those fixtures. Check records,
   IDs, source identities, membership, ordering, timestamps, settings and profile
   relationships, then close and reopen the real repositories. Exercise fault
   boundaries for changed journaled migration paths.
3. Keep import tests separate: import released exports into a clean candidate,
   then test supported Merge/Copy/Replace and re-export semantics. File-local IDs
   need intentional remapping; in-place upgrades must preserve durable IDs.
4. For Android storage/bootstrap/plugin changes, additionally install the genuine
   previous release (matching application ID/signing/ABI), seed isolated data,
   upgrade with the candidate and compare first-start and cold-reopen behavior.
   Follow device authorization/lease rules. Missing device access is a disclosed
   pending gate, not a passing result.
5. Run the existing complete regression suite on the final integration candidate.
   The data gate does not replace it, and the suite does not replace upgrade
   provenance or native acceptance.

A candidate can be prepared with pending gates, but must not be described as
release-qualified while relevant upgrade checks are missing. Do not dispatch
release workflows or publish artifacts merely to obtain this evidence.

## Keep it small and maintainable

Use subsystem docs for enduring contracts, tests for executable behavior, and
the ordinary task/release report for exact commands/results and limitations.
Do not add a parallel issue queue, user-count guess, migration-result cache or
new metadata platform. The initial audit is a dated source inventory, not a live
tracker. Update the relevant policy/schema entry when a new format actually
ships; old development handoffs are historical evidence, not current authority.

## One final schema increment per public release

Owner decision, 2026-11-20: for each existing persisted/file/protocol contract,
all changes since the last public release share one final next version (or retain
the old version if compatible). Do not increment again for each issue or branch.
A new independent contract starts at 1. Keep the final shape, not a ladder of
unreleased formats. Do not reset any published schema number, field ID, revision,
sequence counter or build number to implement this rule.

A reused source-payload version is an alias, not an independent protocol counter:
MiteMite Following source schema 2 remains 2; its transport protocol is separately
1. Operations should have operation discriminators, not separate journal versions.
Preserve strict shape/authority checks when consolidating them.

Run `python3 scripts/audit_schema_versions.py --baseline <published-tag> --candidate
<committed-candidate> --inventory` before release qualification. The read-only
checker derives limits from Git blobs using `scripts/schema_contracts.json`;
its baseline is pinned to reviewed release evidence. A new public release requires
reviewing the catalog's source locators and baseline, not raising ceilings to
silence failures. Review changed unregistered markers reported by `--inventory`.
The check is intentionally a source-level aid, not proof of semantic compatibility,
complete persistence inventory, old-writer fixture provenance or successful migration.

The [2026-11-20 audit](schema_version_audit_2026-11-20.md) and
[local implementation handoff](handoffs/schema-version-consolidation.md) identify
current violations and cleanup order. Until production upgrade/import/reopen
and crash-recovery tests prove the direct path, prepare the cleanup but do not
silently delete data or claim that numeric renumbering fixed the migration.
