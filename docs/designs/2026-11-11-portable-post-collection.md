# Directly openable Post collection documents

Source baseline: `22348b2fb20049088705ce38f5b261e191b148af`. Proposed product/architecture direction, not an approved implementation or a new remote Content Group kind.

## Existing foundation

[BoorusamaLinkFile](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/posts/links/boorusama_link_file.dart) is already a credential-free navigation document: `.bslink`, MIME `application/vnd.boorusama.link`, version 1, exactly format/version/uri, maximum 16 KiB. It accepts strict Post, Group, Search and Artist addresses. [openBoorusamaLinkFile](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/posts/links/open_link_file.dart) validates bytes and opens a route without importing a backup. [Group link routing](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/posts/links/boorusama_group_link_page.dart) already pins an access binding, handles ambiguous profiles, and supports approved public readers.

A remote Group link opens that source Group's current membership. A Search link reruns a query. Neither represents an immutable user-selected set of specific Posts.

## Recommended model

Extend `.bslink` with a versioned **collection document**, rather than turning `.bsexport` into a viewer or introducing a second Bookmark database. Keep the v1 reader and writer unchanged for existing single-resource links. Define a strict v2 discriminated envelope (`kind: collection`) with an optional title and an ordered list of portable Post references. Use the existing ContentReference/key codecs, including original Pixiv Work/page keys; do not serialize local Bookmark IDs, profile IDs, credentials or synthetic Group Posts.

The document is an immutable local navigation manifest, not a remotely addressable `ContentKind.group`. Its entries are fixed at creation time. Reuse a route-scoped manual Riverpod controller and the shared PostGrid/ViewerEntry/access machinery for presentation. Keep document order authoritative; asynchronous resolution must fill the same positions rather than reorder by completion. Selection exports use visible timeline order, not the order in which checkboxes were clicked. Deduplicate selected Posts by semantic source identity; preserve real distinct pages.

Reference-only v2 is the smallest reliable first version. Optional export-safe snapshots/covers can improve first paint later, but must use existing sanitized snapshot codecs and strict source/media policy; never embed arbitrary raw Post JSON or trusted authentication headers. A reference document needs network access unless media is already cached. It requires Boorusama (or a future compatible reader); it is not a self-contained offline image album.

## Create, share and view

Expose **Share Collection** for selected Posts and a saved Bookmark Group's explicitly chosen direct/subtree Post projection. Show title and count in a compact Kurumi sheet, then use the existing native file-share adapter. Do not silently expand remote Pools/Works/Galleries or crawl unselected remote pages. A later mixed-entry format can preserve typed Group references separately, but should not change what 'specific Posts' means.

Tapping the file opens its timeline immediately, without an import wizard, profile creation or library writes. Use the normal header, grid controls and Viewer; show one compact unavailable count with explanations. Resolve source access once per source/account binding, using an existing compatible profile or the approved anonymous-reader policy. Ask for a profile only when ambiguous; do not switch accounts silently if a bound profile disappears. Restricted/unavailable references remain in the manifest and keep their positions.

An explicit **Save to Bookmark Group** action persists through the existing unified library mutation service. Opening and closing a document does not pollute Default/All Bookmarks, modify favorites, subscribe to sync or change memberships. #144 folder synchronization remains separate.

## Format and platform safety

Dispatch formats before interpreting payloads. Retain v1's 16 KiB limit; propose initial v2 caps of 2 MiB and 5,000 references, enforced during bounded reading and validation, with smaller per-field limits. These are proposed operational limits to test, not measured requirements. Use JSON rather than ZIP/base64-in-a-URI for the file. Reject unknown versions cleanly and explain when an older app needs updating. Never relax URI parser rules to fit collections into one huge deep link.

Reuse filename sanitization, native content-URI grants and the existing generic-MIME/renamed-file fallback. Inspect all native ingress byte caps when adding v2, not just the Dart decoder. Validate unknown keys, malformed origins, duplicate identities and unsafe hosts before networking; incoming data cannot authorize arbitrary-host requests or credential forwarding. No background prefetch of the entire collection.

## Verification

Round-trip v1 and v2; preserve selected order across mixed sites and Pixiv pages; no persistence on open; explicit Save is transactional; zero profiles/ambiguous profiles/private sources remain safe; deletion/offline/missing members preserve identity; malformed/oversize files are bounded. Test cold-start and warm-start Android file opening, generic MIME delivery, cancellation and a large collection with lazy resolution. No runtime code or native handoff was tested here.
