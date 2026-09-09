# Paperlike — Goal Prompt

## One-line goal

Build a tiny macOS menu bar app that makes a MacBook screen look like matte
paper: a fine, static grain texture with a faint warm tint laid over
everything on screen, turned on and off with one click on the menu bar icon
or one global hotkey.

Think of a "Paperlike" screen protector (the matte film people put on iPads
for a paper feel), but done in software, so it costs nothing, can be toggled
instantly, and can be tuned.

## Why

Glossy displays feel harsh for long reading and writing sessions. A matte
protector diffuses light and softens the image, which many people find easier
on the eyes. A software overlay cannot change how glass reflects light, but it
can reproduce the visual side of the effect: fine grain, slightly lifted
blacks, warmer whites, softer contrast. That is what this app delivers.

## What "done" looks like

1. User opens the app. A small icon appears in the menu bar. No Dock icon,
   no main window.
2. Clicking the icon (or pressing the hotkey, default `⌃⌥⌘P`) turns the
   filter on. Every window, the desktop, the Dock, the menu bar, and
   full-screen apps now look like they are printed on slightly warm, lightly
   grained paper. Mouse, keyboard, trackpad gestures, drag and drop, and
   window resizing work exactly as before. The overlay is invisible to the
   cursor.
3. Clicking or pressing the hotkey again turns it off instantly. No fade
   longer than 150 ms.
4. The filter survives display sleep and wake, lid close and open,
   connecting or disconnecting an external display, resolution changes,
   Space switches, and Mission Control. Each connected display gets its own
   overlay sized to that display.
5. Leaving the filter on all day shows 0.0% CPU in Activity Monitor when
   idle and no entry worth noticing in the Energy tab. No timers, no
   display link, no per-frame work.
6. The app is small: under 5 MB on disk, under 30 MB resident memory with
   two displays, zero network access, no analytics.
7. Optional: launch at login, remembered on/off state across relaunch.

## The chosen approach (do this, not something else)

**One borderless overlay window per display, drawn once.**

- Swift + AppKit. `LSUIElement = true` so there is no Dock icon. An
  `NSStatusItem` in the menu bar is the whole UI, with a small popover or
  menu for settings.
- For every `NSScreen`, create one `NSWindow` with `styleMask = .borderless`,
  `isOpaque = false`, `backgroundColor = .clear`, `hasShadow = false`,
  `ignoresMouseEvents = true`, `frame = screen.frame`.
- Window level above everything the user looks at, including the menu bar
  and Dock: `level = .screenSaver` (or one step below
  `CGShieldingWindowLevel()` if `.screenSaver` proves unreliable on the
  target macOS version).
- `collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary,
  .ignoresCycle]` so the overlay follows the user across Spaces and sits on
  top of full-screen apps.
- `sharingType = .none` so the overlay is **excluded from screenshots,
  screen recordings, and screen sharing**. The filter is for the person
  looking at the glass, not for what they capture or present. Expose this as
  a setting, default on.
