# Direct destinations, not a More hierarchy

Decision refinement after explicit-profile navigation review. Audited base:
`timberpile/Boorusama` develop `d78c0aa09eac22dea9eaede9d5bbf92fe8686c7b`.
Branch: `feature/navigation-direct-destinations-preview`.

## Decision

Keep a bottom **shortcut bar** for Browse, Following and Bookmarks. Its separately
marked **Menu button opens the global drawer**. Menu is an action, not a fourth
selected destination and not a parent page. Secondary pages have independent
identities and resumable state. Opening Pools from Explore does not require
popping Explore, opening a More overview, or replacing a shared More stack.

This is a deliberate hybrid, not a claim that an action is a conventional tab.
Its icon, divider and expanded semantics distinguish it from the three page
shortcuts. On a secondary page none of those three shortcuts is falsely selected;
the page title, source label and selected drawer row identify the actual location.

For a visible item in an expanded group, the mobile switch costs two taps: Menu,
then destination. Collapsed groups need one more tap; long catalogs need scrolling
or local filtering. The design does not pretend to make every function one-tap.
A permanent desktop sidebar provides direct access without a second bottom bar.

## Existing code: routes, renderers and instances are different

`lib/core/posts/favorites/src/routes/routes.dart` declares one `/favorites` entry.
`FavoritesPage` chooses `favoritesPageBuilder` from the scoped profile's engine.
For example `GelbooruBuilder` supplies `GelbooruFavoritesPage`; Danbooru supplies
its own renderer. Other engine functions, such as `/danbooru/explore`, already
have dedicated routes. Two accounts on the same engine can reuse one renderer
class while still needing independent route, draft and scroll state.

The new invariant is `(profile UUID, function ID)`, not function name, renderer
class, profile display name, or an ambient active configuration. Generic searches
also carry their task origin and explicit owner. A Topic search stays in its
Following task rather than replacing Browse.

## Catalog and presentation

The same target definitions drive every entry point. Rendering the catalog may
read cached capability/account metadata but must not instantiate destination
pages, fetch all account details, or start background work for every profile.

Mobile drawer: search, profile groups, global groups. Each profile heading is a
button that expands/collapses a **single vertical list**. Remember the user's
expansion choices while switching/reopening. During filtering temporarily reveal
matching entries, without overwriting those choices. No multi-column tool cards
or multi-column profile groups. Long names may wrap inside their row.

Hide functions unavailable for that engine/account. A direct route still validates
availability; hiding a row is not access control. When credentials expire after a
page was opened, preserve a recoverable state on that exact profile rather than
substituting a different account. Signing in through Profiles can reveal the
newly available function. Duplicate names need site/account disambiguation.

There is no global active-profile picker. Browse alone has a horizontal profile
choice. Global views remain global; a source-bound page retains its explicit
owner. Actions on an ambiguous imported post can require a **one-operation**
account choice, without mutating Browse or future operations.

Mobile primary links are not repeated in the drawer because the bar stays
operable underneath the open drawer. Opening Menu restores a scroll-hidden bar.
The scrim covers the content, not those shortcuts. On desktop, where the bottom
bar is absent, show Browse, Following and Bookmarks in one sidebar column.
Keyboard and selection are deliberate exceptions to bar visibility.

### Complete placement inventory

| Destination | Main shortcut | Catalog location |
| --- | --- | --- |
| Browse | Yes | Desktop primary list; profile choice inside Browse |
| Following | Yes | Desktop primary list; Topics and folder feeds remain one subsystem |
| Bookmarks | Yes | Desktop primary list; All and protected Default remain distinct |
| Blacklist | No | Global library tools |
| Favorite Tags | No | Global library tools |
| Bulk Download | No | Global download tools; explicit job source |
| Download Manager | No | Global download tools; jobs retain their owners |
| Profiles | No | Global management |
| Backups | No | Global management; existing export/import contracts |
| Donate | No | Help/support; preserve actual build-flavor eligibility in production |
| Get support | No | Help/support |
| Settings | No | Global management |
| Booru-specific pages | No | Their owning profile's collapsible section |

Every additional global page can be another stable catalog entry without adding a
bottom slot or another nesting level. Menu is not duplicated as its own row.

## Navigation behavior

Every primary/secondary page resumes its prior hierarchy, draft/filter and anchor.
Reselecting a shortcut does not refresh or reset the destination. Breadcrumbs and
Back explicitly move through that destination's hierarchy. The browser history
in the HTML study is chronological and does not undo data mutations.

For example: Pools -> open a pool -> scroll -> Menu -> Explore -> Menu -> Pools
resumes the pool and its position. It does not show the More overview or the Pools
root. Same-engine Favorites for two profiles remain independent.

The menu over a viewer must not close it merely by opening or dismissing the menu.
Choosing another destination finishes the viewer transition correctly. Bookmark
mutations persist immediately with Undo; the viewer's immutable sequence is a
presentation snapshot, not a delayed database transaction. Following topics have
one query and owner each; folder-feed RSS remains an explicit separate action.

Transient surfaces get priority: keyboard, menu/dialog, dirty form, selection,
viewer, local parent. Back at a secondary root returns to the configured primary
start rather than replaying all prior menu choices. Deep links and invalid targets
need explicit compatibility mapping in production.

## Reading chrome and accessibility

The bar auto-hides on downward movement in post-reading views and reappears on
upward movement, using different distance thresholds to prevent jitter. Top of
list, a new destination and Menu opening reveal it. Menus, organizer lists and
forms do not independently hide their navigation controls. Provide an always-show
preference. A hidden bar must not remain keyboard-focusable or hit-testable.

