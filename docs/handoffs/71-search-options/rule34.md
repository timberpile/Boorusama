# Rule34 search coverage and authenticated API verification

Refs #71. Updated 2026-10-23 after the user explicitly authorized using the
local Rule34 test user ID/API key only at `api.rule34.xxx`. Credentials were
read from the ignored local entry, never printed or committed. Redirects were
restricted to the authorized HTTPS host. Username autocomplete is out of scope.

## Website help and actual API behavior differ

The [website cheatsheet](https://rule34.xxx/index.php?page=help&topic=cheatsheet)
documents `aspectratio:N:D`, `aspectratiof:decimal`, and `sourcedomains:domain`.
The [API guide](https://api.rule34.xxx/) says website metatags work in its tag
parameter. That documentation alone did not establish working API support.

Authenticated API probes returned HTTP 200 with an empty JSON body for these
three predicates. A deterministic positive/negative control established that
this is not simply a query without matching posts:

- Post 19122690 was returned by the combined `one_piece rating:questionable
  score:>=10` query. It is 1280x1280, rated questionable, with a source hosted
  at subscribestar.art. A query using that post's MD5 returns exactly this post.
- Adding `rating:questionable` or `width:>=1280` retains it. Adding
  `rating:explicit` or `width:>1280` returns empty, confirming filtering.
- Adding `aspectratio:1280:1280`, `aspectratio:1:1`, `aspectratiof:1.0`,
  `aspectratiof:>0`, or `aspectratiof:>=0.5` returns empty even though the
  known post satisfies each condition.
- Adding `sourcedomains:subscribestar.art` also returns empty, despite its
  known matching source. `source:*subscribestar.art*` and
  `source:*://subscribestar.art/*` retain it; a deliberately nonmatching
  `source:*issue71-nonexistent.invalid*` returns empty.

The guided API catalog therefore omits aspect-ratio and source-domain options
and offers the verified native `source:` URL/pattern field instead. URL pattern
matching is not the same as domain-only matching. No client-side filtering,
ignored extra request parameter or lossy domain-to-substring rewrite is used.
The metatag extractor/highlighting follows the same API capabilities. Existing
raw queries/history are preserved; no stored query or pin migration deletes
unsupported input. Re-enable those guided predicates only after a known-match
API check succeeds, rather than assuming the website help proves deployment
support. Other Gelbooru-family hosts do not inherit these Rule34 changes.

## Live results

The corrected verification predicates use the API's full-word rating values,
not legacy single-letter assumptions. Each nonempty listing below contained
30 rows; every row was checked against the requested metadata predicate:

- `rating:questionable`, `rating:explicit`, `-rating:questionable`.
- `score:>=10`, `score:<10`.
- `sort:score:desc`, `sort:score:asc`, `sort:id:asc` (monotonic returned values).
- Two `sort:random` calls returned different ordered ID lists.
- `one_piece rating:questionable score:>=10` retained all three conditions.
- Ordinary tag autocomplete `one_pie` returned ten suggestions including
  `one_piece` through the API autocomplete endpoint.

`rating:safe` returns a bodyless HTTP 200, also observed for `rating:s` and
`rating:general`. With no known matching Safe post, this is an empty-result
limit, not proof of an invalid rating or a successful positive Safe check.
The existing Rule34 listing parser already maps bodyless successful responses
to an empty list; no parser change is needed.

Further positive source checks returned 30 matching rows for
`source:*subscribestar.art*` and three matching rows for `one_piece
rating:questionable score:>=10 source:*subscribestar.art*`. Each row satisfied
the URL-pattern/tag/rating/score conditions independently.

Local sanitized evidence:
`/tmp/71-rule34-corrected-live.jsonl`,
`/tmp/71-rule34-diagnose.jsonl`,
`/tmp/71-rule34-fixture-probe.jsonl`,
`/tmp/71-rule34-source-control.jsonl`,
`/tmp/71-rule34-source-listing.jsonl`.
The initial probe assumed single-letter ratings and was corrected after
inspecting the actual response schema; its failed predicates are not app bugs.

## Local verification after the capability correction

Updated catalog and real-provider regression tests assert that supported
source/random syntax is offered and recognized, while the API-incompatible
ratio/domain keys are absent. Unknown/native raw input remains available.
On runtime commit `8743a087a`, the focused options/metatag suite passes 132
checks; all 64 changed Dart files analyze cleanly. The dev APK builds and the
current-APK common search smoke check passes on a leased emulator (released).
The complete regression passes 6054 Dart/Flutter tests, 72 Python tests and
repository shell checks, with two existing GoRouter skips. Full command,
source/APK correspondence and UI limits are recorded in `follow-up.md`. Earlier complete passes on `cfd53476b` do not
qualify this runtime correction. Realbooru's API outage and Danbooru's global
sort failures remain separate outstanding limits.
