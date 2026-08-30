#!/usr/bin/env bash
set -euo pipefail

mode=${BOORUSAMA_WORKSPACE_MODE:-}
workspace=${BOORUSAMA_WORKSPACE:-}
repository_root=${BOORUSAMA_REPOSITORY_ROOT:-/workspace/Boorusama}

fail() {
  printf 'Dev Container workspace error: %s\n' "$1" >&2
  exit 1
}

case "$mode" in
  standard | worktree) ;;
  *) fail 'BOORUSAMA_WORKSPACE_MODE must be standard or worktree.' ;;
esac

[[ -n $workspace && -d $workspace ]] || fail "Workspace does not exist: ${workspace:-<unset>}"

git_help=$(git worktree add -h 2>&1 || true)
[[ $git_help == *'--[no-]relative-paths'* ]] || \
  fail 'Git does not support relative worktree paths. Rebuild the Dev Container with the pinned image.'

cd "$workspace"
top_level=$(git rev-parse --show-toplevel 2>/dev/null) || \
  fail "Cannot resolve a Git working tree from $workspace."
git_dir=$(git rev-parse --absolute-git-dir 2>/dev/null) || \
  fail "Cannot resolve the private Git metadata from $workspace."
common_dir=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || \
  fail "Cannot resolve the shared Git metadata from $workspace."

[[ $top_level == "$workspace" ]] || \
  fail "The selected workspace resolves to a different Git working tree: $top_level"

worktree_prefix="$repository_root/.worktrees/"
case "$mode" in
  standard)
    [[ $workspace == "$repository_root" && $git_dir == "$common_dir" ]] || \
      fail 'This is a linked worktree. Select the worktree Dev Container configuration.'
    ;;
  worktree)
    [[ $git_dir != "$common_dir" ]] || \
      fail 'This is the main checkout. Select the standard Dev Container configuration.'
    [[ $workspace == "$worktree_prefix"* && $workspace != "$worktree_prefix" ]] || \
      fail "Linked worktrees must be located at $worktree_prefix<name>."
    [[ $common_dir == "$repository_root/.git" ]] || \
      fail "The linked worktree does not use the shared metadata at $repository_root/.git."
    ;;
esac

printf 'Validated %s checkout at %s\n' "$mode" "$workspace"
