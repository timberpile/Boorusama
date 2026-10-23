# Search option coverage and evidence

Related: #71. Branch: `feature/71-search-options`. Sources inspected on
2026-10-23. This is a capability/implementation inventory, not a live-server
certification. The remote continuation has not run Flutter or API acceptance
tests. **All filters on all sites are not yet implemented.**

**Realbooru source update (2026-10-23):** The site's own cheatsheet and
API help confirm the common legacy metatag and sort baseline, including
sorting by rating and parent; Rule34's random/source extras are not inferred
for Realbooru. Rule34's own website-documented ratio/domain predicates are
omitted from its API catalog after authenticated known-match probes returned
empty. The shared parser and UI now agree on these host-specific API rules. See the dedicated realbooru.md handoff for
live-validation limits.

The registered-site inventory is `packages/booru_clients/boorus.yaml`. Thirteen
of its seventeen engine families now have at least one guided option. That
count does not imply exhaustive coverage, deployment compatibility or account
entitlement. Native input remains available; unsupported and unverified are
not interchangeable labels.

## Site and engine matrix

| Engine / registered sites | Implemented guided coverage | Evidence and remaining work |
| --- | --- | --- |
| Danbooru: danbooru.donmai.us, donmai.moe, safebooru.donmai.us, testbooru.donmai.us; AIBooru | Current public metatag vocabulary: counts/dimensions, dates/age, rating, score, status, type, ratios/sizes/duration, sources/text/hash, user roles, pools/groups/saved searches, ordering, limits/random. | Current Danbooru parser and help; cloned deployments and account permissions still need acceptance. Advanced Boolean/text/custom-order payloads are not fully graphical. |
| Gelbooru.com | Rating, sort/random, score/ID, uploader, dimensions, exact parent/favorite/pool IDs, MD5. | Official help plus existing client/extractor. No invented Danbooru age or date filter. |
| Gelbooru 0.2 family: Rule34, HypnoHub, Realbooru, Xbooru, Safebooru.org, Bbooru, TBIB | Existing integration-declared common rating/sort/score/ID/user/dimension/parent/hash fields. Rule34 additionally has random sorting and verified source URL/pattern filtering. Its website-documented ratio/domain controls are omitted because authenticated known-match API probes return empty. | Common legacy baseline is not individually live-verified. Rule34 API rating/score/sort/random/source and tag autocomplete were checked live; Safe returned empty. Its additions are host-specific and are not propagated to all clones. Unknown custom hosts remain conservative. |
| Gelbooru 0.1: illusioncards.booru.org | No new guided catalog. | Legacy tag search remains. Its current public filter grammar has not been established; do not assign it the 0.2 catalog merely by family name. |
| Moebooru: Konachan.com/.net, Yande.re, Sakugabooru | Rating, sort, score/ID, uploader, dimensions/ratio, dates, source/hash, pools/favorites/subscriptions/votes and documented state flags. Username autocomplete. | Engine parser and user controller. Version and deployed-site differences require overrides after verification. Some predicates cannot be negated with the same payload. |
| e621 / e926 | Public metatag/count/boolean vocabulary, own dialect for ratings/status/locks, types, dimensions/date/age, file sizes, source/text, account relations, order, exact IDs/seed/limit. Username lookup. | e621ng parser. Staff-only flags and private vote/favorite queries require role/privacy handling; a visible field does not establish access. |
| Philomena: Derpibooru / Ponybooru | Public numeric/date/text/ID/boolean fields, uploader/favorite relations and own-account filters; suffix comparisons and ranges. API sorting through `sf`/`sd`. | Current parser/sort modules and existing client. Ratings are tags, not a fictional `rating:` field. Moderator-only fields are omitted. Older deployments require acceptance. |
| Shimmie2: Rule34 @ Paheal | Fields advertised by Paheal's live help: IDs/poster/score/date/counts/dimensions/size/ratio/duration, source/hash/file/media fields, comment/vote users, locks and ordering. | Live Paheal help. Restricted to this host; Shimmie extensions differ. Native exact values use `=`, comparisons have no colon. |
| Szurubooru: user-configured instances | Public named post-search fields, counts/dates/media/source/hash/category, rating/sort, user relations, pool ID and own-account special predicates. User/pool suggestions. | Public parser and API docs. Inclusive ranges, negated strict bounds and comma sort directions. Instance permissions and versions require acceptance. |
| Hydrus: user-configured client API | Dimensions, counts/views, file size, duration/framerate, absolute dates and limit. | Developer API/system predicate parser. Partial: service-dependent ratings/domains, similarity, arbitrary regex/URL predicates, unary predicates and API sorting remain. Leading `-system:` is never generated. |
| Anime-Pictures | Exact favoriting account ID via existing `stars_by` API parameter. | Current client contract. Partial: other web controls still need verified request mappings and coverage. No claimed username lookup. |
| Hybooru | Date/ID/score/size/server-preset ordering, numeric service ratings and closed ranges, inbox/archive/trash. | Documented query syntax. Numeric service ratings are not safety ratings; imported rating scales and custom sorts are instance-specific. |
| e-shuushuu | Exact uploader/favoriting account IDs via existing API parameters. | Current client contract. Partial: other API/web controls and entity discovery remain. Existing tag resolution semantics are unchanged. |
| Nozomi | Existing Date/Popular post-index ordering exposed in the common interface. | Existing index client and previously implemented ordering. No invented score/age/rating/dimension predicate. |
| Zerochan / Asiachan | No new guided catalog. | Existing client has recency/popularity only for a nonempty tag search. It needs query-aware availability plus a request adapter; the current normal post provider fixes recency. Public documentation verification was insufficient. |
| Sankaku: Channel, beta, app and Idol variants | No new guided catalog. | Existing native authenticated search remains. Current official syntax/account restrictions could not be verified sufficiently; do not copy Danbooru's complete grammar. |
| Pixiv | No new guided catalog. | Client has search target/order/duration/date parameters, but current user scope overrides text search. Needs validated mutually exclusive endpoint scopes, parameter wiring and entitlement checks; merely displaying those controls would silently ignore combinations. |

