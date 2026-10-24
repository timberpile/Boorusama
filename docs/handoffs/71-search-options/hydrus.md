# Hydrus numeric, date and media predicates

Refs #71. Added typed system predicates for dimensions, integer file sizes,
media duration/framerate, tag/URL/note/frame/word counts, view counts,
import/modified/archive/last-view dates and result limits. The exact native
clause is already accepted by the existing Hydrus client tags-array request.
No extra network transport or post-load filtering is involved.

The Hydrus parser explicitly permits underscores in predicate names. This
allows single-item values such as `system:number_of_tags>10` without the search
item's spaces-to-underscores conversion changing literal values. Exact tests
use '='. Only NumberTest fields receive <=/>= controls; older relational
fields use =/</>. File sizes require an integer plus a unit. Duration uses
ms/s/m/h. Date controls are absolute dates, not made-up upload-age metatags.
No serializer emits `-system:...`, which Hydrus explicitly rejects. An
Exclude comparison is offered only when the inverse operator is supported.

Sources inspected 2026-10-23:
- https://hydrusnetwork.github.io/hydrus/developer_api.html
- https://github.com/hydrusnetwork/hydrus/blob/master/hydrus/external/SystemPredicateParser.py

This is not the entire Hydrus predicate language. Service-specific ratings,
file/tag domains, duplicate relationships, arbitrary regex/URL predicates,
unary metadata predicates, similarity search and API sort controls still need
additional typed models and/or instance discovery. Current server versions
and API permissions remain authoritative. Manual native input is preserved.

Tests cover exact serialization, rejected operators and the real selected-item
round-trip; not executed here. Locally exercise the full Hydrus package tests,
configured API permissions, older client versions, pagination with explicit
limits, zero-result predicates and query restoration.
