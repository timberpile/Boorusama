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
  'issue-numbered feature branches can target develop' \
  "$validator" \
  develop \
  feature/42-load-original-on-zoom

expect_success \
  'fix branches can target develop' \
  "$validator" \
  develop \
  fix/51-handle-empty-tags

expect_success \
  'feature branches without an issue can target develop' \
  "$validator" \
  develop \
  feature/load-original-on-zoom

expect_success \
  'upstream synchronization can target develop without an issue' \
  "$validator" \
  develop \
  sync/upstream-master

expect_success \
  'develop can be promoted to master without an issue' \
  "$validator" \
  master \
  develop

expect_failure \
  'feature branches cannot target master directly' \
  "$validator" \
  master \
  feature/42-load-original-on-zoom

expect_failure \
  'obsolete title and body arguments are rejected' \
  "$validator" \
  develop \
  feature/42-load-original-on-zoom \
  'An unused title' \
  ''

dependabot_context=(env 'PR_AUTHOR=dependabot[bot]' \
  PR_HEAD_REPOSITORY=timberpile/Boorusama \
  PR_BASE_REPOSITORY=timberpile/Boorusama)

expect_success 'Dependabot Actions updates can target develop' \
  "${dependabot_context[@]}" "$validator" develop dependabot/github_actions/actions/checkout-6
expect_failure 'Dependabot updates cannot target master' \
  "${dependabot_context[@]}" "$validator" master dependabot/github_actions/actions/checkout-6
expect_failure 'a human cannot impersonate a Dependabot branch' \
  "${dependabot_context[@]}" PR_AUTHOR=someone "$validator" develop dependabot/github_actions/actions/checkout-6
expect_failure 'a Dependabot branch from a fork is rejected' \
  "${dependabot_context[@]}" PR_HEAD_REPOSITORY=someone/Boorusama "$validator" develop dependabot/github_actions/actions/checkout-6
expect_failure 'Dependabot exception is restricted to this target repository' \
  "${dependabot_context[@]}" PR_BASE_REPOSITORY=someone/Boorusama "$validator" develop dependabot/github_actions/actions/checkout-6
expect_failure 'Dependabot exception requires event metadata' \
  env -u PR_AUTHOR -u PR_HEAD_REPOSITORY -u PR_BASE_REPOSITORY \
  "$validator" develop dependabot/github_actions/actions/checkout-6
expect_failure 'unconfigured Dependabot ecosystems are rejected' \
  "${dependabot_context[@]}" "$validator" develop dependabot/pub/some-package-2

if ((failures > 0)); then
  echo "$failures pull request policy test(s) failed"
  exit 1
fi

echo 'All pull request policy tests passed'
