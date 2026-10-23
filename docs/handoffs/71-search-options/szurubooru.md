# Szurubooru graphical catalog

Refs #71. The shared option UI now exposes every public canonical named post
filter in the inspected Szurubooru parser, including source, category, media
flags, metadata counts, checksums, dates, user roles, pool ID and own-account
special filters. Aliases remain usable as native text rather than duplicating
every row. `liked`/`disliked` user filters are server-internal and deliberately
represented only by the documented own-account `special` choices.

Comparisons serialize to native inclusive ranges. Strict boundaries use an
exact negated range, not a floating-point epsilon. For example `>1.5` becomes
`-image-aspect-ratio:..1.5`. Exclude flips that negation. Date upper bounds mean
the end of the selected day, as defined by the server. Sorting uses commas,
not Gelbooru's colons. File sizes are entered in bytes, with MiB quick choices.
Pool lookup shows a name but applies the numeric ID only.

Primary sources inspected 2026-10-23:
- https://github.com/rr-/szurubooru/blob/master/server/szurubooru/search/configs/post_search_config.py
- https://github.com/rr-/szurubooru/blob/master/server/szurubooru/search/parser.py
- https://github.com/rr-/szurubooru/blob/master/server/szurubooru/search/configs/util.py
- https://github.com/rr-/szurubooru/blob/master/doc/API.md

Added serialization and coverage tests in search_szurubooru_test.dart. These
have not run here. Local verification must include a configured instance,
permission-sensitive own-account queries, dates/ranges, cancellation and pool
selection. Generic extension labels still require the localization follow-up;
missing translations currently fall back to native identifiers, not fabricated
English descriptions. No deployed server was queried in this environment.
