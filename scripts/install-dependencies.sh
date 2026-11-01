#!/usr/bin/env bash
# Stage published bundles atomically; never fall back to dependency source builds.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p tmp build/dependencies
stage=$(mktemp -d "$PWD/tmp/dependencies.XXXXXX")
trap 'rm -rf "$stage"' EXIT
case "$(uname -s)-$(uname -m)" in
  Linux-x86_64) platform=linux ;;
  Darwin-arm64) platform=macos ;;
  *) echo 'Supported platforms: Linux x86-64 and Apple Silicon macOS.' >&2; exit 1 ;;
esac
for dependency in sun_ui sun_gobject; do
  release=dev
  if [[ $dependency == sun_ui ]]; then release=${SUN_UI_RELEASE:-dev}; else release=${SUN_GOBJECT_RELEASE:-dev}; fi
  package=${dependency//_/-}
  if [[ $platform == linux ]]; then asset="${package}_0.dev_amd64.deb"; else asset="${dependency}-arm64-apple-darwin.tar.gz"; fi
  archive="$stage/$asset"
  curl --fail --location --retry 3 "https://github.com/namo-robotics/$dependency/releases/download/$release/$asset" -o "$archive"
  mkdir -p "$stage/unpack-$dependency" "$stage/$dependency/build"
  if [[ $platform == linux ]]; then
    dpkg-deb --extract "$archive" "$stage/unpack-$dependency"
    prefix="$stage/unpack-$dependency/usr"
    notices="$prefix/share/doc/$package"
    cp "$notices/copyright" "$stage/$dependency/LICENSE"
  else
    tar -xzf "$archive" -C "$stage/unpack-$dependency"
    prefix="$stage/unpack-$dependency"
    notices="$prefix/share/$dependency"
    cp "$notices/LICENSE" "$stage/$dependency/LICENSE"
  fi
  cp "$prefix/lib/sun/"*.moon "$stage/$dependency/build/"
  cp "$notices/sun-version.txt" "$stage/$dependency/build/"
  if [[ $dependency == sun_gobject ]]; then
    mkdir -p "$stage/$dependency/build/native"
    if [[ $platform == linux ]]; then native="$prefix/lib/sun/native"; else native="$prefix/lib"; fi
    cp "$native/libsun_gobject_native.a" "$stage/$dependency/build/native/"
  else
    test -f "$stage/$dependency/build/sun_plot.moon"
    test -f "$stage/$dependency/build/sun_ui_gtk.moon"
  fi
  (cd "$stage" && shasum -a 256 "$asset") > "$stage/$dependency/archive.sha256"
  printf '%s\n' "$release/$asset" > "$stage/$dependency/release.txt"
done
# All downloads and layouts must succeed before replacing the installed bundles.
for dependency in sun_ui sun_gobject; do
  rm -rf "build/dependencies/$dependency"
  mv "$stage/$dependency" "build/dependencies/$dependency"
done
printf '%s\n' 'Bundles installed. Builds require ui.Kind.Drawing and register_drawing; older releases will fail explicitly.'
