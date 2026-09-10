#!/usr/bin/env python3
"""Run with python3 tests/test-gtk-contrast.py in a GTK4 graphical session."""
from pathlib import Path
import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Gdk", "4.0")
from gi.repository import Gdk, Gtk


def contrast(foreground, background):
    def luminance(channels):
        linear = [v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
                  for v in channels]
        return sum(v * weight for v, weight in zip(linear, (0.2126, 0.7152, 0.0722)))
    low, high = sorted((luminance(foreground), luminance(background)))
    return (high + 0.05) / (low + 0.05)


# Reproduce Breeze's border-as-text rule independently of the user's palette.
baseline = Gtk.CssProvider()
baseline.load_from_string("""
@define-color insensitive_base_fg_color_breeze #939393;
@define-color insensitive_unfocused_fg_color_breeze #939393;
treeview.view { color: #fcfcfc; background-color: #121212; }
treeview.view:disabled { color: #161616; }
treeview.view:disabled:backdrop { color: #161616; }
treeview.view:selected { color: #181818; background-color: #f25e70; }
""")
display = Gdk.Display.get_default()
assert display is not None, "A GTK4 graphical session is required"
Gtk.StyleContext.add_provider_for_display(display, baseline, 1000)
view = Gtk.TreeView()
context = view.get_style_context()


def color(state):
    context.set_state(state)
    value = context.get_color()
    return (value.red, value.green, value.blue)


normal = color(Gtk.StateFlags.NORMAL)
selected = color(Gtk.StateFlags.SELECTED)
background = (18 / 255,) * 3
assert contrast(color(Gtk.StateFlags.INSENSITIVE), background) < 2
fix = Gtk.CssProvider()
fix.load_from_path(str(Path(__file__).resolve().parents[1] / "theme/gtk-4.0/contrast.css"))
Gtk.StyleContext.add_provider_for_display(display, fix, 1001)
assert contrast(color(Gtk.StateFlags.INSENSITIVE), background) >= 4.5
assert contrast(color(Gtk.StateFlags.INSENSITIVE | Gtk.StateFlags.BACKDROP), background) >= 4.5
assert color(Gtk.StateFlags.NORMAL) == normal, "Normal rows changed"
assert color(Gtk.StateFlags.SELECTED) == selected, "Selected rows changed"
print("PASS: disabled and backdrop headings readable; normal and selected rows unchanged")
