# AnimeBoxes Export Converter Design

## Purpose

Add a repository-native command-line migration tool that turns an AnimeBoxes
CSV export into a readable, versioned JSON document and then converts that
document into Boorusama-compatible bookmark, blacklist, and pinned-search JSON
exports.

The converter is intended for an auditable private migration. It does not add
an AnimeBoxes importer to the Flutter application and does not migrate
profiles or search-history databases.

## Source analysis

The analyzed AnimeBoxes 2.0.7 export uses format version 1.0 and contains six
fixed-width sections:

| Section | Records | Shape |
| --- | ---: | --- |
| Metadata | 1 | 10 columns |
| Servers | 6 | 19 columns |
| History | 1,000 | 10 columns |
| Favorites | 3,347 | 39 columns |
| Tag blacklist | 10 | 8 columns |
| Home pins | 138 | 11 columns |

The favorite records contain 3,346 logical site-and-post identities. One
Danbooru identity occurs twice with different media and metadata revisions;
the later post revision is retained. All favorite records have the required
post URL, sample URL, preview URL, file URL, tags, MD5, and favorite-added
timestamp.

The home-pin section contains 132 searches in six folders. Every search has a
valid folder reference. The history contains 1,000 rows and 999 unique query
strings.

Some server rows contain plaintext usernames and API credentials. The source
CSV and every generated file are private migration data and must remain
untracked. Credentials and usernames are not written to normalized JSON,
diagnostics, tests, logs, or Boorusama exports.

## Scope

The first version:

- Parses every known section from AnimeBoxes Android export format 1.0.
- Produces a credential-free normalized JSON representation of every section.
- Produces separate Boorusama JSON exports for bookmarks, blacklisted tags,
  and pinned searches.
- Produces a machine-readable conversion report.
- Uses synthetic fixtures for all committed tests.

The first version does not:

- Generate or import Boorusama profiles.
- Copy usernames, API keys, password hashes, cookies, or raw authorization
  parameters.
- Generate the SQLite search-history backup used by Boorusama.
- Generate a bulk backup ZIP.
- Add an import flow or other behavior to the Flutter application.
- Fetch posts or other data from remote booru servers.

## Command-line interface

The existing repository CLI gains an `animeboxes` command with two
subcommands:

```text
boorusama animeboxes normalize --input <animeboxes.csv> --output <normalized.json>
boorusama animeboxes export --input <normalized.json> --output-dir <directory>
```

`normalize` validates and converts the source CSV. `export` accepts only the
normalized document, making the reviewed JSON the auditable boundary between
the external format and Boorusama formats.

Successful commands print counts and the paths they created. Expected input
errors print a concise, secret-safe message to standard error and return a
non-zero exit code. `normalize` writes a temporary sibling and renames it only
after complete encoding. `export` requires a target directory that does not
already exist, writes every artifact into a temporary sibling directory, and
renames the directory only after every artifact is complete. A failed command
therefore leaves no partial target.

The export command creates deterministic filenames:

- `boorusama_bookmarks.json`
- `boorusama_blacklisted_tags.json`
- `boorusama_pinned_searches.json`
- `conversion_report.json`

## Components

Implementation lives under
`packages/boorusama_cli/lib/src/migrations/animeboxes/`:

- `AnimeBoxesCsvReader` recognizes section markers, validates record widths,
  and parses positional values into typed source records.
- Source record types describe metadata, servers, history, favorites,
  blacklist rows, folders, and pinned searches without depending on Flutter.
- `AnimeBoxesNormalizer` maps engines, names fields, removes sensitive values,
  resolves duplicate favorites, and returns a normalized document plus
  diagnostics.
- Normalized value types and `AnimeBoxesDocumentCodec` own normalized schema
  version 1 and its JSON representation.
- `BoorusamaMigrationExporter` converts a normalized document into the three
  supported Boorusama backup envelopes and a report.
