#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

fvm flutter build web --web-define=BOORUSAMA_ICON_FLAVOR=dev "$@"
