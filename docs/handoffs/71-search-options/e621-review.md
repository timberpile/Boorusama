# e621 exact values and range review

Refs #71. `user_id`, `parent` and `randseed` use safe-ID parsing, not numeric
range parsing. Their graphical controls now accept exact integers only; parent
keeps any/none. Added the documented `limit` directive as an exact count. Score
supports native prefix negation for equality and ranges, not only comparison
complements. Szurubooru's `comment` option is labeled Commented by because it
selects a user, not comment text.

Source inspected 2026-10-23:
https://github.com/e621ng/e621ng/blob/master/app/logical/tag_query.rb

The engine's role/privacy rules still apply. Staff-only flagger/flagnote and
restricted vote queries are present in the parser but not automatically usable
by every account. Role discovery and role-aware catalog visibility are NOT
implemented here. Validate effective server enforcement locally; do not infer
entitlement from the presence of a row. Native limit can interact with an
explicit API page limit and needs a request/server acceptance check.

Added focused serializer and semantic-label regression tests; no Dart/Flutter
execution is available here. No full-coverage or integration-readiness claim.
