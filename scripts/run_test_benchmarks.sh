#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

fvm flutter test --no-pub --concurrency=1 \
  benchmark/bookmark_pipeline_performance_test.dart \
  benchmark/post_pipeline_performance_test.dart \
  benchmark/feed_cache_profile_uuid_performance_test.dart
