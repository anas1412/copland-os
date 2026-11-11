#!/usr/bin/env bash
# Copland OS boot and console look (needs sudo):
#  - boot animation fills the screen (no black bars)
#  - Copland GRUB theme; the menu says "Copland OS Enterprise" instead of Debian
#  - text console (TTYs, and the boot log behind Esc) in Copland colours, Terminus font
#
#   ./copland-boot.sh          install all of it
#   ./copland-boot.sh --undo   put everything back
#
# Needs the Copland boot animation already installed (the installer's "boot" step):
# its first frame is reused as the GRUB background, so no artwork is stored here.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PLY=/usr/share/plymouth/themes/copland
THEME_DIR=/boot/grub/themes/copland
GRUB=/etc/default/grub
CONSOLE=/etc/default/console-setup

# Copland palette for the text console: background, then the terminal's 15 colours
VT_RED=16,224,95,230,25,154,70,204,74,255,138,245,90,184,143,255
VT_GRN=24,80,215,210,122,124,186,221,92,112,240,230,168,160,214,255
VT_BLU=56,122,167,138,186,240,239,255,154,150,200,168,232,255,250,255

rebuild() {
    sudo update-initramfs -u -k all      # animation and console font live in the initramfs
    local log; log=$(mktemp)
    sudo update-grub 2>&1 | tee "$log"
    grep -q 'Found theme' "$log" || echo "NOTE: update-grub did not report a theme"
    rm -f "$log"
}

install() {
    [ -f "$PLY/copland.plymouth" ] || { echo "Copland boot animation is not installed ($PLY)"; exit 1; }
    for f in plymouth/script.script grub/copland/theme.txt; do
        [ -f "$HERE/$f" ] || { echo "missing: $HERE/$f"; exit 1; }
    done
    command -v grub-mkfont >/dev/null || { echo "grub-mkfont not found"; exit 1; }

    # build the GRUB fonts and background in a temp folder first (no root needed)
    local tmp; tmp=$(mktemp -d)
    cp "$HERE"/grub/copland/* "$tmp"/
    cp "$PLY/progress-1.png" "$tmp/background.png"
    grub-mkfont -s 26 -o "$tmp/c059-26.pf2" /usr/share/fonts/opentype/urw-base35/C059-BdIta.otf 2>/dev/null
    grub-mkfont -s 14 -o "$tmp/mono-14.pf2" /usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf 2>/dev/null

    # 1. boot animation: keep the original script once, then put ours in
    [ -f "$PLY/script.script.orig" ] || sudo cp -a "$PLY/script.script" "$PLY/script.script.orig"
    sudo install -m 644 -o root -g root "$HERE/plymouth/script.script" "$PLY/script.script"

    # 2. GRUB theme
    sudo rm -rf "$THEME_DIR"
    sudo install -d -m 755 "$THEME_DIR"
    sudo install -m 644 -o root -g root "$tmp"/* "$THEME_DIR"/
    rm -rf "$tmp"

    # 3. console font
    [ -f "$CONSOLE.copland-bak" ] || sudo cp -a "$CONSOLE" "$CONSOLE.copland-bak"
    sudo sed -i -E 's/^FONTFACE=.*/FONTFACE="Terminus"/; s/^FONTSIZE=.*/FONTSIZE="10x20"/' "$CONSOLE"

    # 4. /etc/default/grub: back up once, then (re)write our block at the end.
    #    Later lines win, so Debian's own lines stay untouched.
    [ -f "$GRUB.copland-boot-bak" ] || sudo cp -a "$GRUB" "$GRUB.copland-boot-bak"
    sudo sed -i '/^# copland-boot-begin$/,/^# copland-boot-end$/d' "$GRUB"
    printf '%s\n' '# copland-boot-begin' \
        'GRUB_DISTRIBUTOR="Copland OS Enterprise"' \
        "GRUB_THEME=$THEME_DIR/theme.txt" \
        "GRUB_BACKGROUND=$THEME_DIR/background.png" \
        "GRUB_CMDLINE_LINUX_DEFAULT=\"\$GRUB_CMDLINE_LINUX_DEFAULT vt.default_red=$VT_RED vt.default_grn=$VT_GRN vt.default_blu=$VT_BLU\"" \
        '# copland-boot-end' | sudo tee -a "$GRUB" >/dev/null

    rebuild
    echo "Done. All of it shows on the next reboot."
}

undo() {
    [ -f "$PLY/script.script.orig" ] && sudo cp -a "$PLY/script.script.orig" "$PLY/script.script"
    [ -f "$CONSOLE.copland-bak" ] && sudo cp -a "$CONSOLE.copland-bak" "$CONSOLE"
    sudo sed -i '/^# copland-boot-begin$/,/^# copland-boot-end$/d' "$GRUB"
    sudo rm -rf "$THEME_DIR"
    rebuild || true
    echo "Undone: original animation, Debian GRUB look, stock console."
}

case "${1:-}" in
    --undo) undo ;;
    "")     install ;;
    *)      sed -n 2,12p "$0"; exit 2 ;;
esac
