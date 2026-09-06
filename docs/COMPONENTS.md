# Components and versions

The configuration is distribution-independent. The published snapshot was
developed and tested on:

- KDE Plasma Workspace 6.7.4 on CachyOS
- KWin 6.7.4, Wayland
- Fastfetch 2.66.0
- Qt 6.11.1
- Samsung Odyssey G9 at 5120×1440
- NVIDIA RTX 4080 (the configuration is not NVIDIA-specific)

## Appearance

- Plasma theme: modified LetMinimalDark / Iridescent-inspired square styling
- colors: LetMinimalDark
- Qt Widgets style: `NothingDolphin`, a small native Breeze override built from
  `native/dolphin-style` with Qt Widgets 6.7+ (from Qt base) and KDE Frameworks
  KIOFileWidgets 6.21+ (from KIO development files), using its public breadcrumb
  background API. Only Dolphin breadcrumb/path backgrounds and normal
  unselected tabs use subtle charcoal `#191919`; the active-tab pink indicator
  and hover feedback remain native. Titlebar, toolbars, sidebar, file area,
  and global color roles are untouched; other applications use native Breeze
- icons: modified Yet Another Monochrome Icon Theme (`YAMIS`)
- cursor: We10XOS
- typography: bundled Inter 4.1 (static text family, not Inter Display) for all
  general UI/body text; widgets inherit the theme font. Local NType 82 Headline
  is decorative-only for the calendar heading; NDot remains on clocks
- KDE body/menu/toolbar/window-title roles: 10pt, smallest readable role: 9pt;
  monospace remains unchanged. See the [local font prerequisite](../README.md#local-font-prerequisite).

The full installer installs `nothingos-dolphin-style.so` to
`~/.local/lib/qt6/plugins/styles/`, selects `KDE/widgetStyle=NothingDolphin`,
and prepends the parent plugin directory to `QT_PLUGIN_PATH` in
`plasma-workspace/env/nothing-mono-kde.sh`, retaining inherited paths. Log out
and back in, then reopen applications so they discover and load the style.
Restore reinstates the previous style selection and environment script; the
plugin file may remain dormant. Log out and back in after restoring as well.
Layout-only installation leaves the style and environment unchanged.

## Plasma applets

- AppGrid 1.9.3: external prerequisite, centered popup (`dev.xarbit.appgrid`,
  not `dev.xarbit.appgrid.panel`), replacing Kickoff
- Nothing Calendar, Notes, CPU and RAM
- Nothing Weather, Digital Clock and Media by Jaxparrow07
- Panel Colorizer
- PlasMusic Toolbar
- Window Title
- custom compact virtual desktop pager
- stock Global Menu and Icon-only Task Manager
- customized PowerDevil Brightness & Color tray applet with an HDR/WCG switch

AppGrid uses `start-here-kde`, `verticalOffset=0`, `gridColumns=5`,
`backgroundOpacity=100`, `enableBlur=false`, `openAnimation=1` (fade),
`hoverAnimation=0`, and
`startWithFavorites=false` in its General configuration; other settings retain
upstream defaults. Install it through the [official distro or user-local
universal instructions](https://appgrid.xarbit.dev/#install), then log out and
back in. On an existing themed desktop, use **Show Alternatives → AppGrid**
on the launcher and apply those settings; do not rerun the full installer.

Optional local Wayland panel-input fix: `install-appgrid-fix.sh` applies
`patches/appgrid-panel-input.patch` to official AppGrid `v1.9.3`, commit
`7843b094d6a2f1b7f9d02df1f67fa5f1fd0a7053`. The center-only binary is labeled
`1.9.3+panel-input-fix`; the universal update checker remains enabled. Its
fullscreen input region excludes real Plasma panel geometries while preserving
outside-click dismissal elsewhere and the existing drag-out region. Centered
layout, styling, and animations remain native. The standalone build/install
requires an existing user-local AppGrid and plugin path; it backs up and
atomically replaces only the center binary, without restarting Plasma. See
the [build, reload, and update caveats](../README.md#appgrid-panel-input-fix).

## KWin and OLED behavior

- Smooth Windows (stable `bouncingWindows` plugin ID): KDE adaptation with
  500ms OutQuint opening scale .9→1 and OutCubic fade; 240ms OutCubic closing
  scale 1→.96 and fade
- KDE AnimationDurationFactor: 1 on install; subsequent KDE speed changes
  scale both the window and native slide effects. AppGrid keeps its native fade
- Hide Cursor at 15 seconds
- custom edge-group controller: left and right widget columns independently
  hide after 10 seconds away from the group and return when the pointer reaches
  the corresponding screen edge
- top and bottom panels use Plasma's independent auto-hide. Native Sliding
  Popups uses 500ms in / 240ms out to match the window timing; this also applies
  to other Plasma surfaces using that effect. KWin retains its built-in
  OutCubic entrance / InCubic exit, edge translation, and Plasma's hide delay
- PowerDevil turns the display off after 60 seconds on AC

No black-overlay screensaver is installed. Native display power management is
used instead.
No Dynamic Island or full-shell replacement is installed.
