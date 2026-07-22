#!/bin/bash
# Packages dist/Meetco.app into a branded drag-to-install DMG.
# Usage: Scripts/build-dmg.sh <version> [output-directory]
# Requires: create-dmg (brew install create-dmg) and an existing app bundle
# from Scripts/build-app-bundle.sh.

set -euo pipefail

version="${1:?usage: build-dmg.sh <version> [output-directory]}"
project_root="$(cd "$(dirname "$0")/.." && pwd)"
output_dir="${2:-$project_root}"
bundle="$project_root/dist/Meetco.app"
background_dir="$project_root/Resources/DMG"
dmg_path="$output_dir/Meetco-$version.dmg"

[ -d "$bundle" ] || { echo "error: $bundle missing — run Scripts/build-app-bundle.sh first" >&2; exit 1; }

# Combine 1x + 2x backgrounds into a HiDPI TIFF so Finder renders crisply on retina.
background="$background_dir/dmg-background.tiff"
tiffutil -cathidpicheck \
    "$background_dir/dmg-background.png" \
    "$background_dir/dmg-background@2x.png" \
    -out "$background"

staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT
cp -R "$bundle" "$staging/"

rm -f "$dmg_path"
create-dmg \
    --volname "Meetco" \
    --volicon "$project_root/Resources/Brand/Meetco.icns" \
    --background "$background" \
    --window-pos 200 120 \
    --window-size 660 400 \
    --text-size 13 \
    --icon-size 128 \
    --icon "Meetco.app" 165 200 \
    --hide-extension "Meetco.app" \
    --app-drop-link 495 200 \
    --no-internet-enable \
    "$dmg_path" \
    "$staging"

echo "$dmg_path"
