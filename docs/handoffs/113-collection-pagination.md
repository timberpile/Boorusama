# Issue #113 — collection pagination handoff

[Current all-branch review](113-all-live-review-2026-10-30.md) supersedes the technical-readiness status below; this record retains its original evidence.

Continue `bug/113-collection-pagination`, based on develop
`422aeae087c1108e655d85d1a3dac25120456cd6`. Read current AGENTS.md and issue
comments first. The remote implementation session releases ownership on handoff.
Do not create a replacement branch, merge, close the issue, create a PR, or
publish a release without the corresponding authorization.

## Source changes

- PostGridController now consumes explicit hasMore first, then maxPage and
  known totals, before falling back to nonempty raw pages. Local visibility and
  deduplication are not treated as proof that an unknown source ended.
- The final nonempty page is ingested even when hasMore is false. Paginated
  previous-page navigation remains available; failed next-page requests retain
  their retry position.
- SinglePagePostListScaffold explicitly marks its snapshot as complete.
- Pool ID slices expose maxPage/hasMore independently of missing or restricted
  returned posts. Failed repository lookups propagate instead of becoming a
  successful empty collection.
- Two focused test files cover these contracts.

## Checks and limits

Original copied source was verified against GitHub blob SHAs, and the focused
source diff and `git diff --check` were inspected. Work was prepared in an
isolated partial-source Git worktree and published using GitHub Git objects
against the complete remote base tree; it was not a full local checkout.

The attempted `fvm flutter test --no-pub` command could not start: fvm is absent
(exit 127). Flutter and Dart are absent. No formatting, analyzer, Dart tests,
Android build, emulator, or independent review has passed here. No integration
readiness is claimed.

## Local completion

1. Fetch and attach the existing remote branch to an isolated normal worktree.
2. Format the changed Dart files with FVM, analyze the affected scope, and run:

   ```bash
   fvm flutter test --no-pub test/core/posts/listing/post_grid_controller_exhaustion_test.dart test/core/posts/pools/pool_post_ids_exhaustion_test.dart test/core/posts/listing/post_grid_controller_refresh_test.dart test/core/posts/post_grid_controller_selection_test.dart
   ```

3. Check relevant existing pool, search-pagination, and mixed-viewer consumers.
   Pay attention to sources that return misleading page-local totals. Do not
   infer exhaustion from the filtered item count or merely a short page.
4. On Android, open Related Posts and small/large Pools from a post. Verify no
   redundant Load More for complete data, final-page retention, normal loading
   for larger pools, all-filtered intermediate pages, and retry after a failure.
   Follow emulator leases and Maestro instructions; do not expose credentials.
5. Fix findings, rerun affected checks, and run the complete regression suite
   before any develop integration. Prepare a development build for Timber's
   manual acceptance, reporting the exact commit and actual test/device results.

This branch does not contain or depend on #114–#120. Those tasks must not be
silently cherry-picked into this candidate.
