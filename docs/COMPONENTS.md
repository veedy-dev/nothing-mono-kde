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
- font: Nothing dot font for display labels; normal system font for note text

## Plasma applets

- Nothing Calendar, Notes, CPU and RAM
- Nothing Weather, Digital Clock and Media by Jaxparrow07
- Panel Colorizer
- PlasMusic Toolbar
- Window Title
- custom compact virtual desktop pager
- stock Global Menu and Icon-only Task Manager
- customized PowerDevil Brightness & Color tray applet with an HDR/WCG switch

## KWin and OLED behavior

- Bouncing Windows, adjusted to retain the effect but shorten close animation
- Hide Cursor at 15 seconds
- custom edge-group controller: left and right widget columns independently
  hide after 10 seconds away from the group and return when the pointer reaches
  the corresponding screen edge
- top and bottom panels use Plasma's independent auto-hide
- PowerDevil turns the display off after 60 seconds on AC

No black-overlay screensaver is installed. Native display power management is
used instead.
