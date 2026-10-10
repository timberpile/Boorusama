# Opt-in test benchmarks

These benchmark-style Flutter tests exercise unusually large representative
workloads and print timing/size diagnostics:

- `bookmark_pipeline_performance_test.dart`: persist and cold-load 1,000 Hive bookmarks
- `post_pipeline_performance_test.dart`: round-trip 1,000 posts and resolve 5,000 origins
- `feed_cache_profile_uuid_performance_test.dart`: deserialize a full following-feed cache

They are intentionally outside `test/` and are therefore **not run** by the
ordinary root `fvm flutter test` command or its regular CI invocation.
Run them explicitly from the repository root:

```bash
./scripts/run_test_benchmarks.sh
```

For useful comparisons, run the same workload on `develop` and on the
candidate branch with the same SDK, machine, load, and test options. Record
the toolchain and per-file timings. These are exploratory diagnostics; their
loose (or absent) timing thresholds do not prove UI performance.

Functional regression coverage remains in the normal suite:
`test/core/bookmarks/bookmark_provider_test.dart`,
`test/core/posts/post/stored_post_codec_test.dart`,
`test/core/posts/post/post_origin_resolver_test.dart`, and
`test/core/search/subscriptions/feed_post_snapshot_test.dart`.