- The window's content view is layer-backed with exactly two static layers:
  a flat tint layer, and a grain layer whose `backgroundColor` is an
  `NSColor(patternImage:)` built from a **pre-generated grain tile** (about
  256x256 device pixels, generated once from a seeded PRNG, rendered at the
  display's `backingScaleFactor` so grain is crisp on Retina). Nothing in the
  view is redrawn after that unless the user changes a setting or the
  display configuration changes.
- Grain is **static**, not animated. Animated noise is film grain, not
  paper, and would burn battery. The tile must be seamless so the repeat is
  not visible at normal viewing distance.
- Toggle sources: menu bar click, a global hotkey registered with Carbon
  `RegisterEventHotKey` (works without Accessibility permission), and a menu
  item. The status item icon reflects on/off state.
- Rebuild the set of overlay windows on
  `NSApplication.didChangeScreenParametersNotification`. Diff by display ID
  so an unchanged display keeps its window.
- Launch at login via `SMAppService.mainApp` (macOS 13+).
- Settings persisted in `UserDefaults`.

**Do not**: use `CGDisplayStream`, `ScreenCaptureKit`, or any capture API;
use a `CVDisplayLink` or timer; use Metal or a custom shader pipeline; use
`NSVisualEffectView` blur; require Accessibility or Screen Recording
permission; add ads, analytics, or network access; ship as anything other
than a plain `.app`.

## The look

Match a matte paper protector, not a photo filter. Default parameters:

| Parameter        | Default | Range          | Notes                                     |
|------------------|---------|----------------|-------------------------------------------|
| Grain strength   | 0.18    | 0.00 to 0.45   | Alpha of the grain layer                  |
| Grain size       | 1 px    | 1 to 3 px      | Block size of one grain, device pixels    |
| Grain colour     | 0.70    | 0.00 to 1.00   | 0 = monochrome, 1 = fully independent RGB |
| Tint colour      | #F4EEDF | any warm off-white | Slight cream, like uncoated paper     |
| Tint strength    | 0.08    | 0.00 to 0.25   | Alpha of the flat tint layer              |
| Presets          | Paper, Newsprint, Off-white, Custom | Newsprint = greyer tint, more grain |

The grain is **coloured**, not monochrome. Each grain gets a shared
luminance offset plus an independent per-channel (R, G, B) offset; the
"grain colour" parameter mixes between the two. At the default the result
reads as fine, slightly iridescent paper fibre rather than grey static.
Distribution is Gaussian around mid-grey, fine, evenly spread, with no
visible tiling seams and no banding.

Compositing is plain source-over alpha. The window server does not let one
window blend (overlay, soft light) against the windows beneath it, and
`CALayer.compositingFilter` only blends against sibling layers in the same
window, so do not reach for blend modes. A mid-grey-centred tile at low
alpha already does what a matte film does optically: lifts blacks a little,
dims whites a little, adds texture.

Hard rule: text on a white background must remain fully legible at every
setting in range. If a setting makes body text hard to read, the range is too
wide.

## Known platform limits (state these in the README, do not fight them)

- The overlay is not shown on the login window, the lock screen, or over
  secure system dialogs.
- Some system UI drawn by the window server at special levels (the cursor,
  some notification banners while animating) may appear above the overlay.
- With `sharingType = .none` the effect is not in screenshots. That is
  intended; document it so users are not confused.
- Night Shift and True Tone are independent and stack with this filter.

## Stack and constraints

- Swift 5.9+, AppKit. SwiftUI is allowed only for the settings popover if it
  keeps the binary under the size budget.
- Deployment target macOS 13. Apple silicon and Intel.
- Zero third-party dependencies. Xcode project or Swift Package with an
  executable target plus a minimal `Info.plist`.
- Release build with optimisation on. Report app bundle size and idle
  CPU/memory in the README.
- Unit tests for the grain tile generator (determinism from seed, value
  distribution, seamless edges). A manual test checklist for the window
  behaviour, since it depends on the window server.

## Acceptance checklist

- [ ] Menu bar icon and hotkey both toggle the overlay; icon shows state.
- [ ] Overlay covers each display fully, including menu bar and Dock.
- [ ] Overlay sits on top of full-screen apps and follows Space switches.
- [ ] All mouse and keyboard input passes through; no app behaves
      differently; cursor never changes over the overlay.
- [ ] Activity Monitor shows 0.0% CPU while idle with the filter on.
- [ ] Plug and unplug an external display: overlays appear and disappear
      with it, existing displays are untouched.
- [ ] Display sleep and wake, lid close and open: filter still on.
- [ ] Screenshots and screen recordings do not include the overlay.
- [ ] Settings changes apply live without recreating windows.
- [ ] Bundle under 5 MB, no network entitlement, no Accessibility or
      Screen Recording prompt ever shown.
- [ ] README explains setup, the hotkey, and the limitations above.

## Repo layout

```
Paperlike/            App sources
  App/                AppDelegate, StatusItemController, HotKey
  Overlay/            OverlayWindow, OverlayController (per-display)
  Grain/              GrainTile generator
  Settings/           Settings model, popover UI
PaperlikeTests/       GrainTile unit tests
GOAL.md               This file
README.md             User-facing docs, screenshots, limitations
```
