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
- icons: modified Yet Another Monochrome Icon Theme (`YAMIS`)
- cursor: We10XOS
- typography: bundled Inter 4.1 (static text family, not Inter Display) for all
  general UI/body text; widgets inherit the theme font. Local NType 82 Headline
  is decorative-only for the calendar heading; NDot remains on clocks
- KDE body/menu/toolbar/window-title roles: 10pt, smallest readable role: 9pt;
  monospace remains unchanged. See the [local font prerequisite](../README.md#local-font-prerequisite).

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
