# AnimeBoxes Export Converter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> `superpowers:executing-plans` to implement this plan task-by-task.

**Goal:** Add a credential-safe, deterministic CLI migration that converts an
AnimeBoxes Android 1.0 CSV into readable normalized JSON and then into
Boorusama bookmark, blacklist, and pinned-search backup files.

**Architecture:** Keep the external positional format, normalized schema, and
Boorusama backup formats behind separate typed boundaries. Parse every source
section without retaining secret values, normalize and validate into a strict
versioned document, then export complete backup payloads in memory before an
atomic filesystem write. Bridge the standalone Dart CLI and Flutter app with
shared golden files that the production Boorusama codecs parse.

**Tech Stack:** Dart 3.11+, `package:args`, `package:csv` 8.0.0,
`dart:convert`, `dart:io`, `package:path`, Dart tests, Flutter contract tests,
and Maestro for a synthetic Android import check.

**Spec:**
[AnimeBoxes Export Converter Design](../specs/2026-09-24-animeboxes-export-converter-design.md)

## Global constraints

- Work only in `/home/timber/code/Boorusama/.worktrees/animeboxes-export-converter`
  on `feature/animeboxes-export-converter`.
- Rebase the branch onto the latest `origin/develop` before implementation.
- Keep `16 August 2026 08_48_50 CEST.csv`, normalized personal data, and every
  generated migration artifact untracked. Stage only explicit paths.
- Never store, hash, log, interpolate into exceptions, or serialize source
  usernames or credential values. Parse only whether those cells are present.
- Use synthetic fixtures in committed tests. The private CSV is allowed only
  for the final local count check.
- Run `fvm dart format` after each Dart file batch.
- Follow red-green-refactor within every task: add the named failing test, run
  it and observe the expected failure, implement the smallest behavior, then
  rerun the focused tests.
- Do not add profiles, search-history SQLite output, a bulk ZIP, app UI, or
  network access.
- Do not push, open a pull request, merge, or perform other GitHub actions
  without separate user authorization.

## Data contracts to keep fixed

The favorite row is 39 columns. The exporter behavior recovered from the
AnimeBoxes APK fixes the fields relevant to this migration as follows:

| Index range | Meaning |
| --- | --- |
| 15 | all tags |
| 16 | general tags |
| 17 | artist tags |
| 18 | character tags |
| 19 | copyright tags |
| 20 | MD5 |
| 21 | external source |
| 22 | nullable parent post ID |
| 23 | score |
| 24 | rating |
| 25 | has notes, mapped to `isTranslated` |
| 26 | has comments, mapped to `hasComment` |
| 27 | has children |
| 28 | favorite `dateAdded` |
| 29-38 | reserved and required to be empty |

Consequences that every layer must preserve:

- Bookmark `createdAt` and `updatedAt` come from `dateAdded`.
- Snapshot `createdAt` is absent because the source has no post-creation time.
- `parentId` comes from column 22.
- `hasParentOrChildren` is `hasChildren || parentId != null`.
- `fileSize` is `0` and `duration` is `-1.0` because neither is exported.
- Video status is inferred from the normalized file extension. MP4 and WebM
  use the file URL as `videoUrl` and preview URL as `videoThumbnailUrl`; GIF is
  still an image. ZIP follows the existing Boorusama video/archive behavior.
- Duplicate identity is normalized host plus upstream post ID. The greatest
  `dateAdded` instant wins, with the later source position breaking a tie.

Normalized JSON has root keys `schema`, `version`, `source`, `profiles`,
`searchHistory`, `bookmarks`, `blacklist`, `pinnedSearchFolders`, and
`diagnostics`. The schema name is `boorusama.animeboxes.normalized` and its
version is `1`. Decode rejects unknown keys at every level so an unexpected
secret-bearing or future field cannot be silently accepted.

Boorusama artifacts have deterministic names:

- `boorusama_bookmarks.json`
- `boorusama_blacklisted_tags.json`
- `boorusama_pinned_searches.json`
- `conversion_report.json`

## Review focus

Before completion, review the entire diff specifically for these five failure
classes and point to the test that prevents each one:

1. A credential or username survives in memory beyond CSV parsing, output,
   diagnostics, exception text, or command output.
2. A positional favorite field shifts, especially parent ID, tag categories,
   flags, or `dateAdded`.
3. A generated JSON file looks plausible but fails a production Boorusama
   codec or loses folder membership.
