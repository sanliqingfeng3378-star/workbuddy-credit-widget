#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

# One app for both Mac architectures by default; native builds are faster locally.
target="${1:-universal}"
case "$target" in
  universal) architectures=(arm64 x86_64) ;;
  arm64|x86_64) architectures=("$target") ;;
  *) printf 'Usage: bash scripts/build.sh [universal|arm64|x86_64]\n' >&2; exit 2 ;;
esac
sdk="${WORKBUDDY_WIDGET_SDK:-$(xcrun --show-sdk-path)}"
sdk_version="$(xcrun --sdk "$sdk" --show-sdk-version)"
sign_identity="${WORKBUDDY_SIGN_IDENTITY:--}"
mkdir -p build/ModuleCache
staging="$(mktemp -d "$PWD/build/staging.XXXXXX")"
trap 'rm -rf "$staging"' EXIT
app="$staging/WorkBuddy Credits.app"
extension="$app/Contents/PlugIns/WorkBuddyCreditsWidget.appex"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$extension/Contents/MacOS" "$extension/Contents/Resources"
host_bins=()
widget_bins=()
for arch in "${architectures[@]}"; do
  host_bins+=("$staging/host-$arch")
  widget_bins+=("$staging/widget-$arch")
  common=(-parse-as-library -swift-version 5 -sdk "$sdk" -target "$arch-apple-macosx14.0" -module-cache-path build/ModuleCache -O)
  swiftc "${common[@]}" -module-name WorkBuddyCredits Shared/*.swift App/*.swift -o "$staging/host-$arch"
  # Retain WidgetBundle registration alongside the XPC extension bootstrap.
  swiftc "${common[@]}" -module-name WorkBuddyCreditsWidget -application-extension \
    -Xlinker -e -Xlinker _NSExtensionMain \
    -Xlinker -platform_version -Xlinker macos -Xlinker 14.0 -Xlinker "$sdk_version" \
    Shared/*.swift Widget/*.swift -o "$staging/widget-$arch"
done
xcrun lipo -create "${host_bins[@]}" -output "$app/Contents/MacOS/WorkBuddyCredits"
xcrun lipo -create "${widget_bins[@]}" -output "$extension/Contents/MacOS/WorkBuddyCreditsWidget"
python3 scripts/bundle.py "$app"
sign_flags=(--force --sign "$sign_identity")
if [[ "$sign_identity" != '-' ]]; then sign_flags+=(--options runtime --timestamp); fi
codesign "${sign_flags[@]}" --entitlements Resources/Widget.entitlements "$extension"
codesign "${sign_flags[@]}" "$app"
codesign --verify --deep --strict "$app"
for arch in "${architectures[@]}"; do
  xcrun lipo "$app/Contents/MacOS/WorkBuddyCredits" -verify_arch "$arch"
  xcrun lipo "$extension/Contents/MacOS/WorkBuddyCreditsWidget" -verify_arch "$arch"
done
output="$PWD/build/$target/WorkBuddy Credits.app"
mkdir -p "$(dirname "$output")"
if [[ -e "$output" ]]; then mv "$output" "$staging/previous.app"; fi
mv "$app" "$output"
printf 'Built: %s\n' "$output"
