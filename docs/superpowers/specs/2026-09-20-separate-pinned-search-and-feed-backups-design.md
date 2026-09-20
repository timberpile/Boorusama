# Separate Pinned Search and Following Feed backups

## Intent and scope

Pinned Searches and Following Feeds are separate user-facing features, so users
can export, import, and select them independently. A complete backup includes
both. This change separates their backup contracts and import flows; it does
not change the live search or feed storage model.

Neither backup format has shipped. Each starts at source format version 1. The
experimental combined `pinned_searches` version 4 format is deliberately
unsupported: importing it reports an invalid or unsupported source format.
There is no v4 migration. The ZIP manifest retains its own version 1.

## Sources and file contracts

Register two `JsonBackupSource` entries:

| Source ID | User-facing entry | Contents |
| --- | --- | --- |
| `pinned_searches` | Pinned Searches | Independent pins, named folders, Home membership and order |
| `following_feeds` | Following Feeds | Feed definitions and ordered query lists |

Each source produces its own file, clipboard payload, and device-transfer
endpoint using the existing source ID convention. A complete ZIP has one
manifest entry and one file for each selected source. The backup picker shows
the two entries separately and gives each its own count and import/export
result text. Counts for Pinned Searches exclude feed-internal searches; counts
for Following Feeds count feeds, not their member queries. All new visible
strings use localization resources.

Each JSON envelope requires `source` equal to its source ID and `version: 1`.
The existing `date`, `exportVersion`, and `data` fields retain their current
meanings. The source codec checks both `source` and source-format `version`
before accepting rows. The existing app-version compatibility check remains
separate. A missing or wrong source, a version other than 1, a legacy bare
array, or a mixed row type is rejected before any import write. This also
prevents a Feeds file from being accepted through the Pinned Searches picker,
or vice versa.

The Pinned Searches `data` list contains explicit `search`, `folder`, and
`organization` rows. It contains no `feed` row or feed-internal search. Search
rows retain their UUID, optional name, query, position, and portable profile
reference. Folder rows retain UUID, name, position, and ordered member search
IDs. One organization row retains ordered Home search IDs. Export filters
folder and Home references to the exported independent pins.

The Following Feeds `data` list contains only `feed` rows. Each has a feed UUID,
name, position, portable profile reference, and ordered query strings. The
exporter walks each feed's `sourceIds` in order to obtain its queries. It does
not export internal search IDs, post IDs, cached posts, thumbnails, refresh
checkpoints, errors, or NEW state. Both source formats permit an empty `data`
list where appropriate; an empty pinned export still records its organization.
Malformed UUIDs, references, profile data, names, positions, or query lists are
rejected before import. A feed requires 1 to 1000 nonblank queries; query
identity is normalized and duplicate queries collapse in first-seen order,
matching the live feed model.

## Components and profile matching

Keep separate data models, codecs, backup sources, import services, and result
counts for the two features. Extract only the portable profile reference,
normalization, and matching rule into a small shared backup helper. Both
imports match the same profile ID **and** booru type and normalized site URL
first. If that fails, they accept exactly one profile with the same booru type
and normalized URL. Profile name is descriptive, not identity. Missing or
ambiguous matches are unresolved.

The shared helper does not make a pin depend on a feed or vice versa. Their
runtime repository may remain shared. In particular, importing a standalone
pin for a query used in a feed must create or reuse an independent pin; it must
not attach the visible pin to the feed's internal search or share its NEW state.

For a standalone source import, preview unresolved profiles before changing
that source. In a ZIP or device transfer that selects both sources, preview
both against the profiles that the selected import will leave in place and
show one confirmation with separate pin and feed skip counts. Confirming skips
only the affected records; canceling stops the selected import before writes.
A headless import with unresolved profiles fails instead of silently dropping
records. Recheck the unresolved sets before applying an approval so a profile
change between preview and execution cannot import a different set of rows.

## Import behavior

Pinned Search import keeps its existing merge behavior for independent pins
and folders: it maps imported pin IDs into Home and folder membership, reuses
an existing independent pin by ID or normalized query, and retains local
runtime state for reused pins. A feed-internal search is never a candidate for
this reuse. The pinned import cannot create, rename, delete, or reorder feeds.

Following Feed import is definition-based. For each resolved profile:

- A feed with the same UUID and target profile is **replaced** with the imported
  name, order, and complete query list. This includes removing queries absent
  from the file; it is not a union of old and imported queries.
- A feed with a different UUID remains separate even when its name or queries
  match. The importer does not merge feeds by name.
- A UUID already owned by a different profile is an explicit feed import
  conflict. The importer detects it before any feed record is written and
  fails that source; it must not overwrite the local feed or silently create
  repeated duplicates on later imports.
- To place feeds within each profile, remove the imported feed IDs from the
  local order, then insert imported rows by ascending exported position and
  backup row order. Clamp each insertion to the available list length and
  place it after any imported row already inserted at that position. Local
  feeds absent from the backup retain their relative order. Renumber the
  resulting positions from zero.

For a replacement, existing internal searches for unchanged query identities
are reused with their runtime state, including NEW. New queries get new
internal searches with no NEW state. Removed internal searches are deleted only
if no other feed references them. Independent visible pins are unaffected.
The feed's cached recent posts are invalidated when its query membership
changes and retained when only its name or position changes. Feed NEW remains
derived from its current member searches; import does not synthesize NEW.

Validate an entire source payload before applying any record. A failed
replacement restores that feed's previous definition, cache, and internal
source membership. The import as a whole need not be one transaction across
all feed records: if a later record fails, earlier successful records may
remain and the source reports failure. Result counts distinguish created or
replaced feeds, already identical feeds, and feeds skipped for unresolved
profiles.

## Orchestration and errors

ZIP and device-transfer import prepare selected sources before writing. If
profiles are selected, prepare and import them first so both dependent sources
map against the intended profile set. A failed profile import prevents both
Pinned Searches and Following Feeds from executing; unrelated prepared sources
may continue. A failure in either dependent source is reported for that source
and does not block the other. Preparation failure for one source likewise does
not invalidate the other source's prepared payload. A user cancellation during
the shared profile preflight stops the selected import before any writes.

An older ZIP without `following_feeds` can still import its unrelated valid
sources. Its experimental v4 `pinned_searches` entry is reported as unsupported
rather than migrated or treated as a version 1 pin file. Source-format errors
should identify the selected feature and the reason; they must not appear as a
successful zero-item import.

## Verification

- Codec tests cover independent round trips, source and version checks,
  rejection of v4, cross-source files, mixed rows, and malformed references.
- Import tests cover portable profile matching, missing and ambiguous profiles,
  separate pin and feed counts, feed replacement after changed queries,
  repeated imports, same-name feeds, wrong-owner UUID conflicts, query order,
  preservation of shared internal searches, and failed replacement rollback.
- ZIP and device-transfer tests cover separate source selection, both sources
  in a complete backup, profile-first preflight, profile failure, and
  independent failure of either dependent source.
- UI tests cover separate backup entries, localized counts, and the combined
  unresolved-profile confirmation. Manual Android verification uses the
  available emulator for the visible picker and import dialogs.

No migration of the experimental v4 payload, runtime cache export, or change
to search-refresh behavior is included.
