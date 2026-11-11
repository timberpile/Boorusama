# Gelbooru Pools and Related support

Baseline: `22348b2fb20049088705ce38f5b261e191b148af`; public documentation reviewed 2026-11-11. Scope is source-group browsing, not an unrestricted 'etc.' feature bundle or server-side Pool editing.

## Confirmed application gap

[createGelbooru](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/boorus/gelbooru/gelbooru.dart) registers a parser, builder and repository, but no Group capability. [GelbooruRepository](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/boorus/gelbooru/gelbooru_repository.dart) supplies Posts, tags, favorites, comments and notes, not a shared Pool/Related source. The existing [Group provider](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/content/groups/group_source_provider.dart) already supplies access-bound creation, metadata loading, cancellation and quota-aware reads; extend that infrastructure rather than adding a parallel collection repository.

The [Post parser](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/boorus/gelbooru/posts/parser.dart) retains parentId and hasChildren-shaped DTO fields. Its expression `dto.hasChildren ?? hasParent` also suppresses a real parent when hasChildren is explicitly false; the correct combined indicator for a site that supplies these facts is `hasChildren == true || hasParent`. This is a source-level edge case, not proof that Gelbooru.com currently supplies useful parent relationships.

## External evidence: do not conflate Pools and Related

The official [cheatsheet](https://gelbooru.com/index.php?id=26263&page=wiki&s=view), updated 2026-05-02, documents `pool:<id>` search. It does not list `parent:`. The official [API wiki](https://gelbooru.com/index.php?id=18780&page=wiki&s=view) says supported website metatags can be passed to Post queries, but does not document a Pool metadata/order endpoint.

An [older help page](https://gelbooru.com/index.php?page=help&topic=cheatsheet) lists parent search but explicitly warns it is out of date. A historical [moderator clarification](https://gelbooru.com/index.php?id=1939&page=forum&s=view) says parent/child associations were removed. That old statement is not a current live API test, but it makes blindly copying Danbooru Related semantics particularly unsafe. The public Pool listing exists; older [Pool help](https://gelbooru.com/index.php?page=help&topic=pool) describes ordering and different access types, also with an outdated warning.

## Recommended rollout

**Pools first.** Verify a representative accessible Pool with read-only requests: metadata identity/title, membership, page continuation, source order and access restrictions. Start from documented `pool:<id>` Post reads; inspect the site's actual metadata/order request rather than guessing a `dapi` endpoint. If no supported JSON route is available, a narrow fixture-tested HTML adapter is an explicit maintenance tradeoff, not an undocumented assumption. Do not bypass challenges or crawl the entire site.

Register a Gelbooru-owned Group capability and strict `pool:<positive-id>` key codec for verified hosts only. Return shared ContentGroupSummary/Details and GroupMemberBatch values, with unknown counts/order represented honestly. Reuse existing Group cards, embedded member grids, bookmarks, mixed Viewer, safe snapshots and `.bslink` sharing. Add Pool navigation only after listing/metadata retrieval is verified. Preserve the source's order when authoritative; ordinary `pool:` search order is not proof of custom Pool order. If custom order cannot be read, expose the available sort explicitly rather than labeling it Ordered.

Keep all reads access-scoped and bounded. Existing API credentials may not authorize personal Pool pages; retain unavailable references without leaking or silently changing accounts. Do not infer that a visibility label named Private has the same semantics as another engine's private group. Keep remote add/delete/reorder actions out of the initial read-only feature.

**Related separately.** Do not enable Danbooru-style Related on Gelbooru.com from legacy documentation or DTO field names. Require current verified parent/member semantics, then add a site-owned family key and resolver. Never approximate families using similar tags, uploader or adjacent IDs. If current Gelbooru.com has no relationship feature, this part is unsupported, not an app implementation omission. Other Gelbooru derivatives require their own capability evidence.

## Verification

Parser/capability fixtures for Pool metadata, actual ordering, pagination, unavailable/deleted members, malformed IDs, account restrictions and ignored metatags. Shared consumer tests for bookmark round-trip, mixed Viewer restoration, profile revocation and no unbounded member fetch. Test the parent-indicator truth table independently, but do not advertise Related solely because that small correction passes.

No authenticated Pool read, live parent query, runtime adapter or UI implementation was performed here. The exact current metadata/order endpoint remains the key prerequisite; the documented Post `pool:` search gives a concrete starting point rather than proof of full Pool support.
