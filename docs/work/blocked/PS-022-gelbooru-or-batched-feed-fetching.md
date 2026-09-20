# Evaluate a single Gelbooru OR search for followed tags

Priority: Low
Affected feature: Following-feed source fetching; Gelbooru integration

## Problem

The general feed path uses a separate internal search for each followed tag.
For a Gelbooru feed whose followed tags can be ORed, this creates unnecessary
search records and requests. A bounded probe with 1,000 artist tags returned a
valid first page, including a controlled result from the 1,000th operand.
The first page represented 16 artists, which is sufficient for a first page of
one combined search; those artists do not need individual search checkpoints.

## Expected behavior

The feed owns its user-facing list of followed tags. An optional
Gelbooru-specific strategy compiles compatible tags into **one internal
TrackedSearch** with an OR query. That search has one refresh checkpoint, NEW
state, and paginated result stream. The feed derives NEW from that internal
search and any other internal searches it contains. There are no individual
TrackedSearch records for tags covered by the OR search. Keep the general
independent-search path for engines and queries that cannot use the strategy.
An individually pinned tag is a separate visible TrackedSearch with its own
checkpoint and NEW state; it does not share the aggregate feed search.

## Acceptance criteria

- Keep followed-tag membership in the feed definition, independent of the
  generated OR query. Generate one internal search for compatible tags from
  the same Gelbooru profile; do not create one internal search per tag.
- Define eligibility for plain artist tags. Exclude aliases, metatags,
  compound queries, and unsupported syntax unless their behavior is verified.
- Treat the generated OR search as one ordinary paginated search for refresh,
  NEW, feed history, and its session cache. Do not require attribution or
  checkpoints for the individual tags in that search.
- When tags are added or removed, rebuild the generated query, establish the
  appropriate no-NEW baseline for newly followed content, and remove stale
  feed results that match only removed tags.
- Check authenticated API behavior, query length, pagination, ordering, and
  error/rate-limit behavior. Measure representative feeds before claiming a
  performance benefit.
- Preserve the general independent-search path for unsupported engines or
  queries; migrate existing Gelbooru feed tags without losing the feed
  definition or creating duplicate internal searches.
- Keep the compiler behind an engine-specific interface so other boorus and
  ordinary pinned searches do not depend on Gelbooru OR syntax. Verify that
  opening or refreshing the feed leaves a separately pinned tag's read state
  unchanged.

## Relevant context and dependencies

- [Artist fixtures and measured OR probe](../../superpowers/data/README.md).
- [Large-feed refresh task](../done/PS-010-large-feed-incremental-refresh.md)
  already identified OR sharding as conditional future work; this task tracks
  the separate decision and implementation evidence.
- Depends on the new feed/source architecture and its pagination and freshness
  contract. No implementation is requested during the current design phase.

## Blocker

The feed's followed-tag definition and its engine-specific search compiler are
still being designed. The authenticated Gelbooru post API has not yet been
verified with the combined query in this project.
