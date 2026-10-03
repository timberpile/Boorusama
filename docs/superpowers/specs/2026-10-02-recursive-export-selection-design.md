# Recursive export selection design

## Goal

Make large custom exports understandable without limiting future bookmark,
pinned-search, or feed organization to a fixed number of folder levels. Reuse
the same hierarchy for optional import recommendations and keep the current
`.bsexport` container model.

## Scope

- Render exportable collections through one recursive selection tree.
- Group pinned searches by their current folder, including Home when nonempty.
- Show a subdued, right-aligned profile name for pinned searches and following
  feeds.
- Render suggested import behavior with the same recursive hierarchy.
- Preserve folder structure when only some searches in a folder are exported.
- Simplify template naming to `Save as template` with `Cancel` and `Save`.
- Reject loose legacy JSON files in the unified import flow.
- Never show an empty `Problems to resolve` section, and do not require warning
  acknowledgement for a plan that performs no writes.

## Non-goals

- No user-visible undo after a successful import.
- No import history or retained successful rollback snapshots.
- No implementation of nested bookmark, pinned-search, or feed storage. Their
  current domain models remain unchanged.
- No removal of supported legacy archive formats merely because loose JSON is
  rejected.

## Recursive presentation model

Each export source exposes a recursive tree of presentation nodes. A node has a
stable ID, zero or more children, and optional presentation metadata such as a
trailing profile label. The tree is UI and selection metadata; it does not
duplicate the exported domain records.

The manifest continues to store a source-level selection plus a set of stable
selected node IDs:

- selecting a node itself means the complete subtree at export time, including
  children added after a template was saved;
- selecting descendant IDs means only those exact descendants;
- selecting every current descendant individually is therefore distinct from
  selecting the parent node;
- source-level `all` retains its existing meaning of all current and future
  items in the category.

The recursive widget derives checked, unchecked, and partial states from those
IDs. It shows `All, including future items`, `All current`, or `N of M selected`
as appropriate at every expandable level. Expansion and selection remain
separate accessible actions.

This representation supports arbitrary UI depth immediately. A future domain
feature that introduces real nested folders will still require a source schema
update, but will not require redesigning the export UI or template selection
model.

## Pinned-search and profile presentation

Pinned searches appear beneath their owning folder. Searches in Home appear in
a virtual Home node only when that node is nonempty. Selecting a folder node
selects its complete live contents. Selecting individual searches records only
their search IDs.

When a subset of a folder is exported, the payload includes the folder as a
structural shell with only the selected search IDs. The searches therefore
remain grouped after import instead of becoming Home entries.

Pinned-search and following-feed rows show the profile name at the trailing
edge using the theme's lower-emphasis text color. Folder rows have no profile
label because a folder may contain searches from several profiles.

## Suggested import behavior

The recommendation editor consumes the same presentation tree, filtered to the
items that will be exported. Categories and folders are collapsible, so large
exports remain scannable. Action selectors remain attached to the concrete
manifest items they configure and use the standard Kurumi settings selector.

Recommendations remain advisory. The recipient continues to see and override
every supported action during import review.

## Template flow

The naming dialog title is `Save as template` and offers only `Cancel` and
`Save`. Saving returns to the configured export screen. The existing page-level
`Create export` action performs the export separately.

Templates continue to store stable IDs. A selected folder includes future
descendants; individually selected descendants do not.

## Import validation and no-op behavior

The file picker and inbound-file path accept `.bsexport` and supported legacy
archives, but no longer stage a loose JSON file as a legacy import.

The review derives visible blocking errors separately from the internal
`warnings_not_acknowledged` guard. `Problems to resolve` is rendered only when
at least one visible blocking problem exists.

If the planned change summary contains no creates, updates, or removals, the
screen immediately offers `Nothing to import` and `Done`. Warnings may remain
visible as information, but no acknowledgement is required because no mutation
can follow. Warning acknowledgement remains mandatory before an import that
will write data.

## Verification

- Unit tests cover recursive selection semantics, future-subtree versus
  explicit-current selection, template round trips, and subset folder export.
- Widget tests cover arbitrary nesting, expansion, partial states, profile
  labels, hierarchical recommendation editing, the two-action template dialog,
  and no-op warning behavior.
- Import staging tests prove loose JSON rejection while retaining supported
  archive behavior.
- Focused analysis and export/import tests run before the complete Flutter test
  suite.
- The revised custom-export and no-op import flows are exercised on Android
  through Maestro.
