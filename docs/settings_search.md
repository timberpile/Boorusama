# Settings search

## Behavior

The settings search is initially hidden. The magnifying-glass action at the
right of the main Settings app bar opens the Kurumi search field above the mobile
settings list or the wide-layout sidebar and focuses it. The action changes to
a close icon while searching. Closing the field dismisses its focus, clears the
query, and restores normal navigation. Results identify the matched setting and
its owning category. Selecting a result uses the existing category navigation;
it does not toggle or change any preference. Mobile back navigation preserves
the query as long as search remains open, and desktop results remain available
while inspecting another category.

Matching is case-insensitive and requires every query word, in any order, across
the localized title, category, description, and supporting aliases. Exact titles
rank first; ties retain the catalog order. Clear restores the ordinary settings
list, Enter opens the first result, and Escape clears the query before dismissing
focus. Searching does not access the network or retain query history.

## Maintenance and scope

`settings_search_catalog.dart` is an explicit metadata catalog using the same
translation getters as the real controls. Keep it in sync when adding, renaming,
or removing settings. It deliberately does not build offstage settings pages:
that would initialize providers and services merely to discover their labels.
Categories come from the existing navigation entries, so hidden developer options
cannot leak into search. The download-network entry is mobile-only, matching the
settings page. Conditional sub-options are represented by their owning control
(for example, fixed refresh intervals by the interval control).

This first implementation opens the owning category, not an individual control
or nested subpage. Profile-specific settings and the separate support/about links
are outside this catalog. The conditionally available incognito-keyboard control
is not indexed yet. Exact-control anchors, deeper profile/nested-setting coverage,
and dedicated search-specific empty-state wording are follow-up work.

## Acceptance checks

- Confirm the search is absent initially on mobile and desktop, can be opened
  with the app-bar magnifying glass (with focus), and closes/clears with its
  close action. Reopening must show an empty query and ordinary settings.
- Find controls with localized labels, descriptions, and aliases such as `audio`,
  `cache limit`, `reduce animations`, and `following refresh`.
- Open a result and return without losing the query. On a wide layout, select a
  result while a nested settings page is open; the owning category must replace it.
- Clear a query; ordinary categories and other settings must return. Verify an
  unmatched query, Enter, Escape, and that unavailable categories are absent.
- Check 320-pixel mobile and 240-pixel sidebar widths, doubled text size, and an
  open keyboard. Search and clear controls must remain usable without overflow.
- Confirm direct category routes and the existing `scrollTo=support` shortcut.
