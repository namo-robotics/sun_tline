#!/usr/bin/env bash
# Run Sun build orchestration from this repository's root.
set -euo pipefail
cd "$(dirname "$0")"
exec "${SUN_EXECUTABLE:-sun}" src/tools/build.sun -- "${1:---all}"
