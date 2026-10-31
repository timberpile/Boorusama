# Neighboring Series and Pool Bookmarks — Current Scope

Issue: [#68](https://github.com/timberpile/Boorusama/issues/68).
Branch: `feature/group-neighboring-series`.
Accepted scope corrected on 2026-10-31; earlier acceptance reports describe
superseded candidates and do not verify the current source.

## Search grouping

Group only actual adjacent runs of at least two posts with a confirmed common
Series, scoped to the originating site, profile and authentication context.
Normal Danbooru Search owns this display projection. Never reorder raw results,
infer Series from artist/tags, group generic Collections, or replace controller
posts with synthetic collection posts. The shared `groupNeighboringSeries`
primitive preserves raw addressing and deterministic common-membership rules.

Use the existing Pool Gallery card with title, Series label and authoritative
whole-Series count. Loaded-run length is not a remote total. Tapping opens the
full Series under its source profile; returning preserves the underlying search.
Direct Series views and explicit `pool:`/`series:` queries do not collapse again.
Long-press enters selection over actual member posts; selecting all uses the raw
controller list. Related grouping and its tap interaction remain OPEN.

Metadata admissions contain at most 40 posts, coalesce overlapping requests, and
retain a bounded source/account-scoped cache. The first admission completes
before posts are delivered. Later viewport admissions may group only unseen
entries; built entries and anchors remain stable. Metadata failures keep ordinary
posts visible. Raw pagination retains its existing ownership/exhaustion rules;
collapsing posts must not initiate an unbounded remote fill.

## Bookmarks and covers

Keep individual bookmarked Posts separate and perform no automatic membership
lookup in Bookmarks. Explicit Pool/Series references remain independent cards in
the same Bookmark Groups. Preserve group memberships, removal/Undo, downloaded
files, individual Posts, and compatible backups/imports. A reference never implies
that its remote members are bookmarked or selected.

Persist compact reference metadata and bounded tag coverage/upload extrema,
never a complete member snapshot database. The existing bounded summary indexer
and cached-tag filtering rules remain applicable; partial tag unions cannot prove
absence in all remote members. Unknown upload extrema remain unknown.

Persist only one selected static cover's thumbnail, sample, original and media
variants. Resolve it with the source's existing listing quality provider and
headers. Existing records lacking variants use the same bounded summary path as
a fallback without rewriting their identity or memberships. Preserve visibility
policy, blacklist/rating restrictions, and missing-profile isolation. Quality
changes do not change ordinary bookmarked Post thumbnail behavior.

## Verification

Verify actual Search routing, confirmed type/count, adjacent/separated/overlapping
runs, selection, pagination, delayed metadata and stable anchors. Exercise the
live `malberrybush` search and record current data rather than assuming a Pool ID
or count. Keep individually saved Series members separate in Bookmarks. Cover
checks include old records, quality changes after persistence, mixed references
and Posts, source/account isolation, removal/Undo and backup round trips.

The local rebase onto develop is required; publication and integration are not
authorized by the review follow-up. Record exact commits and current-source
evidence in the branch handoff. Related interaction remains pending separately.
