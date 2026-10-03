# Unified export and import

## Intent

Boorusama has one user-facing data-transfer concept: **Export and import**.
Every export is a `.bsexport` package. A complete export is also the user's
personal backup; a partial export can share selected collections with another
person. There is no separate backup file format and no new standalone JSON
export.

The feature must support both of these examples without giving either one a
special storage path:

- A user chooses **Full export**, saves one file, and can later replace their
  app data from it, including profile credentials.
- A user chooses two bookmark groups and one feed, recommends **Update** for
  one group and **Merge** for the other items, sends the file, and the receiver
  can approve or adjust those actions before importing.

The interactive reference for the visible flows is
[the export and import mockup](../mockups/2026-09-24-backup-sharing-flows.html).

## Goals

- Make a complete personal backup require no category-by-category setup.
- Let people share individual bookmark groups, pinned searches, pinned-search
  folders, and feeds without exposing unrelated data.
- Preserve stable collection identities across devices so repeated imports can
  update or merge the same logical collection.
- Show the complete effect of an import and resolve every problem before the
  first application-data write.
- Recover all affected data if applying an import fails or the app stops during
  the operation.
- Let a received `.bsexport` attachment open directly into Boorusama's import
  review when the operating system preserves its file type.
- Keep reusable export templates local to the device.

## Non-goals

- Continuous or automatic synchronization between devices.
- A cloud account, collection owner, revision server, or conflict history.
- Identity-only or metadata-light bookmark exports. Exported bookmarks always
  include their complete stored `StoredPostSnapshot`.
- Encrypted export packages. A package with credentials is portable plain data
  and must be presented as private.
- Exporting templates, even as part of Full export.
- Creating new standalone JSON exports. Existing JSON and ZIP files remain
  import-only compatibility inputs for formats the app already supports.

## Current system and required change

The current backup registry exposes one JSON file and clipboard operation per
source. Bulk backup asks those sources to write individual JSON files into a
temporary directory and wraps them in a `.zip` with `manifest.json`. The
current complete export can still produce a package when a selected source
failed, profile JSON always contains credentials, and ZIP import reads the
whole archive into memory before extracting it.

Current ZIP and nearby-device import prepare the selected sources before
execution, but then execute them independently. A later source failure can
leave earlier sources applied. Some source-specific importers compensate their
own writes, but there is no package-level atomic boundary. Bookmark-group
conflicts support only Merge or Replace and current Replace does not remove
bookmark records that became unused. Pinned Searches and Following Feeds have
more deliberate profile matching and source-local rollback, but are not part
of a common import plan.

The implementation replaces these parallel paths with one package builder and
one package import coordinator. Existing source codecs and repositories remain
useful behind new source adapters, but UI and orchestration no longer invoke a
source's file or clipboard capability directly.

## User experience

### Entry screen

Settings contains one **Export & import** section with these actions:

- **Export data**
- **Import file**
- **Import from clipboard**
- automatic export settings, if enabled by the existing platform

The clipboard row may say that a Boorusama export was detected by type and
show non-sensitive metadata made available by the platform. Boorusama reads
the clipboard payload only after the user taps the row. If no recognized type
is present, the row remains available and says that tapping it will inspect
the latest clipboard entry.

### Export flow

The first export screen offers:

1. **Full export** — a permanent built-in preset containing every current
   export source and profile credentials.
2. **Choose data** — a selection tree for categories and individual items.
3. Saved user templates — quick export plus edit, duplicate, and delete.

Full export does not show configuration checkboxes. The review screen states
that it contains settings, histories, and credentials and requires one private
data confirmation before creation. Newly registered export sources are always
included in Full export.

Choose data displays collection categories as expandable rows rather than
placing every collection at the top level:

- **Bookmark groups** contains each named group and **No group**.
- **Pinned searches** contains Home searches and folders. Expanding a folder
  shows its searches without changing the folder selection identity.
- **Following feeds** contains the feeds.
- **Booru profiles** contains profiles.
- Settings, histories, tags, downloads, and other registered sources use the
  same selection tree when they expose child entries.

Selecting profiles never silently selects credentials. **Include credentials**
is a separate toggle, enabled only when at least one profile is selected. It
includes API keys, logins, password hashes, cookies or tokens represented by a
profile, and proxy credentials. Without it, those fields are absent or null;
the remaining profile definition and preferences are exported.

