#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
install_root="$data_home/nothingos-kde-rice"
backup_root="$state_home/nothingos-kde-rice/backups"
timestamp="$(date +%Y%m%d-%H%M%S)"
backup_dir="$backup_root/$timestamp"

dry_run=false
install_packages=true
layout_only=false
assume_yes=false
user_systemd=false

usage() {
    cat <<'EOF'
Usage: ./install.sh [options]
  --dry-run       Print the planned actions without changing files
  --no-packages   Skip dependency installation
  --layout-only   Apply only the Plasma layout (still creates a backup)
  --yes           Do not ask for confirmation
  -h, --help      Show this help
EOF
}

while (($#)); do
    case "$1" in
        --dry-run) dry_run=true ;;
        --no-packages) install_packages=false ;;
        --layout-only) layout_only=true; install_packages=false ;;
        --yes) assume_yes=true ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

run() {
    printf '+'
    printf ' %q' "$@"
    printf '\n'
    if ! $dry_run; then
        "$@"
    fi
}

copy_tree() {
    local source="$1" destination="$2"
    run install -d "$destination"
    if $dry_run; then
        printf '+ cp -a %q/. %q/\n' "$source" "$destination"
    else
        cp -a "$source/." "$destination/"
    fi
}

install_dependencies() {
    if command -v pacman >/dev/null 2>&1; then
        run sudo pacman -S --needed cmake gcc qt6-base kio fastfetch
    elif command -v apt-get >/dev/null 2>&1; then
        run sudo apt-get install -y cmake g++ qt6-base-dev libkf6kio-dev
        if apt-cache show fastfetch >/dev/null 2>&1; then
            run sudo apt-get install -y fastfetch
        else
            printf 'Note: Fastfetch is not available in the configured APT repositories.\n'
        fi
    elif command -v dnf >/dev/null 2>&1; then
        run sudo dnf install -y cmake gcc-c++ qt6-qtbase-devel kf6-kio-devel fastfetch
    elif command -v zypper >/dev/null 2>&1; then
        run sudo zypper --non-interactive install cmake gcc-c++ \
            qt6-base-devel kf6-kio-devel fastfetch
    else
        cat >&2 <<'EOF'
No supported package manager was detected.
Install CMake, a C++ compiler, Qt 6.7+ and KDE Frameworks KIO 6.21+ development files,
and optionally Fastfetch, then rerun with --no-packages.
EOF
        exit 1
    fi
}

# GTK 2 rc and xsettingsd are not INI files: keep their native quoted syntax.
set_font_line() {
    local file="$1" pattern="$2" setting="$3"
    printf '+ set %s in %q\n' "$setting" "$file"
    $dry_run && return 0
    install -d "$(dirname -- "$file")"
    if [[ -f "$file" ]] && grep -qE "$pattern" "$file"; then
        sed -i -E "s|$pattern.*|$setting|" "$file"
    else
        printf '\n%s\n' "$setting" >> "$file"
    fi
}

if [[ "${XDG_CURRENT_DESKTOP:-}" != *KDE* && "${XDG_CURRENT_DESKTOP:-}" != *Plasma* ]]; then
    printf 'Warning: this does not appear to be a KDE Plasma session.\n' >&2
fi
if ! command -v plasmashell >/dev/null 2>&1; then
    printf 'KDE Plasma is required, but plasmashell was not found.\n' >&2
    exit 1
fi
if command -v systemctl >/dev/null 2>&1 \
        && systemctl --user show-environment >/dev/null 2>&1; then
    user_systemd=true
fi
plasma_version="$(plasmashell --version 2>/dev/null | grep -oE '[0-9]+' | head -1 || true)"
if [[ -n "$plasma_version" && "$plasma_version" -lt 6 ]]; then
    printf 'KDE Plasma 6 or newer is required (detected Plasma %s).\n' \
        "$plasma_version" >&2
    exit 1
fi
if ! $dry_run; then
    required_fonts=('NType 82 Headline')
    if $layout_only; then required_fonts+=('Inter'); fi
    for family in "${required_fonts[@]}"; do
        if ! command -v fc-match >/dev/null 2>&1 \
            || [[ "$(fc-match --format='%{family}' "$family")" != "$family" ]]; then
            printf 'Required local font family missing: %s.\nInstall ntype82-headline.otf locally; Inter is bundled with the full installer but must already be installed for --layout-only. Run fc-cache -f, then retry. See README.md: Local font prerequisite.\n' "$family" >&2
            exit 1
        fi
    done
    if ! appgrid_available="$(qdbus6 org.kde.plasmashell /PlasmaShell \
        org.kde.PlasmaShell.evaluateScript \
        'print(knownWidgetTypes.indexOf("dev.xarbit.appgrid") !== -1);')" \
        || [[ "$appgrid_available" != true ]]; then
        printf 'AppGrid (dev.xarbit.appgrid) must be available in the running Plasma session.\nInstall it from https://appgrid.xarbit.dev/#install, then log out and back in before rerunning.\n' >&2
        exit 1
    fi
