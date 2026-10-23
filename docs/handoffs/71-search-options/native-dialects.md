# Native comparison dialects and Paheal

Refs #71. Paheal's registered Shimmie2 integration now has guided inputs for
all semantic filters advertised by its current live search-help page: IDs,
poster, score, posted date, tag/comment counts, dimensions, ratios, file size,
media length, comments/vote users, comment locks, source/hash/name/MIME,
extensions, media content and the listed sort fields. The catalog is restricted
to rule34.paheal.net; it is not a promise about arbitrary Shimmie extensions.

Source inspected 2026-10-23: https://rule34.paheal.net/help/search
The source documents exact values with '=' and comparisons without a colon.
Length uses ms/s/m/h/d/y, not Danbooru's minutes/months suffixes. Date equality
is a timestamp comparison, not a whole-day filter; prefer >= or < on that site.

The active-option reader understands colon, Philomena comparator suffixes and
Shimmie comparison forms. It only matches known keys, prevents prefix collisions,
and protects unfinished native values from submission. Guided replacement
recognizes these equivalent wire keys; opaque raw items remain unchanged.

New tests cover serialization, exclusion, reopening, incomplete input and
same-option replacement. Flutter tests/formatting/analyzer remain unrun here.
Include these tests and the existing search-input suite in local verification.
