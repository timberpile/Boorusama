#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
validator="$repo_root/.devcontainer/validate-workspace.sh"
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

mkdir -p "$test_root/bin"
mkdir -p "$test_root/repo/.worktrees/feed" "$test_root/elsewhere/feed"
cat >"$test_root/bin/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case "$*" in
  "rev-parse --show-toplevel") printf '%s\n' "$FAKE_TOPLEVEL" ;;
  "rev-parse --absolute-git-dir") printf '%s\n' "$FAKE_GIT_DIR" ;;
  "rev-parse --path-format=absolute --git-common-dir")
    if [[ ${FAKE_COMMON_DIR_ERROR:-false} == true ]]; then
      exit 1
    fi
    printf '%s\n' "$FAKE_COMMON_DIR"
    ;;
  "worktree add -h")
    if [[ ${FAKE_RELATIVE_PATHS:-true} == true ]]; then
      printf '%s\n' '    --[no-]relative-paths use relative paths for worktrees'
    fi
    ;;
  *)
    printf 'Unexpected git invocation: %s\n' "$*" >&2
    exit 2
    ;;
esac
EOF
chmod +x "$test_root/bin/git"

run_validator() {
  local mode=$1
  local workspace=$2
  shift 2
  env \
    PATH="$test_root/bin:$PATH" \
    BOORUSAMA_WORKSPACE_MODE="$mode" \
    BOORUSAMA_WORKSPACE="$workspace" \
    BOORUSAMA_REPOSITORY_ROOT="$test_root/repo" \
    "$@" \
    bash "$validator"
}

expect_success() {
  local name=$1
  shift
  if ! output=$("$@" 2>&1); then
    printf 'FAIL: %s\n%s\n' "$name" "$output" >&2
    exit 1
  fi
  printf 'PASS: %s\n' "$name"
}

expect_failure() {
  local name=$1
  local message=$2
  shift 2
  if output=$("$@" 2>&1); then
    printf 'FAIL: %s unexpectedly succeeded\n' "$name" >&2
    exit 1
  fi
  if [[ $output != *"$message"* ]]; then
    printf 'FAIL: %s did not report %q\n%s\n' "$name" "$message" "$output" >&2
    exit 1
  fi
  printf 'PASS: %s\n' "$name"
}

expect_success \
  'accepts the main checkout in standard mode' \
  run_validator standard "$test_root/repo" \
  FAKE_TOPLEVEL="$test_root/repo" \
  FAKE_GIT_DIR="$test_root/repo/.git" \
  FAKE_COMMON_DIR="$test_root/repo/.git"

expect_success \
  'accepts a project-local linked worktree in worktree mode' \
  run_validator worktree "$test_root/repo/.worktrees/feed" \
  FAKE_TOPLEVEL="$test_root/repo/.worktrees/feed" \
  FAKE_GIT_DIR="$test_root/repo/.git/worktrees/feed" \
  FAKE_COMMON_DIR="$test_root/repo/.git"

expect_failure \
  'rejects worktree mode for the main checkout' \
  'Select the standard Dev Container configuration' \
  run_validator worktree "$test_root/repo" \
  FAKE_TOPLEVEL="$test_root/repo" \
  FAKE_GIT_DIR="$test_root/repo/.git" \
  FAKE_COMMON_DIR="$test_root/repo/.git"

expect_failure \
  'rejects standard mode for a linked worktree' \
  'Select the worktree Dev Container configuration' \
  run_validator standard "$test_root/repo/.worktrees/feed" \
  FAKE_TOPLEVEL="$test_root/repo/.worktrees/feed" \
  FAKE_GIT_DIR="$test_root/repo/.git/worktrees/feed" \
  FAKE_COMMON_DIR="$test_root/repo/.git"

expect_failure \
  'rejects linked worktrees outside the supported directory' \
  'must be located at' \
  run_validator worktree "$test_root/elsewhere/feed" \
  FAKE_TOPLEVEL="$test_root/elsewhere/feed" \
  FAKE_GIT_DIR="$test_root/repo/.git/worktrees/feed" \
  FAKE_COMMON_DIR="$test_root/repo/.git"

expect_failure \
  'reports unresolved common Git metadata' \
  'Cannot resolve the shared Git metadata' \
  run_validator worktree "$test_root/repo/.worktrees/feed" \
  FAKE_TOPLEVEL="$test_root/repo/.worktrees/feed" \
  FAKE_GIT_DIR="$test_root/repo/.git/worktrees/feed" \
  FAKE_COMMON_DIR="$test_root/repo/.git" \
  FAKE_COMMON_DIR_ERROR=true

expect_failure \
  'reports incompatible Git installations' \
  'Git does not support relative worktree paths' \
  run_validator worktree "$test_root/repo/.worktrees/feed" \
  FAKE_TOPLEVEL="$test_root/repo/.worktrees/feed" \
  FAKE_GIT_DIR="$test_root/repo/.git/worktrees/feed" \
  FAKE_COMMON_DIR="$test_root/repo/.git" \
  FAKE_RELATIVE_PATHS=false
