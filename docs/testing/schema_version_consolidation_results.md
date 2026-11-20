# Published-data upgrade qualification

The baseline is `v4.6.1-timberpile.3` at
`422aeae087c1108e655d85d1a3dac25120456cd6`. The compatibility branch was rebased
onto `d9203ae62dcbc5ff81e0bd70702607fb24070787`. Both original branch commits
replayed without a patch change. The original remote tip `016755e82` is also a
parent of the task branch ancestry commit. Its tree is identical to the first
parent, which permits ordinary fast-forward publication of the rebased work.

## Final formats

| Contract | Published | Final |
| --- | --- | --- |
| Bookmark transfer | Writer 5, readers 4/5 | Writer 6, readers 4/5/6. Version 6 requires explicit nested organization and complete dated memberships. |
| Local Bookmark organization | 1 | 2, activated directly from the released layout. |
| Bookmark repository metadata | New | 1, with a required ownership document from initialization. |
| Bookmark mutation journal | New | 1, with a hashed operation and plan for records, organization, restoration and mirrors. |
| MiteMite protocol and source payloads | New protocol, existing Following payload | Protocol 1, Bookmark payload 6, Following payload 2. |
| MiteMite private activity, events, outbox, tap intent and Following rollback | New | Initial version 1 for each format. Following definition digests use the same version-1 state and explicitly cover profile and child definitions. |
| Listed Post payload | New | 1 with the listed discriminator. The published common envelope and Gelbooru V2 engine payload are both version 2. |

Released Bookmark v4/v5 file imports and published rollback exports use
the released semantics. A current private rollback retains exact reserved
local IDs and checks its existing authority. The user-facing wire decoder
rejects development v6-v10 shapes. The local migration preserves the released
source files and rejects obsolete active or pending development generations
before replacing them. The v1 recovery input and current Collection projections
still use legacy Pool and Related metadata, so those conversions remain in
place. Repository and import tests exercise corruption, partial writes, commit
guards, read-only ownership and replay after restart.

## Source inventory

The source audit initially found six violations in the four Bookmark contracts
and their dependent readers and alias. The final inventory covers 87 changed
marker paths. Its registered paths cover the final formats above and the
published profile, settings, tag, Following, feed, SQLite, container and link
contracts. Manual review also covered references to known versions inside
registered files.

The separately named Post Hive row marker remains distinct from its embedded
common and engine payloads. Native Group metadata delegates its payload version
to the selected engine. Existing SQLite versions, record revisions, allocator
bounds, Following definition and transport sequence counters, app/Android
versions, UUID variants and external API paths retain their established meanings.
The remaining inventory includes version-1 content references, local policy and
diagnostic formats, MiteMite catalog and preference records, aliases and
publication intents. Android notification channel/group tags are OS identifiers,
while the native tap payload is a versioned document. Imports of protocol or
conversion modules and dynamic references to registered versions add no format.

## Evidence

The tested candidate was `c8cfc5ad0c11bed1d0a3402dc3fa7b78e5a8cb72` with tree
`f9dc529f08253566426185318eeb1598e5c045b2`. The subsequent report commit adds only
this document.

The [fixture inventory and generation commands](../../test/fixtures/released_upgrade/README.md)
identify the six published writers. The raw captures are pinned in
[SHA256SUMS](../../test/fixtures/released_upgrade/SHA256SUMS).

- The released Bookmark v4/v5 fixtures enter production decode, Replace, Merge,
  Copy and v6 re-export paths. The latest package provides the released
  Bookmark bytes and Following/feed bindings. Current recovery accepts the
  published rollback payload after its old local IDs have disappeared.
- Host tests copy the closed production Hive and SQLite fixture. Assertions
  cover exact stored Bookmark snapshots and IDs, shared memberships, empty
  folders, deterministic aliases, ordering, timestamps, ID reservation,
  profile bindings, explicit settings, tags, Following, feeds, history,
  downloads and sidecars. They inspect first start and two cold opens.
- The migration fault tests interrupt each of the six exposed durable
  boundaries. Recovery validates source evidence, replays the plan and
  reopens again without duplicating records or groups.
- The supplementary snapshot comparator matched all nine projected domains
  at first start and cold reopen. Expected state came from tagged exports,
  closed SQLite rows, and the documented transforms. The projection materializes
  the disabled proxy from the released Hive converter, includes the additive
  settings defaults, and accounts for the older swipe/zoom selectors removed
  in the develop base. Separate production assertions cover published
  timestamp precision and the allocated IDs.
- The source audit passed all 29 registered checks. Manual review covered
  all 87 inventory paths. The checksum manifest verified all 19 fixture files.
- The 74 focused migration and durability tests passed. The follow-up fixture,
  rollback and notification run passed 19 tests. The Undo, mirror-schema and
  snapshot capture run passed 13 tests. The eight dependent test files passed
  all 61 tests after their data and expectations were aligned to the final format.
- The complete regression command exited 0 with 8,004 app tests, 1,730 package
  and CLI tests, 140 Python tests, and both shell suites passing. Two
  `go_router` tests retained their existing skips.
- Dart analysis of changed files finished with 0 errors, 0 warnings and 287
  informational findings. Changed Dart files were formatted with FVM.

The principal commands ran from the isolated task checkout:

```bash
python3 scripts/audit_schema_versions.py \
  --baseline v4.6.1-timberpile.3 --candidate c8cfc5ad0 --inventory --json
./scripts/run_regression_tests.sh
(cd test/fixtures/released_upgrade && sha256sum -c SHA256SUMS)
git diff --name-only origin/develop c8cfc5ad0 -- '*.dart'
```

The analyzer ran `fvm dart analyze` on the existing Dart files in the last
command's output. The complete runner used six physical cores. Its log and
the JSON audit, capture and comparison artifacts are in
`.worktrees/_artifacts/release-compatibility-policy/` under the primary
checkout. The regression log SHA-256 is
`2406dc7dd33a546457add0e4e76a0a688403000e6e0d4fe5ddb8bacf8aa8c964`.

## Native acceptance pending

The signed released Android APK to signed candidate upgrade, native first and
cold startup, app lock/secure-storage state, SAF URI permission and backup
recovery, and Android notification permission and tap delivery remain unrun.
The repository checks use isolated synthetic fixture storage.