fi
if ! $assume_yes && ! $dry_run; then
    printf 'This will replace the current Plasma panels and desktop widgets.\n'
    read -r -p 'Continue after creating a backup? [y/N] ' answer
    case "$answer" in y|Y|yes|YES) ;; *) printf 'Cancelled.\n'; exit 0 ;; esac
fi

printf '\n==> Backing up KDE configuration to %s\n' "$backup_dir"
run install -d "$backup_dir/config"
for file in kdeglobals kcminputrc kglobalshortcutsrc kscreenlockerrc kwinrc \
            plasmarc plasma-org.kde.plasma.desktop-appletsrc powerdevilrc \
            Trolltech.conf gtk-3.0/settings.ini gtk-4.0/settings.ini \
            xsettingsd/xsettingsd.conf plasma-workspace/env/nothing-mono-kde.sh \
            systemd/user/nothingos-edge-groups.service \
            autostart/nothingos-edge-groups.desktop fastfetch/config.jsonc \
            fastfetch/config.jsonc.before-nothingos; do
    if [[ -f "$config_home/$file" ]]; then
        run install -d "$backup_dir/config/$(dirname -- "$file")"
        run cp -a "$config_home/$file" "$backup_dir/config/$file"
    elif ! $dry_run; then
        printf '%s\n' "$file" >> "$backup_dir/absent-config"
    fi
done
if [[ -f "$HOME/.gtkrc-2.0" ]]; then
    run cp -a "$HOME/.gtkrc-2.0" "$backup_dir/gtk2rc"
fi

if $layout_only; then
    printf '\n==> Layout-only mode\n'
else
    if $install_packages; then
        printf '\n==> Installing build/runtime dependencies\n'
        install_dependencies
    fi

    printf '\n==> Installing themes, widgets, font, wallpaper and Fastfetch\n'
    copy_tree "$repo_dir/plasmoids" "$data_home/plasma/plasmoids"
    copy_tree "$repo_dir/theme/icons" "$data_home/icons"
    copy_tree "$repo_dir/theme/cursors" "$data_home/icons"
    copy_tree "$repo_dir/theme/plasma" "$data_home/plasma/desktoptheme"
    copy_tree "$repo_dir/theme/color-schemes" "$data_home/color-schemes"
    copy_tree "$repo_dir/kwin/effects" "$data_home/kwin/effects"
    copy_tree "$repo_dir/kwin/scripts" "$data_home/kwin/scripts"

    qt_qml_root="$(qmake6 -query QT_INSTALL_QML)"
    copy_tree "$qt_qml_root/org/kde/desktop" \
        "$install_root/qtquickcontrols/org/kde/desktop"
    run sed -i '/^prefer /d' \
        "$install_root/qtquickcontrols/org/kde/desktop/qmldir"
    run install -m 0644 \
        "$repo_dir/theme/qtquickcontrols/org/kde/desktop/Slider.qml" \
        "$install_root/qtquickcontrols/org/kde/desktop/Slider.qml"
    run install -m 0644 \
        "$repo_dir/theme/qtquickcontrols/org/kde/desktop/Switch.qml" \
        "$install_root/qtquickcontrols/org/kde/desktop/Switch.qml"

    run install -d "$config_home/plasma-workspace/env"
    if $dry_run; then
        printf '+ generate %q\n' \
            "$config_home/plasma-workspace/env/nothing-mono-kde.sh"
    else
        printf 'export QML_IMPORT_PATH=%q${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}\n' \
            "$install_root/qtquickcontrols" \
            > "$config_home/plasma-workspace/env/nothing-mono-kde.sh"
        printf '%s\n' 'export QT_QUICK_CONTROLS_STYLE=org.kde.desktop' \
            >> "$config_home/plasma-workspace/env/nothing-mono-kde.sh"
        printf 'export QT_PLUGIN_PATH=%q${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}\n' \
            "$HOME/.local/lib/qt6/plugins" \
            >> "$config_home/plasma-workspace/env/nothing-mono-kde.sh"
    fi

    run install -d "$data_home/fonts/NothingOS"
    copy_tree "$repo_dir/fonts/inter" "$data_home/fonts/Inter"
    run install -m 0644 "$repo_dir/fonts/ndot.ttf" \
        "$data_home/fonts/NothingOS/ndot.ttf"
    run install -d "$data_home/wallpapers/NothingOS-Airplane/contents/images"
    run install -m 0644 \
        "$repo_dir/assets/wallpaper/nothingos-airplane-5120x1440.jpg" \
        "$data_home/wallpapers/NothingOS-Airplane/contents/images/5120x1440.jpg"

    if $dry_run; then
        printf '+ %q/install-fastfetch.sh\n' "$repo_dir"
    else
        "$repo_dir/install-fastfetch.sh"
    fi
    run fc-cache -f

    printf '\n==> Building the targeted Dolphin style\n'
    build_dir="$repo_dir/native/dolphin-style/build"
    run cmake -S "$repo_dir/native/dolphin-style" -B "$build_dir" \
        -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF
    run cmake --build "$build_dir" --parallel
    run install -d "$HOME/.local/lib/qt6/plugins/styles"
    run install -m 0755 "$build_dir/nothingos-dolphin-style.so" \
        "$HOME/.local/lib/qt6/plugins/styles/nothingos-dolphin-style.so"

    printf '\n==> Building the independent widget edge controller\n'
    build_dir="$repo_dir/native/edge-groups/build"
    run cmake -S "$repo_dir/native/edge-groups" -B "$build_dir" \
        -DCMAKE_BUILD_TYPE=Release
    run cmake --build "$build_dir" --parallel
    run install -d "$HOME/.local/libexec"
    run install -m 0755 "$build_dir/nothingos-edge-groups" \
        "$HOME/.local/libexec/nothingos-edge-groups"
    run install -d "$config_home/systemd/user"
    run install -m 0644 "$repo_dir/systemd/nothingos-edge-groups.service" \
        "$config_home/systemd/user/nothingos-edge-groups.service"
    if ! $user_systemd; then
        run install -d "$config_home/autostart"
        if $dry_run; then
            printf '+ generate %q\n' \
                "$config_home/autostart/nothingos-edge-groups.desktop"
        else
            cat > "$config_home/autostart/nothingos-edge-groups.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=NothingOS widget edge groups
