# Realbooru and Gelbooru-family search verification

Refs #71. Sources reviewed on 2026-10-23. The website documentation was
accessible, but this remote environment could not fetch dynamic API results.
**No live site or Flutter execution is claimed.**

## Realbooru: independently documented features

https://realbooru.com/index.php?page=help&topic=cheatsheet
https://realbooru.com/index.php?page=help&topic=dapi
https://realbooru.com/index.php?page=help&topic=rating

The website documents user and MD5 searches, negative ratings, parent IDs,
score and image-dimension comparisons, and sort by id, score, rating,
user, height, width, parent, source or updated (asc and desc).
The API guide states that the post listing tags parameter accepts the same
metatag search syntax. Rating values: safe, questionable, explicit.

The current nine-option Gelbooru-v2 catalog includes these fields and
the existing post-ID control. The website cheatsheet does not explicitly
document the post-ID metatag; its API has a separate post-ID parameter.

Realbooru does NOT document Rule34 aspect-ratio filters, source-domain
filtering or random sorting. Do not advertise or infer them there.

## Other priority engines and websites

Rule34: https://rule34.xxx/index.php?page=help&topic=cheatsheet
Documents random ordering, aspectratio, aspectratiof and sourcedomains,
but does not list sorting by rating. Subsequent authenticated API known-match
checks contradict the ratio/domain help: those guided API controls are omitted;
verified native source URL patterns remain available. See `rule34.md`.

Gelbooru.com: https://gelbooru.com/index.php?id=26263&page=wiki&s=view
Documents random ordering with an optional integer seed from 0 through 10000.
Does not list parent as a sortable type (parent ID is separately searchable).
Seeded random can be entered natively; a graphical seed input is not part
of the current option dialog.

Danbooru: its syntax uses order: and its richer schema. Nothing from
the Gelbooru family is applied to Danbooru by these changes.

The shared website-specific sort rules now drive both Search Options and
metatag extraction, including highlighting. Rule34-specific fields are
recognized as metatags instead of ordinary text. Quick choices are unique.
Unknown sites do not automatically inherit Rule34 or Gelbooru.com extras.
User autocomplete is explicitly out of scope.

## Required local verification

Run the new test/core/search/options/search_priority_gelbooru_sites_test.dart,
test/core/search/options/search_rule34_coverage_test.dart and
test/metatag_regex_test.dart, plus affected consumer tests, then the complete
required regression suite before integration. Format and analyze changed code.
With configured live accounts, test queries such as these, one site at a time:

- Realbooru: rating:safe, -rating:questionable, score:>=10,
  width:>=1000 height:>1000, sort:rating:desc, sort:parent:asc
- Rule34: sort:random, aspectratio:16:9, aspectratiof:>=1.5,
  sourcedomains:<a-domain-known-to-match>, sort:score:desc
- Gelbooru.com: sort:random, sort:random:1234, sort:rating:desc,
  score:>=10, -rating:questionable
- Danbooru: age:<7d, -rating:q, order:score, score:>=10

Verify that the server actually applies each filter, not merely that it
returns HTTP 200. Test keyboard-open query editing, chip styling, profile
switching, history, Topics, and sharing. Distinguish no matching posts,
rate limiting, account restrictions and network blocking; none proves a pass.

The website API result URLs could not be opened in this environment;
local network and Android-Maestro acceptance remain outstanding.


## Local availability check (2026-10-23)

At runtime candidate `cfd53476bb90343eb6b282277d66d41cac0be4dc`, anonymous
`/index.php?page=dapi&s=post&q=index&json=1&limit=2&tags=rating:safe`
returns HTTP 200 but XML `response success="false"`: the API explicitly says
it has been shut off indefinitely because it is broken. This is not an empty
matching-post list or a successful filter test. The normal web listing is
reachable. `/autocomplete.php?q=one` returns a ten-item JSON list including
`one_piece`, so ordinary tag autocomplete is live even though post API
acceptance is blocked.

Serializer/provider tests verify the declared rating, score, dimensions,
uploader, exact parent-ID and rating/parent-sort grammar. The Realbooru post-ID
metatag remains undocumented/unverified. No actual post-result acceptance is
claimed for these filters while the API is offline. Do not infer that new
Rule34-specific controls should be enabled here. Username autocomplete remains
explicitly out of scope.

See `follow-up.md` for the actual local suite, Android and other-site results;
the remote-phase non-execution notes above are historical, not current totals.