Keep the content viewport stable during animation. Reserve a constant trailing
scroll inset so the last item remains reachable. Coordinate bottom search,
selection actions, Snackbar/Undo, scroll-to-top and OS safe-area/keyboard insets.
Menu focus belongs to its search/results plus visible shortcuts, not the covered
page. Dismissing a menu must consume the tap and restore sensible focus.

Single-column lists do not prohibit a post-image grid: image browsing and
navigation scanning are different tasks. Large labels wrap within their one row
or column; they do not force the navigation into an arbitrary two-dimensional
button matrix.

## Inspiration and trade-offs

Slack's official documentation separates a small navigation bar from a sectioned
sidebar. The applicable idea is different access speeds without pretending that
the sidebar is a mandatory parent screen, not Slack's global workspace switcher:
https://slack.com/help/articles/212596808-Adjust-your-sidebar-preferences

Apple Mail documents the same favorite mailboxes in a sidebar and Favorites bar.
This shows why duplication is not categorically wrong. Our compact design can
avoid it because its shortcuts really remain reachable under the drawer:
https://support.apple.com/guide/mail/use-favorite-mailboxes-mlhl6e39ca4a/mac

Outlook distinguishes its module navigation from its folder tree. The useful
part is persistent access plus clearly grouped destinations, not reproducing
Outlook's exact hierarchy:
https://support.microsoft.com/en-au/outlook/what-is-the-navigation-pane

These are documented product patterns, **not evidence of superior usability or
UI-specific ratings**. General app-store ratings mix reliability, pricing and
features with navigation. No comparative user study or UI-rating claim is made.
The three-shortcuts-plus-Menu design needs actual user/device review, especially
whether an unselected primary shortcut state on a secondary page is clear enough.

## Delivered artifacts and implementation scope

The standalone HTML study and editable source are provided in the conversation
package. It implements all required global pages with representative synthetic
interactions, direct destinations, independent histories, collapsible capability-
filtered profile groups, preserved filters, immediate bookmark Undo, folder feeds,
source-bound jobs, and narrow/wide layouts. It makes no network requests.

This branch contains a **native Flutter preview host and sample-page adapter**
under `lib/dev/navigation_preview/`, plus a default-off/dev-gated router entry.
It is a native implementation of the navigation mechanics, not a migration of the
actual app's feature pages. The visible sample-data banner and Exit preview action
make that distinction explicit. See its README for launch/check commands.

The native host creates independent Navigators lazily, retains their widget state,
uses stable destination identity, exposes session activity, and supplies a compact
drawer/persistent sidebar/shortcut bar. It leaves production navigation and data
providers unchanged unless the explicit dev preview is requested. Sample copy is
isolated and bilingual; existing destination names use context.t.

### Why stop short of real page adapters here?

The authoring container has no FVM/Dart/Flutter SDK and cannot obtain a full Git
checkout through its network. A native compile, analyzer pass or device run was
not possible. Root GoRouter helpers, imperative folder navigation, RouteAware
feed interests, source-config scopes and native post viewers are precisely the
interfaces where an unverified broad rewrite could regress released behavior.

A retained hidden widget is not necessarily inactive. Flutter documents that
Offstage children can continue animations and focus unless controlled:
https://api.flutter.dev/flutter/widgets/Offstage-class.html

Nor should a separate ad-hoc Router for every profile independently publish
platform routes; Flutter's Router documentation distinguishes that responsibility:
https://api.flutter.dev/flutter/widgets/Router-class.html

The next native increment should adapt one real Following folder/feed/search
journey and one Bookmark journey to the host with explicit source context and
active-route signals, then integrate booru pages, root menus and external links.
Do not merely mount the existing pages in the sample builder: their current
ref.router helpers would escape the retained session.

Do not silently evict a page and lose its place. The finite native sample catalog
keeps visited sessions resident. Production needs measured memory use and, when
necessary, lightweight route/anchor restoration plus cached results. Process-death
restoration is not implemented by this preview.

## Verification

The final HTML revision passed **11 Node model tests and 16 Chromium journeys**,
including **24 viewport/text/scenario combinations**. Tests also verify vertical
alignment of entire profile groups, not only rows within a group. Screenshots of
phone, drawer, folder feed and desktop were visually inspected. No JavaScript
page errors or external requests were observed in those tests.

The managed browser blocked file:// navigation. Browser tests therefore used
set_content with the exact generated standalone bytes. Double-click opening was
not directly tested in that managed browser. The document itself is self-contained.
No live-site, native gesture, performance or accessibility conformance claim follows
from these checks. Native source includes two identity tests and five widget tests,
all **unrun** because FVM/Flutter was unavailable. Formatting and static analysis
were also unavailable. The branch is **not a verified integration candidate**.

## Next native acceptance cases

1. A real pool, Explore and two same-engine account favorites retain independent
   nested locations; no route escapes to or reconstructs an old Home shell.
2. Following -> Pixiv Topic -> Danbooru Browse -> Following retains Topic owner,
   query and originating UUID; no global account mutation occurs.
3. Bookmarks retain Default/All semantics, immediate writes, Undo and the immutable
   viewer sequence; switches do not replay or postpone mutations.
4. Hidden pages stop visible-only media/prefetch/feed interest while independent
   scheduled refresh and jobs continue according to their existing policies.
5. Expired/deleted/edited owners and capability changes cannot rebind a route,
   pending favorite, late response or download to another profile.
6. Drawer/keyboard/selection/viewer Back ordering, dirty-form guards, outside taps,
   focus and native predictive/edge gestures behave at phone and desktop sizes.
7. Layout changes and text enlargement do not recreate sessions. Bottom search,
   page controls, Snackbar and navigation do not overlap or relayout post content.
8. Ordinary startup, legacy/external routes, import/restore, app-global theme and
   services remain unchanged with the preview flag off.
9. After real adapter integration, run the required complete suite on the final
   develop integration candidate before any merge.
