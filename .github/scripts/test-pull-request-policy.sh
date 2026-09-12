#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
validator="$script_dir/validate-pull-request-policy.sh"
failures=0

expect_success() {
  local description=$1
  shift

  if "$@" >/dev/null 2>&1; then
    echo "ok - $description"
  else
    echo "not ok - $description"
    failures=$((failures + 1))
  fi
}

expect_failure() {
  local description=$1
  shift

  if "$@" >/dev/null 2>&1; then
    echo "not ok - $description"
    failures=$((failures + 1))
  else
    echo "ok - $description"
  fi
}

expect_success \
  'feature branches with a matching title and linked issue can target develop' \
  "$validator" \
  develop \
  feature/42-load-original-on-zoom \
  "Merge branch 'feature/42-load-original-on-zoom'" \
  'Closes #42'

expect_success \
  'fix branches with a matching title and linked issue can target develop' \
  "$validator" \
  develop \
  fix/51-handle-empty-tags \
  "Merge branch 'fix/51-handle-empty-tags'" \
  'Fixes #51'

expect_failure \
  'develop rejects branches without an issue identifier' \
  "$validator" \
  develop \
  feature/load-original-on-zoom \
  "Merge branch 'feature/load-original-on-zoom'" \
  'Closes #42'

expect_failure \
  'develop rejects titles that do not name the source branch' \
  "$validator" \
  develop \
  feature/42-load-original-on-zoom \
  'Load original images on zoom' \
  'Closes #42'

expect_failure \
  'develop rejects pull requests without a closing issue reference' \
  "$validator" \
  develop \
  feature/42-load-original-on-zoom \
  "Merge branch 'feature/42-load-original-on-zoom'" \
  'Implements the requested behavior.'

expect_success \
  'develop can be promoted to master' \
  "$validator" \
  master \
  develop \
  "Merge branch 'develop'" \
  'Closes #60'

expect_failure \
  'feature branches cannot target master directly' \
  "$validator" \
  master \
  feature/42-load-original-on-zoom \
  "Merge branch 'feature/42-load-original-on-zoom'" \
  'Closes #42'

if ((failures > 0)); then
  echo "$failures pull request policy test(s) failed"
  exit 1
fi

echo 'All pull request policy tests passed'