Every completed export always offers **Save file** and **Share file**. A small
export without credentials additionally offers **Copy as Base64**. Clipboard
copy is an extra transport, never the only way to obtain the package.

### Selection meaning

Selection nodes have explicit semantics that survive template reuse:

- A checked collection node means **all items in this known collection**. It
  includes user-created children added later, such as a new bookmark group.
- An indeterminate collection node means an explicit frozen set of child
  identities, even when the user happened to select every child that existed
  at the time.
- An unchecked node is excluded.

The state model stores a dynamic collection selector separately from an
explicit identity set; it must not infer one from the number of selected
children.

App-defined selection nodes are different from user-created collection items.
A user template stores the exact app-defined node IDs and schema fields known
when it is saved. A later top-level category or newly selectable settings field
is excluded from that template. No migration prompt or implicit opt-in is
shown. Data fields required to decode an already selected source continue to
follow that source's versioned schema.

### Export templates

A custom export review contains **Save this configuration as a template**.
The save dialog has a name and these actions:

- **Save only**
- **Save & export**

A template stores:

- selected app-defined node IDs;
- dynamic-collection versus explicit-item selectors;
- selected stable item identities;
- whether credentials are included;
- recommended import actions;
- a filename pattern if the UI exposes one.

It stores no exported user data. Templates are app-local preferences and are
excluded from every `.bsexport`, including Full export. Full export is a
built-in live preset, not a template.

### Import entry

The normal import action opens a file picker before any snapshot screen. A
file association or share intent bypasses the picker and opens the same review
flow for the received file. Merely opening a file never applies it.

The flow is:

1. Read and validate the package.
2. Choose categories and items to import.
3. Choose or confirm actions and profile mappings.
4. Run comprehensive preflight and show the exact planned changes.
5. Apply only after the user confirms.

A valid package card displays **Valid**. A clean preflight displays only
**All checks passed** plus the planned-change summary. Explanatory detail is
shown only for warnings and errors.

### Import actions

Whole-value sources, such as app settings and a history, support:

- **Replace** — replace the selected local source with the exported value.
- **Skip** — leave it unchanged.

Collection categories support:

- **Replace entire category** — make that category equal to the complete
  category represented in the export. Local items absent from it are removed.
- **Configure items individually** — expose the actions below for each item.
- **Skip category** — make no change to it.

`Replace entire category` is available only when the package declares that its
selection is complete for that category. A partial export cannot claim that
unexported items should be removed.

An individual collection item supports only actions that are meaningful for
the detected local state:

- **Update matching item** appears when the stable identity exists locally.
  It makes the local definition and membership mirror the exported item.
- **Merge with matching item** appears when the stable identity exists. It
  keeps the local identity and local-only members while adding exported
  members.
- **Merge into another item…** appears only when a compatible local target
  exists and opens a required target picker.
- **Import as a new copy** assigns a new UUID to identity-bearing collections.
- **Skip** makes no change.

The default for the same UUID is **Update matching item**. An export may embed
sender-recommended actions, including Replace or Merge. These are untrusted
recommendations used to preselect the review controls; they never bypass
preflight, private-data warnings, or the receiver's final confirmation.

For example, an export can recommend Update for the `Inspiration` bookmark
group and Merge for `Favorite artists`. A receiver who already has those UUIDs
sees both recommendations selected, can change either one, then confirms one
plan. A receiver without `Inspiration` sees Import as new using the preserved
UUID instead of an inapplicable Update control.

### Replacement wording

The review explains replacement in terms of its selected boundary:

> Replace makes the selected category match this export. Current items in that
> category that are absent from the export are removed. Skipped categories and
> items are unchanged. Boorusama creates a rollback checkpoint before applying
> anything.

This text is not shown during export because exporting does not change current
data.

## Identity and source behavior

### Bookmarks and bookmark groups

The new format assumes the bookmark identity migration lands first. The
portable identity is:

`(booru type, normalized source site, post ID)`

The site is required because two sites using the same engine can assign the
same post ID. Profile IDs and media URLs are not bookmark identity. Legacy
imports continue through a compatibility adapter that can read their historic
URL identity, but all newly created `.bsexport` packages use the post identity.

