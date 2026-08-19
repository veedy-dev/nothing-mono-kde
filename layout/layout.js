// Reproducible NothingOS-inspired Plasma 6 layout.
// The installer replaces __WALLPAPER_URI__ before evaluation.

var WEATHER_CITY = "Jakarta";
var WORLD_CLOCK_CITY = "TOKYO";
var WORLD_CLOCK_ZONE = "Asia/Tokyo";

function configure(widget, group, values) {
    widget.currentConfigGroup = group;
    for (var key in values) {
        widget.writeConfig(key, values[key]);
    }
}

function addDesktopWidget(desktop, plugin, x, y, width, height, values) {
    var widget = desktop.addWidget(plugin);
    widget.geometry = new QRectF(x, y, width, height);
    if (values) {
        configure(widget, ["General"], values);
    }
    return widget;
}

// Plasma's scripting API exposes the logical geometry of the screen.
var desktop = desktops()[0];
var area = screenGeometry(desktop.screen);
var width = area.width > 0 ? area.width : 5120;
var height = area.height > 0 ? area.height : 1440;

// Keep the reference widget sizes on large screens and scale down only when
// necessary. Positions stay anchored to the corresponding screen edge.
var scale = Math.min(1, Math.max(0.70, height / 1440));
var margin = Math.round(Math.max(24, 48 * scale));
var topY = Math.round(Math.max(48, 64 * scale));
var gap = Math.round(16 * scale);

var calendarW = Math.round(432 * scale);
var calendarH = Math.round(320 * scale);
var tile = Math.round(208 * scale);
var rightW = Math.round(368 * scale);
var notesH = Math.round(272 * scale);
var stripH = Math.round(144 * scale);
var rightX = width - margin - rightW;

// This is destructive by design; install.sh creates a backup first.
var oldPanels = panels();
for (var p = 0; p < oldPanels.length; ++p) {
    oldPanels[p].remove();
}
var oldWidgets = desktop.widgets();
for (var w = 0; w < oldWidgets.length; ++w) {
    oldWidgets[w].remove();
}

desktop.wallpaperPlugin = "org.kde.image";
configure(desktop, ["Wallpaper", "org.kde.image", "General"], {
    Image: "__WALLPAPER_URI__",
    PreviewImage: "__WALLPAPER_URI__",
    FillMode: 2
});

// Left group: large calendar with two equal tiles underneath.
addDesktopWidget(desktop, "nothing-calendar-widget",
                 margin, topY, calendarW, calendarH);
addDesktopWidget(desktop, "com.jaxparrow07.nothingkdewidgets.weather",
                 margin, topY + calendarH + gap, tile, tile, {
                     widgetVariant: 0,
                     location: WEATHER_CITY,
                     temperatureUnit: 0,
                     themeMode: 0,
                     useSystemAccent: false
                 });
addDesktopWidget(desktop, "com.jaxparrow07.nothingkdewidgets.digitalclock",
                 margin + calendarW - tile,
                 topY + calendarH + gap, tile, tile, {
                     widgetVariant: 1,
                     cityName: WORLD_CLOCK_CITY,
                     timeZone: WORLD_CLOCK_ZONE,
                     use24HourFormat: true,
                     themeMode: 0,
                     useSystemAccent: false
                 });

// Right group: utilities and system information in one aligned column.
addDesktopWidget(desktop, "nothing-notes-widget",
                 rightX, topY, rightW, notesH);
addDesktopWidget(desktop, "nothing-cpu-widget",
                 rightX, topY + notesH + gap, rightW, stripH);
addDesktopWidget(desktop, "nothing-ram-widget",
                 rightX, topY + notesH + stripH + gap * 2, rightW, stripH);
addDesktopWidget(desktop, "com.jaxparrow07.nothingkdewidgets.media",
                 rightX, topY + notesH + stripH * 2 + gap * 3,
                 rightW, stripH, {
                     themeMode: 0,
                     useSystemAccent: false
                 });

