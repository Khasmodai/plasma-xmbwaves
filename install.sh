#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

PLUGIN_ID="org.kde.plasma.xmbwaves"
VERT_SRC="shaders/xmb.vert"
VERT_OUT="package/contents/ui/shaders/xmb.vert.qsb"
FRAG_SRC="shaders/xmb.frag"
FRAG_OUT="package/contents/ui/shaders/xmb.frag.qsb"

# 1. Recompile vertex and fragment shaders with --qt6
QSB_BIN=""
for candidate in qsb-qt6 /usr/lib64/qt6/bin/qsb /usr/lib/qt6/bin/qsb qsb; do
    if command -v "$candidate" >/dev/null 2>&1; then
        QSB_BIN="$candidate"
        break
    fi
done

if [[ -n "$QSB_BIN" ]]; then
    echo "Compiling GPU shaders with $QSB_BIN --qt6..."
    mkdir -p "$(dirname "$FRAG_OUT")"
    "$QSB_BIN" --qt6 -b -o "$VERT_OUT" "$VERT_SRC"
    "$QSB_BIN" --qt6 -o "$FRAG_OUT" "$FRAG_SRC"
fi

# 2. Install or upgrade the Plasma 6 Wallpaper KPackage
if kpackagetool6 --type Plasma/Wallpaper --show "$PLUGIN_ID" >/dev/null 2>&1; then
    echo "Upgrading existing $PLUGIN_ID wallpaper plugin..."
    kpackagetool6 --type Plasma/Wallpaper --upgrade package
else
    echo "Installing $PLUGIN_ID wallpaper plugin..."
    kpackagetool6 --type Plasma/Wallpaper --install package
fi

# 3. Clear plasmashell QML cache and restart plasmashell so updated QML & shaders reload from disk
read -r -p "Clear plasmashell QML cache and restart plasmashell now? [y/N] " response
if [[ "$response" =~ ^[Yy]([Ee][Ss])?$ ]]; then
    rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}/plasmashell/qmlcache"
    if systemctl --user is-active plasma-plasmashell.service >/dev/null 2>&1; then
        echo "Restarting plasmashell to reload QML & shader cache..."
        systemctl --user restart plasma-plasmashell.service
    fi
    echo "Done! XMB Waves is installed and plasmashell has been reloaded."
else
    echo "Done! XMB Waves is installed (skipped QML cache clear & plasmashell restart)."
fi
