# Verify upgrades from released data

This is the local execution contract for the
[release compatibility policy](../release_compatibility.md). It prepares an actual
upgrade qualification, not another installer smoke test. Raw fixtures/probes must
be created locally with Flutter/FVM and, when required, authorized Android access.
No real released fixtures or device pass are claimed by this preparation branch.

## 1. Pin the producer and the candidate

Resolve the live latest published release/tag, verify its commit and inspect its
schema writers. The audit baseline is `v4.6.1-timberpile.3` /
`422aeae087c1108e655d85d1a3dac25120456cd6`; recheck before execution. Record the
candidate commit and exact commands in the ordinary verification report. Keep
release artifacts and raw fixture inputs immutable; record their checksums with
the fixtures. A current build with a lower version number is **not** the producer.
Do not use the current encoder and merely replace its `version` field.

Use an isolated old-release worktree/build or the genuine signed released APK.
A fixture-only driver may call the old production repositories/exporter, but must
not change their serialization/migration behavior; retain the driver diff and
command. Generate only artificial test accounts/content. Disable network refresh
and background sync so the experiment cannot make server mutations or mix new
remote state into the observation. Never use the owner's actual app directory.

## 2. Seed and capture independently

Seed a small but nontrivial library through old production writers: two profiles
with differing settings/order; a Post in multiple Groups; Default plus nested
folders and an empty folder; real old bookmark timestamp precision; Topics with
profile/placement relationships and explicitly disabled refresh; a legacy feed;
favorite and blacklist tags; history rows; saved download tasks and sidecars.
Include a missing/deleted-profile case in a separate fixture. No Pool/Related or
MiteMite data may be fabricated as "released `.3` data"; those are current-feature
tests, not old-release fixtures.

Close writers and take a consistent raw Hive/SQLite snapshot (checkpoint/close
SQLite, or copy its complete transaction state). Capture a genuine multi-source
`.bsexport` separately. Keep raw storage and exports as separate fixture types:
importing a backup is not an in-place upgrade test. Hash closed fixture bytes.

Define the expected **logical** post-upgrade state independently of the code under
test. A reviewed adapter may project old/new schemas into the same semantic
representation; document all transformations. Example: released folders become
parent Groups with deterministic ID mapping. Preserve record IDs for in-place
upgrades and record the explicit mapping for unavoidable folder UUID collisions.
For file imports, use an independent source-content/membership mapping rather than
requiring file-local IDs to equal allocated local IDs. New default fields must be
explicitly expected. Never derive expected values from the candidate's migration
output or reduce assertions to record counts.

## 3. Execute two distinct data paths

**Headless repository path:** copy raw fixtures into a fresh temporary test store;
initialize using production repository factories/migration/codec paths; capture
state after first start; close all stores and reopen; capture state again. For
changed journal migration code, inject failure at each durable boundary and
reopen. Assert content, ID allocation, membership, timestamps, profiles and
settings; preserve unsupported data or fail before writing, never replace it
with an empty store. An unknown future schema should fail safely.

**Import path:** start a clean candidate, import the released `.bsexport`/supported
v4 or v5 source, and exercise meaningful Merge/Copy/Replace variants. Validate
source identity and required profile mapping separately from optional hints.
Re-export/re-import and cold reopen without losing data or multiplying records.
Round trips between two candidate writers are additional tests, not provenance.

**Native path, when required:** follow `docs/android_emulator.md` authorization and
lease rules. Install the genuine old APK (correct package, certificate and ABI),
seed in that installation, stop it, then update to the actual candidate without
uninstalling or clearing data. Open through production bootstrap and verify both
first start and fresh cold restart. Validate app-lock/credential presence and SAF
behavior separately using isolated non-secret fixtures; never serialize actual
keys/PINs/cookies into the logical snapshots. An old-source debug build can prove
schema behavior but must not be described as an update from the signed release.
Record signing mismatch/device/toolchain limitations instead of bypassing them.

## 4. Compare full logical observations

`scripts/compare_upgrade_snapshots.py` is a read-only comparison helper. The
producer/migration test must capture three independent files:

- `expected.json`: independently reviewed expected logical state for the fixture;
- `first-start.json`: candidate state after the completed first initialization;
- `reopened.json`: candidate state after closing and reopening the stores.

Each root is an object containing these nine domain objects/arrays:
`profiles`, `settings`, `bookmarks`, `following_topics`, `topic_feeds`,
`favorite_tags`, `blacklisted_tags`, `downloads`, `search_history`.
Use full records, not a numeric count. Empty domains are legitimate in an isolated
scenario, but the qualification matrix must include seeded representative data.
Extra fields/domains are compared too. Sort inherently unordered maps/sets in the
reviewed capture adapter; preserve meaningful list order, positions and dates.
Do not include arbitrary observation time, runtime cache state or real secrets.

```bash
python3 scripts/compare_upgrade_snapshots.py \
  .worktrees/_artifacts/release-upgrade/expected.json \
  .worktrees/_artifacts/release-upgrade/first-start.json \
  .worktrees/_artifacts/release-upgrade/reopened.json
```

Exit 0 means both logical observations match, 1 means a semantic difference,
and 2 means invalid/incomplete input. The helper preserves JSON types, detects
missing/extra values and ordering changes, rejects duplicate keys/non-finite
numbers and caps input size/depth/output. It prints paths, not field values.
Only synthetic, reviewed captures belong in source control; dynamic map keys
can also reveal sensitive data and must not come from real user dumps.

A helper pass is **not proof** of release provenance, fixture capture, production
migration execution, Android behavior or assertion completeness. These remain
obligations of the producer/consumer tests. There are deliberately no ignore-field
flags or a general "approve this diff" switch. Review intentional schema
transformations explicitly rather than teaching the helper to hide differences.

## 5. Release gate and durable evidence

The release report distinguishes:

| Evidence | Required statement |
| --- | --- |
| Installer/version smoke | Exactly what APKs were installed; no data-preservation claim |
| Old-writer fixtures | Source tag/commit, driver/command, synthetic dataset and raw checksums |
| Repository upgrade/import | Actual test command, candidate, first/cold/fault results |
| Native acceptance | Device/ABI/signatures, original release, startup and cold-reopen results |
| Full regression | Final candidate, executed complete-suite results and existing skips |

Keep logs under `.worktrees/_artifacts/release-upgrade/` and summarize in the usual
tracked handoff. Do not put credentials, private databases or signing material
in Git. Clean fixture directories only; never automate cleanup against app/user
storage. No release command, tag push or workflow dispatch is part of this test
procedure. Missing required evidence is a pending release gate, not permission
to substitute lower-version candidate builds or remove legacy support first.
