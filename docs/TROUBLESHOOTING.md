# Troubleshooting

## Widgets or panels do not appear

Log out and back in. If needed:

```bash
systemctl --user restart plasma-plasmashell.service
systemctl --user restart nothingos-edge-groups.service
```

## Left/right groups do not reveal

Check the controller:

```bash
systemctl --user status nothingos-edge-groups.service
journalctl --user -u nothingos-edge-groups.service -b
```

Move the pointer against the left or right edge over any member of that group.

## Layout is too small or too large

The script scales margins and keeps practical widget sizes. KDE's global
display scale still affects the apparent size. Start with 100% on a 5120×1440
G9 and adjust in System Settings → Display & Monitor.

## GTK app headings are nearly black

Breeze GTK4 uses a border color for disabled treeview text. Apps such as
Proton VPN use disabled rows as search-section headings, exposing that mismatch.
The shared `theme/gtk-4.0/contrast.css` override uses the disabled foreground
roles instead; normal and selected rows keep their native colors. GTK3 does
not need this correction. The full installer installs the override and
preserves existing custom GTK CSS. Reopen GTK4 applications after installation
when safe; restarting a VPN client may interrupt its connection.

Check the rule with `python3 tests/test-gtk-contrast.py` in a GTK4 graphical
session. This runs a local widget only and does not launch or control a VPN.

## Restore the previous desktop

```bash
~/.local/share/nothingos-kde-rice/restore-latest.sh
```

The restore is intentionally file-based and does not remove unrelated packages.

