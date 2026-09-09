# Paperlike

A tiny macOS menu bar app that makes your MacBook screen look like matte
paper. It lays a fine, static, faintly coloured grain and a warm tint over
everything on screen. One click, or `⌃⌥⌘P`, turns it on or off.

It is the software version of a matte "paper-like" screen protector:
nothing to stick on the glass, tunable, and free to switch off when you want
full colour accuracy back.

## How it works

Paperlike opens one borderless, transparent, click-through window per
display, above the menu bar and Dock, and paints two static layers into it:
a flat tint and a tiled grain texture generated once from a seeded random
number generator. The window server composites it like any other window.
There is no timer, no render loop, no screen capture, and no shader. Idle
cost is zero CPU. Input goes straight through to whatever is underneath.

By default the overlay is excluded from screenshots, screen recordings and
screen sharing, so what you capture or present is untouched.

## Install

Requires macOS 13 or later and Xcode command line tools.

```sh
git clone https://github.com/Argado2248/paperlike.git
cd paperlike
make install      # builds, bundles, ad-hoc signs, copies to /Applications, opens it
```

Or `make app` to get `dist/Paperlike.app` without installing. `swift run`
also works for development, but "Launch at login" is disabled without a
bundle.

The app is ad-hoc signed. On first launch macOS may ask you to confirm in
System Settings → Privacy & Security.

## Use

| Action                       | How                                  |
|------------------------------|--------------------------------------|
| Toggle on/off                | Click the menu bar icon, or `⌃⌥⌘P`   |
| Options menu                 | Right-click or Option-click the icon |
| Presets                      | Paper, Newsprint, Off-white          |
| Live tuning                  | Settings… (grain, colour, size, tint)|
| Hide from screenshots        | On by default, toggle in the menu    |
| Launch at login              | Toggle in the menu                   |

## Settings

| Setting        | Default | Range        |
|----------------|---------|--------------|
| Grain          | 0.18    | 0 to 0.45    |
| Grain colour   | 0.70    | 0 (mono) to 1 (full RGB) |
| Grain size     | 1 px    | 1 to 3 px    |
| Tint           | #F4EEDF | any colour   |
| Tint strength  | 0.08    | 0 to 0.25    |

## Limitations

- Not shown on the login window, lock screen or secure system dialogs.
- The mouse cursor and a few window-server animations draw above it.
- With "Hide from screenshots" on, the effect is missing from captures by
  design.
- Night Shift and True Tone are independent and stack with Paperlike.

## Development

```sh
swift test        # grain generator and settings unit tests
swift build       # debug build
make app          # release bundle in dist/
```

Layout:

```
Sources/PaperlikeCore/   Grain tile generator, settings model (pure Foundation, tested)
Sources/Paperlike/       AppKit app: overlay windows, menu bar, hotkey, settings panel
Tests/PaperlikeCoreTests/
Support/Info.plist
GOAL.md                  Project goal prompt
```

Measured size and idle numbers: to be filled in after the first release
build on a Mac (`make app` prints the bundle size; check Activity Monitor
with the filter on).
