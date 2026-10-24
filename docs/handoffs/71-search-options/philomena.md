# Philomena fields and request parameters

Refs #71. Derpibooru/Ponybooru now have a graphical public query-field catalog:
number/count/size comparisons, dates, uploader/favorite identities, source,
formats, hashes, description, processing booleans, galleries/filter IDs and
own-account queries. Use suffix comparisons (`score.gte:50`), grouped bounds
and native negation. Exact ID fields intentionally have no comparison controls.
Rating is a site tag taxonomy, not an invented `rating:` field.

Sort is one explicit Boorusama item (`sort:score:desc`) translated by the engine
request adapter into `sf=score&sd=desc`; it is never sent as a native q clause.
Only recognized standalone items are consumed. Unknown/grouped native input
is preserved. An API sort directive embedded inside an opaque raw Boolean
expression is NOT interpreted. Keep it as a separate item. Sort metadata stays
in the stored query so normal typed history and profile snapshots retain it.
Local acceptance must exercise share/Topic paths that flatten typed queries;
do not claim those raw round-trips work without verifying them.

The client gained optional `nativeQuery`; existing callers keep their legacy
tag conversion. The post adapter preserves underscores in native fields and
literal values instead of changing `created_at` to `created at`. Plain tags
still convert underscores to spaces. Moderator-only fields are not advertised
without a role-capability source. Deployed older versions may lack newer fields.

Primary sources inspected 2026-10-23:
- https://github.com/philomena-dev/philomena/blob/master/lib/philomena/images/query.ex
- https://github.com/philomena-dev/philomena/blob/master/lib/philomena_query/parse/parser.ex
- https://github.com/philomena-dev/philomena/blob/master/lib/philomena/images/search/sort_field.ex

Added query and request mapping tests. Required local checks include the entire
booru_clients package suite and related application/consumer tests, HTTP
parameter assertions, live queries and cancel/apply behavior. No runtime checks
were available here. This commit is a reviewable implementation, not a release
or verification claim.