Exec=$HOME/.local/libexec/nothingos-edge-groups
OnlyShowIn=KDE;
X-KDE-autostart-after=panel
X-KDE-StartupNotify=false
EOF
        fi
    fi

    printf '\n==> Applying KDE and OLED-safe preferences\n'
    run kwriteconfig6 --file kdeglobals --group General --key ColorScheme \
        LetMinimalDark-Theme
    run kwriteconfig6 --file kdeglobals --group Icons --key Theme YAMIS
    run kwriteconfig6 --file kdeglobals --group KDE --key widgetStyle NothingDolphin
    run kwriteconfig6 --file kdeglobals --group KDE --key AnimationDurationFactor 1
    for role in font menuFont toolBarFont; do
        run kwriteconfig6 --notify --file kdeglobals --group General --key "$role" \
            'Inter,10,-1,5,50,0,0,0,0,0'
    done
    run kwriteconfig6 --notify --file kdeglobals --group General --key smallestReadableFont \
        'Inter,9,-1,5,50,0,0,0,0,0'
    run kwriteconfig6 --notify --file kdeglobals --group WM --key activeFont \
        'Inter,10,-1,5,50,0,0,0,0,0'
    run kwriteconfig6 --file Trolltech.conf --group qt --key font \
        'Inter,10,-1,5,50,0,0,0,0,0'
    run install -d "$config_home/gtk-3.0" "$config_home/gtk-4.0"
    for version in 3.0 4.0; do
        run kwriteconfig6 --file "$config_home/gtk-$version/settings.ini" \
            --group Settings --key gtk-font-name 'Inter 10'
    done
    set_font_line "$HOME/.gtkrc-2.0" '^[[:space:]]*gtk-font-name[[:space:]]*=' \
        'gtk-font-name="Inter 10"'
    set_font_line "$config_home/xsettingsd/xsettingsd.conf" '^[[:space:]]*Gtk/FontName[[:space:]]+' \
        'Gtk/FontName "Inter 10"'
    run kwriteconfig6 --file plasmarc --group Theme --key name \
        LetMinimalDark-Theme
    run kwriteconfig6 --file kcminputrc --group Mouse --key cursorTheme \
        We10XOS-cursors

    run kwriteconfig6 --file kwinrc --group Desktops --key Number 3
    run kwriteconfig6 --file kwinrc --group Desktops --key Rows 1
    run kwriteconfig6 --file kwinrc --group Effect-hidecursor \
        --key HideOnTyping --type bool false
    run kwriteconfig6 --file kwinrc --group Effect-hidecursor \
        --key InactivityDuration 15
    run kwriteconfig6 --file kwinrc --group Effect-slidingpopups \
        --key SlideInTime 500
    run kwriteconfig6 --file kwinrc --group Effect-slidingpopups \
        --key SlideOutTime 240
    for plugin in bouncingWindows slidingpopups hidecursor minimizeall nothingos-edge-groups; do
        run kwriteconfig6 --file kwinrc --group Plugins \
            --key "${plugin}Enabled" --type bool true
    done
    run kwriteconfig6 --file kwinrc --group Plugins \
        --key scaleEnabled --type bool false
    run kwriteconfig6 --file kwinrc --group Plugins \
        --key shapecornersEnabled --type bool false
    run kwriteconfig6 --file kwinrc --group Plugins \
        --key kwin4_effect_shapecornersEnabled --type bool false

    run kwriteconfig6 --file kglobalshortcutsrc --group kwin \
        --key MinimizeAll 'Meta+D,none,Minimize all windows'
    run kwriteconfig6 --file kglobalshortcutsrc --group kwin \
        --key 'Show Desktop' 'none,Meta+D,Peek at Desktop'

    run kwriteconfig6 --file powerdevilrc --group AC --group Display \
        --key TurnOffDisplayWhenIdle --type bool true
    run kwriteconfig6 --file powerdevilrc --group AC --group Display \
        --key TurnOffDisplayIdleTimeoutSec 60

    wallpaper_path="$data_home/wallpapers/NothingOS-Airplane/contents/images/5120x1440.jpg"
    wallpaper_uri="file://$wallpaper_path"
    run kwriteconfig6 --file kscreenlockerrc --group Greeter \
        --key WallpaperPlugin org.kde.image
    run kwriteconfig6 --file kscreenlockerrc --group Greeter --group Wallpaper \
        --group org.kde.image --group General --key Image "$wallpaper_uri"
    run kwriteconfig6 --file kscreenlockerrc --group Greeter --group Wallpaper \
        --group org.kde.image --group General --key PreviewImage "$wallpaper_uri"