Every exported bookmark includes its complete `StoredPostSnapshot`; there is
no empty or deferred bookmark state. A bookmark referenced by several selected
groups is stored once and referenced by identity.

Bookmark groups keep their UUID across devices. Names are display data, not
identity. **No group** is a selection and import boundary, not a stored group
with a synthetic UUID.

- Update mirrors the exported group's name, order, and exact membership.
- Merge with the match keeps the local UUID and local display name and unions
  membership in local order followed by exported-only members.
- Merge into another group keeps the target's UUID, name, and existing order.
- Import as copy assigns a new UUID and uses the exported name.

When Update removes a bookmark from a group, it behaves like the equivalent
manual membership edit. If the bookmark then belongs to no other group, it is
deleted from the bookmark library; it must not unexpectedly appear under No
group. Bookmarks that were already ungrouped or are not affected by the
updated group remain unchanged.

### Pinned searches and folders

An independent pinned search is matched by:

`(resolved portable profile, normalized query)`

Whitespace normalization follows the live pinned-search duplicate rule.
Pinned-search UUIDs may remain in the source payload as file-local references
for folder and Home ordering, but they are not cross-device conflict identity.
If the same search already exists, import silently reuses it and retains its
runtime state. The summary may say, for example, **3 searches already present**;
there is no conflict row or cancel choice for those searches.

Pinned-search folders retain stable UUIDs and therefore support Update, Merge,
Merge into another folder, Import as copy, and Skip. Update mirrors name,
position, and exact ordered membership. Merge retains the local name and order
and appends exported-only searches. Home is a special ordered destination,
not a UUID-bearing folder.

Export and import continue to exclude previews, caches, NEW state, checkpoints,
attempts, errors, and creation timestamps. Newly created searches establish a
baseline through the existing explicit or automatic refresh behavior.

### Following feeds

Feeds keep their UUID across devices and are scoped to a resolved portable
profile. Update mirrors the name, order, and exact ordered query membership.
Merge retains the local name and existing source order and appends unique
exported queries. Merge into another feed retains the target UUID and name.
Import as copy assigns a new UUID.

Existing internal searches for unchanged profile/query identities retain
their runtime state. Removed searches are deleted only when no other feed
references them. Feed caches are invalidated only when membership changes, as
in the current feed import contract.

### Profiles and credentials

A portable profile reference contains its exported stable reference, booru
type, normalized URL, and display name. Matching tries the same local profile
ID with compatible booru type and URL, then a unique compatible profile by
booru type and normalized URL. The display name is descriptive only.

When a referenced profile has no match:

- exactly one compatible local profile is selected automatically;
- several compatible profiles require the user to choose one;
- an exported profile selected for import can be used as the dependency;
- otherwise the user may create a credential-free profile from the portable
  definition, map to a compatible profile, skip every dependent item, or stop.

No dependent record is applied while its mapping is unresolved. Profile
credentials are never inferred from a portable reference.

Profile Update mirrors all exported fields. A credential-free imported
profile leaves existing local credentials unchanged when updating a match and
creates an unauthenticated profile when creating a new one. An export that
contains credentials makes credential replacement explicit in the change
summary.

### Other sources

Settings, tags, histories, downloads, and future sources declare their own
stable source ID, schema version, selection tree, dependencies, and supported
actions through the common adapter contract. A source without item-level merge
semantics exposes only Replace and Skip.

## `.bsexport` package

### File type

- Extension: `.bsexport`
- MIME type: `application/vnd.boorusama.export`
- Apple UTI: `com.timberpile.boorusama.export`
- Container: ZIP

Saved, directly shared, automatic, and Nearby export files use
`boorusama-YYYY-MM-DD_HH-mm-ssZ.bsexport` (UTC). Saving or automatically
exporting into a directory with an existing name adds `-2`, `-3`, and so on
before the extension rather than overwriting the existing file.

The archive is an implementation container, not a user-visible ZIP export.
Renaming a legacy `.zip` does not make it a valid `.bsexport`.

### Layout

```text
manifest.json
sources/
  profiles/data.json
  bookmarks/data.json
  pinned_searches/data.json
  following_feeds/data.json
  ...
```

`manifest.json` version 1 contains:

