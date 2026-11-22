# Release compatibility — consolidate unreleased schemas and qualify upgrades

Continue `maintenance/release-compatibility-policy` in `timberpile/Boorusama`.
This supplements [the earlier preparation](2026-11-18-release-compatibility-preparation.md)
and supersedes its cleanup numbering where the owner now requires **at most one
schema increase per contract since the last public release**.

Published baseline: `v4.6.1-timberpile.3`, `422aeae087c1108e655d85d1a3dac25120456cd6`.
Current develop inspected: `d9203ae62dcbc5ff81e0bd70702607fb24070787`.
The task branch started from `a9ce9de`; do not assume it already contains newer
#166/#134/#176 changes. Fetch and reconcile current develop into this task's
isolated worktree before runtime implementation, preserving both sets of changes.
Do not force-push or modify the owner's primary checkout. Nothing authorizes a
merge into develop/master, a PR, release, issue closure, or deleting worktrees.

## Already prepared

- Existing release/public-data policy and logical snapshot comparator remain.
- [2026-11-20 source audit](../schema_version_audit_2026-11-20.md) names concrete
  violations, target versions and the new ListedPostData classification question.
- `scripts/audit_schema_versions.py` plus 21 source locators checks committed
  public/candidate trees. Numeric jumps, lost public readers and divergent
  MiteMite payload aliases fail; unknown/missing evidence fails closed.
- `.github/workflows/release-validation.yml` has a read-only latest-public-release
  schema gate. It is deliberately **not green** for the current violations.
- New tooling tests are synthetic; they are not app or data-upgrade tests.

## Remote checks actually completed

The isolated tooling copy passed **34 new tests** (32 audit/catalog/Git-fixture
cases and two workflow-source checks), Python compilation, workflow YAML parsing,
the extracted gate shell's `bash -n`, and `git diff --cached --check`.

```bash
python3 -m unittest discover -s scripts/tests -p test_audit_schema_versions.py -v
python3 -m unittest discover -s scripts/tests -p test_schema_audit_workflow.py -v
```

This count does not include the previous snapshot-comparator tests or the existing
repository suite, which were not rerun here. No actual release/candidate Git-tree
CLI run, Flutter suite, old-writer fixture, Hive/SQLite upgrade or Android execution
is claimed. Source findings came from the pinned GitHub files. The full-checkout
source audit and production upgrade evidence below remain local requirements.

## Execute in this order

1. Read current AGENTS and relevant workflow/verification rules. Recheck the
   public release and current branch tips. Keep all existing published import
   support; no permanent support-window sunset or owner-data reset is approved.
   Run the new source audit on the actual complete checkout and manually review
   all `--inventory` entries (also markers in already registered files).
2. Establish old-writer fixtures **before removing compatibility**. Use public
   v4 writers (`v4.5.0-timberpile.3/.4`) and v5 writers (`.5` and
   `v4.6.1-timberpile.1/.2/.3`) to emit synthetic exports; use the actual last
   release's repositories to seed local Hive/SQLite data. Record writer SHA,
   generation command and hashes. Do not relabel a new payload as old. Test IDs,
   snapshots, profile bindings, empty folders, shared memberships, ordering,
   timestamps, explicit settings, Following state and restart. Keep user secrets
   and real personal databases out of Git.
3. Consolidate **Bookmark wire schema 5 → 6** into the final nested-Group shape.
   Inspect `bookmarks_source.dart`, `bookmark_backup_codec.dart`, import preview/
   execution, detached/worker codecs, tests and `mitemite/bookmark_package.dart`.
   The final v6 is the current final record/hierarchy design, NOT the obsolete
   development v6 design. Require its explicit `organizationSchema` discriminator
   and validate record/member structure before any writes. Keep v4/v5 conversion;
   remove old development 6–9 and transitional-v10 branches. Reject an old dev-v6
   payload clearly, rather than reinterpreting it as a final-v6 empty collection.
   Use a dependency-free shared schema constant where it prevents divergence;
   do not make a codec/isolate depend on UI providers. MiteMite Bookmark source
   schema becomes 6, while MiteMite protocol remains 1 and Following source 2.
   Update audit locators if the constant moves; never raise ceilings to pass.
4. Replace **organization v1 → staged v2 → v3** with one direct **v1 → final v2**
   migration. `_openLegacy()` currently activates intermediate v2, so deleting
   it without replacement breaks the released path. Reuse hierarchy conversion
   but stage the final generation directly. Preserve original source files,
   deterministic folder/Group collision mapping, Group/Post IDs, memberships,
   empty folders, Default semantics, preference aliases and allocator high-water
   marks. Flush and validate before one activation marker. Fault-inject every
   durable boundary; reopen twice and assert no duplication or loss. Test a
   fresh install separately. Do not reset a database merely because it bears an
   old development marker; preserve it and surface unsupported-state handling.
5. Consolidate **new repository metadata and mutation journal**. Their absence
   from the public baseline permits one initial schema 1. Replace the journal's
   1/2/3/4 operation-dependent version with explicit operation kinds (or another
   equally strict, simple discriminator). Keep all current constraints for
   ordinary record writes, organization changes, trusted restoration and mirrors.
   Preserve previous/target revision checks, reservation monotonicity, hash
   validation, idempotent replay, read-only ownership and commit-time access
   guards. Include final mirror metadata in the initial repository contract;
   retaining an explicit initialized/present invariant is essential. A missing
   required ownership record must still fail closed, not appear empty. This is
   a format simplification, not permission to weaken journal validation.
6. Review the unregistered inventory, especially engine payload codec versions
   and the newly marked ListedPostData codecVersion 3. Establish the correct
   contract namespace from writers/readers before changing it; shared common
   Post schema 2 is already published and must not be reset. Leave real published
   SQLite migration versions and unrelated sequence/build/API counters intact.
   Remove development-only storage/projection compatibility only after proving
   it is not part of the direct released path or still-used current UI model.
7. Update subsystem docs and fixtures alongside code. Historical handoffs remain
   dated evidence, not specifications for the new final format. New invalid,
   ambiguous and truncated payload cases must fail before mutation. Keep existing
   useful crash, corruption, trust, read-only and import atomicity tests.
8. Run source audit until all **registered checks pass and inventory is reviewed**;
   run real production migration/import/reopen tests for all affected domains and
   `./scripts/run_regression_tests.sh` on the final combined candidate. Format and
   analyze changed Dart. Use the existing snapshot comparator only as an extra
   check, not fixture provenance or the sole assertion. For necessary authorized
   Android testing, use the genuine released APK with seeded data and the device
   lease; compare first-start and cold-reopen state. Same-source lower-build APK
   installation remains only an installer check. Report unrun gates explicitly.
9. Review the final diff, commit and push **this branch only**. Report exact
   published and candidate SHAs, each old → final schema, obsolete branches removed,
   fixture provenance, commands/results and remaining native acceptance.

## Acceptance criteria

Each real published contract has no more than one new final version; no released
format is repurposed. Export/import and local startup all use coherent final
schemas. MiteMite uses the same source schema as its payload, without introducing
an unnecessary protocol bump. Released data survives production upgrade/import
and two cold opens; new journal replay remains strict under fault injection.
No code/data is removed solely because its name contains `legacy` or `v2`.
No repeated cover-policy/reader redesign or unrelated #166 change is in scope.

The remote preparation did not execute Flutter, actual app migrations or Android
checks and did not renumber runtime schemas. Its new helper tests passed, but
local full-checkout audit and production evidence remain mandatory. There is no
merge/release-readiness claim. Do not ask to continue after each item; stop only
for a genuinely destructive/public-support decision outside this authorization.