4. Duplicate selection or generated ordering changes between runs.
5. A failed command leaves a partial final file or directory.

---

### Task 1: Establish the parser boundary and exact source schema

**Files:**

- Modify: `packages/boorusama_cli/pubspec.yaml`
- Modify: `packages/boorusama_cli/pubspec.lock`
- Create: `packages/boorusama_cli/lib/src/migrations/animeboxes/errors.dart`
- Create: `packages/boorusama_cli/lib/src/migrations/animeboxes/source_types.dart`
- Create: `packages/boorusama_cli/lib/src/migrations/animeboxes/csv_reader.dart`
- Create: `packages/boorusama_cli/test/migrations/animeboxes/fixtures/complete.csv`
- Create: `packages/boorusama_cli/test/migrations/animeboxes/csv_reader_test.dart`

**Step 1: Refresh the branch and dependencies**

From the feature worktree:

```bash
git fetch origin develop
git rebase origin/develop
cd packages/boorusama_cli
fvm dart pub get
fvm dart test
```

Expected: the rebase applies the existing documentation commits without a
content conflict, dependency resolution succeeds, and the unchanged CLI test
suite passes. Stop and diagnose any baseline failure before adding behavior.

Add `csv: ^8.0.0` to `dependencies`, run `fvm dart pub get`, and retain the
resulting lockfile change.

**Step 2: Write the failing complete-export parser test**

Build `complete.csv` entirely from synthetic values. It must contain exactly
one metadata block and all six section markers, use CRLF endings, include one
row of every record kind, and exercise a quoted comma and Unicode. Give its
server row obvious sentinel secrets such as `fixture-user-never-serialize` and
`fixture-key-never-serialize`.

Add this first contract to `csv_reader_test.dart`:

```dart
test('parses every Android 1.0 section into typed source records', () {
  final source = AnimeBoxesCsvReader().parse(fixture('complete.csv'));

  expect(source.metadata.formatVersion, '1.0');
  expect(source.servers, hasLength(1));
  expect(source.history, hasLength(1));
  expect(source.favorites, hasLength(1));
  expect(source.blacklist, hasLength(1));
  expect(source.folders, hasLength(1));
  expect(source.pinnedSearches, hasLength(1));
});
```

Run:

```bash
fvm dart test test/migrations/animeboxes/csv_reader_test.dart
```

Expected: FAIL because `AnimeBoxesCsvReader` and the source types do not exist.

**Step 3: Define secret-free source types and parser errors**

Use immutable plain Dart records/classes. The outer result must make every
section explicit:

```dart
final class AnimeBoxesExport {
  const AnimeBoxesExport({
    required this.metadata,
    required this.servers,
    required this.history,
    required this.favorites,
    required this.blacklist,
    required this.folders,
    required this.pinnedSearches,
  });

  final AnimeBoxesMetadata metadata;
  final List<AnimeBoxesServer> servers;
  final List<AnimeBoxesHistoryEntry> history;
  final List<AnimeBoxesFavorite> favorites;
  final List<AnimeBoxesBlacklistEntry> blacklist;
  final List<AnimeBoxesPinFolder> folders;
  final List<AnimeBoxesPinnedSearch> pinnedSearches;
}
```

`AnimeBoxesServer` must expose `loginPresent` and `credentialsPresent`, never
username, password, API key, cookie, token, authorization parameters, or raw
server cells. Source records include a one-based `sourceRow` and zero-based
`sourcePosition` only where later diagnostics/order need them.

Use a stable safe exception:

```dart
final class AnimeBoxesFormatException implements FormatException {
  const AnimeBoxesFormatException(this.code, this.message, {
    this.section,
    this.row,
  });

  final String code;
  @override
  final String message;
  final String? section;
  final int? row;

  @override
  int? get offset => null;

  @override
  Object? get source => null;

  @override
  String toString() => [
    code,
    if (section != null) 'section=$section',
    if (row != null) 'row=$row',
    message,
  ].join(': ');
}
```

Messages may name a field but must never contain a raw cell value or source
row.

**Step 4: Implement section recognition and fixed-width parsing**

Implement:

```dart
final class AnimeBoxesCsvReader {
  const AnimeBoxesCsvReader();

  AnimeBoxesExport parse(String csvText);
}
```

Decode with `Csv().decode(csvText)`. Accept an optional UTF-8 BOM on the first
cell, recognize each section once, and validate exact widths before indexing:
metadata 10, servers 19, history 10, favorites 39, blacklist 8, and home pins
11. Split home-pin type 4 rows into folders and type 3 rows into searches.
Reject unknown row kinds rather than guessing.