```json
{
  "format": "boorusama-export",
  "formatVersion": 1,
  "exportId": "7e307c25-7b35-46b0-ae1c-60c78f09d229",
  "createdAt": "2026-10-01T12:00:00Z",
  "appVersion": "1.2.3",
  "preset": "full",
  "containsCredentials": true,
  "sources": [
    {
      "id": "bookmarks",
      "schemaVersion": 3,
      "selection": {"kind": "all"},
      "parts": [
        {
          "path": "sources/bookmarks/data.json",
          "sha256": "...",
          "byteLength": 123456,
          "itemCount": 142
        }
      ],
      "recommendedAction": "replace"
    }
  ]
}
```

The manifest never contains a template. It records whether each collection is
complete or explicitly selected so the importer can reject an invalid Replace
entire category action. Recommended actions can also be stored per item by
stable identity.

Every payload part has a SHA-256 digest and exact uncompressed byte length.
Paths are normalized relative paths under `sources/`. Unknown manifest fields
are ignored within the same format version; unknown sources are shown as
unsupported and cannot be selected.

### Size and parts

Version 1 normally uses one JSON payload per source. Bookmark snapshots can be
large, but splitting them before a demonstrated limit would complicate
references and atomic validation without reducing the amount imported.

The manifest uses a `parts` list from the start so a later source schema may
chunk data without changing the container version. Package creation streams
source payloads to temporary files and streams them into the ZIP. Import
streams validated entries to an app-private staging directory. Neither path
loads the complete archive into memory.

Archive limits reject path traversal, duplicate paths, encrypted entries,
unsupported compression, an excessive file count, entries larger than their
declared limits, and unreasonable compressed-to-uncompressed ratios.

### Export completeness

Package creation captures one logical read snapshot per source, writes every
selected source, computes hashes, and only then atomically renames the finished
temporary package to its requested filename. If any selected source fails,
creation fails and no usable package is published. A Full export therefore
cannot quietly be a partial backup.

## Clipboard transport

Clipboard export Base64-encodes the exact `.bsexport` bytes. Decoding the text
must reproduce a byte-identical valid package. The clipboard item advertises
`application/vnd.boorusama.export`; Apple platforms additionally use the
custom UTI. A short plain-text prefix identifies the encoding version before
the Base64 body so an app without custom-type access can still validate after
the user taps import.

Clipboard copy is unavailable when the package contains credentials or exceeds
a conservative platform-independent encoded-size limit. The first
implementation uses 1 MiB of Base64 text as that limit. Save and Share remain
available in both cases.

## Operating-system file handling

Android registers `ACTION_VIEW` and `ACTION_SEND` filters for the custom MIME
type and accepts a readable `content:` URI. Export sharing grants temporary
read permission and supplies the custom MIME type through the existing file
provider. An invisible exported activity receives file intents and forwards the
URI, with its read grant, into Boorusama's own task. The Flutter activity never
receives the `content:` URI as navigation data; its file channel copies the
stream into app-private staging before review because URI access can be
transient. The receiver must create URI ClipData without querying the external
provider for its MIME type, and dismiss malformed or ungranted intents without
crashing. The handoff handles both cold-start and `singleTop` delivery. Keep
the Flutter activity in `singleTop` mode because `singleTask` disrupts billing.

Android attachment handlers are primarily matched by MIME type, and messaging
or file-manager apps can replace an unknown type with
`application/octet-stream`. Boorusama does not register as a handler for every
octet-stream file. Therefore direct open works when the sender preserves the
custom type; the in-app **Import file** picker remains the reliable fallback
and validates the `.bsexport` contents rather than trusting its extension.

iOS and macOS export the custom UTI, associate `.bsexport` and the MIME type,
and list it in supported document types. Incoming document URLs are copied to
private staging and routed to the same review. The type conforms to
`public.content` and `public.data`, allowing Files and AirDrop to represent it.
Desktop registrations use the same MIME/extension contract where supported.

## Import architecture

### Adapter contract

Each source registers an `ExportImportSource` with these responsibilities:

- describe its localized selection tree and sensitive fields;
- capture an immutable export snapshot for a resolved selection;
- encode and decode its versioned payload;
- validate the complete selected payload without writes;
- report dependencies and portable identities;
- plan supported actions against a supplied target-state snapshot;
- capture rollback state for the affected boundary;
- apply an immutable resolved plan;
- restore its rollback state idempotently;
- summarize counts and planned changes.

