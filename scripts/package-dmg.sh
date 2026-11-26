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

work_dir="$(mktemp -d "$(dirname "$output")/.blindfold-dmg.XXXXXX")"
trap 'rm -rf "$work_dir"' EXIT
mkdir "$work_dir/contents"
ditto --norsrc --noextattr "$app" "$work_dir/contents/Blindfold.app"
ln -s /Applications "$work_dir/contents/Applications"

image="$work_dir/Blindfold.dmg"
hdiutil create -srcfolder "$work_dir/contents" -volname Blindfold -fs HFS+ -format UDZO "$image"
hdiutil verify "$image"
mv -n "$image" "$output"
if [[ -e "$image" ]]; then
    printf 'Output already exists: %s\n' "$output" >&2
    exit 1
fi

printf '\nPackaged %s\n' "$output"