For favorite columns 15-28, implement the table in **Data contracts to keep
fixed** literally. Parse integer booleans only from the accepted source
representations and validate timestamps with `DateTime.tryParse`, while
retaining their original offset-bearing string for later JSON output. Require
columns 29-38 to be empty.

**Step 5: Add focused malformed-input and secrecy cases**

Use loop-based cases with one `test()` per case for:

- missing and repeated sections;
- every incorrect row width;
- unsupported format/application combination;
- invalid required integer, boolean, URL, rating, and timestamp;
- non-empty favorite column 29 through 38;
- quoted comma, embedded quote, Unicode, CRLF, BOM, and empty optional fields;
- home-pin row type other than 3 or 4.

Add an exact positional test whose favorite row has distinct sentinel values
in columns 15-28. Assert every parsed property separately, including that
column 22 is `parentId` and column 28 is `dateAdded`.

Add a recursive/string safety assertion over `source.toString()` and every
thrown exception:

```dart
for (final secret in [
  'fixture-user-never-serialize',
  'fixture-key-never-serialize',
]) {
  expect(source.toString(), isNot(contains(secret)));
}
```

Run:

```bash
fvm dart format lib/src/migrations/animeboxes test/migrations/animeboxes
fvm dart test test/migrations/animeboxes/csv_reader_test.dart
```

Expected: PASS.

**Step 6: Commit the parser boundary**

Stage only the files listed in this task, verify the private CSV is still
untracked, then commit:

```bash
git add packages/boorusama_cli/pubspec.yaml packages/boorusama_cli/pubspec.lock packages/boorusama_cli/lib/src/migrations/animeboxes packages/boorusama_cli/test/migrations/animeboxes
git commit -m "feat(cli): parse AnimeBoxes exports"
```

---

### Task 2: Define and strictly decode normalized JSON

**Files:**

- Create: `packages/boorusama_cli/lib/src/migrations/animeboxes/normalized_types.dart`
- Create: `packages/boorusama_cli/lib/src/migrations/animeboxes/document_codec.dart`
- Create: `packages/boorusama_cli/test/migrations/animeboxes/document_codec_test.dart`

**Step 1: Write failing normalized round-trip tests**

Construct a complete in-memory `NormalizedAnimeBoxesDocument` with one item in
each collection. Assert pretty JSON round-trips without changing field values
or order and starts with:

```json
{
  "schema": "boorusama.animeboxes.normalized",
  "version": 1
}
```

Also assert an offset such as `2026-08-16T08:48:50+0200` is emitted exactly as
received instead of being changed to UTC.

Run:

```bash
fvm dart test test/migrations/animeboxes/document_codec_test.dart
```

Expected: FAIL because the normalized types and codec do not exist.

**Step 2: Implement explicit normalized value types**

Define the aggregate:

```dart
final class NormalizedAnimeBoxesDocument {
  const NormalizedAnimeBoxesDocument({
    required this.source,
    required this.profiles,
    required this.searchHistory,
    required this.bookmarks,
    required this.blacklist,
    required this.pinnedSearchFolders,
    required this.diagnostics,
  });

  static const schema = 'boorusama.animeboxes.normalized';
  static const version = 1;
}
```

Use named types for source metadata, profile, history entry, bookmark and media
variants, blacklist rule, pinned folder/search, engine mapping, diagnostic, and
ISO timestamp. The timestamp type stores both the validated raw string and its
parsed instant:

```dart
final class AnimeBoxesTimestamp {
  AnimeBoxesTimestamp.parse(this.raw) : instant = DateTime.parse(raw);

  final String raw;
  final DateTime instant;
}
```

All collections are copied to unmodifiable lists. The normalized profile type
has no field capable of holding a username or credential value.

**Step 3: Implement a strict codec**

Expose only:

```dart
final class AnimeBoxesDocumentCodec {
  const AnimeBoxesDocumentCodec();

  String encode(NormalizedAnimeBoxesDocument document);
  NormalizedAnimeBoxesDocument decode(String source);
}
```

Encode with `JsonEncoder.withIndent('  ')` plus a trailing newline. Keep source
order. Decode through small helpers such as `_object`, `_list`, `_string`,
`_integer`, `_boolean`, `_optionalString`, and `_requireExactKeys` so malformed
data produces `AnimeBoxesFormatException` with a stable code and JSON path but
never a rejected value.