UI widgets do not contain source business logic. Manually declared Riverpod
Notifier or AsyncNotifier state owns the export and import workflows.

### Package import stages

The coordinator uses immutable values between stages:

```text
received file
  -> staged package
  -> decoded package
  -> user selection
  -> proposed action plan
  -> resolved action plan
  -> validated execution plan
  -> rollback checkpoint
  -> applied import
```

Changing a selection, action, target, or profile mapping invalidates the later
stages and reruns planning. The Apply button accepts only the exact validated
plan revision; it cannot recalculate against newer state behind the review.
Immediately before writing, the coordinator confirms that repository
revisions used by planning are unchanged. A change returns to preflight rather
than applying a stale plan.

### Comprehensive preflight

Before any application-data write, preflight checks:

- container version, archive safety, declared sizes, and every digest;
- each selected source version and complete nullable field parsing;
- duplicate or malformed identities and references;
- cross-source dependencies and selected profile results;
- whether every requested action is supported and every merge target exists;
- whether complete-category replacement is legal for the exported selection;
- credential presence and the requested credential effect;
- expected creates, updates, deletions, preserved records, and no-op records;
- available staging and rollback storage;
- source repository readiness and captured revision tokens;
- whether a durable rollback checkpoint can be created.

Errors disable Apply and explain the required resolution. Warnings require an
explicit acknowledgement. Identical records are no-ops, not warnings.

Example: importing Pinned Searches without their referenced profile is an
error until the user maps the profile, includes its exported profile, or skips
all affected searches. If exactly one compatible local profile exists,
preflight selects it and reports it in the planned changes without asking.

### Apply and rollback

The coordinator serializes import with other mutations. Before the first
application-data write it creates an app-private durable transaction directory
containing:

- the validated plan and repository revision tokens;
- rollback payloads for every affected source;
- an ordered journal of started and completed source steps;
- hashes for the plan and rollback payloads.

Sources apply in dependency order; profiles precede profile-dependent data.
After every source step, the journal is flushed. On any error, completed and
started sources restore in reverse order. Rollback restores the full affected
state, including definitions, memberships, ordering, caches, positions, and
runtime records that a source mutation may have removed.

If the process stops, startup detects the incomplete journal and finishes
rollback before normal data access. A successfully applied import deletes the
checkpoint only after repositories and required app reload state are durable.
If rollback itself fails, the checkpoint is retained and normal mutation of
the affected sources remains blocked while the recovery screen offers Retry
and preserves diagnostic details. It never reports a partial import as
success.

This is an application-level durable transaction. It does not require every
repository to share one database transaction, but it gives the user all-or-old
state across the selected package.

## Compatibility and migration

- Existing `.zip` bulk backups remain importable through a clearly labeled
  legacy picker path or automatic file sniffing. They are converted to the new
  in-memory plan and receive the same preflight and rollback behavior wherever
  their source data can express it.
- Existing supported per-source JSON files remain importable through legacy
  file sniffing, but Boorusama no longer creates them and does not offer JSON
  clipboard export.
- Existing automatic backup settings begin producing Full `.bsexport` files.
  The automatic-backup manifest accepts both `.zip` and `.bsexport` entries so
  retention can age old files out normally.
- The current source format versions remain decoder inputs. New `.bsexport`
  source schema versions are incremented only where identity or selection
  metadata changes, including bookmark post identity.
- Nearby device transfer may remain available, but it transfers one generated
  `.bsexport` package and sends it through the same receiving coordinator. It
  no longer exposes independent source endpoints as the user contract.

## Security and privacy

- Package fields never include export templates or ephemeral provider state.
- Credential-free profiles are encoded by an explicit sanitizer, not by
  post-processing arbitrary JSON keys.
- Logs contain source IDs and counts, not payload values, queries, URLs with
  user info, credentials, clipboard bodies, or bookmark metadata.
- Package filenames and review summaries do not reveal credential values.
- Incoming archives are treated as untrusted data and staged under bounded
  limits before parsing.
- Sender-recommended destructive actions are never automatically confirmed.
- Clipboard metadata inspection is best effort and does not read the payload
  until user action.

## Validation strategy

### Contract and unit tests

- Manifest round trip, forward-compatible fields, bad versions, bad hashes,
  duplicate paths, traversal, oversized entries, and compression limits.
