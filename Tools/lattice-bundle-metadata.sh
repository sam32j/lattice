#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Samuel Ji
set -euo pipefail
cd "$(dirname "$0")/.."
APP="${1:?Pass staged app path}"
META="Downstream/release.json"
TAG="$(plutil -extract upstreamTag raw -o - "$META")"
REVISION="$(plutil -extract revision raw -o - "$META")"
BASE="$(plutil -extract baseCommit raw -o - "$META")"
if [[ ! "$TAG" =~ '^v[0-9]+\.[0-9]+\.[0-9]+$' || ! "$REVISION" =~ '^[1-9][0-9]*$' \
      || ! "$BASE" =~ '^[0-9a-f]{40}$' ]]; then
    echo 'Invalid Lattice release provenance' >&2; exit 1
fi
INFO="$APP/Contents/Info.plist"
UPSTREAM_BUILD="$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$INFO")"
plutil -convert xml1 "$INFO"
perl -pi -e 's/Vorssaint/Lattice/g' "$INFO"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${TAG#v}-d.$REVISION" "$INFO"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $UPSTREAM_BUILD.$REVISION" "$INFO"
/usr/libexec/PlistBuddy -c "Set :NSHumanReadableCopyright Lattice contributors; based on Vorssaint, GPL-3.0-or-later" "$INFO"
/usr/libexec/PlistBuddy -c "Add :LatticeUpstreamBase string $BASE" "$INFO"
/usr/libexec/PlistBuddy -c "Add :LatticeUpstreamTag string ${TAG#v}" "$INFO"
/usr/libexec/PlistBuddy -c "Add :LatticeDownstreamRevision integer $REVISION" "$INFO"
cp "$META" "$APP/Contents/Resources/LatticeProvenance.json"
for STRINGS in "$APP"/Contents/Resources/*.lproj/InfoPlist.strings(N); do
    plutil -convert xml1 "$STRINGS"
    perl -pi -e 's/Vorssaint/Lattice/g' "$STRINGS"
done