Require the exact root keys and exact keys for every nested object. Validate:

- schema and version;
- absolute HTTP(S) profile/media/page URLs and normalized hosts;
- known engine names and current IDs;
- UUID syntax and unique folder/search IDs;
- bookmark identity uniqueness;
- rating names;
- folder membership exactly once across folders and Home;
- diagnostics as code/count/location metadata only.

**Step 4: Add rejection tests**

Parameterize mutated documents for wrong schema/version, missing keys, unknown
root and nested keys, wrong primitive types, invalid timestamps/URLs/UUIDs,
unknown engines, duplicate identities, and broken membership. Include unknown
keys named `username`, `apiKey`, `password`, `cookie`, and `authorization` at
multiple nesting levels. Each must fail without the supplied value appearing
in the exception.

Run:

```bash
fvm dart format lib/src/migrations/animeboxes test/migrations/animeboxes
fvm dart test test/migrations/animeboxes/document_codec_test.dart
```

Expected: PASS.

**Step 5: Commit the normalized boundary**

```bash
git add packages/boorusama_cli/lib/src/migrations/animeboxes/normalized_types.dart packages/boorusama_cli/lib/src/migrations/animeboxes/document_codec.dart packages/boorusama_cli/test/migrations/animeboxes/document_codec_test.dart
git commit -m "feat(cli): define AnimeBoxes normalized schema"
```

---

### Task 3: Normalize engines, relationships, and duplicates safely

**Files:**

- Create: `packages/boorusama_cli/lib/src/migrations/animeboxes/normalizer.dart`
- Create: `packages/boorusama_cli/test/migrations/animeboxes/normalizer_test.dart`

**Step 1: Write the failing mapping test**

Parse the complete synthetic CSV and normalize it:

```dart
final document = const AnimeBoxesNormalizer().normalize(source);

expect(document.profiles.single.credentialsPresent, isTrue);
expect(document.bookmarks.single.parentId, 123);
expect(document.bookmarks.single.isTranslated, isTrue);
expect(document.bookmarks.single.hasComment, isTrue);
expect(document.bookmarks.single.hasParentOrChildren, isTrue);
expect(document.bookmarks.single.dateAdded.raw, fixtureDateAdded);
```

Encode the result and assert both synthetic secret sentinels are absent.

Run:

```bash
fvm dart test test/migrations/animeboxes/normalizer_test.dart
```

Expected: FAIL because the normalizer does not exist.

**Step 2: Implement canonical engine and URL mapping**

Implement:

```dart
final class AnimeBoxesNormalizer {
  const AnimeBoxesNormalizer();

  NormalizedAnimeBoxesDocument normalize(AnimeBoxesExport source);
}
```

Centralize the supported mapping in immutable values:

| Hosts/site family | Engine | Boorusama type ID |
| --- | --- | ---: |
| `danbooru.donmai.us`, Donmai aliases | `danbooru` | 20 |
| `gelbooru.com` | `gelbooru` | 21 |
| `rule34.xxx`, `realbooru.com` | `gelbooruV2` | 23 |
| Konachan hosts | `moebooru` | 24 |

Normalize scheme/host case, default ports, trailing slash, and known base-path
shape once. Map using the known host, then confirm the AnimeBoxes numeric type
agrees. Unknown hosts and disagreements fail with `unsupported_engine` or
`engine_mismatch` and identify only section/row.

**Step 3: Normalize every source section**

- Source metadata keeps format/app versions and offset-preserving export time.
- Profiles keep source ID, display name, normalized URL, engine name/type ID,
  non-sensitive behavioral settings, `loginPresent`, and
  `credentialsPresent`.
- History keeps every row in source order, including repeated queries, but has
  no later Boorusama target.
- Bookmarks keep page/media URLs, dimensions, exact tag subsets, MD5, optional
  external source, optional parent ID, score, normalized rating, flags,
  `dateAdded`, host, engine, source profile ID, post ID, and source position.
- Blacklist keeps exact rule text and source order.
- Folders contain their searches in source order; validate unique UUIDs and
  exactly one membership for each search.

Diagnostics use codes and integer counts, plus section/row/source-position only
when needed. They never contain queries, tags, rule text, full URLs, rejected
values, usernames, or credentials.

**Step 4: Resolve duplicate bookmarks deterministically**

