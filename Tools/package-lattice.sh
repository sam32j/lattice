#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Samuel Ji
set -euo pipefail
cd "$(dirname "$0")/.."
TEAM="${LATTICE_TEAM_ID:?Set the validated fork team ID}"
VERSION="${LATTICE_VERSION:?Set the validated downstream version}"
[[ "$TEAM" =~ '^[A-Z0-9]{10}$' && "$TEAM" != 3D485NHW29 ]] || exit 1
[[ "$VERSION" =~ '^[0-9]+\.[0-9]+\.[0-9]+-d\.[1-9][0-9]*$' ]] || exit 1
APP=build/stage/Lattice.app
REQ="identifier \"io.github.sam32j.lattice\" and anchor apple generic and certificate leaf[subject.OU] = \"$TEAM\""
codesign --verify --deep --strict -R="$REQ" "$APP"
[[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")" == "$VERSION" ]] || exit 1
REQUIRE_NOTARIZATION=1 ./Tools/notarize.sh "$APP"
mkdir -p dist
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/Lattice.app"
ln -s /Applications "$STAGE/Applications"
DMG="dist/Lattice-$VERSION.dmg"
[[ ! -e "$DMG" ]] || { echo 'Refusing to replace an existing DMG' >&2; exit 1; }
hdiutil create -volname Lattice -srcfolder "$STAGE" -format UDZO "$DMG"
IDENTITY="$(security find-identity -v -p codesigning | grep 'Developer ID Application' | grep -F "($TEAM)" | head -1 | sed -E 's/.*"(.*)".*/\1/')"
[[ -n "$IDENTITY" ]] || exit 1
codesign --force --timestamp --sign "$IDENTITY" "$DMG"
codesign --verify --strict -R="anchor apple generic and certificate leaf[subject.OU] = \"$TEAM\"" "$DMG"
REQUIRE_NOTARIZATION=1 ./Tools/notarize.sh "$DMG"
xcrun stapler validate "$APP"
xcrun stapler validate "$DMG"
spctl -a -t exec "$APP"
(cd dist && shasum -a 256 "Lattice-$VERSION.dmg" > SHA256SUMS)
