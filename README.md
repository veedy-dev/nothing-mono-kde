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
- a centered AppGrid application launcher with an opaque monochrome background
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

Build dependency installation is automatic on Arch-based, Debian/Ubuntu-based,
Fedora, and openSUSE systems. On another distribution, install CMake, a C++
compiler, Qt 6.7+ and KDE Frameworks KIO 6.21+ development files, and optionally
Fastfetch, then run the installer with `--no-packages`.

**AppGrid is an external prerequisite**, not bundled or installed by this script.
Install it using the [official distro or user-local universal instructions](https://appgrid.xarbit.dev/#install),
then log out and back in so the running Plasma session discovers it. The
version exercised for this integration is **1.9.3**. The installer checks for
`dev.xarbit.appgrid` before backups or changes (except during `--dry-run`);
it stops if unavailable rather than falling back to Kickoff.

Already using this theme? No full installer rerun is needed: right-click the
existing launcher → **Show Alternatives → AppGrid** (not AppGrid Panel). In
AppGrid settings, retain the `start-here-kde` icon and set vertical offset to
0 (centered), grid columns to 5, background opacity to 100%, blur off, hover
animation to None, and start with favorites off. Other settings stay native.

## AppGrid panel input fix

For AppGrid 1.9.3 on Plasma 6.7 Wayland, the optional standalone fix keeps the
centered fullscreen overlay and outside-click dismissal, but excludes actual
Plasma panel windows from its normal input region so dock clicks reach the dock.
Native launcher styling, animations, and drag-out behavior are retained.

First install the official **user-local universal AppGrid** and log out and back
in. The script requires its existing center binary at
`~/.local/lib/qt6/plugins/plasma/applets/dev.xarbit.appgrid.so`, that plugin root
in `QT_PLUGIN_PATH`, and AppGrid discovery in the running Plasma session. It
does not install AppGrid from scratch or set up plugin discovery.

Install Git, CMake, a C++20 compiler/build tool, and the
[upstream development dependencies](https://appgrid.xarbit.dev/docs/#dependencies-per-distro)
first; see also the [1.9.3 build prerequisites](https://github.com/xarbit/plasma6-applet-appgrid/tree/v1.9.3#build-from-source).
These include Qt 6 Quick/Gui/DBus/Network, ECM, KDE Frameworks 6, Plasma and
PlasmaQuick, LayerShellQt, Plasma Activities/Stats, and AppStreamQt. CMake
reports missing development packages; the script never runs a package manager
or sudo. The full theme installer does not install these extra dependencies.

```bash
./install-appgrid-fix.sh --dry-run   # offline plan, no changes
./install-appgrid-fix.sh             # build and replace only the center binary
```

The script clones the official repository at `v1.9.3`, verifies commit
`7843b094d6a2f1b7f9d02df1f67fa5f1fd0a7053`, and applies
`patches/appgrid-panel-input.patch` in a fresh temporary workspace (removed on
exit). Existing source checkouts are never reset or modified. It builds only
`dev.xarbit.appgrid`, labels it `1.9.3+panel-input-fix`, disables tests, and keeps
the universal build's opt-in update checker. Before atomic replacement it saves
the previous binary under
`${XDG_STATE_HOME:-$HOME/.local/state}/nothingos-kde-rice/backups/appgrid.<unique suffix>/`.
Backups stay outside Qt plugin discovery; atomic staging uses a hidden file.
The running shell continues mapping the old binary safely until restarted.
The `.panel` variant, AppGrid settings, session environment, and manifests are
untouched. No shell restart or layout change is automatic.

**After installation:** log out and back in, or in a systemd-managed Plasma
session run `systemctl --user restart plasma-plasmashell.service`. Do not rerun
the full installer or layout script. To restore, use the exact printed backup
path (not the full theme restore helper), stage beside the plugin, and rename
atomically; never overwrite the mapped binary in place:

```bash
backup=/exact/printed/backup/path/dev.xarbit.appgrid.so
plugin="$HOME/.local/lib/qt6/plugins/plasma/applets/dev.xarbit.appgrid.so"
staged="$(mktemp "${plugin%/*}/.dev.xarbit.appgrid.so.restore.XXXXXXXX")"
if install -m 0755 -- "$backup" "$staged" && mv -fT -- "$staged" "$plugin"; then
    printf 'Restored; log out and back in to reload Plasma.\n'
else
    rm -f -- "$staged"
    printf 'Restore failed; the backup is unchanged.\n' >&2
fi
```

An upstream AppGrid update may overwrite this local fix. Check whether the
new release already fixes panel input before rebuilding; this script always
builds **1.9.3**, so rerunning after an upgrade would replace the center binary
with that older version. A Qt/Plasma ABI upgrade may also require a rebuild
against the new development files. Keep the upstream package and local fix
version compatible rather than blindly reapplying the patch to newer sources.

## Local font prerequisite

Inter 4.1 is bundled under `fonts/inter` and installed automatically by the
full installer. It is the general UI font; NType 82 is not used for body text.

Install **NType 82 Headline** yourself, for your user only, before running the
installer. This decorative calendar-heading font is not bundled or downloaded
by the installer. Upstream describes it as personal/noncommercial; review its
terms before use. The reference source is [Nothing KDE Widgets, `1-common/fonts`](https://github.com/jaxparrow07/nothing-kde-widgets/tree/4c1ae8752bb3cf5c8abba0b897631d3a695973f2/1-common/fonts)
at commit `4c1ae8752bb3cf5c8abba0b897631d3a695973f2`.

Once you have a local copy of `ntype82-headline.otf`:

```bash
font_dir="${XDG_DATA_HOME:-$HOME/.local/share}/fonts/NothingOS"
install -d "$font_dir"
install -m 0644 /path/to/ntype82-headline.otf "$font_dir/"
fc-cache -f
fc-match --format='%{family}\n' 'NType 82 Headline'
```

The last command must return exactly `NType 82 Headline`, not a substitute.
The installer rejects a missing Headline family before any backup or change.
Layout-only mode also requires Inter to be installed already because it does
not install assets. Dry-run skips these checks.

KDE body, menu, toolbar and title fonts use Inter at 10pt; the smallest readable
font is 9pt. General widget text inherits the theme font. NType 82 Headline is
decorative-only for the calendar heading; NDot remains on clocks. Existing
terminal/monospace preferences are left alone. Qt legacy, GTK 2/3/4 and
xsettingsd receive matching Inter 10 settings; other toolkit preferences are
preserved. GTK 2 uses `~/.gtkrc-2.0`; if you override `GTK2_RC_FILES`,
ensure that file is included in your override.

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

The installer backs up affected KDE and toolkit configuration files under:

```text
~/.local/state/nothingos-kde-rice/backups/<timestamp>/
```

Nested toolkit files and `~/.gtkrc-2.0` are included. Restore also removes
configuration files that were absent before installation. Installed theme
assets, the dormant Dolphin style plugin, and user-local fonts are not uninstalled
by the restore helper. Restoring `kdeglobals` and the previous session environment
script restores style selection; installed Qt plugins remain discoverable.

Restore the most recent backup with:

```bash
~/.local/share/nothingos-kde-rice/restore-latest.sh
```

Log out and back in once after installation or restoration so KWin, fonts,
Qt plugin discovery, and autostarted services are loaded consistently. Reopen
applications to pick up the selected style.

The full installer builds the Qt 6 Widgets style `NothingDolphin` and installs
it under `~/.local/lib/qt6/plugins/styles/`. Qt Widgets comes from the Qt base
development dependency; KDE Frameworks KIO 6.21+ development files provide the
public breadcrumb background API. Its session script prepends `~/.local/lib/qt6/plugins`
to `QT_PLUGIN_PATH`, preserving inherited entries. Only Dolphin breadcrumb/path
backgrounds and normal unselected tabs become subtle charcoal (`#191919`);
the active-tab pink indicator and hover feedback stay native. Titlebar,
toolbars, sidebar, file area, and the global color scheme are unchanged by
this override. Other applications receive native Breeze. `--layout-only`
does not build, install, or select this style.

Motion is a Nothing-inspired adaptation to KDE, not a full Nothing OS shell
replacement. Window opening uses a 500ms OutQuint scale with OutCubic fade;
closing uses 240ms OutCubic. The installer sets KDE AnimationDurationFactor to 1, including
when a previous setup disabled animation; later changes to KDE animation
speed scale the effect. AppGrid retains its own fade. No Dynamic Island is
installed.

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
