## Context

The bulk removal notifier currently returns only an integer count of removed
memberships. The multi-selection menu uses that count to format its success
toast, while the repository already exposes the membership map needed to
identify bookmarks whose last named-group membership is being removed.

## Goals / Non-Goals

**Goals:**

- Return enough structured information to distinguish removed memberships from
  bookmarks that become ungrouped.
- Keep the membership-only removal semantics unchanged: bookmarks remain stored
  and become visible in `No Group` when their last named membership is removed.
- Keep the success message localized and omit the additional clause when its
  count is zero.

**Non-Goals:**

- Do not change single-post final-membership deletion behavior.
- Do not add a new operation or change group-selection behavior.
- Do not change the existing success or failure handling for add and delete.

## Decisions

### Return a dedicated removal result

Change the bulk removal operation to return a small result object containing
`removedCount` and `movedToNoGroupCount`. A dedicated type is preferable to a
record or a second out-parameter because the result is part of the bookmark
domain API and its fields need names that remain clear at call sites.

The provider will determine `movedToNoGroupCount` from the membership snapshot
before mutation: a bookmark counts when it belongs to the selected group and
that group is its only named membership. Bookmarks with additional memberships
are counted only in `removedCount`.

### Use two localized success-message variants

Keep the current concise message for the common case and add a second localized
message for the case where one or more bookmarks become ungrouped. The UI will
select the second variant only when `movedToNoGroupCount > 0`, avoiding empty or
awkward placeholders and allowing translators to reorder the two counts.

### Keep the provider authoritative

The UI will not infer the No Group count from its pre-dialog aggregate state.
The provider returns the result of the actual repository mutation, so concurrent
changes or bookmarks that no longer belong to the selected group cannot produce
an incorrect toast.

## Risks / Trade-offs

- **Caller/API update:** Changing the integer result to a structured result
  requires updating the multi-selection caller and provider tests. → Keep the
  result type small and update all known call sites together.
- **Translation wording:** The phrase may need grammatical variation across
  languages. → Use separate localized message keys instead of concatenating
  fragments in Dart.
- **Mixed memberships:** A bookmark can lose one membership while remaining in
  another group. → Calculate the No Group count only when the removed group was
  the complete named-membership set.
