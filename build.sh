#!/usr/bin/env bash
# Build configured products and run the selected tests from the repository root.
set -euo pipefail
cd "$(dirname "$0")"
compiler=${SUN_EXECUTABLE:-sun}
mode=${1:---all}
if (($# > 1)); then
  echo 'Usage: ./build.sh [--all|--build|--test|--plot-test|--self-test]' >&2
  exit 1
fi
case "$mode" in
  --all|--build|--test|--plot-test|--self-test) ;;
  *) echo "Unknown build mode: $mode" >&2; exit 1 ;;
esac
mkdir -p build
"$compiler" --version > build/sun-version.txt
configuration=$("$compiler" describe --config sun-config.json)

# Read an artifact path from the compiler's resolved configuration.
product_path() {
  python3 -c 'import json, sys; print(next(entry for entry in json.load(sys.stdin)["entrypoints"] if entry["name"] == sys.argv[1])[sys.argv[2]])' "$1" "$2" <<< "$configuration"
}

# Build a named test product and run its generated test executable.
run_tests() {
  "$compiler" build --config sun-config.json --entrypoint "$1"
  "$(product_path "$1" test_binary_name)" --test-sequential
}

case "$mode" in
  --test) run_tests tline-tests ;;
  --plot-test) run_tests plot-tests ;;
  *)
    "$compiler" build --config sun-config.json --entrypoint sun_tline
    cp "$(product_path sun_tline output_name)" build/sun_tline
    if [[ $mode == --all ]]; then
      run_tests tline-tests
      run_tests plot-tests
    fi
    if [[ $mode != --build ]]; then build/sun_tline --self-test; fi
    ;;
esac