- `AnimeBoxesCommand` owns arguments, file handling, summaries, and exit codes.

These units have no network access. Parsing, normalization, encoding, and file
I/O remain separate so the data rules can be tested without subprocesses or
temporary filesystem setup.

## Normalized document

The root object is:

```json
{
  "schema": "boorusama.animeboxes.normalized",
  "version": 1,
  "source": {},
  "profiles": [],
  "searchHistory": [],
  "bookmarks": [],
  "blacklist": [],
  "pinnedSearchFolders": [],
  "diagnostics": []
}
```

### Source

`source` records the AnimeBoxes format version, application name, application
version, and export timestamp. Timestamps are emitted as ISO 8601 strings with
their source offsets retained.

### Profiles

Each profile contains its AnimeBoxes identifier, display name, normalized URL,
mapped engine name, and non-sensitive behavioral settings. Sensitive fields
are replaced by booleans such as `loginPresent` and `credentialsPresent`.
Neither the original value nor a hash of it is retained.

Engine mapping is based on the supported site rather than trusting only the
AnimeBoxes numeric engine field:

| Site family | Boorusama engine | Current type ID |
| --- | --- | ---: |
| Danbooru and Donmai | `danbooru` | 20 |
| Gelbooru.com | `gelbooru` | 21 |
| Rule34 and Realbooru | `gelbooruV2` | 23 |
| Konachan | `moebooru` | 24 |

An unknown host or disagreement between the numeric type and known host is an
input error. This prevents a valid-looking export from assigning posts to an
incorrect engine.

### Search history

Search history keeps every source row in source order, including repeated
queries. It stores the query, timestamp, and available flags. It is retained
for readability only and is not included in a Boorusama artifact in this
version.

### Bookmarks

Each normalized bookmark contains:

- Source profile reference, normalized site, and upstream post ID.
- Post page URL.
- Preview, sample, original file, and optional JPEG media variants with their
  dimensions.
- All tags and available general, artist, copyright, and character subsets.
- MD5, external source, optional parent ID, score, rating, and favorite-added
  time.
- Notes/translation, comments, and parent-or-child data. Video is inferred
  from the media format.
- Its original source position for stable ordering and diagnostics.

Empty optional values are represented as `null` or omitted according to the
field contract. Positional CSV arrays and unused trailing columns are not
copied into the normalized document. A non-empty value in a currently unused
column is rejected so data cannot be silently discarded.

### Blacklist

Blacklist entries retain their rule text and source order. AnimeBoxes does not
provide per-rule timestamps in this export, so normalization records that the
source export timestamp supplies the later Boorusama timestamps.

### Pinned searches

Folders contain their searches directly in source order for readability. Each
search retains its stable source UUID, query, optional display name, normalized
site URL, and mapped engine name. Folder UUIDs and memberships are validated
before the document is emitted.

### Diagnostics

Diagnostics use stable codes and counts. They may identify a section and row
number but never echo query strings, tag lists, URLs with query parameters,
usernames, or credential material. Version 1 records:

- The number and kind of sensitive fields omitted.
- Duplicate bookmark identities and which source position won.
- Normalizations that change representation without losing meaning.
- Records intentionally retained without a Boorusama target, such as history.

## Bookmark export

The bookmark artifact uses Boorusama bookmark backup version 2. It contains a
versioned `StoredPostSnapshot` for each normalized bookmark.

- Bookmark `localId` values are sequential and deterministic in retained
  source order.
- `postId` is the upstream AnimeBoxes post ID.
- Bookmark `createdAt` and `updatedAt` use the AnimeBoxes `dateAdded` value.
- Snapshot `createdAt` is omitted because the export does not contain the
  upstream post creation time.
- Origin uses the mapped current Boorusama type ID and normalized source host.
  It omits `profileIdHint` because no Boorusama profile is generated.
- Common data preserves media URLs, dimensions, format, MD5, tags, rating,
  flags, source, and score. Its file size is `0` because AnimeBoxes does not
  export one, and its duration is Boorusama's unknown-duration value.
