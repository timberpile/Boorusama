# Nozomi ordering in the shared interface

Refs #71. The existing date/popular index selection is exposed through the
same Search Options UI instead of separate search-page sort controls. A typed
`order:date` or `order:popular` item is consumed by the request adapter and
passed to the existing Nozomi client as `NozomiPostOrder`; it is never requested
as a tag index. No score, age, safety-rating or size filtering is invented.

The previous route order is retained as the fallback for existing deep links.
An explicit query item takes precedence. Unknown items and opaque raw groups
are preserved. Flattened opaque raw queries containing an adapter directive
still require consumer round-trip checks, as with Philomena. The legacy
standalone control classes remain for compatibility with other callers/tests;
the normal search page no longer renders the competing control.

Evidence is the existing fork's `nozomi_client.dart`, `post_order.dart`,
`nozomiPostRepoWithOrderProvider` and the previously implemented index order UI.
This change does not infer new remote capabilities. Added request and catalog
tests are unrun here. Locally test first-page reset, Date/Popular switching with
and without tags, old order deep links, history/share restoration, and the
existing Nozomi package tests. FVM, emulator and live execution are unavailable
in this environment.
