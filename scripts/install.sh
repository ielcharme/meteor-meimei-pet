#!/bin/bash
set -euo pipefail

usage() {
  echo "Usage: $0 --target codex|desktop|all --dry-run|--install [--replace]"
}

TARGET=""
MODE=""
REPLACE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      [[ $# -ge 2 ]] || { usage; exit 2; }
      TARGET="$2"
      shift 2
      ;;
    --dry-run)
      [[ -z "$MODE" ]] || { echo "Choose exactly one of --dry-run or --install." >&2; exit 2; }
      MODE="dry-run"
      shift
      ;;
    --install)
      [[ -z "$MODE" ]] || { echo "Choose exactly one of --dry-run or --install." >&2; exit 2; }
      MODE="install"
      shift
      ;;
    --replace)
      REPLACE=1
      shift
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

[[ "$TARGET" == "codex" || "$TARGET" == "desktop" || "$TARGET" == "all" ]] || { usage; exit 2; }
[[ "$MODE" == "dry-run" || "$MODE" == "install" ]] || { usage; exit 2; }
[[ -n "${HOME:-}" ]] || { echo "HOME is not set." >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CODEX_ROOT="${CODEX_HOME:-$HOME/.codex}"
CODEX_DEST="$CODEX_ROOT/pets/meteor-meimei"
DESKTOP_DEST="$HOME/Applications/妹妹.app"

timestamp() {
  date +%Y%m%d-%H%M%S
}

show_target() {
  local label="$1"
  local source="$2"
  local destination="$3"
  echo "$label"
  echo "  source:      $source"
  echo "  destination: $destination"
  if [[ -e "$destination" ]]; then
    echo "  existing:    yes"
  else
    echo "  existing:    no"
  fi
}

prepare_destination() {
  local destination="$1"
  if [[ -e "$destination" ]]; then
    if [[ "$REPLACE" -ne 1 ]]; then
      echo "Refusing to overwrite existing target: $destination" >&2
      echo "Re-run only after review with --replace; the old target will be backed up." >&2
      exit 3
    fi
    local backup="${destination}.backup-$(timestamp)"
    mv "$destination" "$backup"
    echo "Backed up existing target to: $backup"
  fi
  mkdir -p "$(dirname "$destination")"
}

install_codex() {
  prepare_destination "$CODEX_DEST"
  mkdir -p "$CODEX_DEST"
  cp "$SKILL_DIR/assets/pet/pet.json" "$CODEX_DEST/pet.json"
  cp "$SKILL_DIR/assets/pet/spritesheet.webp" "$CODEX_DEST/spritesheet.webp"
  echo "Installed Codex pet: $CODEX_DEST"
}

install_desktop() {
  prepare_destination "$DESKTOP_DEST"
  /usr/bin/ditto "$SKILL_DIR/assets/desktop/妹妹.app" "$DESKTOP_DEST"
  /usr/bin/codesign --verify --deep --strict "$DESKTOP_DEST"
  echo "Installed desktop companion: $DESKTOP_DEST"
}

if [[ "$TARGET" == "codex" || "$TARGET" == "all" ]]; then
  show_target "Codex pet" "$SKILL_DIR/assets/pet" "$CODEX_DEST"
fi
if [[ "$TARGET" == "desktop" || "$TARGET" == "all" ]]; then
  show_target "Desktop companion" "$SKILL_DIR/assets/desktop/妹妹.app" "$DESKTOP_DEST"
fi

if [[ "$MODE" == "dry-run" ]]; then
  echo "Dry run only: no files were changed."
  exit 0
fi

if [[ "$TARGET" == "codex" || "$TARGET" == "all" ]]; then
  install_codex
fi
if [[ "$TARGET" == "desktop" || "$TARGET" == "all" ]]; then
  install_desktop
fi
