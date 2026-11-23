# Published writer fixtures

All accounts, URLs and records are synthetic. The writer harnesses call the
production code from these pinned release commits.

| Tag | Commit | Bookmark schema |
| --- | --- | --- |
| `v4.5.0-timberpile.3` | `46a20296bdd74c5eaf99f8917d1a1d1f69c0d0cd` | 4 |
| `v4.5.0-timberpile.4` | `01c0b31de9b2e2083009d7853e2935fce2336396` | 4 |
| `v4.5.0-timberpile.5` | `d4e15586f06192f0ff4315d36a3f61ae69a752d5` | 5 |
| `v4.6.1-timberpile.1` | `f06458805b7b87736d696d3ee5e014dd3103cd42` | 5 |
| `v4.6.1-timberpile.2` | `6875e0ce778aecfb2b83780c2185ce9273a9b2cc` | 5 |
| `v4.6.1-timberpile.3` | `422aeae087c1108e655d85d1a3dac25120456cd6` | 5 |

Use a fresh capture output directory. Existing per-tag outputs are rejected,
not skipped: a `bookmarks.json` file may have been written before test teardown
or Hive flushing failed. Preserve failed captures for diagnosis and rerun into
a new directory; do not overwrite the tracked fixtures automatically.

From the candidate checkout, with FVM installed and all six tags fetched:

```bash
root="$(pwd)"
mkdir -p "$root/../_artifacts/release-compatibility-policy"
artifact="$(realpath "$root/../_artifacts/release-compatibility-policy")"
git worktree add --detach "$artifact/released-writer" v4.6.1-timberpile.3
(
  cd "$artifact/released-writer"
  fvm install
)
scripts/fixtures/capture_released_bookmarks.sh \
  "$artifact/released-writer" "$artifact/captured"
git worktree add --detach "$artifact/latest-release" v4.6.1-timberpile.3
mkdir -p "$artifact/captured-auxiliary"
cp "$artifact/captured/v4.6.1-timberpile.3/bookmarks.json" \
  "$artifact/captured-auxiliary/"
cp scripts/fixtures/released_data_writer.dart.txt \
  "$artifact/latest-release/test/released_data_writer_test.dart"
(
  cd "$artifact/latest-release"
  fvm install
  ./gen.sh
  RELEASE_FIXTURE_OUTPUT="$artifact/captured-auxiliary" \
    fvm flutter test --no-pub --reporter expanded test/released_data_writer_test.dart
)
```

The Bookmark driver supplies synthetic posts and an export date to the tagged
repositories, scope builder, codec, and envelope encoder. It captures the wire
output before closing Hive. The exported Bookmark timestamps retain
microseconds, while the released Hive rows retain milliseconds. The latest
release records a recent Group, colliding folder/Group UUIDs, an empty nested
folder, Default and overlapping direct memberships. The auxiliary driver adds
two ordered profiles, explicit settings, tags, Following Topics with refresh
disabled, a legacy feed, search history, and a saved download with sidecar data.
It creates the separate orphan Topic fixture with a missing profile. Both
drivers close the databases before the raw files are copied. The package uses
the released container writer and source adapters, including the released
Bookmark payload bytes.

The tracked bytes include six Bookmark exports, the latest release's closed
repository files, the separate orphan file, and the latest release's
`.bsexport`. [SHA256SUMS](SHA256SUMS) pins the raw captures. SQLite timestamps,
random IDs and archive metadata can differ when the published writers are rerun.

## Version 1 Downloads database

The closed Downloads database for `v4.5.0-timberpile.3` was created by
the published repository's initializer and task writers. It contains a
synthetic named saved task. The import test verifies its identity and settings
after upgrading to version 2, then opens the restored database again.

From the candidate checkout, prepare a detached worktree at
`v4.5.0-timberpile.3` (`46a20296bdd74c5eaf99f8917d1a1d1f69c0d0cd`) and
copy `scripts/fixtures/released_downloads_v1_writer.dart.txt` into it as
`test/released_downloads_v1_writer_test.dart`. Install the worktree's pinned FVM
SDK, resolve dependencies at the root and in `packages/boorusama_cli`, and run
`./gen.sh`. Run the following with a fresh absolute output path.

```bash
RELEASE_FIXTURE_OUTPUT=/path/to/new/download.db \
  fvm flutter test --no-pub --reporter expanded \
    test/released_downloads_v1_writer_test.dart
```

## Interrupted released import

The files under `v4.6.1-timberpile.3/interrupted-import` come from the same
published commit. The driver enters the released `ImportTransaction` and uses
the released Bookmark package source to capture the private rollback payload
and journal. It fails the released Group membership operation after the actual
write, lets the released inner rollback delete the new Post, then suspends it
before membership restoration. The driver checks the dangling member and closes
Hive while the released outer transaction still marks Bookmarks as applying.

To capture again from the candidate checkout using the prepared detached
`latest-release` worktree above, run:

```bash
mkdir "$artifact/captured-interrupted-import"
cp scripts/fixtures/released_import_recovery_writer.dart.txt \
  "$artifact/latest-release/test/released_import_recovery_writer_test.dart"
(
  cd "$artifact/latest-release"
  git rev-parse HEAD
  RELEASE_FIXTURE_OUTPUT="$artifact/captured-interrupted-import" \
    fvm flutter test --no-pub --reporter expanded \
      test/released_import_recovery_writer_test.dart
)
```

The synthetic captured journal and its hashes are used together with the raw
closed files. The candidate test copies these files to disposable storage.
