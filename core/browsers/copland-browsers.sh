#!/usr/bin/env bash
# Copland OS colours for every Chromium-based browser (needs sudo).
#
# Writes one policy file, BrowserThemeColor = Copland navy, into the policy
# folder of each Chromium family. The browser builds its whole palette from that
# one colour, for every profile, from the first launch. Folders are created even
# for browsers that are not installed yet, so a browser added later is covered too.
#
# Firefox needs nothing: it draws its toolbar from the GTK theme by default.
#
# It is a "managed" policy: users cannot change the browser theme while it is set.
#
#   ./copland-browsers.sh          install
#   ./copland-browsers.sh --undo   remove the policy files again
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
NAME=copland-theme.json
DIRS=(
    /etc/brave/policies/managed             # Brave
    /etc/chromium/policies/managed          # Chromium (Debian), Vivaldi reportedly reads this too
    /etc/chromium-browser/policies/managed  # Chromium (Ubuntu builds)
    /etc/opt/chrome/policies/managed        # Google Chrome
    /etc/opt/edge/policies/managed          # Microsoft Edge
)

install() {
    [ -f "$HERE/$NAME" ] || { echo "missing: $HERE/$NAME"; exit 1; }
    local d
    for d in "${DIRS[@]}"; do
        sudo install -d -m 755 "$d"
        sudo install -m 644 -o root -g root "$HERE/$NAME" "$d/$NAME"
        echo "  $d/$NAME"
    done
    echo "Done. Restart your browsers; check with brave://policy or chrome://policy."
}

undo() {
    local d
    for d in "${DIRS[@]}"; do
        [ -f "$d/$NAME" ] && sudo rm -f "$d/$NAME" && echo "  removed $d/$NAME"
        # remove the folders again only if nothing else lives in them
        sudo rmdir -p --ignore-fail-on-non-empty "$d" 2>/dev/null || true
    done
    echo "Done. Restart your browsers."
}

case "${1:-}" in
    --undo) undo ;;
    "")     install ;;
    *)      sed -n 2,15p "$0"; exit 2 ;;
esac