- `hasParentOrChildren` is true when AnimeBoxes reports children or provides a
  parent ID. The parent ID is retained when present.
- Engine-specific custom data is empty and does not invent fields unavailable
  in AnimeBoxes. Boorusama can therefore display cached common data through
  its safe generic fallback when a native payload cannot be reconstructed.
- Every bookmark is assigned to one `AnimeBoxes` bookmark group. The export
  omits the group ID so every import creates a fresh group instead of
  conflicting with an existing group identity.

Favorite identity is the normalized site plus upstream post ID. When repeated,
the record with the latest valid `dateAdded` wins; source position breaks an
exact timestamp tie. The analyzed duplicate therefore resolves to its newer
Danbooru revision. The decision is reported without including media URLs or
tags.

## Blacklist export

The blacklist artifact uses Boorusama blacklisted-tags backup version 1. Each
entry receives a sequential deterministic ID, remains active, and uses the
source export timestamp for `createdDate` and `updatedDate`. No blacklist rule
is merged or rewritten.

## Pinned-search export

The pinned-search artifact uses source `pinned_searches` and backup version 1.

- Existing valid source UUIDs are retained.
- Folder and search positions follow source order.
- Folders retain their complete membership.
- The organization row contains searches that were not assigned to a folder;
  it is empty for the analyzed export.
- Profile references use the source profile ID, mapped engine name, normalized
  URL, and non-sensitive profile name.

No profile is created. During import, Boorusama's existing preflight matches by
engine and normalized URL, preferring the supplied ID when available. Its
existing confirmation flow offers to skip searches whose profile does not
match an installed profile.

## Validation and failures

Normalization rejects:

- A missing or repeated known section.
- A source format other than AnimeBoxes Android 1.0.
- Incorrect row widths.
- Invalid required integers, booleans, URLs, ratings, or timestamps.
- Missing required bookmark media or identity fields.
- Unknown engines or inconsistent site-and-engine mappings.
- Duplicate folder or search UUIDs.
- Missing or repeated folder membership references.
- Non-empty data in an unmapped column.

Export rejects:

- A root schema name other than `boorusama.animeboxes.normalized`.
- A normalized schema version other than 1.
- Invalid normalized field types or relationships.
- Duplicate bookmark output identities or local IDs.
- Any sensitive-value field not defined by the credential-free schema.

Validation collects no more data than needed to locate an error. Commands do
not dump source rows or exception objects that could contain secrets.

## Testing

Committed tests use synthetic data only. Coverage includes:

- A complete six-section CRLF export.
- CSV quoting, embedded commas, Unicode, and empty optional cells.
- Credential and username redaction from normalized JSON, reports, and command
  output.
- Missing, repeated, malformed, and unsupported sections and rows.
- Host and engine mapping.
- Duplicate bookmark selection and deterministic local IDs.
- Image, GIF, MP4, and WebM media mapping.
- Short and long rating normalization.
- Optional tag-category and source data.
- Blacklist activation and timestamp policy.
- Folder membership, order, and unmatched-profile references.
- Normalized JSON encode/decode round trips.
- Golden Boorusama envelopes.
- Parsing generated artifacts with Boorusama's actual bookmark, blacklist, and
  pinned-search codecs.
- Atomic file output and non-zero command failures.

Validation runs the CLI package tests, focused Flutter backup contract tests,
the relevant full suites, formatting, and static analysis. A small synthetic
dataset is imported on Android through Maestro to verify the user-visible
backup flow. The real export is used only locally to generate private output
and compare aggregate counts; it is never a committed fixture or screenshot
source.

## Repository and privacy handling

The provided CSV and generated migration outputs stay untracked. Git staging
uses explicit paths. Tests and documentation contain aggregate counts only.
No command logs source rows, and no remote service is contacted during
conversion or validation.
