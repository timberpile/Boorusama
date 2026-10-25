# Sanitized source metadata fixtures

Captured from public source metadata endpoints on 2026-10-25 UTC. These are
allowlisted fields from actual responses, not complete raw responses. Numbers,
field absence and content-rating strings retain source semantics. Media/source
URLs, descriptions, account names and free-form tags are replaced by
synthetic fixture values; credentials, cookies and request headers are excluded.
Public post/media identifiers are retained where source identity needs them.
Tests never contact live sources or download media.

`provenance.json` records the initial host sweep, HTTP outcome, response shape and
source field names. Each post fixture records its own endpoint and capture time;
subsequent detail/authenticated captures are identified separately. The Gelbooru
authenticated capture retains no authentication query parameters. The Realbooru
HTML fixture retains its actual post-owned upload-day label and media facts, with
an anonymized uploader; it exercises the shared #76 parser rather than another
parser.

Successful fixtures cover Danbooru variants, authenticated Gelbooru, Gelbooru V2
JSON/XML variants, all four Moebooru hosts, e621/e926, both Philomena hosts,
Sankaku's shared API, Shimmie XML, Anime Pictures listing/details, HyBooru
summary/details, e-shuushuu and selected Nozomi image/video metadata records. Anime Pictures
Original facts require the resolved download URL; the filename in its detail
response alone is insufficient. A separate live HEAD check verified the
redirect-issued cookie and exact Original Content-Length without reading media.

These fixtures do not establish every registered host or permission variation:

- donmai.moe and illusioncards.booru.org returned 403; Zerochan and Asiachan 503.
- Anonymous Rule34 returned JSON without a Post record; the authenticated probe
  returned a non-JSON response. HTTP 200 alone is not counted as metadata success.
- All seven Sankaku aliases were subsequently exercised through the production
  client: four Channel hosts share sankakuapi.com and three Idol hosts share
  iapi.sankakucomplex.com. Idol listing metadata includes its ISO upload date;
  the current client has no separate Idol detail endpoint implementation.
- No configured Szurubooru/Hydrus instance or Pixiv authentication was available.
  Their absence/known-zero/semantic contracts use controlled DTO tests.
- Hypnohub/Realbooru media-layout evidence reuses #76's separate sanitized HTML
  fixtures; live ambiguous/adversarial layouts were not observed.

The complete acceptance report distinguishes controlled tests, source metadata,
Android presentation and unavailable live gates.