## Shared UI, distinct request contracts

The same section, value editor and suggestion surface consume small
`SearchOption` definitions. Options describe their own input type, choices,
operators, units, allowed ranges and exclusion. Specialized serializers handle
non-interchangeable syntax. `withFree` preserves those serializers instead of
turning them into generic colon-tag options. FREE still uses existing metadata;
it is not monetary pricing or an account privilege.

Numbers, durations, dates/calendars, choices, ratios and file sizes reuse typed
controls. Account/pool fields use verified entity endpoints where available.
Selecting a suggestion changes the sheet draft only. Apply commits; Cancel,
barrier dismissal and system Back must leave the query unchanged. Requests are
profile-scoped, debounced and bounded, with cancellation for direct HTTP calls.
There is no generic fall-through from username lookup to ordinary tag results.

Native wire expressions use the existing selected-item representation. Known
colon, comparator-suffix and equals forms are recognized for reopening and
replacement. Raw items remain opaque unless explicitly selected for editing.
Danbooru's ordered pool/favorite/vote operators share an exclusive ordering
family; other engines do not automatically inherit that rule.

Some options are API parameters rather than native query clauses. Philomena,
Nozomi and the added e-shuushuu/Anime-Pictures account filters have explicit
request adapters. Supported top-level directives are consumed even when
History, sharing or Topics flatten mixed input into one raw item. The bounded scanner preserves the
remaining native query as one item; it does not split arbitrary raw text into
tags. Quoted, escaped, grouped, malformed, negated and unknown directives remain
opaque. Regression cases cover flattened Philomena sorting, Nozomi ordering and
account-ID parameters, including quoted/grouped input. General native Boolean
parsing and reconstruction of lost tag boundaries remain outside this adapter.
See the local continuation results in the issue handoff for runtime/live limits.

## Danbooru's former native-only rows

Those were an incomplete conservative first pass, not a fundamental API
limitation. The current public parser vocabulary now receives typed basic
editors. `newpool` is a post-edit operation and `locked` is absent from the
current Danbooru post-search parser; they are not advertised as current filters.
Existing pins/raw expressions are not deleted. Future unknown asset keys retain
a native fallback instead of receiving an invented schema.

