#!/bin/bash

set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
configuration="${MEETCO_CONFIGURATION:-release}"
destination="${MEETCO_DIST_DIR:-$project_root/dist}"
bundle="$destination/Meetco.app"

cd "$project_root"
swift build -c "$configuration" -debug-info-format none --product MeetcoApp
swift build -c "$configuration" -debug-info-format none --product MeetcoMCP
bin_path="$(swift build -c "$configuration" --show-bin-path)"

rm -rf "$bundle"
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Helpers" "$bundle/Contents/Resources"
cp "$project_root/Config/Meetco-Info.plist" "$bundle/Contents/Info.plist"
cp "$bin_path/MeetcoApp" "$bundle/Contents/MacOS/Meetco"
cp "$bin_path/MeetcoMCP" "$bundle/Contents/Helpers/MeetcoMCP"
cp "$project_root/Resources/Brand/Meetco.icns" "$bundle/Contents/Resources/Meetco.icns"
cp "$project_root/Resources/Brand/MeetcoAppIcon.png" "$bundle/Contents/Resources/MeetcoAppIcon.png"
chmod 755 "$bundle/Contents/MacOS/Meetco" "$bundle/Contents/Helpers/MeetcoMCP"

plutil -lint "$bundle/Contents/Info.plist"
codesign --force --deep --sign - \
    --entitlements "$project_root/Config/Meetco.entitlements" \
    "$bundle"
codesign --verify --deep --strict --verbose=2 "$bundle"

echo "$bundle"
