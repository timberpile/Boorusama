# Local Media Metadata Lookup · #184

Local Media keeps its managed file and SHA-256 identity. Exact lookup reuses the
importer's MD5, configured profiles, and the shared profile visibility checks.
Only the MD5 is sent for an exact search. Image bytes stay on the device.

## Entry points

- **Find on Other Profiles** uses the shared profile and method selector for
  local and remote posts. Results are grouped by profile and method. Each
  method has its own loading, retry, and pagination state. The Selection Manager
  offers Find for a single eligible post. Opening a result starts at that post
  in a swipeable snapshot of the loaded results, with each entry bound to its
  profile. Remote Find excludes the source profile.
- **Enrich** in the viewer and Selection Manager fills missing metadata on
  selected files. MP4 and WebM support exact MD5 lookup. Select profiles and
  methods once for a batch. Cancel stops the remaining work and retains
  completed updates. A successful batch returns to its origin and shows a
  toast, including files whose metadata was already current. A run requiring
  attention opens one results dialog with collapsible Enriched, Need Review,
  Skipped, and Failed sections, including per-file reasons and direct review.
  Exact lookups, tag category requests, and IQDB signature queries use the
  shared API coordinator. Manual batches use bulk pacing per site. Danbooru
  and its legacy Safebooru frontend share a quota. Automatic enrichment also
  uses the passive request budget and background priority.
  Results distinguish rate limits from other exact lookup failures and report
  matches hidden by the selected profile.
- **Enrich Imports Online** in Privacy defaults to off. After consent, successful
  first imports of untagged images enqueue background enrichment. Duplicates and
  repairs never enqueue another search. Manual actions ask for one-time consent
  for MD5 while the automatic setting is off. **Allow always** turns on the
  shared Privacy setting. Privacy also contains **Matching Profiles** and the
  independent **Use Danbooru IQDB** switch, which defaults to off. Confirming
  an IQDB selection while the switch is off asks to enable it in Privacy.
  The selector shows profiles with applicable methods. Configured selections
  are shared across Find, Enrich, and eligible imports. New profiles require
  selection after the first save.
- Tag chips in the viewer open an exact Local Media tag search. **Tag Count**
  includes quick options for zero tags and at least one tag. The search profile
  pickers carry applied exact tags and exclusions between Local Media and
  remote profiles. The source retains its draft and profile-specific filters.
- File Details shows copyable SHA-256 and MD5 digests and verified match references.
  Opening a saved match fetches the specific post through its current profile
  and checks visibility again. Exact matches also revalidate MD5. IQDB
  references show the score recorded when Enrich applied the match.

## Metadata

Manual enrichment adds the union of tags from verified visible results. Existing
tags and categories take precedence. The matched profile's taxonomy supplies
categories when the post only reports tag names. A new tag with conflicting
categories is general. A tag with no reported category is unknown. Automatic enrichment adds tags when the supplied sets and categories
agree, and applies metadata only with complete coverage. Both modes fill an
unknown rating with the strictest available rating in Explicit, Questionable,
Sensitive, General order. Both fill an empty source when the supplied values
agree. Existing ratings, sources, and edits made during a lookup take precedence.

The additive v1 tables store exact matches and accepted IQDB matches with their
profile-bound origins. They share the library's serialized writer and cascade
on item deletion. The
additive metadata revision protects edits while a lookup is pending. Existing
libraries open in place. The latest public release, v4.6.1-timberpile.4
(`45f3df6c3b2e2c977480b5ac3f3aef415765d218`), predates the Local Media database.

## Verification boundary

Repository and headless widget tests exercise the profile selector, independent
result methods, enrichment, and source-bound media transport. An authenticated
host check exercised the production signature and Danbooru request for the
original PNG, a 512 × 512 JPEG, and a 205 × 205 JPEG. Android device acceptance
remains pending.

## Danbooru IQDB

The selector lists IQDB for Danbooru and the default Safebooru profile. It
explains the username and API key requirement for guest profiles. Authenticated
requests stay on the selected profile's official host. Safebooru matches must
be general-rated and have a file URL. The app decodes JPEG, PNG, or still WebP
in an isolate, bounds the encoded size and
decoded dimensions, and generates one signature at a time. For a remote post,
it tries the sample, then the original through the source's media permission.
The Danbooru request contains the signature and a result limit.

Enrich tries selected MD5 methods first. IQDB runs when all selected exact
searches complete without a match, or when IQDB is the only selected method.
Auto-accept requires a raw score at or above the Privacy setting (90 by
default, adjustable from 80 to 100) and a unique highest score among distinct
posts. Tied posts need review. A post returned by several accounts or both
Donmai hosts counts once. The result and review screens hide scores below 70%. Stronger
hidden hits and incomplete responses block automatic acceptance. The results
dialog opens each pending file in the swipeable candidate viewer. The viewer
shows the score, profile, and method. Its Match and Original toggle uses the
same viewport and zoom, keeps the candidate mounted, and displays the local
original after its first frame decodes. Applying or skipping updates the row
in the results dialog. Each accepted match is saved immediately. Leaving
review discards pending candidates. Image imports apply only automatic
decisions and require both online enrichment and persistent IQDB consent.

### Calibration

An authenticated host experiment sent locally generated 533-character IQDB
signatures to the [Danbooru IQDB API](https://github.com/danbooru/danbooru/blob/master/app/logical/iqdb_client.rb).
It used the [reference Haar transform](https://github.com/danbooru/iqdb/tree/109444c0533300d945de0f6253ddfa672899c571)
with libgd, then a standalone Dart prototype using the app's existing image
package. The probe used public posts [12624776](https://danbooru.donmai.us/posts/12624776)
and [12625250](https://danbooru.donmai.us/posts/12625250).

| Input | Dart scores for the expected posts | Ranking |
| --- | --- | --- |
| Original JPEG | 94.40% and 92.86% | First for both |
| Resized JPEG, 69 kB and 79 kB | 94.39% and 89.99% | First for both |
| Recompressed JPEG | 94.43% and 92.90% | First for both |
| Crop retaining 85% of each dimension | 30.14% and 43.28% | First for both |
| Unrelated synthetic controls | Top scores 6.66% and 11.14% | Expected posts absent from the top ten |

The resized, recompressed and cropped files had a different MD5 from their
original. The unauthenticated endpoint returned HTTP 403 for both the signature
and a post-ID control.

[Claret Flint, post 12596931](https://danbooru.donmai.us/posts/12596931) ranked
first for every test below. The source PNG was 2048 × 2048 and scored 91.38%.
The highest other hit across the JPEG tests was 21.24% or lower.

| JPEG scale | Dimensions | Quality 90 | Quality 80 | Quality 50 |
| --- | --- | ---: | ---: | ---: |
| 100% | 2048 × 2048 | 91.50% | 91.47% | 91.33% |
| 50% | 1024 × 1024 | 91.42% | 91.43% | 91.36% |
| 25% | 512 × 512 | 91.40% | 91.45% | 91.49% |
| 10% | 205 × 205 | 75.35% | 76.09% | 74.06% |

The 90-point default auto-accepts the nine larger JPEGs in this sample. The
10% variants qualify for manual review. IQDB scores measure similarity and
these probes cover a small set of images.
