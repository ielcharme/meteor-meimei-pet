# Asset contract

Use this reference for verification, repair, or rebuild work.

## Codex v2 atlas

- `assets/pet/pet.json` declares `id: meteor-meimei`, `displayName: 妹妹`, and `spriteVersionNumber: 2`.
- `assets/pet/spritesheet.webp` is RGBA WebP, exactly `1536×2288`.
- Layout is 8 columns × 11 rows with `192×208` cells.
- Rows 0–8 are idle, running-right, running-left, waving, jumping, failed, waiting, task-running, and review.
- Rows 9–10 contain 16 clockwise look directions in 22.5° steps.
- `validation.json` records the deterministic v2 atlas validation produced during hatching.
- Video-guided desktop actions do not replace or repurpose these Codex state rows.

The preview files are review aids, not runtime dependencies:

- `contact-sheet.png`: all 11 animation rows
- `look-directions.png`: neutral plus 16 labeled look directions
- `idle-preview.gif`: idle animation preview

## Desktop companion

The prebuilt arm64 app is stored as `assets/desktop/妹妹.app.zip`, so macOS does not index a second runnable copy inside the repository. The installer expands one canonical app at `~/Applications/妹妹.app`. Its source is in `assets/desktop-source/`.

The desktop app loads two atlases:

- `spritesheet.webp`: the validated Codex `1536×2288` atlas
- `video-actions.webp`: a desktop-only lossless `3072×3328` atlas with `384×416` cells, containing eight complete eight-frame rows keyed from the latest `720×720` real-dog green-screen footage: head tilt, eating, rolling, waiting, startup, walking left, walking right, and expectant

Behavior:

- transparent floating pet near the bottom of the current screen
- autonomous real-video left/right walking and waiting, plus head-tilt greeting, expectant-based edge emergence and upward drag/drop, startup, review waiting, scheduled eating, and periodic rolling/belly-up states
- clicking **和妹妹玩** chooses head tilt, rolling, or expectant; the paw menu can directly play head tilt, rolling, waiting, startup, and expectant, while **叫妹妹过来** uses the expectant row
- custom actions use source-appropriate `1.4–5.0 fps` timing; the source MP4 pixels supply the final real-dog appearance and motion, with the green set removed and the eating bowl retained
- all visible desktop modes and direct drag/edge frames resolve to live-video rows `11–18`; the illustrated Codex atlas remains bundled for Codex compatibility but is never selected as a desktop fallback
- every non-looping action holds its first frame, reaches and holds its last frame without wrapping, then blends that terminal frame into frame 0 of the incoming action for `0.62 s`
- uses the repository's small resting width of `97 px`; left/right walking and belly/rolling expand smoothly to `1.5×`, preserving the atlas `192:208` aspect ratio and keeping the full body visible
- renders the desktop action atlas with high-quality interpolation from lossless 2× cells, avoiding runtime upscaling at `1.5×` Retina size and preserving the useful detail available in the `720×720` source clips
- permits only one LaunchServices instance through `LSMultipleInstancesProhibited`; launch with `open` and never `open -n`
- uses relaxed motion timing: real-video directional walking is `5.0 fps` at `42 pt/s`, real-video waiting is `1.4 fps`, autonomous walking is selected only about 12 percent of ordinary decisions, and most decisions choose a `10–22 s` idle period
- renders walking-left and walking-right from their own keyed real-video body-motion rows, with tracked baseline normalization and backing-pixel-aligned window movement; because every supplied right-walk frame clips the tail, only the missing tail is completed from mirrored real-tail pixels in the paired left-walk source
- upward dragging and the gravity drop use the expectant/approach row while following the pointer and returning to the screen baseline
- during recent computer activity, one randomized timer plays the rolling/belly-up row about every `8–18 minutes`, only from an idle/review state; direct menu and single-click triggers remain available and reset the timer
- after `180 s` without direct interaction, waits for a safe visible idle/review state and plays one uninterrupted walk-left → head-tilt → roll → walk-right routine; direct interaction cancels it, and another routine is scheduled `180 s` after completion if she remains ignored
- the eating row loops only during local-time windows `08:30–09:00`, `12:00–12:30`, and `19:00–19:30`; random play, single-click, petting, edge emergence, jumping, and the action menu cannot trigger extra meals
- when manually parked at the left or right bottom edge, five minutes without direct pet interaction triggers a slow retreat that leaves a clickable `24 pt` peek
- the peeking area has an always-active hover tracker; mouse entry triggers a `0.82 s` eased hop back to the same corner and resets the five-minute timer without starting a walk
- shows a bundled offline cold joke every 40–90 minutes for about 8 seconds while visible and unpaused
- once per hour, checks whether local input occurred during the previous five minutes; when actively working and not hidden, paused, full-screen, or in cinema mode, shows a movement-and-water speech bubble for `10 s` and then dismisses it automatically
- a due reminder waits for the three-second typing quiet period before appearing; when it temporarily reveals an edge-hidden pet, the pet returns to that edge after the bubble closes
- hides during keyboard activity and returns to the same state and location after about `3 s` without a key event
- hides while the foreground app has a full-screen window or is a known media player; manual menu-bar cinema mode covers windowed browser playback without inspecting its content
- single-click to play after the double-click interval; double-click to show an immediate offline cold joke; move the pointer back and forth by `84 pt` over the pet to trigger the expectant action, followed by a `12 s` petting cooldown; drag to reposition; right-click the pet and choose `暂时退出妹妹` to terminate the running app without uninstalling it; menu-bar controls to recall, play, tell a joke, toggle cinema mode, pause, hide, or quit
- focus protection may read only anonymous seconds-since-last-key-event, frontmost app identity, and window geometry; it must not record key values or inspect screen, browser, or conversation content
- no network, telemetry, conversations, credentials, login-item persistence, Accessibility permission, screen recording, or protected-device access

Build output must remain a valid signed-on-disk app bundle. Ad-hoc signing is sufficient for local use; it is not Apple notarization.

## Replacement rules

Do not replace only one look-direction cell or combine cells from unrelated generations. If artwork changes, regenerate and validate the complete containing row through `$hatch-pet`, then update the atlas, previews, validation report, desktop app resource, and repository documentation together.
