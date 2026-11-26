#!/bin/bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ $# -gt 2 ]]; then
    printf 'Usage: %s [Blindfold.app] [output.dmg]\n' "$0" >&2
    exit 64
fi

app="${1:-$repo_dir/.build/Blindfold.app}"
codesign --verify --strict --all-architectures "$app"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")"
output="${2:-$repo_dir/.build/Blindfold-$version-macOS.dmg}"
if [[ "$output" != *.dmg || -e "$output" || -L "$output" ]]; then
    printf 'Choose an unused .dmg output path: %s\n' "$output" >&2
    exit 1
fi

if ! command -v uvx >/dev/null 2>&1; then
    printf 'Install uv (https://docs.astral.sh/uv/) to package the disk image.\n' >&2
    exit 1
fi

work_dir="$(mktemp -d "$(dirname "$output")/.blindfold-dmg.XXXXXX")"
trap 'rm -rf "$work_dir"' EXIT
render_icon="$repo_dir/scripts/render-icon.swift"
artwork="$repo_dir/assets/installer"
swift "$render_icon" "$artwork/volume-icon.svg" "$work_dir/volume.icns"
swift "$render_icon" "$artwork/background.svg" "$work_dir/background.png" 560 292
swift "$render_icon" "$artwork/background.svg" "$work_dir/background@2x.png" 1120 584

image="$work_dir/Blindfold.dmg"
uvx --from dmgbuild==1.6.7 dmgbuild -s "$repo_dir/scripts/dmg-settings.py" \
    -D "app=$app" -D "icon=$work_dir/volume.icns" -D "background=$work_dir/background.png" \
    Blindfold "$image"
hdiutil verify "$image"
mv -n "$image" "$output"
if [[ -e "$image" ]]; then
    printf 'Output already exists: %s\n' "$output" >&2
    exit 1
fi

printf '\nPackaged %s\n' "$output"
