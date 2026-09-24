#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

fvm dart run tool/generate_app_icon_sources.dart
fvm dart run flutter_launcher_icons
fvm dart run tool/generate_app_icon_flavor_outputs.dart
