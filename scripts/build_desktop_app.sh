#!/bin/bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This desktop app can only be built on macOS." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_ROOT="${1:-$SKILL_DIR/dist}"
APP_PATH="$OUTPUT_ROOT/妹妹.app"
CONTENTS="$APP_PATH/Contents"
SOURCE="$SKILL_DIR/assets/desktop-source/MeteorMeimei.m"
PLIST="$SKILL_DIR/assets/desktop-source/Info.plist"
ATLAS="$SKILL_DIR/assets/pet/spritesheet.webp"
PET_MANIFEST="$SKILL_DIR/assets/pet/pet.json"

for required in "$SOURCE" "$PLIST" "$ATLAS" "$PET_MANIFEST"; do
  [[ -f "$required" ]] || { echo "Missing build input: $required" >&2; exit 1; }
done

SDK_PATH="$(/usr/bin/xcrun --sdk macosx --show-sdk-path)"
BUILD_ROOT="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/meteor-meimei-build.XXXXXX")"
trap '/bin/rm -rf "$BUILD_ROOT"' EXIT

/bin/mkdir -p "$BUILD_ROOT/妹妹.app/Contents/MacOS" "$BUILD_ROOT/妹妹.app/Contents/Resources"
/usr/bin/clang -fobjc-arc -fmodules -mmacosx-version-min=13.0 \
  -fmodules-cache-path="$BUILD_ROOT/module-cache" \
  -isysroot "$SDK_PATH" \
  -framework Cocoa \
  -framework ApplicationServices \
  "$SOURCE" \
  -o "$BUILD_ROOT/妹妹.app/Contents/MacOS/MeteorMeimei"
/bin/cp "$PLIST" "$BUILD_ROOT/妹妹.app/Contents/Info.plist"
/bin/cp "$ATLAS" "$BUILD_ROOT/妹妹.app/Contents/Resources/spritesheet.webp"
/bin/cp "$PET_MANIFEST" "$BUILD_ROOT/妹妹.app/Contents/Resources/pet.json"
/usr/bin/printf 'APPLMMPT' > "$BUILD_ROOT/妹妹.app/Contents/PkgInfo"
/usr/bin/codesign --force --deep --sign - "$BUILD_ROOT/妹妹.app"
/usr/bin/codesign --verify --deep --strict "$BUILD_ROOT/妹妹.app"

/bin/mkdir -p "$OUTPUT_ROOT"
if [[ -e "$APP_PATH" ]]; then
  echo "Refusing to overwrite existing build: $APP_PATH" >&2
  exit 3
fi
/usr/bin/ditto "$BUILD_ROOT/妹妹.app" "$APP_PATH"
echo "Built and signed: $APP_PATH"
