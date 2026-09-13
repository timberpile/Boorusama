#!/usr/bin/env bash
set -euo pipefail

if (($# != 4)); then
  echo 'usage: validate-pull-request-policy.sh <base> <head> <title> <body>' >&2
  exit 2
fi

base_branch=$1
head_branch=$2
pull_request_title=$3
expected_title="Merge branch '$head_branch'"

if [[ "$pull_request_title" != "$expected_title" ]]; then
  echo "Pull request title must be: $expected_title" >&2
  exit 1
fi

case "$base_branch" in
  develop)
    if [[ ! "$head_branch" =~ ^(feature|fix)/([0-9]+-)?[a-z0-9]+(-[a-z0-9]+)*$ && "$head_branch" != sync/upstream-master ]]; then
      echo 'Pull requests to develop must use feature/<description>, fix/<description>, or sync/upstream-master.' >&2
      exit 1
    fi
    ;;
  master)
    if [[ "$head_branch" != develop ]]; then
      echo 'Only develop can be promoted to master.' >&2
      exit 1
    fi
    ;;
  *)
    echo "Unsupported protected base branch: $base_branch" >&2
    exit 1
    ;;
esac