fi

printf '\n==> Applying Plasma layout\n'
wallpaper_path="$data_home/wallpapers/NothingOS-Airplane/contents/images/5120x1440.jpg"
wallpaper_uri="file://$wallpaper_path"
run install -d "$install_root"
if $dry_run; then
    printf '+ render %q with wallpaper %q\n' "$repo_dir/layout/layout.js" "$wallpaper_uri"
else
    sed "s|__WALLPAPER_URI__|$wallpaper_uri|g" \
        "$repo_dir/layout/layout.js" > "$install_root/layout.js"
fi

if $dry_run; then
    printf '+ qdbus6 org.kde.plasmashell /PlasmaShell evaluateScript < layout.js\n'
else
    if ! qdbus6 org.kde.plasmashell /PlasmaShell \
        org.kde.PlasmaShell.evaluateScript \
        "$(cat "$install_root/layout.js")"; then
        printf 'Could not apply the live layout; log in to Plasma and rerun.\n' >&2
        exit 1
    fi
fi

if ! $layout_only; then
    if $user_systemd; then
        run systemctl --user daemon-reload
        run systemctl --user enable --now nothingos-edge-groups.service
    else
        printf 'systemd user services are unavailable; using KDE Autostart.\n'
        if ! $dry_run; then
            "$HOME/.local/libexec/nothingos-edge-groups" \
                >"$state_home/nothingos-edge-groups.log" 2>&1 &
        fi
    fi
    run qdbus6 org.kde.KWin /KWin reconfigure
fi

printf '\n==> Installing restore helper\n'
run install -d "$install_root"
if $dry_run; then
    printf '+ generate %q\n' "$install_root/restore-latest.sh"
else
    cat > "$install_root/restore-latest.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
backup_dir=$(printf '%q' "$backup_dir")
config_home=$(printf '%q' "$config_home")
home=$(printf '%q' "$HOME")
install -d "\$config_home"
cp -a "\$backup_dir/config/." "\$config_home/"
if [[ -f "\$backup_dir/absent-config" ]]; then
    while IFS= read -r file; do
        rm -f "\$config_home/\$file"
    done < "\$backup_dir/absent-config"
fi
if [[ -f "\$backup_dir/gtk2rc" ]]; then
    install -d "\$home"
    cp -a "\$backup_dir/gtk2rc" "\$home/.gtkrc-2.0"
else
    rm -f "\$home/.gtkrc-2.0"
fi
systemctl --user unset-environment QML_IMPORT_PATH QT_QUICK_CONTROLS_STYLE 2>/dev/null || true
qdbus6 org.kde.KWin /KWin reconfigure 2>/dev/null || true
systemctl --user restart plasma-plasmashell.service
printf 'Restored KDE configuration from %s\\n' "\$backup_dir"
printf 'Log out and back in, then reopen applications to reload the restored style and environment.\\n'
EOF
    chmod 0755 "$install_root/restore-latest.sh"
fi

printf '\nDone. Log out and back in once for a fully clean reload.\n'
printf 'Backup: %s\n' "$backup_dir"
printf 'Restore: %s/restore-latest.sh\n' "$install_root"