- Selection trees distinguish dynamic all-items rules from explicit complete
  child sets and freeze future app-defined nodes in user templates.
- Full export always includes newly registered sources and credentials; custom
  profiles omit credentials unless selected.
- Export failure publishes no package.
- Clipboard Base64 round trips byte-for-byte and rejects credential-bearing or
  oversized packages.
- Bookmark matching uses booru type, normalized site, and post ID; identical
  post IDs on two sites stay distinct.
- Bookmark group Update deletes newly orphaned bookmarks and does not create
  ungrouped leftovers; Merge preserves local-only membership.
- Identical pinned searches are silently reused by profile/query, including
  folder membership remapping.
- Folder and feed Update, Merge, Merge into target, Copy, and Skip preserve the
  defined identities and runtime state.
- Exactly one compatible profile auto-maps; zero and ambiguous matches remain
  unresolved.
- Recommended actions preselect controls but cannot bypass invalid-action or
  target checks.
- A stale repository revision invalidates a previously checked plan.
- Failure at every apply step restores every earlier affected source. Startup
  recovery completes rollback from every journal boundary.

### Widget tests

- Full export needs only the private-data confirmation and includes credentials.
- Choose data exposes credentials separately and renders checked,
  indeterminate, and unchecked parent states correctly.
- Bookmark groups, Pinned Searches, folders, No group, and feeds expand under
  their categories.
- Item actions appear only when their match or target exists.
- A clean preflight says only All checks passed; warnings and errors show
  details and block or gate Apply.
- Template Save only and Save & export work, and templates never appear in Full
  export contents.
- Clipboard detection and undetected fallback use the same import review.

### Integration and platform tests

- Stream creation and import of a large bookmark package stay within a bounded
  memory budget.
- File picker, share sheet, cold-start open, and warm `singleTop` open route the
  same `.bsexport` into review on Android.
- iOS/macOS document type registration opens a package through the same route.
- A messaging app that preserves the custom MIME type can send an attachment
  directly into Boorusama; a stripped MIME type remains importable through the
  file picker.
- Automatic exports use `.bsexport`, include every current source and
  credentials, and retain legacy ZIP history until normal cleanup.
- Android visible flows are verified with the repository's Maestro emulator in
  addition to automated tests.

## Delivery sequence

Implementation is split into reviewable vertical foundations, each keeping the
app buildable:

1. Define package, selection, template, and plan domain contracts with tests.
2. Add streaming package creation/reading and archive validation.
3. Adapt sources to snapshot, validate, plan, apply, and roll back; migrate
   bookmark identity before enabling new bookmark packages.
4. Add the durable package transaction coordinator and startup recovery.
5. Build the unified export flow, templates, credential sanitizer, file/share,
   and clipboard output.
6. Build import selection, action resolution, profile mapping, preflight, and
   result screens.
7. Add Android and Apple file-type/intent handling and route received files.
8. Move automatic and nearby-device transfer to `.bsexport`, retain legacy
   import compatibility, and remove new-output JSON/ZIP paths.
9. Complete focused, full-suite, memory, and Maestro validation before removing
   the old user-facing entry points.

## Acceptance criteria

- Every newly created export is a valid `.bsexport`; no UI creates standalone
  JSON or legacy ZIP exports.
- Full export includes every current export source and credentials without
  further configuration and fails rather than publishing a partial package.
- Custom export can select individual collection items and profiles with or
  without credentials.
- Parent selection and saved templates retain dynamic-all versus explicit-item
  semantics; existing templates never gain new app-defined entries.
- Templates are local-only and support Save only and Save & export.
- Every export can be saved and shared; eligible packages can also be copied as
  Base64 with the custom clipboard type.
- File picker, supported file association, and clipboard input all enter the
  same import review.
- Receiver actions include applicable Update, Merge, Merge into target, Copy,
  Replace, and Skip choices; same UUID defaults to Update.
- Identical pinned searches are reused without a conflict prompt.
- Import performs all parsing, identity, dependency, target, storage, and
  rollback checks before changing application data.
- An apply failure or interrupted process restores the complete affected state.
- Bookmark-group Update removes bookmarks orphaned by that update instead of
  leaving them under No group.
- Clean validation is concise; only warnings and errors add explanatory text.