Group on `(normalizedHost, postId)`. Pick the greatest `dateAdded.instant`; if
equal, pick the greatest `sourcePosition`. Emit retained bookmarks in the
winning records' source order. Add a diagnostic containing the duplicate count
and winning/losing positions, not post URLs, tags, or identity values.

Test both the timestamp decision and exact-timestamp tie. Normalize the same
input twice and assert byte-identical encoded JSON.

**Step 5: Cover mappings, flags, and relationships**

Add table-driven cases for all supported hosts, all short/full rating names,
image/GIF/MP4/WebM formats, parent-only, child-only, neither relationship,
empty optional tag subsets/source, orphan folder references, duplicate UUIDs,
engine disagreement, and unknown host.

Explicitly assert:

```dart
expect(bookmark.hasParentOrChildren, bookmark.hasChildren || bookmark.parentId != null);
expect(bookmark.dateAdded.raw, sourceFavorite.dateAdded.raw);
```

Run:

```bash
fvm dart format lib/src/migrations/animeboxes test/migrations/animeboxes
fvm dart test test/migrations/animeboxes/normalizer_test.dart
fvm dart test test/migrations/animeboxes
```

Expected: PASS.

**Step 6: Commit normalization**

```bash
git add packages/boorusama_cli/lib/src/migrations/animeboxes/normalizer.dart packages/boorusama_cli/test/migrations/animeboxes/normalizer_test.dart
git commit -m "feat(cli): normalize AnimeBoxes data"
```

---

### Task 4: Export production-compatible Boorusama backups

**Files:**

- Create: `packages/boorusama_cli/lib/src/migrations/animeboxes/boorusama_exporter.dart`
- Create: `packages/boorusama_cli/lib/src/migrations/animeboxes/conversion_report.dart`
- Create: `packages/boorusama_cli/test/migrations/animeboxes/boorusama_exporter_test.dart`
- Create: `packages/boorusama_cli/test/migrations/animeboxes/fixtures/boorusama_bookmarks.json`
- Create: `packages/boorusama_cli/test/migrations/animeboxes/fixtures/boorusama_blacklisted_tags.json`
- Create: `packages/boorusama_cli/test/migrations/animeboxes/fixtures/boorusama_pinned_searches.json`
- Create: `test/core/backups/animeboxes_migration_contract_test.dart`

**Step 1: Write failing exporter golden tests**

Define the output as encoded strings so all validation completes before file
I/O:

```dart
final class BoorusamaMigrationArtifacts {
  const BoorusamaMigrationArtifacts({
    required this.bookmarks,
    required this.blacklistedTags,
    required this.pinnedSearches,
    required this.report,
  });

  final String bookmarks;
  final String blacklistedTags;
  final String pinnedSearches;
  final String report;
}

final class BoorusamaMigrationExporter {
  const BoorusamaMigrationExporter();

  BoorusamaMigrationArtifacts export(NormalizedAnimeBoxesDocument document);
}
```

Compare the first three strings to the committed synthetic golden files and
decode the report to assert aggregate counts/codes. Run:

```bash
fvm dart test test/migrations/animeboxes/boorusama_exporter_test.dart
```

Expected: FAIL because the exporter does not exist.

**Step 2: Implement bookmark backup version 2**

Emit the normal Boorusama envelope with `version: 2`, `date` set to the source
export timestamp, `data`, and a no-ID `AnimeBoxes` group containing every
bookmark's file-local ID. Omit `exportVersion` because the
available value identifies AnimeBoxes rather than Boorusama. Each row has
`localId`, `createdAt`, `updatedAt`, `snapshot`, and `postId`.

Assign one-based `localId` values in retained source order. Use `dateAdded.raw`
for both bookmark timestamps. Snapshot origin is:

```dart
{
  'booruTypeId': bookmark.engine.typeId,
  'booruId': bookmark.engine.typeId,
  'sourceHost': bookmark.host,
}
```

Omit `profileIdHint`. Snapshot `common` must contain the exact keys expected by
`StoredPostCodec`:

