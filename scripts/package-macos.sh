#!/usr/bin/env bash
# Bundle native dependencies, sign the application, and create a tested disk image.
set -euo pipefail
cd "$(dirname "$0")/.."
[[ $(uname -s)-$(uname -m) == Darwin-arm64 ]]
app="$PWD/build/macos/Sun Tline.app"
contents="$app/Contents"
rm -rf build/macos
mkdir -p "$contents/MacOS" "$contents/Frameworks" "$contents/Resources/licenses" "$contents/Resources/share/glib-2.0/schemas"
cp build/sun_tline "$contents/MacOS/sun_tline"
cp README.md NOTICE build/sun-version.txt "$contents/Resources/licenses/"
cp packaging/licenses/* "$contents/Resources/licenses/"
for dep in sun_ui sun_gobject; do
  source_var=SUN_UI_SOURCE; [[ $dep == sun_gobject ]] && source_var=SUN_GOBJECT_SOURCE
  source_dir=${!source_var:-build/dependencies/$dep}
  cp "$source_dir/LICENSE" "$contents/Resources/licenses/LICENSE.$dep"
done
cat > "$contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>org.namo.sun_tline</string>
<key>CFBundleName</key><string>Sun Tline</string>
<key>CFBundleExecutable</key><string>sun-tline</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>${GITHUB_RUN_NUMBER:-1}</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
cat > "$contents/MacOS/sun-tline" <<'LAUNCHER'
#!/bin/bash
# Locate bundled schemas and start the native application independently of the shell environment.
set -euo pipefail
location=$(cd "$(dirname "$0")/.." && pwd)
export GSETTINGS_SCHEMA_DIR="$location/Resources/share/glib-2.0/schemas"
export GSK_RENDERER=cairo
exec "$location/MacOS/sun_tline" "$@"
LAUNCHER
chmod +x "$contents/MacOS/sun-tline"
# Resolve loader-relative paths against the original file before copying its dependencies.
resolve_library() {
  local name=$1 owner=$2 base candidate rpath
  base=$(dirname "$owner")
  case "$name" in
    /*) printf '%s\n' "$name" ;;
    @loader_path/*) printf '%s/%s\n' "$base" "${name#@loader_path/}" ;;
    @executable_path/*) printf '%s/%s\n' "$PWD/build" "${name#@executable_path/}" ;;
    @rpath/*)
      while IFS= read -r rpath; do
        rpath=${rpath/@loader_path/$base}
        rpath=${rpath/@executable_path/$PWD/build}
        candidate="$rpath/${name#@rpath/}"
        if [[ -f "$candidate" ]]; then printf '%s\n' "$candidate"; return; fi
      done < <(otool -l "$owner" | awk '/cmd LC_RPATH/{want=1;next} want && /path /{print $2;want=0}')
      candidate="$(brew --prefix)/lib/${name#@rpath/}"
      [[ -f "$candidate" ]] || { echo "Cannot resolve $name from $owner" >&2; return 1; }
      printf '%s\n' "$candidate" ;;
    *) echo "Unsupported native dependency $name" >&2; return 1 ;;
  esac
}
# Grow an explicit queue so each original library is inspected before relocation.
originals=("$PWD/build/sun_tline")
relatives=(MacOS/sun_tline)
index=0
: > build/macos-native-files.tsv
while ((index < ${#originals[@]})); do
  original=${originals[index]}
  relative=${relatives[index]}
  destination="$contents/$relative"
  printf '%s\t%s\n' "$original" "$relative" >> build/macos-native-files.tsv
  while IFS= read -r name; do
    case "$name" in /usr/lib/*|/System/Library/*) continue ;; esac
    resolved=$(resolve_library "$name" "$original")
    resolved=$(realpath "$resolved")
    # A dylib's first load-command entry is its own install name.
    [[ "$resolved" == "$(realpath "$original")" ]] && continue
    basename=${resolved##*/}
    target="$contents/Frameworks/$basename"
    known=0
    for ((j=0; j<${#originals[@]}; j++)); do
      if [[ ${originals[j]} == "$resolved" ]]; then known=1; fi
      if [[ ${relatives[j]} == "Frameworks/$basename" && ${originals[j]} != "$resolved" ]]; then
        echo "Conflicting library names: $basename" >&2; exit 1
      fi
    done
    if ((known == 0)); then
      cp "$resolved" "$target"; chmod u+w "$target"
      originals+=("$resolved"); relatives+=("Frameworks/$basename")
      install_name_tool -id "@executable_path/../Frameworks/$basename" "$target"
    fi
    install_name_tool -change "$name" "@executable_path/../Frameworks/$basename" "$destination"
  done < <(otool -L "$original" | tail -n +2 | sed 's/^[[:space:]]*//;s/ (compatibility.*//')
  index=$((index + 1))
done
# Include schemas and licensing provenance from every bundled Homebrew keg.
for original in "${originals[@]}"; do
  case "$original" in
    */Cellar/*)
      prefix=${original%%/Cellar/*}/Cellar
      rest=${original#*/Cellar/}; formula=${rest%%/*}; rest=${rest#*/}; version=${rest%%/*}
      keg="$prefix/$formula/$version"
      notices="$contents/Resources/licenses/$formula"
      if [[ ! -d "$notices" ]]; then
        mkdir -p "$notices"
        find "$keg" -maxdepth 1 -type f \( -iname '*license*' -o -iname '*copying*' -o -iname '*notice*' \) -exec cp {} "$notices/" \;
        [[ ! -d "$keg/.brew" ]] || cp -R "$keg/.brew" "$notices/recipe"
        [[ ! -d "$keg/share/doc" ]] || cp -R "$keg/share/doc" "$notices/doc"
        if [[ -d "$keg/share/glib-2.0/schemas" ]]; then
          find "$keg/share/glib-2.0/schemas" -name '*.xml' -exec cp {} "$contents/Resources/share/glib-2.0/schemas/" \;
        fi
      fi ;;
  esac
done
glib-compile-schemas "$contents/Resources/share/glib-2.0/schemas"
cp build/macos-native-files.tsv "$contents/Resources/licenses/"
for relative in "${relatives[@]}"; do
  if otool -L "$contents/$relative" | tail -n +2 | grep -E '/opt/homebrew|/usr/local|/Users/|/private/tmp'; then
    echo 'Unrelocated dependency in app' >&2; exit 1
  fi
  codesign --force --sign - "$contents/$relative"
done
codesign --force --sign - "$app"
codesign --verify --deep --strict "$app"
"$contents/MacOS/sun-tline" --self-test
ln -s /Applications build/macos/Applications
hdiutil create -ov -format UDZO -volname 'Sun Tline' -srcfolder build/macos build/sun-tline-arm64.dmg
hdiutil verify build/sun-tline-arm64.dmg
shasum -a 256 build/sun-tline-arm64.dmg > build/sun-tline-arm64.dmg.sha256
