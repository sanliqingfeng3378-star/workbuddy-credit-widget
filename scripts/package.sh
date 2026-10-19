#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
architecture="${1:-universal}"
case "$architecture" in universal|arm64|x86_64) ;; *) echo 'Usage: bash scripts/package.sh [universal|arm64|x86_64]' >&2; exit 2;; esac
version="$(cat VERSION)"
app="build/$architecture/WorkBuddy Credits.app"
test -d "$app" || { echo 'Build the app first.' >&2; exit 1; }
codesign --verify --deep --strict "$app"
mkdir -p dist
archive="dist/WorkBuddy-Credits-$version-macOS-$architecture.zip"
ditto -c -k --sequesterRsrc --keepParent "$app" "$archive"
(cd dist && shasum -a 256 "$(basename "$archive")" > "$(basename "$archive").sha256")
echo "Created $archive"
