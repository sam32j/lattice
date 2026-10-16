#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Samuel Ji
set -euo pipefail
cd "$(dirname "$0")/.."
TEAM="${LATTICE_TEAM_ID:?Set the validated fork team ID}"
VERSION="${LATTICE_VERSION:?Set the validated downstream version}"
IS_ADHOC=0
if [[ "$TEAM" == "ADHOC" || "${LATTICE_ALLOW_ADHOC:-0}" == "1" ]]; then
    IS_ADHOC=1
else
    [[ "$TEAM" =~ '^[A-Z0-9]{10}$' && "$TEAM" != 3D485NHW29 ]] || exit 1
fi
[[ "$VERSION" =~ '^[0-9]+\.[0-9]+\.[0-9]+-d\.[1-9][0-9]*$' ]] || exit 1
APP=build/stage/Lattice.app
if (( IS_ADHOC )); then
    REQ='identifier "io.github.sam32j.lattice"'
else
    REQ="identifier \"io.github.sam32j.lattice\" and anchor apple generic and certificate leaf[subject.OU] = \"$TEAM\""
fi
codesign --verify --deep --strict -R="$REQ" "$APP"
[[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")" == "$VERSION" ]] || exit 1

if (( ! IS_ADHOC )); then
    REQUIRE_NOTARIZATION=1 ./Tools/notarize.sh "$APP"
fi

mkdir -p dist
DMG="dist/Lattice-$VERSION.dmg"
rm -f "$DMG"

if [[ -f Tools/make-dmg.sh ]]; then
    ./Tools/make-dmg.sh
else
    STAGE="$(mktemp -d)"
    trap 'rm -rf "$STAGE"' EXIT
    ditto "$APP" "$STAGE/Lattice.app"
    ln -s /Applications "$STAGE/Applications"
    hdiutil create -volname Lattice -srcfolder "$STAGE" -format UDZO "$DMG"
fi

if (( IS_ADHOC )); then
    codesign --force --sign - "$DMG"
    codesign --verify --strict "$DMG"
else
    IDENTITY="$(security find-identity -v -p codesigning | grep 'Developer ID Application' | grep -F "($TEAM)" | head -1 | sed -E 's/.*"(.*)".*/\1/')"
    [[ -n "$IDENTITY" ]] || exit 1
    codesign --force --timestamp --sign "$IDENTITY" "$DMG"
    codesign --verify --strict -R="anchor apple generic and certificate leaf[subject.OU] = \"$TEAM\"" "$DMG"
    REQUIRE_NOTARIZATION=1 ./Tools/notarize.sh "$DMG"
    xcrun stapler validate "$APP"
    xcrun stapler validate "$DMG"
    spctl -a -t exec "$APP"
fi
(cd dist && shasum -a 256 "Lattice-$VERSION.dmg" > SHA256SUMS)

