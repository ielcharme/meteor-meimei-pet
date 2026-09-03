---
name: meteor-meimei-pet
description: Install, launch, verify, restore, or maintain Lucie's Meteor Meimei border-collie pet as a Codex v2 pet or an optional macOS desktop companion. Use only for this specific pet and its bundled assets, not for creating unrelated pets.
---

# Meteor Meimei Pet

Use the bundled, already-approved 妹妹 assets instead of regenerating her identity.

## Choose the requested mode

- **Codex pet:** install `assets/pet/pet.json` and `assets/pet/spritesheet.webp` into the active Codex pet directory.
- **macOS desktop companion:** install or rebuild the transparent menu-bar app at the repository's small `97 px` resting width. Walking left and right are rendered at `1.5×`; rolling is rendered at `1.8×`, with smooth bottom-anchored panel expansion so the full body stays visible. It uses calm animation timing, includes eight green-screen-keyed live-dog loops (head tilt, eating, rolling, waiting, startup, walking left, walking right, and expectant), joins actions with endpoint holds and a tail-frame-to-head-frame crossfade, tells an offline cold joke on double-click, recognizes back-and-forth pointer petting and responds with eating, uses the expectant/approach action while dragged upward and dropped, plays a rolling/belly-up action about every 8–18 minutes during recent computer use, retreats into a screen edge after five ignored minutes when parked in a corner, returns to that corner on hover, hides during typing/full-screen/video playback, shows a self-dismissing hourly movement-and-water bubble during active work, and offers a right-click **暂时退出妹妹** action directly on the pet.
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

The bundled app archive is for Apple Silicon macOS. Prefer it for ordinary installation. The archive prevents macOS from indexing a second runnable copy inside the repository; the installer expands exactly one app at `~/Applications/妹妹.app`. Use `scripts/build_desktop_app.sh` when the user asks to rebuild it, when the binary is missing, or when source changes are required. The app may read only anonymous seconds-since-last-key-event, the frontmost app identity, and on-screen window geometry. It must never capture key values, screen pixels, browser content, conversations, or other Codex state.

Preserve the single-instance contract when rebuilding: `LSMultipleInstancesProhibited` must remain enabled, the resting desktop width must remain `97 px`, walking must use the verified `1.5×` scale, rolling must use `1.8×`, and launch commands must use `open` without `-n`.

Preserve the interaction schedule when rebuilding: upward dragging and the gravity drop use the expectant row, while autonomous rolling/belly-up is governed by one randomized `8–18 minute` timer and only starts during recent computer activity from an idle or review state. Menu and single-click roll triggers remain available and reset that timer.

For directional walking, retain the supplied leftward and rightward source-body motion. The supplied right-walk clip cuts off the tail in every source frame, so complete only the missing tail with a mirrored real-tail donor from the left-walk clip, align it behind the recipient body by nose and baseline, and preserve the right-walk legs, torso, head, and cadence. Keep the completed dog centered and baseline-aligned inside each cell while the desktop panel supplies horizontal travel. Preserve the calmer timing constants and the deterministic `--print-behavior-config` verification hook when rebuilding.

Preserve the separate desktop action atlas when rebuilding: `assets/desktop-source/video-actions.webp` is `1536×1664`, with eight complete eight-frame rows in this order: head tilt, eating, rolling, waiting, startup, walking left, walking right, and expectant. The latest approved green-screen MP4 files define the final real-dog appearance and motion for these rows. Key the actual source pixels, retain the attached food bowl, remove detached floor/keying residue without cutting away paws or feathered fur, and do not redraw or restyle them as an electronic dog. All visible desktop modes and direct drag/edge frames must resolve to rows `11–18`; `illustrated_fallback=false` is a verified invariant. Keep these rows desktop-only so the Codex v2 `8×11` atlas and state semantics remain unchanged.

Preserve action continuity when rebuilding: non-looping actions must hold frame 0 briefly, play through the terminal frame exactly once, hold that terminal frame, and never modulo-wrap to frame 0 before the mode ends. On every row change, hold the incoming action on frame 0 while blending from the outgoing terminal displayed frame for `0.62 s`, then start the incoming animation. Preserve the calm autonomous behavior weights and `10–22 s` idle windows.

Preserve direct interactions when rebuilding: single-click uses the normal play selector only after the double-click interval expires; double-click cancels that pending single-click and shows a bundled offline cold joke. Back-and-forth pointer movement over the pet accumulates an `84 pt` petting gesture, plays eating once, and then observes a `12 s` cooldown so ordinary hovering cannot repeatedly restart it.

Preserve focus protection when rebuilding: hide while keyboard activity is recent, while a foreground window is full-screen, while a known media player is active, or while manual cinema mode is enabled. Restore the same pet state and location after protection ends. Because browser page content is intentionally not inspected, use the menu-bar cinema toggle for windowed browser video.

Preserve the local wellness reminder when rebuilding: check once per hour, deliver only when input activity occurred within the previous five minutes, defer briefly until recent typing stops, skip the run when hidden, paused, idle, full-screen, or in cinema mode, and automatically dismiss the speech bubble after ten seconds. If the reminder temporarily reveals a pet hidden at the screen edge, return it to that edge after dismissal. Do not implement this reminder through chat or a network service.

Preserve the pet context menu when rebuilding: right-clicking Meimei must offer **暂时退出妹妹**, which terminates only the running app. It must not uninstall the bundle, delete preferences, or add persistent background behavior.

Launch the app only when the user asks. Use `open` on the installed app; do not add login-item persistence, Accessibility access, screen recording, microphone, camera, or network behavior unless separately requested and approved.

## Invariants

- Pet id: `meteor-meimei`
- Display name: `妹妹`
- `spriteVersionNumber`: `2`
- Atlas: transparent WebP, `1536×2288`, 8 columns × 11 rows, `192×208` cells
- Desktop app: local-only; no network, credentials, telemetry, key-content capture, screen capture, or privileged permissions
- Preserve the meteorite black/graphite/silver coat, white blaze/chest/paws/tail tip, cosmic-blue eyes, and centered copper tag.

Do not silently replace the verified atlas with generated art, publish assets, or alter another installed pet.
