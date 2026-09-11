# niri Computer Use compatibility patches

The pinned Community backend (`787dbd51268d7bc817304e50b64eed31426f061d`)
sets niri window origins to `None`. niri does not expose screen coordinates
for tiled windows, so the portal screenshot's targeted crop fails.

`codex-niri-window-screenshot.patch` uses `niri msg action screenshot-window
--id … --path …` for targeted niri captures. Full-screen and other compositor
paths are unchanged. It polls for the asynchronous PNG write in a private
random temporary directory, validates the PNG and removes the temporary file.
A failed native capture stays an error; it never returns the whole desktop.
The image is still passed through the upstream size/format limits. Native
window dimensions are never cached as desktop dimensions.

`niri-ipc-tiled-window-position.patch` makes niri report the current rendered
position of tiled windows through `tile_pos_in_workspace_view`. The field is
combined with `window_offset_in_tile` by
`codex-niri-window-coordinates.patch`. The backend then adds the logical
origin of the window's output and uses the upstream monitor-scale conversion
before sending pointer input. This keeps window-relative actions correct on
mixed-scale, multi-output layouts.

The backend deliberately discards the coordinates when workspace/output
metadata cannot be read. This avoids clicking an unrelated global position.

Known limits:

- niri's command also puts the PNG on the clipboard.
- The niri patch restores position data that upstream currently omits to avoid
  sending cascading IPC window updates while the scrolling view moves. Large
  window-event subscribers may therefore receive more updates.
- Existing plugin caches/processes may need replacement/restart after
  rebuilding because the upstream plugin version has not changed.
- Activating the niri patch requires a full logout and login; restarting only
  ChatGPT Desktop leaves the old compositor running.

The override in `modules/niri/codex-desktop.nix` builds the patched Rust
backend with screenshot tests enabled, then installs it in the Community
package. Remove the host's `package` override to return to upstream.

Validation on 2026-09-11:

- Rust screenshot test filter: 22 passed, 0 failed.
- Live `cua.getApp(...).getScreenshot()` returned the correct ChatGPT window.
- Live `getAXStateAndScreenshot` returned a 960-pixel wide image without errors.
- The coordinate-enabled backend builds successfully. Live coordinate input
  was verified after activating the rebuilt niri compositor: niri returned
  non-null tiled-window positions, the backend reported global bounds on a
  2× output, and window-relative click and text input completed successfully.
