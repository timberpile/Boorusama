# Follow-up source-review corrections

Refs #71. Corrected a second set of concrete findings before local handoff:

- Danbooru parent accepts a single ID, any/none or a parent status, not numeric
  comparisons or ranges. Child accepts presence/status values, not a child ID.
- Default duration drafts are checked against the selected option's units;
  Hydrus no longer starts with the unsupported Danbooru-style `7d` value.
- The sheet uses the actual remaining viewport rather than enforcing a minimum
  height larger than the available space when a keyboard is open.
- An existing invalid negation can be removed with Include even when the
  backend does not support Exclude for that option.
- Corrected two missing SelectedTagController test imports found during review.
- Added a booru_clients HTTP-interceptor test asserting native Philomena q,
  sf/sd, paging, and backwards-compatible legacy tag conversion.

Source for relationship syntax:
https://github.com/danbooru/danbooru/blob/master/app/models/post.rb

All added Dart/Flutter tests still need to be executed locally. No current
compiler, analyzer, emulator or live API pass is claimed by this source review.