```dart
{
  'schemaVersion': 1,
  'id': bookmark.postId,
  'thumbnailImageUrl': bookmark.previewUrl,
  'sampleImageUrl': bookmark.sampleUrl,
  'originalImageUrl': bookmark.fileUrl,
  'videoUrl': isVideo ? bookmark.fileUrl : '',
  'videoThumbnailUrl': isVideo ? bookmark.previewUrl : '',
  'width': bookmark.width,
  'height': bookmark.height,
  'format': bookmark.format,
  'md5': bookmark.md5,
  'fileSize': 0,
  'duration': -1.0,
  'tags': bookmark.tags,
  if (bookmark.artistTags != null) 'artistTags': bookmark.artistTags,
  if (bookmark.characterTags != null) 'characterTags': bookmark.characterTags,
  if (bookmark.copyrightTags != null) 'copyrightTags': bookmark.copyrightTags,
  'rating': bookmark.rating,
  'hasComment': bookmark.hasComment,
  'isTranslated': bookmark.isTranslated,
  'hasParentOrChildren': bookmark.hasParentOrChildren,
  if (bookmark.parentId != null) 'parentId': bookmark.parentId,
  'source': normalizedPostSource,
  'score': bookmark.score,
}
```

Do not add `createdAt` to `common`. Emit `custom: {}` and `codecVersion: 1`, so
the app can decode complete common data and use its safe unknown/native-data
fallback. Encode external source as `{'kind': 'web', 'url': value}` for an
absolute HTTP(S) URL, `{'kind': 'nonWeb', 'value': value}` for another nonempty
source, and `{'kind': 'none'}` when absent.

**Step 3: Implement blacklist and pinned-search version 1 exports**

Blacklist envelope uses `version: 1` and the source export timestamp as its
deterministic envelope `date`. Assign one-based IDs in source order, keep every
rule active, and use that same timestamp for `createdDate` and `updatedDate`
because AnimeBoxes has no per-rule timestamp.

Pinned-search envelope uses `version: 1`, the source export timestamp as its
deterministic `date`, `source: pinned_searches`, and data rows in this order:
folders, searches, organization. Folder/search positions follow their source
order. Preserve UUIDs and exact memberships. Each profile reference contains
source profile ID, mapped engine name, normalized URL, and non-sensitive
display name. The organization row contains all searches without a folder,
including an empty list for the analyzed export.

The report uses its own fixed schema/version, source/retained/output counts,
and diagnostic codes/counts. It contains no raw query, tag, rule, URL, username,
credential, or post identity.

**Step 4: Add Flutter production-codec contract tests**

In `animeboxes_migration_contract_test.dart`, load the same three fixture files
from `packages/boorusama_cli/test/migrations/animeboxes/fixtures/`. Decode each
envelope with production `decodeData`, then:

- parse bookmarks with `BookmarkBackupCodec`, using `Bookmark.fromJson` for
  legacy parsing and no engine-specific post codec;
- parse blacklisted tags with `ListHandler<BlacklistedTag>` and
  `BlacklistedTag.fromJson`;
- parse pinned searches with `PinnedSearchBackupCodec`.

Assert observable imported fields: bookmark post ID/origin/media/tags/rating,
zero file size, unknown duration, absent post creation time, parent relation,
the no-ID `AnimeBoxes` group, blacklist values/timestamps, folder order,
search order, and
complete membership.

Run from the repository root:

```bash
fvm flutter test test/core/backups/animeboxes_migration_contract_test.dart
```

Expected before exporter/fixtures are complete: FAIL. Expected after completing
the mappings: PASS.

**Step 5: Run both sides of the golden boundary**

```bash
cd packages/boorusama_cli
fvm dart format lib/src/migrations/animeboxes test/migrations/animeboxes
fvm dart test test/migrations/animeboxes/boorusama_exporter_test.dart
cd ../..
fvm dart format test/core/backups/animeboxes_migration_contract_test.dart
fvm flutter test test/core/backups/animeboxes_migration_contract_test.dart
```

Expected: PASS. Review fixture diffs manually; golden updates require an
explanation tied to a backup-contract change.

**Step 6: Commit the exporters and contract bridge**

```bash
git add packages/boorusama_cli/lib/src/migrations/animeboxes/boorusama_exporter.dart packages/boorusama_cli/lib/src/migrations/animeboxes/conversion_report.dart packages/boorusama_cli/test/migrations/animeboxes/boorusama_exporter_test.dart packages/boorusama_cli/test/migrations/animeboxes/fixtures/boorusama_bookmarks.json packages/boorusama_cli/test/migrations/animeboxes/fixtures/boorusama_blacklisted_tags.json packages/boorusama_cli/test/migrations/animeboxes/fixtures/boorusama_pinned_searches.json test/core/backups/animeboxes_migration_contract_test.dart
git commit -m "feat(cli): export AnimeBoxes backups"
```

---

### Task 5: Add CLI commands and atomic output

**Files:**

