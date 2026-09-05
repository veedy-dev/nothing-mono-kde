#!/usr/bin/env python3
"""Run with python3 tests/test-install.py; all writes stay inside a temporary home."""
import os
from pathlib import Path
import subprocess
import tempfile

installer = Path(__file__).resolve().parent.parent / "install.sh"
stubs = r'''
plasmashell() { echo 'plasmashell 6.7.4'; }
systemctl() { return 0; }
qmake6() { echo /unused/qt/qml; }
qdbus6() { printf '%s' "${APPGRID:-true}"; }
fc-match() { if [[ "$2" == "${MISSING:-}" ]]; then echo 'Fallback'; else printf '%s' "$2"; fi; }
export -f plasmashell systemctl qmake6 qdbus6 fc-match
'''
with tempfile.TemporaryDirectory(prefix="nothing-installer-") as directory:
    home = Path(directory)
    config = home / "config"
    env = {**os.environ, "HOME": str(home), "XDG_CONFIG_HOME": str(config),
           "XDG_DATA_HOME": str(home / "data"), "XDG_STATE_HOME": str(home / "state"),
           "XDG_CURRENT_DESKTOP": "KDE", "DBUS_SESSION_BUS_ADDRESS": "unix:path=/nonexistent"}

    def run(script, **overrides):
        return subprocess.run(["bash", "-c", stubs + script, "check", str(installer)],
                              env={**env, **overrides}, capture_output=True, text=True)

    def snapshot():
        return {str(p.relative_to(home)): p.read_bytes() for p in home.rglob("*") if p.is_file()}

    for mode, family in (("--no-packages", "NType 82 Headline"),
                         ("--layout-only", "NType 82 Headline"),
                         ("--layout-only", "Inter")):
        result = run('bash "$1" --yes ' + mode, MISSING=family)
        assert result.returncode != 0 and family in result.stderr, result.stderr
        assert not list(home.iterdir()), "Font rejection mutated home"
    for family in ("Inter", "NType 82"):
        result = run('bash "$1" --yes --no-packages', MISSING=family, APPGRID="false")
        assert result.returncode != 0 and "AppGrid" in result.stderr, result.stderr
        assert not list(home.iterdir()), "Preflight rejection mutated home"
    result = run('bash "$1" --yes --layout-only', APPGRID="false")
    assert result.returncode != 0 and "AppGrid" in result.stderr
    assert not list(home.iterdir()), "AppGrid rejection mutated home"
    result = run('bash "$1" --dry-run --no-packages', MISSING="NType 82 Headline")
    assert result.returncode == 0, result.stderr
    assert not list(home.iterdir()), "Dry-run mutated home"

    gtk2 = home / ".gtkrc-2.0"
    gtk2.write_text('# keep comment\ngtk-theme-name="Breeze"\n gtk-font-name = "Old 10"\n')
    xsettings = config / "xsettingsd/xsettingsd.conf"
    xsettings.parent.mkdir(parents=True)
    xsettings.write_text('Net/ThemeName "Breeze"\n')
    original = snapshot()
    result = run('bash "$1" --yes --layout-only')
    assert result.returncode == 0, result.stderr
    result = run(r'''
source "$1" --dry-run --no-packages >/dev/null
dry_run=false
set_font_line "$HOME/.gtkrc-2.0" '^[[:space:]]*gtk-font-name[[:space:]]*=' 'gtk-font-name="Inter 10"'
set_font_line "$XDG_CONFIG_HOME/xsettingsd/xsettingsd.conf" '^[[:space:]]*Gtk/FontName[[:space:]]+' 'Gtk/FontName "Inter 10"'
''')
    assert result.returncode == 0, result.stderr
    assert gtk2.read_text() == '# keep comment\ngtk-theme-name="Breeze"\ngtk-font-name="Inter 10"\n'
    assert xsettings.read_text() == 'Net/ThemeName "Breeze"\n\nGtk/FontName "Inter 10"\n'
    newly_created = config / "gtk-4.0/settings.ini"
    newly_created.parent.mkdir()
    newly_created.write_text('[Settings]\ngtk-font-name=Inter 10\n')
    result = run('bash "$XDG_DATA_HOME/nothingos-kde-rice/restore-latest.sh"')
    assert result.returncode == 0, result.stderr
    assert all((home / p).read_bytes() == content for p, content in original.items())
    assert not newly_created.exists(), "Restore retained a previously absent config"
print("PASS: font/AppGrid preflight, dry-run isolation, native font edits, nested/absent restore")
