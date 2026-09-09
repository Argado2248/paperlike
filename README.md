# Paperlike

A tiny macOS menu bar app that makes your MacBook screen look like matte
paper. It lays a fine, static, faintly coloured grain and a warm tint over
everything on screen. One click, or `⌃⌥⌘P`, turns it on or off.

It is the software version of a matte "paper-like" screen protector:
nothing to stick on the glass, tunable, and free to switch off when you want
full colour accuracy back.

## How it works

The tint goes through each display's gamma table, the same channel Night
Shift uses. It is applied at the display output, so it covers everything
including the menu bar, Dock, full-screen apps and the desktop-switch
animation, never flickers, and never shows up in screenshots.

The grain is one borderless, transparent, click-through window per display
painted once with a tiled texture generated from a seeded random number
generator. There is no timer, no render loop, no screen capture, and no
shader. Idle cost is zero CPU. Input goes straight through to whatever is
underneath. By default the grain window is excluded from screenshots and
recordings too.

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
| Grain          | 0.05    | 0 to 0.30    |
| Grain colour   | 0.00    | 0 (mono) to 1 (full RGB) |
| Grain size     | 1 px    | 1 to 3 px    |
| Tint           | #F4EEDF | any colour   |
| Tint strength  | 0.03    | 0 to 0.15    |

## Limitations

- The grain window is not shown on the login window, lock screen or secure
  system dialogs, and blinks for a frame when you swipe between desktops.
  At the default strength that is not visible; set grain to 0 and there is
  no window at all. The tint is unaffected.
- The mouse cursor, pop-up menus and the Cmd-Tab switcher draw above the
  grain window.
- Screenshots never include the tint, and by default not the grain either.
- Night Shift and True Tone stack with Paperlike. Apps that also write
  display gamma tables (f.lux and similar) will fight with it.
- Diagnostics: the last line of the right-click menu shows the running
  version, grain window level and collection behaviour. Both can be
  overridden for experiments with `defaults write com.argado.paperlike
  windowLevel -int N` and `collectionBehavior -int N`; `defaults delete`
  restores the defaults.

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

Measured on a MacBook Pro running the release bundle from `make install`:

| Metric                  | Value    |
|-------------------------|----------|
| Private memory          | 19 MB    |
| Real memory (incl. shared AppKit pages) | 76 MB |
| CPU while idle          | ~0%      |

Bundle size is printed by `make app`.
