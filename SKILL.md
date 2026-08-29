---
name: meteor-meimei-pet
description: Install, launch, verify, restore, or maintain Lucie's Meteor Meimei border-collie pet as a Codex v2 pet or an optional macOS desktop companion. Use only for this specific pet and its bundled assets, not for creating unrelated pets.
---

# Meteor Meimei Pet

Use the bundled, already-approved 妹妹 assets instead of regenerating her identity.

## Choose the requested mode

- **Codex pet:** install `assets/pet/pet.json` and `assets/pet/spritesheet.webp` into the active Codex pet directory.
- **macOS desktop companion:** install or rebuild the transparent menu-bar app that matches the current Codex pet width, uses relaxed animation timing, can be lifted upward by the scruff, retreats into a screen edge after five ignored minutes when parked in a corner, jumps back to that corner on hover, and tells occasional offline cold jokes.
- **Inspect or restore:** verify the packaged files first, then repair only the missing or invalid layer.
- **Change the artwork or animation:** use `$hatch-pet` when available; preserve the 8×11 v2 contract and re-run its full QA before replacing bundled assets.

Read [references/asset-contract.md](references/asset-contract.md) when validating, rebuilding, or repairing assets. Ordinary installation does not require loading it.

## Installation workflow

1. Run `scripts/verify_assets.sh` from the skill directory.
2. Run `scripts/install.sh --target codex --dry-run`, `--target desktop --dry-run`, or `--target all --dry-run` according to the request.
3. Show the resolved destinations. Ask for approval immediately before writing outside the skill folder.
4. Run the same command with `--install` after approval.
5. Re-run `scripts/verify_assets.sh --installed` for the selected target. Do not claim installation succeeded from a copy command alone.

The installer refuses to overwrite an existing installation unless `--replace` is explicitly supplied. Before using `--replace`, describe the existing target and obtain approval. The script creates a timestamped sibling backup before replacement.

## Desktop companion

The bundled app is for Apple Silicon macOS. Prefer the prebuilt app for ordinary installation. Use `scripts/build_desktop_app.sh` when the user asks to rebuild it, when the binary is missing, or when source changes are required. The app may read only `avatar-overlay-mascot-width-px` from `~/.codex/config.toml`; it must not read conversations or other Codex state.

For directional walking, render leftward motion as a frame-order-preserving horizontal mirror of the approved rightward row instead of using a visibly unstable left row. Preserve the calmer timing constants and the deterministic `--print-behavior-config` verification hook when rebuilding.

Launch the app only when the user asks. Use `open` on the installed app; do not add login-item persistence, Accessibility access, screen recording, microphone, camera, or network behavior unless separately requested and approved.

## Invariants

- Pet id: `meteor-meimei`
- Display name: `妹妹`
- `spriteVersionNumber`: `2`
- Atlas: transparent WebP, `1536×2288`, 8 columns × 11 rows, `192×208` cells
- Desktop app: local-only; no network, credentials, telemetry, or privileged permissions
- Preserve the meteorite black/graphite/silver coat, white blaze/chest/paws/tail tip, cosmic-blue eyes, and centered copper tag.

Do not silently replace the verified atlas with generated art, publish assets, or alter another installed pet.
