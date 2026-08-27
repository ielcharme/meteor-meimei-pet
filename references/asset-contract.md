# Asset contract

Use this reference for verification, repair, or rebuild work.

## Codex v2 atlas

- `assets/pet/pet.json` declares `id: meteor-meimei`, `displayName: 妹妹`, and `spriteVersionNumber: 2`.
- `assets/pet/spritesheet.webp` is RGBA WebP, exactly `1536×2288`.
- Layout is 8 columns × 11 rows with `192×208` cells.
- Rows 0–8 are idle, running-right, running-left, waving, jumping, failed, waiting, task-running, and review.
- Rows 9–10 contain 16 clockwise look directions in 22.5° steps.
- `validation.json` records the deterministic v2 atlas validation produced during hatching.

The preview files are review aids, not runtime dependencies:

- `contact-sheet.png`: all 11 animation rows
- `look-directions.png`: neutral plus 16 labeled look directions
- `idle-preview.gif`: idle animation preview

## Desktop companion

The prebuilt app lives at `assets/desktop/妹妹.app` and is an arm64 macOS app. Its source is in `assets/desktop-source/`.

Behavior:

- transparent floating pet near the bottom of the current screen
- autonomous left/right walking, idle, waving, jumping, play, and review states
- click to play; drag to reposition; menu-bar controls to recall, pause, hide, or quit
- no network, telemetry, credentials, login-item persistence, or protected-device access

Build output must remain a valid signed-on-disk app bundle. Ad-hoc signing is sufficient for local use; it is not Apple notarization.

## Replacement rules

Do not replace only one look-direction cell or combine cells from unrelated generations. If artwork changes, regenerate and validate the complete containing row through `$hatch-pet`, then update the atlas, previews, validation report, desktop app resource, and repository documentation together.
