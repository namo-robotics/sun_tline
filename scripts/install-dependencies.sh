#!/usr/bin/env bash
# Build configured Git dependencies and retain resolution records and licenses for packaging.
set -euo pipefail
cd "$(dirname "$0")/.."
compiler=${SUN_EXECUTABLE:-sun}
mkdir -p build/dependencies tmp
for dependency in sun_ui sun_gobject; do
  destination="build/dependencies/$dependency"
  mkdir -p "$destination"
  # Preserve build diagnostics; the final output line is the resolution record.
  if ! "$compiler" resolve --config sun-config.json --dependency "namo-robotics/$dependency" > "tmp/resolve-$dependency.log"; then
    cat "tmp/resolve-$dependency.log" >&2
    exit 1
  fi
  cat "tmp/resolve-$dependency.log"
  tail -n 1 "tmp/resolve-$dependency.log" > "$destination/resolution.json"
  root=$(python3 -c 'import json, sys; print(json.load(sys.stdin)["root"])' < "$destination/resolution.json")
  install -m 644 "$root/share/$dependency/LICENSE" "$destination/LICENSE"
done
"$compiler" --version > build/sun-version.txt
echo 'Git dependencies are built and license notices are ready.'
