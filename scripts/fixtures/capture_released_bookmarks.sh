#!/usr/bin/env bash
# Run with a detached fixture-only checkout and a separate output directory.
set -euo pipefail

if [[ $# != 2 ]]; then
  printf 'Usage: %s RELEASE_CHECKOUT OUTPUT_DIRECTORY\n' "$0" >&2
  exit 2
fi
driver="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
checkout="$(realpath "$1")"
mkdir -p "$2"
output="$(realpath "$2")"
cd "$checkout"
if git symbolic-ref -q HEAD || [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
  printf '%s\n' 'Use a detached checkout with no tracked modifications.' >&2
  exit 2
fi

for tag in v4.5.0-timberpile.{3,4,5} v4.6.1-timberpile.{1,2,3}; do
  if [[ -e "$output/$tag/bookmarks.json" ]]; then
    continue
  fi
  git switch --detach "$tag"
  layout=5
  case "$tag" in
    v4.5.0-timberpile.3|v4.5.0-timberpile.4) layout=4 ;;
  esac
  cp "$driver/released_bookmark_writer.dart.txt" test/released_bookmark_writer_test.dart
  if [[ "$layout" == 5 ]]; then
    sed -i "s|// RELEASE_LAYOUT_IMPORTS|import 'package:boorusama/core/groups/folder_tree.dart';|" test/released_bookmark_writer_test.dart
  fi
  cp "$driver/released_bookmark_v$layout.dart.txt" test/released_bookmark_layout.dart
  if [[ "$tag" != v4.6.1-timberpile.3 ]]; then
    sed -i '/await groups.recordManualGroupInteraction/d' test/released_bookmark_layout.dart
  fi
  fvm dart pub get --offline
  ./gen.sh
  git rev-parse HEAD
  RELEASE_FIXTURE_OUTPUT="$output/$tag" fvm flutter test --no-pub --reporter expanded test/released_bookmark_writer_test.dart
done