- Create: `packages/boorusama_cli/lib/src/command/animeboxes_command.dart`
- Create: `packages/boorusama_cli/lib/src/migrations/animeboxes/atomic_output.dart`
- Modify: `packages/boorusama_cli/lib/src/cli.dart`
- Create: `packages/boorusama_cli/test/command/animeboxes_command_test.dart`
- Create: `packages/boorusama_cli/test/migrations/animeboxes/atomic_output_test.dart`

**Step 1: Write failing command-surface tests**

Construct a `CommandRunner<int>` with `AnimeBoxesCommand` and a callback-backed
output collector. Use real temporary directories and the synthetic complete
fixture. Test:

```dart
test('normalize creates only a complete normalized document', () async { ... });
test('export creates all four deterministic artifacts', () async { ... });
test('invalid source returns non-zero without a final file', () async { ... });
test('existing export directory is rejected without changing it', () async { ... });
```

Assert help exposes exactly:

```text
boorusama animeboxes normalize --input <csv> --output <normalized.json>
boorusama animeboxes export --input <normalized.json> --output-dir <directory>
```

Run:

```bash
fvm dart test test/command/animeboxes_command_test.dart
```

Expected: FAIL because the command is not registered.

**Step 2: Implement atomic file and directory writers**

Expose a narrow API:

```dart
final class AtomicMigrationOutput {
  const AtomicMigrationOutput();

  Future<void> writeFile({required File target, required String contents});

  Future<void> writeDirectory({
    required Directory target,
    required Map<String, String> files,
  });
}
```

For a file, require the parent directory to exist, reject an existing target,
write to a uniquely named sibling temp file, flush/close it, then rename to the
target. For a directory, reject an existing target, create a uniquely named
sibling temp directory, write/flush all four already-encoded artifacts there,
then rename the directory. On failure, remove only the exact temp path created
by this call; never delete or change the requested target.

Tests use real temp directories and verify:

- successful final content and no temp sibling;
- existing targets stay byte-for-byte unchanged;
- invalid/missing parent fails with no final target;
- a deliberately invalid artifact filename is rejected before any write;
- final artifacts are absent when preflight or encoding fails.

Artifact names must be selected from the four constant basenames; reject path
separators and `.`/`..`.

**Step 3: Implement `animeboxes normalize`**

The command reads the full 4.45 MB-class input as text, runs
`AnimeBoxesCsvReader`, `AnimeBoxesNormalizer`, and
`AnimeBoxesDocumentCodec.encode`, then atomically writes the target. Require
`--input` and `--output`. Reject identical input/output paths and an existing
output. Print only section/output counts and the target path.

Expected data failures return a non-zero code and a stable safe line such as:

```text
AnimeBoxes input error [invalid_row_width] at Favorites row 12.
```

Do not print raw exception/source objects. Unexpected programmer/I/O errors may
name the operation and path but must not include file contents.

**Step 4: Implement `animeboxes export`**

Require `--input` and `--output-dir`. Decode the normalized document strictly,
build all four artifact strings in memory, then call `writeDirectory`. Never
create the final directory until all document/export validation has passed.
Print the four paths and aggregate counts only.

Register `AnimeBoxesCommand` in the `CommandRunner` and add `animeboxes` to the
handwritten top-level help in `cli.dart`.

**Step 5: Add command secrecy and deterministic-output tests**

Run normalize then export twice into two separate temp paths. Assert normalized
and artifact bytes are identical. Recursively scan file contents and captured
stdout/stderr for the synthetic username/credential sentinels. Feed malformed
rows containing sentinels and assert the same for errors. Confirm no `.tmp` or
partial final path survives any expected failure.

Run:

```bash
fvm dart format lib/src/command/animeboxes_command.dart lib/src/migrations/animeboxes/atomic_output.dart lib/src/cli.dart test/command/animeboxes_command_test.dart test/migrations/animeboxes/atomic_output_test.dart
fvm dart test test/command/animeboxes_command_test.dart
fvm dart test test/migrations/animeboxes/atomic_output_test.dart
fvm dart test test/migrations/animeboxes
```

Expected: PASS.

**Step 6: Commit the CLI surface**

```bash
git add packages/boorusama_cli/lib/src/command/animeboxes_command.dart packages/boorusama_cli/lib/src/migrations/animeboxes/atomic_output.dart packages/boorusama_cli/lib/src/cli.dart packages/boorusama_cli/test/command/animeboxes_command_test.dart packages/boorusama_cli/test/migrations/animeboxes/atomic_output_test.dart
git commit -m "feat(cli): add AnimeBoxes migration commands"
```

