#!/bin/bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

swift build "$@"
bin_dir="$(swift build "$@" --show-bin-path)"

stage_dir="$(mktemp -d "$repo_dir/.build/blindfold-bundle.XXXXXX")"
trap 'rm -rf "$stage_dir"' EXIT
app_dir="$stage_dir/Blindfold.app"
resources_dir="$app_dir/Contents/Resources"

mkdir -p "$app_dir/Contents/MacOS" "$resources_dir"
cp "$bin_dir/Blindfold" "$app_dir/Contents/MacOS/Blindfold"
cp Support/Info.plist "$app_dir/Contents/Info.plist"
cp LICENSE "$resources_dir/LICENSE.txt"
swift scripts/render-icon.swift assets/branding/blindfold-bandana.svg "$resources_dir/Blindfold.icns"

codesign --force --sign - "$app_dir"
codesign --verify --strict "$app_dir"

built_app="$repo_dir/.build/Blindfold.app"
previous_dir="$stage_dir/previous"
if [ -e "$built_app" ]; then
    mkdir "$previous_dir"
    mv "$built_app" "$previous_dir/"
fi
if ! mv "$app_dir" "$repo_dir/.build/"; then
    if [ -e "$previous_dir/Blindfold.app" ] && [ ! -e "$built_app" ]; then
        mv "$previous_dir/Blindfold.app" "$repo_dir/.build/"
    fi
    exit 1
fi

printf '\nBuilt %s\n' "$built_app"
