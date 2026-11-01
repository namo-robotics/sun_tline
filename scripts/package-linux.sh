#!/usr/bin/env bash
# Package the tested executable and resolve its actual native runtime dependencies.
set -euo pipefail
cd "$(dirname "$0")/.."
[[ $(uname -s)-$(uname -m) == Linux-x86_64 ]]
test -x build/sun_tline
root=build/debian/root
rm -rf build/debian
mkdir -p "$root/DEBIAN" "$root/usr/bin" "$root/usr/share/applications" "$root/usr/share/icons/hicolor/scalable/apps" "$root/usr/share/doc/sun-tline" build/debian/debian
install -m755 build/sun_tline "$root/usr/bin/"
install -m644 packaging/sun-tline.desktop "$root/usr/share/applications/"
install -m644 packaging/sun-tline.svg "$root/usr/share/icons/hicolor/scalable/apps/"
cp README.md NOTICE build/sun-version.txt "$root/usr/share/doc/sun-tline/"
cp -R packaging/licenses "$root/usr/share/doc/sun-tline/"
for dep in sun_ui sun_gobject; do
  source_var=SUN_UI_SOURCE; [[ $dep == sun_gobject ]] && source_var=SUN_GOBJECT_SOURCE
  source_dir=${!source_var:-build/dependencies/$dep}
  cp "$source_dir/LICENSE" "$root/usr/share/doc/sun-tline/LICENSE.$dep"
done
# dpkg-shlibdeps requires a source control file even for a single binary package.
cat > build/debian/debian/control <<'CONTROL'
Source: sun-tline
Section: science
Priority: optional
Maintainer: Sun Tline maintainers
Standards-Version: 4.7.0

Package: sun-tline
Architecture: amd64
Description: Interactive transmission-line simulator written in Sun
CONTROL
runtime=$(cd build/debian && dpkg-shlibdeps -O -e root/usr/bin/sun_tline | sed -n 's/^shlibs:Depends=//p')
cat > "$root/DEBIAN/control" <<CONTROL
Package: sun-tline
Version: 0.1.0~dev.${GITHUB_RUN_NUMBER:-1}
Architecture: amd64
Maintainer: Sun Tline maintainers
Depends: $runtime
Section: science
Priority: optional
Description: Interactive transmission-line simulator written in Sun
CONTROL
dpkg-deb --root-owner-group --build "$root" build/sun-tline_amd64.deb
mkdir -p build/package-smoke
dpkg-deb --extract build/sun-tline_amd64.deb build/package-smoke
xvfb-run -a dbus-run-session -- build/package-smoke/usr/bin/sun_tline --self-test
sha256sum build/sun-tline_amd64.deb > build/sun-tline_amd64.deb.sha256
