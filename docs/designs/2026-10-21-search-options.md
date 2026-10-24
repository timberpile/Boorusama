# Guided search options

Related issue: #71. The approved design keeps one search bar and adds a guided
layer rather than a second query builder. This document describes the current
implementation, not a claim that every engine exposes the same capabilities.

## Interaction contract

Focusing or tapping the bar opens the keyboard without automatically opening
advanced options. A trailing down/up arrow inside the field toggles that menu;
typing shows suggestions. Every nonempty draft has a raw-query suggestion after
normal matches, with a localized RAW badge on its right. Selecting it commits the
exact buffer as one raw item, including when replacing an edited chip. There is
no raw toggle, dedicated submit-search button, input clear X or keyboard-dismiss
button.
System Back and Escape close the active editor before leaving the search page;
covered search routes and inactive navigation branches do not consume Back
intended for the active page.
An explicit tap on the Home search bar opens the keyboard even when automatic
focus is disabled. Other fresh-search entry points retain that setting. A fresh
search route is transparent, keeping its source timeline painted until the first
confirmed query supplies results; the modal route prevents interactions with the
covered source. Hiding the keyboard in an unused, empty editor dismisses that
route back to its source so Browse is immediately interactive again. Pending
input, suggestions, advanced options and applied search results retain their
own editor lifecycle. No empty-query request is needed for that transition.
Enter confirms the input; selecting an API suggestion, raw row or quick choice
closes the overlay and keyboard and updates results. Opening the advanced menu
preserves the input and dismisses the keyboard so the graphical controls use the
available space. Closing the menu leaves focus off until the user taps the input;
its control belongs to the text field tap region. An unfinished input
or IME composition does not issue a post search.

Search Options, Favorites, Trending and History have independent collapsible
bodies. Management actions align to the right; the entire remaining header
width toggles its section. Collapsed headers have symmetric vertical spacing,
without an extra bottom margin on Favorites or Trending. Expansion
is retained in the current route through PageStorage, not a new persisted global
setting. Favorites, history, trending providers and their management routes are
reused. The standalone Raw Query section is removed from the normal landing UI.

Every available option appears in the landing list, with pinned options first
in their saved order and all remaining options following in capability order.
Pins prioritize options; they do not hide unpinned entries. Each option has a
compact rounded background and outline, a localized title and inline description,
and existing FREE metadata. Internal spacing uses the same six logical pixels
as the quick-choice gaps; descriptions stay beside the title and occupy at most
two lines. Overflow uses an ellipsis, with the full description available through
a tooltip and the
option editor. All quick choices use smaller rounded chips in a single
horizontally scrollable row, including the graphical editor's choices. Each row
owns its scroll controller and starts at its leading edge; PageStorage offsets
from sibling rows are not restored. The section's initial gap is six logical
pixels, matching either side of its dividers. The list
scrolls independently and occupies at most half the available editor viewport,
after search controls and keyboard displacement. The header icon is the only
catalog entry; there is no duplicate footer button.
Danbooru keeps its existing persisted pins. Other enabled profiles use a small
profile-keyed list in the existing miscellaneous settings store. No content
migration or new storage system is introduced.

The graphical editor owns an uncommitted draft. Apply generates one native
expression and returns to results; dismissing it changes nothing and restores
the previous keyboard focus. Sheets and inline overlays respect the bottom
system/navigation inset. Include/Exclude is offered only when
a serializer can express the complement. Excluding `<7d` must produce `>=7d`,
not `>7d`. Sorting has no exclusion. Ordinary same-key options are replaced by
guided choices; opaque raw items are never searched-and-rewritten. Advanced
multiple conditions and ranges remain possible through native input.