Discovery surfaces show one preferred name for complete field synonyms, using
an explicit engine-scoped alias map. Danbooru prefers `pixiv_id`, explicit
`*_count` fields, `commenter` and `commentaryupdater`; e621 follows its primary
file-type, user/vote and parent/child parser names. The full grammar still
recognizes the other spellings for typed input, history, Topics and sharing.
Old alias pins resolve to the preferred row and unpin clears their saved
spellings. Guided replacement treats synonyms as one field while leaving raw
expressions opaque. Similar labels or partially overlapping predicates are
insufficient grounds for consolidation: uploader name/ID, note creator/updater,
age/date and up/down/any votes retain their distinct controls.

Parent accepts an exact ID or presence/status; child accepts presence/status,
not a numeric child ID. Age/score equality and ranges support predicate negation;
simple comparisons use exact inverse boundaries. Result counts and random
sample sizes accept exact numbers rather than comparisons or ranges. Advanced
quoted multiword text, Boolean groups, custom ordering and some compound entity
payloads remain native-entry features.

## Evidence sources

Primary syntax/server sources:

- Danbooru: https://safebooru.donmai.us/wiki_pages/help:cheatsheet
- Danbooru parser: https://github.com/danbooru/danbooru/blob/master/app/logical/post_query_builder.rb
- Danbooru query rules: https://github.com/danbooru/danbooru/blob/master/app/logical/post_query.rb
- Danbooru relationship predicates: https://github.com/danbooru/danbooru/blob/master/app/models/post.rb
- Gelbooru: https://gelbooru.com/index.php?page=wiki&s=view&id=26263
- Safebooru legacy baseline: https://safebooru.org/index.php?page=help&topic=cheatsheet
- Rule34: https://rule34.xxx/index.php?page=help&topic=cheatsheet
- Moebooru parser: https://github.com/moebooru/moebooru/blob/master/app/models/tag.rb
- Moebooru users: https://github.com/moebooru/moebooru/blob/master/app/controllers/user_controller.rb
- e621 grammar: https://github.com/e621ng/e621ng/blob/master/app/logical/tag_query.rb
- e621 users: https://github.com/e621ng/e621ng/blob/master/app/models/user.rb
- Philomena fields: https://github.com/philomena-dev/philomena/blob/master/lib/philomena/images/query.ex
- Philomena comparisons: https://github.com/philomena-dev/philomena/blob/master/lib/philomena_query/parse/parser.ex
- Philomena order: https://github.com/philomena-dev/philomena/blob/master/lib/philomena/images/search/sort_field.ex
- Paheal: https://rule34.paheal.net/help/search
- Szurubooru: https://github.com/rr-/szurubooru/blob/master/server/szurubooru/search/configs/post_search_config.py
- Szurubooru grammar: https://github.com/rr-/szurubooru/blob/master/server/szurubooru/search/parser.py
- Szurubooru API: https://github.com/rr-/szurubooru/blob/master/doc/API.md
- Hydrus API: https://hydrusnetwork.github.io/hydrus/developer_api.html
- Hydrus predicates: https://github.com/hydrusnetwork/hydrus/blob/master/hydrus/external/SystemPredicateParser.py
- Hybooru: https://github.com/funmaker/Hybooru#searching-query-syntax

The first Rule34 fetch encountered age verification; a subsequent fetch of its
current help succeeded and supplied the host-specific additions above. Syntax
research is not evidence that every deployed API/account accepts every option.
For client-backed mappings inspect the corresponding files under
`packages/booru_clients/lib/src/` and `lib/boorus/`; do not replace those actual
contracts with generic engine assumptions.

## Verification and localization

The remote implementation phase did not execute Flutter. The subsequent local
continuation applied the manifests to the actual English/German resources,
generated accessors, completed the declared-label/description gaps, compiled
and tested the implementation, and exercised Android at narrow width/2x text.
Consult the current handoff for the checked runtime SHA, final suite counts,
actual live-service evidence and remaining authentication/availability gates.
Historical remote-phase source review is not runtime proof, and successful
local automation does not certify every deployed site/account.

The current local handoff is
[follow-up.md](../handoffs/71-search-options/follow-up.md). Earlier successful
local runs in `verification.md` are historical evidence only and do not qualify
these new commits. Integration requires the complete final-candidate regression
suite, independent review and explicit user approval.
