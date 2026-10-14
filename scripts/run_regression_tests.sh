#!/usr/bin/env bash
# Complete pre-integration regression gate; workload benchmarks stay opt-in.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

test_concurrency="${TEST_CONCURRENCY:-$(python3 scripts/physical_core_count.py)}"
if [[ ! "$test_concurrency" =~ ^[1-9][0-9]*$ ]]; then
  printf '%s\n' 'TEST_CONCURRENCY must be a positive integer.' >&2
  exit 2
fi
fvm flutter test --no-pub "--concurrency=$test_concurrency"
for package in packages/*; do
  [[ -d "$package/test" ]] || continue
  # No matching files returns one; discovery errors must fail the gate.
  test_files="$(rg --files "$package/test" -g '*_test.dart')" || {
    discovery_status=$?
    [[ $discovery_status -eq 1 ]] || exit "$discovery_status"
  }
  [[ -n "$test_files" ]] || continue
  (
    cd "$package"
    # booru_clients uses graphql_flutter through its workspace dependencies.
    if rg --quiet 'sdk: flutter|graphql_flutter:' pubspec.yaml; then
      fvm flutter test --no-pub "--concurrency=$test_concurrency"
    else
      package_status=$?
      [[ $package_status -eq 1 ]] || exit "$package_status"
      fvm dart test "--concurrency=$test_concurrency"
    fi
  )
done
.github/scripts/test-pull-request-policy.sh
.github/scripts/test-android-release-scripts.sh
python3 -m unittest discover -s scripts/tests
