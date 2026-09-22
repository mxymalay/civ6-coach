#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h}"
output_dir="${CIVCOACH_OUTPUT_DIR:-$project_dir/dist}"
app_path="$output_dir/文明 VI 陪练.app"
swift build --package-path "$project_dir" -c release
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
cp "$project_dir/.build/release/CivCoach" "$app_path/Contents/MacOS/CivCoach"
cp "$project_dir/Info.plist" "$app_path/Contents/Info.plist"
cp "$project_dir/Sources/CivCoach/Resources/queries.lua" "$app_path/Contents/Resources/queries.lua"
cp "$project_dir/THIRD_PARTY_LICENSE.txt" "$app_path/Contents/Resources/THIRD_PARTY_LICENSE.txt"
swift "$project_dir/make_icon.swift" "$project_dir/.build/icon.png"
mkdir -p "$project_dir/.build/AppIcon.iconset"
for icon_size in 16 32 128 256 512; do
  sips -z "$icon_size" "$icon_size" "$project_dir/.build/icon.png" --out "$project_dir/.build/AppIcon.iconset/icon_${icon_size}x${icon_size}.png" >/dev/null
  retina_size=$((icon_size * 2))
  sips -z "$retina_size" "$retina_size" "$project_dir/.build/icon.png" --out "$project_dir/.build/AppIcon.iconset/icon_${icon_size}x${icon_size}@2x.png" >/dev/null
done
iconutil -c icns "$project_dir/.build/AppIcon.iconset" -o "$app_path/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$app_path"
codesign --verify --deep --strict "$app_path"
print -r -- "$app_path"