Uploaded presets target older posts: over one month, one year and five years
ago (`age:>1mo`, `age:>1y`, `age:>5y`). They filter past the recent posts already
visible under newest sorting. The editor also accepts hours, days, weeks,
months and years, retaining the native `mo` and `y` suffixes documented by the
[Danbooru cheatsheet](https://safebooru.donmai.us/wiki_pages/help%3Acheatsheet).
Score presets are labeled `20+`, `50+`, `100+` and serialize inclusive thresholds.

## Boundaries and request ownership

`core/search/options` contains a small capability model, provider, labels,
section, suggestion panel and graphical editor. A capability defines its native
key, input shape, valid enum values, quick choices and negation strategy.
Validation describes the graphical subset, not every expression accepted by a
remote server. Unknown native input is preserved, not guessed or normalized
into another site's meaning.

`SearchPageController` owns the current input and selected-item edit draft. It
keeps the pre-edit input for cancellation and refuses to resurrect a selected
item removed while its editor was open. Profile snapshots carry that input mode
and edit identity along with the existing query state. Tapping a chip uses this
controller only in the post-search scope; other consumers retain their own
confirmation dialogs.

The post-search scaffold owns automatic execution. `SearchAutoCommit` coalesces
selection mutations into one post-frame check and compares the completed wire
query with the applied query. It ignores route restoration, disposal, duplicate
selection and existing explicit paths that already applied the same query. Each
applied wire query owns a new post scope: pagination starts at page one and
obsolete refresh/pagination responses cannot enter the new result list. This is
logical cancellation; the underlying transport may still complete. Each completed
query is recorded in the existing search history, including intermediate queries
formed by separately confirmed additions.
Typing requests suggestions only. The applied result header also observes the
selected-item structure so raw/typed conversion is reflected in share and Topic
metadata even when the serialized query is unchanged.

Autocomplete still uses the profile's real repository and existing tag renderer.
API suggestions retain their real metadata. The final raw row represents the
exact input, not a fabricated API tag or count. Cache lookups enrich a returned
API list rather than delay its initial display.
Results are scoped to the exact query/profile; the old cross-profile fallback
is no longer read. A request generation guards category changes, cancellation
and disposal. Real entity suggestions are retained for supported text options.
There is no no-match screen or feedback timer: the raw choice remains available
during pending, failed and empty API responses. Normal controller-backed post
requests serialize typed tags canonically (`one piece` becomes `one_piece`),
while raw items preserve their whitespace and native grouping.

## Implemented capability coverage

| Integration | Guided subset in this change |
| --- | --- |
| Danbooru family | Upload age, rating, sort, score, post ID, uploader; existing remaining catalog available as native-only entries. FREE comes from the existing metadata. |
| Gelbooru.com | Rating, sort, score, ID and uploader, using its own syntax and values. No Danbooru age promise. |
| Listed Gelbooru-v2 hosts | Existing legacy rating vocabulary only; no blanket sort or age guarantee for arbitrary hosts. |
| Moebooru / e621 | Existing short-form rating vocabulary only. |
| Pixiv | No new guided options yet. The current user endpoint supersedes free text, so exposing it as a freely composable filter would mislead users. Existing native user syntax is unchanged. |
| Other engines | Existing search/native behavior, without guessed new option definitions. Nozomi's existing independent sort control remains. |

Host/version/account overrides can extend the provider after verification.
The current implementation serializes native expressions only. Philomena-style
separate API sorting parameters and mutually exclusive endpoint scopes still
need explicit request adapters before they can enter this shared catalog.
A general request-plan framework is intentionally not introduced speculatively.

FREE is a tag-limit hint, not an account entitlement or a claim about monetary
pricing. Absence of the badge does not fabricate a new per-site limit. Existing
profile restrictions and server-side enforcement remain authoritative.

## Deliberate limits

The first graphical number/date controls support a single comparison, not a
Between editor or arbitrary Boolean grouping. Native expressions remain the
escape hatch. The capability catalog is intentionally not exhaustive. There is
no client-side approximation over loaded posts, no favorite-tag redesign and no
Topic editor redesign.

The English/German CLI manifests have been applied to the real locale JSON files
and their accessors generated locally. The original manifests remain in the
handoff as a historical change record, not a recurring setup step.

See [the local verification report](../handoffs/71-search-options/verification.md)
for the checked runtime source, complete local suite and device evidence.