// Full-width Android-like OLED status bar.
var top = new Panel;
top.screen = desktop.screen;
top.location = "top";
top.height = Math.round(48 * scale);
top.alignment = "center";
top.lengthMode = "fill";
top.floating = false;
top.hiding = "autohide";

var launcher = top.addWidget("org.kde.plasma.kickoff");
configure(launcher, ["General"], { icon: "start-here-kde" });

var title = top.addWidget("org.kde.windowtitle");
configure(title, ["Appearance"], {
    txt: "%a",
    altTxt: "Desktop",
    txtSameFound: "%a",
    noIcon: false,
    activityIcon: true,
    fontSize: 14,
    iconSize: 24,
    fixedLength: 260,
    lengthKind: 0,
    isBold: true
});

top.addWidget("org.kde.plasma.appmenu");
top.addWidget("org.kde.plasma.panelspacer");

var music = top.addWidget("plasmusic-toolbar");
configure(music, ["General"], {
    maxSongWidthInPanel: 300,
    textScrollingEnabled: true,
    songTextInPanel: true,
    iconInPanel: true,
    skipBackwardControlInPanel: true,
    playPauseControlInPanel: true,
    skipForwardControlInPanel: true,
    showWhenNoMedia: false
});

top.addWidget("org.kde.plasma.panelspacer");
top.addWidget("nothingos-compact-pager");
top.addWidget("org.kde.plasma.panelspacer");
top.addWidget("org.kde.kdeconnect");

var tray = top.addWidget("org.kde.plasma.systemtray");
var enabledTrayItems = [
    "org.kde.kdeconnect",
    "org.kde.plasma.bluetooth",
    "org.kde.plasma.cameraindicator",
    "org.kde.plasma.clipboard",
    "org.kde.plasma.devicenotifier",
    "org.kde.plasma.manage-inputmethod",
    "org.kde.plasma.mediacontroller",
    "org.kde.plasma.notifications",
    "org.kde.plasma.keyboardindicator",
    "org.kde.plasma.weather",
    "org.kde.kscreen",
    "org.kde.plasma.battery",
    "org.kde.plasma.keyboardlayout",
    "org.kde.plasma.networkmanagement",
    "org.kde.plasma.volume",
    "org.kde.plasma.brightness.hdr"
].join(",");
configure(tray, ["General"], {
    scaleIconsToFit: false,
    iconSpacing: 2,
    extraItems: enabledTrayItems,
    knownItems: enabledTrayItems + ",org.kde.plasma.brightness"
});

var clock = top.addWidget("org.kde.plasma.digitalclock");
configure(clock, ["Appearance"], {
    showDate: false,
    use24hFormat: 2,
    autoFontAndSize: false,
    fontFamily: "Nothing Font (5x7)",
    fontSize: 24,
    fontWeight: 50,
    fontStyleName: "Regular"
});
top.addWidget("org.kde.plasma.showdesktop");

var topColorizer = top.addWidget("luisbocanegra.panel.colorizer");
configure(topColorizer, ["General"], {
    hideWidget: true,
    isEnabled: true
});

// Medium, content-sized dock. Plasma changes its length as launchers/tasks do.
var dock = new Panel;
dock.screen = desktop.screen;
dock.location = "bottom";
dock.height = Math.round(70 * scale);
dock.alignment = "center";
dock.lengthMode = "fit";
dock.minimumLength = 0;
dock.maximumLength = width;
dock.floating = true;
dock.hiding = "autohide";

var tasks = dock.addWidget("org.kde.plasma.icontasks");
configure(tasks, ["General"], {
    launchers: "applications:systemsettings.desktop,applications:org.kde.dolphin.desktop,applications:brave-browser.desktop,applications:steam.desktop,applications:discord.desktop,applications:org.kde.konsole.desktop",
    showOnlyCurrentDesktop: false,
    showOnlyCurrentActivity: false,
    showOnlyCurrentScreen: false,
    iconSpacing: 2
});

var dockColorizer = dock.addWidget("luisbocanegra.panel.colorizer");
configure(dockColorizer, ["General"], {
    hideWidget: true,
    isEnabled: true
});

top.reloadConfig();
dock.reloadConfig();
desktop.reloadConfig();

