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

Validation on 2026-09-11 and 2026-09-12:

- Rust screenshot test filter: 22 passed, 0 failed.
- Live `cua.getApp(...).getScreenshot()` returned the correct ChatGPT window.
- Live `getAXStateAndScreenshot` returned a 960-pixel wide image without errors.
- The coordinate-enabled backend builds successfully. Live coordinate input
  was verified after activating the rebuilt niri compositor: niri returned
  non-null tiled-window positions, the backend reported global bounds on a
  2× output, and window-relative click and text input completed successfully.
- The native desktop adapter exposes window-relative `drag`; a live drag on
  the 2× niri output created the expected text selection, which was then
  cleared with a click.
- Drag motion is interpolated while the button remains pressed because GTK
  applications need post-button-down motion events to enter their drag state.
  The complete Computer Use Rust test suite passed (281 tests). In a live
  Inkscape session, Computer Use created an 11-object robot with shape drags,
  grouped it, moved the entire group, and resized it from a corner handle.

Validation on 2026-09-22:

- The native adapter now starts an installed `.desktop` app when `getApp(id)`
  cannot find a running window. It resolves the entry from XDG/NixOS
  application directories, reconstructs the unique niri Wayland session for
  the launch process, then binds to the newly created window. Live
  `cua.getApp('neovide')` started Neovide and returned its focused niri window.
  `cua.getApp('org.inkscape.Inkscape')` also launched Inkscape.
  The adapter accepts an exact desktop app id or an unambiguous display name.
  An existing Inkscape window is reused by display name, and a newly launched
  window remained available after the Computer Use session was reset.
  `toggleMaximize()` targets the bound niri window id; a live call expanded
  Neovide from 756×963 to 1560×995 in the returned window context.
  An obsolete `gvim.desktop` entry is present, but its `TryExec=gvim` is not
  installed; it cannot be used for launch validation.
- The enabled `codex-niri-scroll-unicode.patch` moves the pointer to a targeted scroll
  location with the existing absolute uinput device before sending ydotool
  wheel events. In a live niri session, the same local Edge page that did not
  scroll with ydotool absolute movement scrolled down and back up correctly.
- The non-ASCII input path uses niri's virtual keyboard through `wtype` without
  modifying the clipboard. An initial attempt omitted the first character;
  a modifier tap before typing fixed this in a live Neovide buffer. Its
  screenshot showed the full string `中文首字完整测试`. The combined backend passed
  all 281 Rust unit tests.
- Edge 148 crashes its main process with SIGILL at the same Chromium `ud2`
  offset when `wtype` injects Chinese into a contenteditable field. ASCII
  input in that field remains stable. The niri backend now recognizes Chromium
  browser windows by app id/class and enters each non-ASCII code point with
  `Ctrl+Shift+U`, its hexadecimal code point, and Space via ydotool; other
  niri applications retain the verified `wtype` path. A live Edge test entered
  `中文🙂` through this sequence without crashing. This path does not touch the
  clipboard. The rebuilt backend passed all 281 Rust tests and a direct
  `cua.getApp('microsoft-edge').typeText('修复验证中文🙂abc123')` call displayed the
  complete string in Edge while its main process stayed alive. Untargeted
  non-ASCII input resolves the focused niri window first and refuses input if
  that window cannot be identified. The final system build passed and a fresh
  Computer Use session displayed `最终验证：中文🙂abc123` in Edge without a new
  crash. The exact Chromium assertion behind the `ud2` is unknown.

Validation on 2026-09-28:

- Desktop release 26.917 changed the public Linux CUA surface to
  `listWindows()`, `getApp({ windowId })`, `computer.launch_app()`, and pixel
  scroll distances. The community adapter still exposed only its earlier
  string app ids, so current CUA calls failed with `e.list_apps is not a
  function` even though the niri host socket and Rust backend were healthy.
- The adapter now accepts both exact `{ windowId }` targets and its legacy app
  ids, supplies `listWindows()` and `computer.launch_app()`, translates pixel
  scroll distances, and removes the failed built-in native inventory error
  after the community inventory succeeds. A live 26.917 session enumerated
  the niri windows, bound Edge by numeric window id, captured its window, and
  scrolled it successfully. The complete NixOS system build also passed.