---

### Task 6: Document, validate, and privately exercise the migration

**Files:**

- Create: `docs/migrations/animeboxes.md`
- Modify: `docs/work/in-progress/MIG-001-animeboxes-export-converter.md`
- Move after every acceptance criterion passes:
  `docs/work/in-progress/MIG-001-animeboxes-export-converter.md` to
  `docs/work/done/MIG-001-animeboxes-export-converter.md`

**Step 1: Document the operator workflow and privacy boundary**

Document the two commands, supported AnimeBoxes Android format 1.0, generated
filenames, backup import order, non-migrated data, profile matching behavior,
and failure/atomicity rules. State plainly that the source may contain
plaintext credentials and should be protected; recommend rotating credentials
after the migration. Never include the user's filename, actual host/account
details, tags, searches, or credentials.

Import order in the guide:

1. Configure the matching Boorusama profiles manually.
2. Import `boorusama_bookmarks.json`.
3. Import `boorusama_blacklisted_tags.json`.
4. Import `boorusama_pinned_searches.json`, review the existing profile-match
   preflight, and skip only intentionally unmatched searches.

**Step 2: Run format, generation, analysis, and automated suites**

From `packages/boorusama_cli`:

```bash
fvm dart format lib test
fvm dart analyze
fvm dart test
```

From the repository root:

```bash
./gen.sh
fvm flutter analyze --no-pub
fvm flutter test test/core/backups/animeboxes_migration_contract_test.dart --no-pub
fvm flutter test --no-pub
```

Expected: all commands pass. If full analysis/test reveals an unrelated known
failure, rerun the isolated failing test and report the evidence; do not call
the feature complete until its acceptance criteria have direct passing
evidence.

**Step 3: Run the private conversion without exposing content**

Create a fresh temporary directory outside the repository with `mktemp -d`.
Run the built CLI commands against the untracked CSV, putting both normalized
and exported files inside that temporary directory. Do not print or inspect
record bodies. Parse only aggregate lengths and verify:

- six profiles;
- 1,000 history rows;
- 3,346 retained bookmarks from 3,347 source favorites;
- ten blacklist rules;
- 132 pinned searches in six folders;
- four export files;
- every nonempty source credential/username cell value is absent from every
  output, checked in-memory without printing those values;
- rerunning to another temporary directory yields byte-identical files.

Keep terminal output limited to filenames, hashes, counts, and pass/fail. Remove
the temporary private outputs after validation using the exact resolved temp
path only. The source CSV remains untouched and untracked.

**Step 4: Verify a synthetic Android import with Maestro**

Use only the committed synthetic artifacts. Target the available emulator
explicitly on every Maestro/ADB operation. Import bookmark, blacklist, and
pinned-search files through the app's existing backup UI and verify visible
bookmark media/details, the active blacklist rule, the folder/search order,
and profile-match preflight behavior. Do not use the private CSV or private
generated output in the emulator, logs, or screenshots.

Record the emulator/device ID, synthetic artifact names, and observed outcomes
in the task's completion evidence. A tool success response without verifying
the visible state is not sufficient.

**Step 5: Perform the five-point review and inspect repository state**

Review the diff against **Review focus** and record the protecting test for
each item in the task file. Then run:

```bash
git status --short
git diff --check
git diff origin/develop...HEAD --stat
git log --oneline --decorate origin/develop..HEAD
```

Expected: only intended source/tests/docs are tracked, the private CSV is the
only expected untracked personal file, no whitespace errors exist, and commit
history is linear.

**Step 6: Complete the task record and commit documentation**

Add concise completion evidence to the task file. Move it to `done` only after
all acceptance criteria, including Maestro, are verified. Stage explicit paths:

```bash
git add docs/migrations/animeboxes.md docs/work/done/MIG-001-animeboxes-export-converter.md
git commit -m "docs(migrations): document AnimeBoxes conversion"
```

If any acceptance criterion remains unverified, keep the task in
`docs/work/in-progress/`, state the remaining check, and do not make a
completion claim.

**Step 7: Request final code review**

Use `superpowers:requesting-code-review` against the complete diff. Apply
technically valid feedback with `superpowers:receiving-code-review`, rerun the
affected focused tests, and then use `superpowers:verification-before-completion`
before presenting delivery options. Do not push or open a pull request without
the user's explicit instruction.
