# Consider independent read state across feeds sharing an internal search

Priority: Low
Affected feature: Following feeds

## Problem

A visible user pin has its own TrackedSearch and read state, even when a feed
follows the same tag. Opening a feed does not mark that pin read. Internal
TrackedSearch records may still be shared by multiple feeds. If one feed is
opened, its internal search is marked read and `NEW` can disappear from another
feed that references the same internal search.

This coupling is accepted for the current feed redesign. The feed's `NEW`
indicator is derived from whether any referenced search has `NEW`; no separate
feed read state is required now.

## Potential future behavior

Evaluate whether each feed should track its own read state while sharing an
internal search's query, refresh checkpoint, and fetched results. If adopted,
reading one feed would not clear another feed's `NEW` state.

## Acceptance criteria

- Document the user benefit and cost of independent read state before changing
  the accepted shared behavior.
- Specify how opening one feed and sharing one internal search across multiple
  feeds affect each feed's `NEW` state.
- If independent state is approved, keep one refresh source per search and
  verify the chosen read behavior for overlapping feeds. Visible user pins
  remain independent in either case.

## Relevant context and dependencies

- Depends on the feed redesign's final search membership model.
- The current decision favors simple, source-level `NEW` state and eventual
  consistency across feeds over separate read checkpoints per feed.

## Blocker

The product decision to add independent read state has been deferred until
the feed redesign is settled and its benefit can be assessed.
