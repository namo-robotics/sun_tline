#!/usr/bin/env bash
# Check the installed app in a new path without build-machine environment settings.
set -euo pipefail
cd "$(dirname "$0")/.."
[[ $# == 1 ]] || { echo 'Usage: test-macos-app.sh APP' >&2; exit 1; }
rm -rf 'build/macos-install-test'
mkdir -p 'build/macos-install-test'
app="$PWD/build/macos-install-test/Sun Tline.app"
ditto "$1" "$app"
contents="$app/Contents"
plutil -lint "$contents/Info.plist"
codesign --verify --deep --strict "$app"
while IFS=$'\t' read -r source relative; do
  while IFS= read -r dependency; do
    case "$dependency" in
      /usr/lib/*|/System/Library/*) ;;
      @loader_path/*) test -f "$(dirname "$contents/$relative")/${dependency#@loader_path/}" ;;
      *) echo "External dependency in $relative: $dependency" >&2; exit 1 ;;
    esac
  done < <(otool -L "$contents/$relative" | tail -n +2 | sed -E 's/^[[:space:]]+//; s/ \(compatibility version.*$//')
  if otool -l "$contents/$relative" | grep 'cmd LC_RPATH' >/dev/null; then
    echo "External runtime search paths remain in $relative" >&2; exit 1
  fi
done < build/macos-native-files.tsv
"$(brew --prefix coreutils)/bin/gtimeout" 60s env -i HOME="$HOME" PATH=/usr/bin:/bin \
  GTK_A11Y=none G_DEBUG=fatal-criticals SUN_TLINE_TRACE_LIBRARIES=1 \
  "$contents/MacOS/sun-tline" --self-test > build/macos-app-acceptance.log 2>&1
tail -n 10 build/macos-app-acceptance.log
./scripts/check-macos-library-trace.sh "$app" build/macos-app-acceptance.log
