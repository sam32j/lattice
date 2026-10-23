#!/bin/sh
set -eu
cd "$(dirname "$0")"
if [ -d Sources ]; then
    # A copy extracted from the app's Resources/MediaTools directory.
    sources="$PWD/Sources"
else
    cd ..
    sources="$PWD/Vendor/MediaTools/Sources"
fi
root="$PWD"
out="$root/build/media-tools"
verify() { printf '%s  %s\n' "$2" "$sources/$1" | shasum -a 256 -c -; }
verify pngquant-2.17.0.tar.gz a27cf0e64db499ccb3ddae9b36036e881f78293e46ec27a9e7a86a3802fcda66
verify libpng-1.6.59.tar.xz d80dd2a38a37f803cb9b6ac7b14bd6e74ddc3b654780a8380bdf93523fdb4389
verify gifsicle-1.98.tar.gz e9d4cc0816db95c64d32e79f778836db0f1f7eb15868490bd330104e5146b66e
stamp=$(shasum -a 256 "$0" "$sources"/* | shasum -a 256 | cut -d' ' -f1)
if [ -x "$out/pngquant" ] && [ -x "$out/gifsicle" ] && [ "$(cat "$out/stamp" 2>/dev/null || true)" = "$stamp" ]; then exit 0; fi
mkdir -p "$out"
work=$(mktemp -d /tmp/lattice-media-tools.XXXXXX)
trap 'rm -rf "$work"' EXIT HUP INT TERM
tar -xf "$sources/libpng-1.6.59.tar.xz" -C "$work"
tar -xf "$sources/pngquant-2.17.0.tar.gz" -C "$work"
tar -xf "$sources/gifsicle-1.98.tar.gz" -C "$work"
export CC="$(xcrun --find clang)"
sdk=$(xcrun --sdk macosx --show-sdk-path)
export SDKROOT="$sdk"
export CPPFLAGS="-isysroot $sdk"
export CFLAGS="-O2 -arch arm64 -mmacosx-version-min=14.0 -isysroot $sdk"
export LDFLAGS="-arch arm64 -mmacosx-version-min=14.0 -isysroot $sdk"
cd "$work/libpng-1.6.59"
./configure --disable-shared --enable-static --disable-dependency-tracking --prefix="$work/png"
make -j 4
make install
cd "$work/pngquant-2.17.0"
./configure --disable-openmp --without-lcms2 --with-libpng="$work/png" --extra-cflags="$CFLAGS" --extra-ldflags="$LDFLAGS"
make -j 4
cp pngquant "$out/pngquant"
cd "$work/gifsicle-1.98"
./configure --disable-gifview --disable-gifdiff --disable-dependency-tracking
make -j 4
cp src/gifsicle "$out/gifsicle"
mkdir -p "$out/Licenses"
cp COPYING "$out/Licenses/gifsicle-COPYING"
cp "$work/pngquant-2.17.0/COPYRIGHT" "$out/Licenses/pngquant-COPYRIGHT"
cp "$work/pngquant-2.17.0/lib/COPYRIGHT" "$out/Licenses/libimagequant-COPYRIGHT"
cp "$work/libpng-1.6.59/LICENSE" "$out/Licenses/libpng-LICENSE"
for tool in "$out/pngquant" "$out/gifsicle"; do
    # No dependency may point at a build machine or Homebrew installation.
    if otool -L "$tool" | tail -n +2 | grep -vE '^\s*(/usr/lib/|/System/Library/)' | grep -q .; then
        echo "Non-system media tool dependency: $tool" >&2; exit 1
    fi
done
printf '%s' "$stamp" > "$out/stamp"
