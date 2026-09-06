# Third-party components

This project packages a reproducible configuration and modified copies of
components used by the rice. Copyright remains with each upstream author.

| Component | Upstream | License |
|---|---|---|
| AppGrid (external prerequisite, not bundled; 1.9.3 exercised) | https://github.com/xarbit/plasma6-applet-appgrid | GPL-2.0-or-later |
| Nothing KDE Widgets | https://github.com/jaxparrow07/nothing-kde-widgets | GPL-3.0 |
| Poor Nothing KDE Widgets | https://github.com/Letaryat/poor-nothing-kde-widgets | Per component metadata |
| Panel Colorizer | https://github.com/luisbocanegra/plasma-panel-colorizer | GPL-3.0 |
| PlasMusic Toolbar | https://github.com/ccatterina/plasmusic-toolbar | GPL-3.0 |
| Window Title | https://github.com/dhruv8sh/plasma6-window-title-applet | GPL-2.0 |
| KDE PowerDevil Brightness & Color | https://invent.kde.org/plasma/powerdevil | GPL-2.0-or-later / LGPL-2.0-or-later |
| Yet Another Monochrome Icon Theme | https://github.com/googIyEYES/Yet-Another-Monochrome-Icon-Theme | See upstream |
| LetMinimalDark theme | https://github.com/Letaryat/kde-LetMinimalDark-Theme | See upstream |
| KDE QQC2 Desktop Style | https://invent.kde.org/frameworks/qqc2-desktop-style | LGPL-3.0 or GPL-2.0+ |
| Fastfetch Groups preset inspiration | https://github.com/LierB/fastfetch | See upstream |
| Inter 4.1 | https://github.com/rsms/inter/releases/tag/v4.1 | SIL Open Font License 1.1; see fonts/inter/LICENSE.txt |

AppGrid is installed separately using its [official distro or user-local
universal instructions](https://appgrid.xarbit.dev/#install). This repository
configures the centered launcher but does not redistribute its package. It
also carries a GPL-2.0-or-later source patch at
`patches/appgrid-panel-input.patch` for official tag `v1.9.3`, commit
`7843b094d6a2f1b7f9d02df1f67fa5f1fd0a7053`. The optional
`install-appgrid-fix.sh` downloads that exact upstream source and builds a
user-local center-only binary labeled `1.9.3+panel-input-fix`; upstream
copyright and licensing remain applicable. See README.md for installation
and update caveats.

Inter is bundled in `fonts/inter` from the official [rsms/inter v4.1 release](https://github.com/rsms/inter/releases/tag/v4.1).
These are the static text-family TTFs (not Inter Display): Regular, Medium,
SemiBold, Bold, Italic and BoldItalic. The upstream copyright notice and SIL
Open Font License 1.1 are retained in `fonts/inter/LICENSE.txt`.

NType 82 Headline is an external, user-local prerequisite used only for the
decorative calendar heading, not general UI/body text. It is not redistributed
or automatically downloaded by this repository. The reference file is
`ntype82-headline.otf`, from [Nothing KDE Widgets `1-common/fonts`](https://github.com/jaxparrow07/nothing-kde-widgets/tree/4c1ae8752bb3cf5c8abba0b897631d3a695973f2/1-common/fonts)
at commit `4c1ae8752bb3cf5c8abba0b897631d3a695973f2`. Upstream describes the
font as personal/noncommercial; its widget code license does not establish
redistribution rights for the font. Review upstream terms before use.

Existing Nothing dot font assets remain in individual widget packages and
`fonts/`; this typography change does not add proprietary font binaries.

Nothing OS and Nothing are trademarks of Nothing Technology Limited. This is
an unofficial community theme and is not affiliated with or endorsed by
Nothing.
