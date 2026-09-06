#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
upstream=https://github.com/xarbit/plasma6-applet-appgrid.git
commit=7843b094d6a2f1b7f9d02df1f67fa5f1fd0a7053
tag=v1.9.3
patch="$repo_dir/patches/appgrid-panel-input.patch"
plugin_root="$HOME/.local/lib/qt6/plugins"
destination="$plugin_root/plasma/applets/dev.xarbit.appgrid.so"
dry_run=false
for arg in "$@"; do
    case "$arg" in
        --dry-run) dry_run=true ;;
        --help|-h) printf 'Usage: ./install-appgrid-fix.sh [--dry-run]\n'; exit 0 ;;
        *) printf 'Unknown option: %s\n' "$arg" >&2; exit 2 ;;
    esac
done

fail() { printf '%s\n' "$*" >&2; exit 1; }
run() {
    printf '+'
    printf ' %q' "$@"
    printf '\n'
    if ! $dry_run; then "$@"; fi
}

# Dry-run is an offline plan: no probing Plasma, downloads, or filesystem changes.
workspace='<fresh-temporary-directory>'
staged=''
if ! $dry_run; then
    for command in git cmake qdbus6; do
        command -v "$command" >/dev/null || fail "Missing $command. See README.md: AppGrid panel input fix."
    done
    [[ -s "$patch" ]] || fail "Missing patch: $patch"
    [[ -f "$destination" && ! -L "$destination" ]] || fail \
        "Install the official user-local AppGrid first: https://appgrid.xarbit.dev/#install (expected regular file $destination)."
    case ":${QT_PLUGIN_PATH:-}:" in
        *":$plugin_root:"*) ;;
        *) fail "QT_PLUGIN_PATH must already include $plugin_root. Follow upstream user-local setup, then log out and back in; this script does not change your environment." ;;
    esac
    if ! available="$(qdbus6 org.kde.plasmashell /PlasmaShell \
        org.kde.PlasmaShell.evaluateScript \
        'print(knownWidgetTypes.indexOf("dev.xarbit.appgrid") !== -1);')" \
        || [[ "$available" != true ]]; then
        fail 'AppGrid must be available in the running Plasma session. Install it upstream, then log out and back in.'
    fi
    workspace="$(mktemp -d "${TMPDIR:-/tmp}/appgrid-panel-input.XXXXXXXX")"
    trap '[[ -z "$staged" ]] || rm -f -- "$staged"; rm -rf -- "$workspace"' EXIT
else
    printf 'Would require existing user-local AppGrid, its QT_PLUGIN_PATH, and discovery in the running Plasma session.\n'
fi

run git clone --depth 1 --branch "$tag" -- "$upstream" "$workspace/source"
if ! $dry_run; then
    [[ "$(git -C "$workspace/source" rev-parse HEAD)" == "$commit" ]] \
        || fail "Upstream $tag does not match pinned commit $commit; refusing to build."
else
    printf 'Would verify HEAD equals %s before applying the patch.\n' "$commit"
fi
run git -C "$workspace/source" apply --check "$patch"
run git -C "$workspace/source" apply "$patch"
run cmake -S "$workspace/source" -B "$workspace/build" \
    -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF \
    -DAPPGRID_UNIVERSAL_BUILD=ON -DAPPGRID_VERSION_OVERRIDE=1.9.3+panel-input-fix \
    || fail 'CMake configuration failed. Install the missing development dependencies listed above; see https://appgrid.xarbit.dev/docs/#dependencies-per-distro .'
run cmake --build "$workspace/build" --target dev.xarbit.appgrid --parallel
binary="$workspace/build/bin/plasma/applets/dev.xarbit.appgrid.so"
if ! $dry_run; then
    [[ -s "$binary" ]] || fail "Build did not produce $binary"
    # Back up before replacing; stage on the same filesystem so rename is atomic.
    backup_root="${XDG_STATE_HOME:-$HOME/.local/state}/nothingos-kde-rice/backups"
    install -d -- "$backup_root"
    backup="$(mktemp -d "$backup_root/appgrid.XXXXXXXX")/dev.xarbit.appgrid.so"
    cp -p -- "$destination" "$backup"
    staged="$(mktemp "${destination%/*}/.dev.xarbit.appgrid.so.new.XXXXXXXX")"
    install -m 0755 -- "$binary" "$staged"
    mv -fT -- "$staged" "$destination"
    staged=''
    printf 'Installed 1.9.3+panel-input-fix. Previous binary: %s\n' "$backup"
else
    printf 'Would back up %s under %s/nothingos-kde-rice/backups/appgrid.<unique suffix>/, then install %s via a hidden same-directory staging file and atomic rename.\n' "$destination" "${XDG_STATE_HOME:-$HOME/.local/state}" "$binary"
fi
printf '\nNo Plasma restart was performed. Log out and back in to load the binary.\n'
printf 'Or, in an existing systemd-managed Plasma session: systemctl --user restart plasma-plasmashell.service\n'
printf 'Do not rerun the full theme installer. AppGrid updates can overwrite this local fix; see README.md before rebuilding.\n'
