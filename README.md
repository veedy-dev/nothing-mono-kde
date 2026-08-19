# Nothing Mono KDE

Set up a complete monochrome, NothingOS-inspired desktop on KDE Plasma 6,
regardless of which Linux distribution you use.
The installer configures the Plasma layout, widgets, themes, animations,
OLED-friendly behavior, and Fastfetch while backing up your existing desktop
configuration first.

The layout supports regular 16:9 screens as well as 21:9 and 32:9 ultrawide
displays. Widget sizes and edge positions are calculated from the active
screen geometry instead of being tied to one monitor.

![Desktop preview](screenshots/nothingos-kde-g9.png)

## What the installer configures

- a responsive desktop layout for 16:9, 21:9, and 32:9 screens
- an OLED-black status bar and a content-sized application dock
- independently hiding left and right widget groups
- configurable weather, world clock, calendar, notes, system monitoring, and
  media controls
- a compact, clickable virtual desktop switcher
- a Brightness & Color tray popup with an HDR and wide-color-gamut switch
- monochrome themes, icons, cursors, wallpaper, and Nothing-style typography
- matching desktop and lock-screen appearance
- tuned KWin animations with a short but visible closing effect
- OLED-conscious cursor hiding, panel hiding, and display power management
- a matching Fastfetch preset
- automatic backups and a generated restoration script

## Supported setup

- any Linux distribution running KDE Plasma
- KDE Plasma **6.7+**
- a Plasma Wayland session
- one primary display
- standard 16:9 resolutions such as 1920×1080 and 2560×1440
- ultrawide 21:9 and 32:9 resolutions up to 5120×1440

The screenshot shows the 5120×1440 reference layout. On a regular 16:9
display, the same widgets stay anchored to the left and right edges with
scaled sizes and margins, leaving the center available for windows.

Dependency installation is automatic on Arch-based, Debian/Ubuntu-based,
Fedora, and openSUSE systems. On another distribution, install CMake, a C++
compiler, Qt 6 development files, and optionally Fastfetch, then run the
installer with `--no-packages`.

## Install

Review the script first—this changes your Plasma layout and KDE preferences.

```bash
git clone https://github.com/veedy-dev/nothing-mono-kde.git
cd nothing-mono-kde
./install.sh
```

Useful modes:

```bash
./install.sh --dry-run        # show actions without changing anything
./install.sh --no-packages    # skip distribution package installation
./install.sh --layout-only    # reinstall only the Plasma layout
```

The installer backs up affected KDE files under:

```text
~/.local/state/nothingos-kde-rice/backups/<timestamp>/
```

Restore the most recent backup with:

```bash
~/.local/share/nothingos-kde-rice/restore-latest.sh
```

Log out and back in once after installation so KWin, fonts, and autostarted
services are all loaded consistently.

## Fastfetch only

```bash
./install-fastfetch.sh
fastfetch
```

The preset is derived from LierB's Groups concept and restyled to match this
rice. It is resolution- and hardware-independent.

## Customize the setup

Before installing, edit the clearly labeled values in `layout/layout.js` to
choose:

- weather location
- world-clock city and time zone
- pinned dock applications

You can also change the widget hide delay in
`native/edge-groups/main.cpp` and the display power-off timeout in
`install.sh`.

See [docs/COMPONENTS.md](docs/COMPONENTS.md) for the exact component list and
[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for common issues.

## Credits and licensing

This rice combines work from several KDE community projects. See
[THIRD_PARTY.md](THIRD_PARTY.md). The repository's original scripts and
configuration are GPL-3.0-or-later; bundled components retain their upstream
licenses.
