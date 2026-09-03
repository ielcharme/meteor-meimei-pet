#!/bin/bash
set -euo pipefail

usage() {
  echo "Usage: $0 [--installed codex|desktop|all] [--app /path/to/App.app]"
}

[[ -n "${HOME:-}" ]] || { echo "HOME is not set." >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PET_DIR="$SKILL_DIR/assets/pet"
APP_ARCHIVE="$SKILL_DIR/assets/desktop/妹妹.app.zip"
APP_PATH=""
MODE="bundled"
TARGET="all"
VERIFY_TMP=""

cleanup() {
  if [[ -n "$VERIFY_TMP" && -d "$VERIFY_TMP" ]]; then
    /bin/rm -rf "$VERIFY_TMP"
  fi
}

trap cleanup EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --installed)
      [[ $# -ge 2 ]] || { usage; exit 2; }
      MODE="installed"
      TARGET="$2"
      shift 2
      ;;
    --app)
      [[ $# -ge 2 ]] || { usage; exit 2; }
      MODE="app-only"
      APP_PATH="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 2
      ;;
  esac
done

if [[ "$MODE" == "installed" ]]; then
  [[ "$TARGET" == "codex" || "$TARGET" == "desktop" || "$TARGET" == "all" ]] || { usage; exit 2; }
  CODEX_ROOT="${CODEX_HOME:-$HOME/.codex}"
  PET_DIR="$CODEX_ROOT/pets/meteor-meimei"
  APP_PATH="$HOME/Applications/妹妹.app"
fi

if [[ "$MODE" == "bundled" ]]; then
  [[ -f "$APP_ARCHIVE" ]] || { echo "Missing desktop app archive: $APP_ARCHIVE" >&2; exit 1; }
  VERIFY_TMP="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/meteor-meimei-verify.XXXXXX")"
  /usr/bin/ditto -x -k "$APP_ARCHIVE" "$VERIFY_TMP"
  APP_PATH="$VERIFY_TMP/妹妹.app"
  [[ -d "$APP_PATH" ]] || { echo "Archive does not contain 妹妹.app: $APP_ARCHIVE" >&2; exit 1; }
fi

verify_pet() {
  local pet_dir="$1"
  local manifest="$pet_dir/pet.json"
  local atlas="$pet_dir/spritesheet.webp"
  [[ -f "$manifest" ]] || { echo "Missing manifest: $manifest" >&2; return 1; }
  [[ -f "$atlas" ]] || { echo "Missing atlas: $atlas" >&2; return 1; }

  local pet_id display_name version atlas_path dimensions width height
  pet_id="$(/usr/bin/plutil -extract id raw -o - "$manifest")"
  display_name="$(/usr/bin/plutil -extract displayName raw -o - "$manifest")"
  version="$(/usr/bin/plutil -extract spriteVersionNumber raw -o - "$manifest")"
  atlas_path="$(/usr/bin/plutil -extract spritesheetPath raw -o - "$manifest")"
  [[ "$pet_id" == "meteor-meimei" ]] || { echo "Unexpected pet id: $pet_id" >&2; return 1; }
  [[ "$display_name" == "妹妹" ]] || { echo "Unexpected display name: $display_name" >&2; return 1; }
  [[ "$version" == "2" ]] || { echo "Unexpected sprite version: $version" >&2; return 1; }
  [[ "$atlas_path" == "spritesheet.webp" ]] || { echo "Unexpected atlas path: $atlas_path" >&2; return 1; }

  dimensions="$(/usr/bin/sips -g pixelWidth -g pixelHeight "$atlas" 2>/dev/null)"
  width="$(printf '%s\n' "$dimensions" | /usr/bin/awk '/pixelWidth:/ {print $2}')"
  height="$(printf '%s\n' "$dimensions" | /usr/bin/awk '/pixelHeight:/ {print $2}')"
  [[ "$width" == "1536" && "$height" == "2288" ]] || { echo "Unexpected atlas size: ${width}x${height}" >&2; return 1; }
  echo "OK pet: $pet_dir"
}

verify_app() {
  local app="$1"
  local plist="$app/Contents/Info.plist"
  local executable="$app/Contents/MacOS/MeteorMeimei"
  local atlas="$app/Contents/Resources/spritesheet.webp"
  local action_atlas="$app/Contents/Resources/video-actions.webp"
  [[ -f "$plist" ]] || { echo "Missing app plist: $plist" >&2; return 1; }
  [[ -x "$executable" ]] || { echo "Missing app executable: $executable" >&2; return 1; }
  [[ -f "$atlas" ]] || { echo "Missing app atlas: $atlas" >&2; return 1; }
  [[ -f "$action_atlas" ]] || { echo "Missing app action atlas: $action_atlas" >&2; return 1; }

  local bundle_id version architecture pet_size behavior_config dimensions width height single_instance
  bundle_id="$(/usr/bin/plutil -extract CFBundleIdentifier raw -o - "$plist")"
  version="$(/usr/bin/plutil -extract CFBundleShortVersionString raw -o - "$plist")"
  architecture="$(/usr/bin/file "$executable")"
  [[ "$bundle_id" == "com.lucie.meteor-meimei" ]] || { echo "Unexpected bundle id: $bundle_id" >&2; return 1; }
  [[ "$version" == "2.6" ]] || { echo "Unexpected app version: $version" >&2; return 1; }
  single_instance="$(/usr/bin/plutil -extract LSMultipleInstancesProhibited raw -o - "$plist")"
  [[ "$single_instance" == "true" ]] || { echo "Desktop app does not prohibit multiple instances." >&2; return 1; }
  [[ "$architecture" == *"arm64"* ]] || { echo "Desktop app is not arm64: $architecture" >&2; return 1; }
  pet_size="$("$executable" --print-pet-size)"
  [[ "$pet_size" == "97x105.08" ]] || { echo "Unexpected desktop pet size: $pet_size" >&2; return 1; }
  dimensions="$(/usr/bin/sips -g pixelWidth -g pixelHeight "$atlas" 2>/dev/null)"
  width="$(printf '%s\n' "$dimensions" | /usr/bin/awk '/pixelWidth:/ {print $2}')"
  height="$(printf '%s\n' "$dimensions" | /usr/bin/awk '/pixelHeight:/ {print $2}')"
  [[ "$width" == "1536" && "$height" == "2288" ]] || { echo "Unexpected desktop atlas size: ${width}x${height}" >&2; return 1; }
  dimensions="$(/usr/bin/sips -g pixelWidth -g pixelHeight "$action_atlas" 2>/dev/null)"
  width="$(printf '%s\n' "$dimensions" | /usr/bin/awk '/pixelWidth:/ {print $2}')"
  height="$(printf '%s\n' "$dimensions" | /usr/bin/awk '/pixelHeight:/ {print $2}')"
  [[ "$width" == "1536" && "$height" == "1664" ]] || { echo "Unexpected desktop action atlas size: ${width}x${height}" >&2; return 1; }
  behavior_config="$("$executable" --print-behavior-config)"
  [[ "$behavior_config" == *"single_instance=true"* && "$behavior_config" == *"fixed_pet_width=97"* && "$behavior_config" == *"enlarged_action_scale=1.5-1.8"* && "$behavior_config" == *"walk_action_scale=1.5"* && "$behavior_config" == *"roll_action_scale=1.8"* && "$behavior_config" == *"enlarged_actions=walk-left-walk-right-roll"* && "$behavior_config" == *"custom_action_rows=11-18"* && "$behavior_config" == *"custom_action_source=keyed-live-video"* && "$behavior_config" == *"video_actions=head-tilt-eating-roll-waiting-startup-walk-left-walk-right-expectant"* && "$behavior_config" == *"illustrated_fallback=false"* && "$behavior_config" == *"action_transition=tail-to-head-crossfade"* && "$behavior_config" == *"transition_seconds=0.62"* && "$behavior_config" == *"endpoint_completion=entry-hold-exit-hold-clamped-last-frame"* && "$behavior_config" == *"double_click=cold-joke"* && "$behavior_config" == *"petting=eating"* && "$behavior_config" == *"petting_distance_px=84"* && "$behavior_config" == *"petting_cooldown_seconds=12"* && "$behavior_config" == *"automatic_behavior=calm"* && "$behavior_config" == *"automatic_roll=periodic"* && "$behavior_config" == *"roll_interval_seconds=480-1080"* && "$behavior_config" == *"roll_active_only=true"* && "$behavior_config" == *"corner_hide_seconds=300"* && "$behavior_config" == *"hover_reveal=eating-to-corner"* && "$behavior_config" == *"focus_protection=typing-fullscreen-media"* && "$behavior_config" == *"cinema_mode=manual"* && "$behavior_config" == *"wellness_interval_seconds=3600"* && "$behavior_config" == *"wellness_display_seconds=10"* && "$behavior_config" == *"work_active_window_seconds=300"* && "$behavior_config" == *"right_click_quit=temporary"* && "$behavior_config" == *"left_source=keyed-live-video"* && "$behavior_config" == *"right_source=keyed-live-video-with-real-tail-completion"* && "$behavior_config" == *"approach_trigger=expectant"* && "$behavior_config" == *"upward_drag=expectant"* && "$behavior_config" == *"drop_action=expectant"* ]] || { echo "Unexpected behavior config: $behavior_config" >&2; return 1; }
  /usr/bin/codesign --verify --deep --strict "$app"
  echo "OK app: $app (pet ${pet_size})"
}

case "$MODE:$TARGET" in
  app-only:*) verify_app "$APP_PATH" ;;
  bundled:*|installed:all)
    verify_pet "$PET_DIR"
    verify_app "$APP_PATH"
    ;;
  installed:codex) verify_pet "$PET_DIR" ;;
  installed:desktop) verify_app "$APP_PATH" ;;
esac

echo "Verification passed."
