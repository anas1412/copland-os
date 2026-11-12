# shellcheck shell=bash
# Copland OS installer: system-wide mode (--system), used on a real machine and by the ISO build.
# Sourced by install.sh; not meant to be run on its own.
#
# Everything goes to shared places, never into a user's home:
#   /usr/share/{themes,icons,backgrounds}, /usr/local/bin, /usr/share/applications
#   /etc/xdg/copland-os/...           XFCE defaults (generated from core/settings.tsv)
#   /etc/X11/Xsession.d/55copland-os  puts /etc/xdg/copland-os first in XDG_CONFIG_DIRS
#   /etc/skel/...                     per-user files for accounts created from now on
#   /etc/lightdm/...conf.d/           login screen and default session, as drop-ins
#   /etc/default/grub.d/copland.cfg   boot menu look and splash
# Files owned by Debian packages are not edited, except where noted (diversions are used
# for the two files we replace). Every file written is listed in the manifest, so
# --system --uninstall can take it out again.
#
# --root DIR writes under DIR instead of / (the ISO build uses --root / inside its chroot;
# tests use a temporary folder). --no-rebuild skips initramfs and GRUB regeneration.

SYS_XDG=/etc/xdg/copland-os
SYS_THEME=/usr/share/themes/CoplandOS
# helpers go to /usr/local/bin for a local install; the Debian package sets
# COPLAND_SYS_BIN=/usr/bin (packages may not install into /usr/local)
SYS_BIN="${COPLAND_SYS_BIN:-/usr/local/bin}"
SYS_WALL=/usr/share/backgrounds/CoplandOS.png
SYS_STATE=/var/lib/copland-os
GRUB_THEME_DIR=/boot/grub/themes/copland
PLY_DIR=/usr/share/plymouth/themes/copland
BROWSER_POLICY_DIRS=(/etc/brave/policies/managed /etc/chromium/policies/managed
    /etc/chromium-browser/policies/managed /etc/opt/chrome/policies/managed /etc/opt/edge/policies/managed)

# TGT is the target root without a trailing slash: "" for /, "/tmp/x" for --root /tmp/x
TGT=""
MANIFEST=""

# ------------------------------------------------------------------ helpers
as_root() { [ "$EUID" -eq 0 ]; }
on_live_root() { [ -z "$TGT" ]; }

# record PATH (as seen on the target system) in the manifest
record() {
    [ "$DRY" -eq 1 ] && return 0
    printf '%s\n' "$1" >> "$MANIFEST"
}

# put_file MODE SRC DEST: install one file, owned by root when we are root
put_file() {
    local mode=$1 src=$2 dest=$3
    run install -D -m "$mode" "$src" "$TGT$dest"
    as_root && [ "$DRY" -eq 0 ] && chown root:root "$TGT$dest"
    record "$dest"
}

# put_text MODE DEST: write stdin to a file
put_text() {
    local mode=$1 dest=$2
    if [ "$DRY" -eq 1 ]; then
        printf '      %s[dry-run]%s write %s\n' "$DM" "$R" "$TGT$dest"; cat >/dev/null; return 0
    fi
    install -d -m 755 "$(dirname "$TGT$dest")"
    cat > "$TGT$dest"
    chmod "$mode" "$TGT$dest"
    as_root && chown root:root "$TGT$dest"
    record "$dest"
}

# put_tree SRC DEST: replace folder DEST with a copy of SRC (root-owned, not group-writable)
put_tree() {
    local src=$1 dest=$2 f
    run rm -rf "$TGT$dest"
    run install -d -m 755 "$(dirname "$TGT$dest")"
    run cp -a "$src" "$TGT$dest"
    if [ "$DRY" -eq 0 ]; then
        as_root && chown -R root:root "$TGT$dest"
        chmod -R go-w "$TGT$dest"
        while IFS= read -r f; do record "${f#$TGT}"; done < <(find "$TGT$dest" \( -type f -o -type l \))
        record "$dest/"
    fi
}

# divert PATH NEWNAME: move a packaged file aside (dpkg keeps installing it there on upgrades)
divert() {
    local path=$1 to=$2
    if [ -n "$TGT" ] && [ ! -d "$TGT/var/lib/dpkg" ]; then
        echo "no dpkg database under $TGT: not diverting $path"; return 0
    fi
    have dpkg-divert || { echo "dpkg-divert not found: not diverting $path"; return 0; }
    local rootopt=()
    [ -n "$TGT" ] && rootopt=(--root "$TGT")
    if dpkg-divert "${rootopt[@]}" --list "$path" 2>/dev/null | grep -q .; then return 0; fi
    run dpkg-divert "${rootopt[@]}" --local --rename --divert "$to" --add "$path"
    record "divert:$path"
}

# ------------------------------------------------------------------ preflight
preflight_system() {
    [ "${BASH_VERSINFO[0]}" -ge 4 ] || die "bash 4 or newer is required."
    local f
    for f in assets/themes/CoplandOS/gtk-3.0/gtk.css assets/backgrounds/CoplandOS.png assets/icons/NineIcons/index.theme \
             "assets/cursors/$CURSOR_THEME/index.theme" settings.tsv config/fastfetch/config.jsonc \
             bin/copland-goto bin/copland-send bin/copland-extras; do
        [ -e "$CORE/$f" ] || die "The Copland OS folder is incomplete: core/$f is missing."
    done
    [ -x "$SRC/tools/xfconf-xml.py" ] || die "tools/xfconf-xml.py is missing."
    have python3 || die "python3 is required to write the XFCE defaults."
    if on_live_root && [ "$DRY" -eq 0 ]; then
        as_root || die "--system writes to /usr and /etc: run it with sudo (sudo ./install.sh --system)."
    fi
    if [ -n "$TGT" ] && [ ! -d "$TGT" ]; then die "--root $TGT does not exist."; fi
    local like=""
    [ -r "$TGT/etc/os-release" ] && like="$(. "$TGT/etc/os-release"; echo "${ID:-} ${ID_LIKE:-}")"
    case " $like " in
        *" debian "*|*" ubuntu "*) ;;
        *) [ -n "$TGT" ] && [ -z "$like" ] || warn "--system supports Debian-based systems only (found: ${like:-unknown})." ;;
    esac
}

# ------------------------------------------------------------------ components
sys_packages() {
    on_live_root || skip "not installing packages into --root $TGT (the ISO build installs them itself)"
    [ "$NO_PACKAGES" -eq 1 ] && skip "--no-packages given"
    have apt-get || skip "apt-get not found"
    local p missing=()
    for p in "${PACKAGES[@]}"; do pkg_installed "$p" || missing+=("$p"); done
    [ "${#missing[@]}" -eq 0 ] && { note "all ${#PACKAGES[@]} packages already installed"; return 0; }
    run apt-get update -q || echo "apt-get update failed; continuing with the current package lists"
    run env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${missing[@]}"
    note "installed ${#missing[@]} packages"
}

# GNOME-side defaults (org.gnome.desktop.interface) for every account, the same values
# the per-user installer sets with gsettings. Firefox and other GTK apps read them: without
# color-scheme=prefer-dark Firefox picks its light look even under a dark GTK theme.
# An override file in /usr/share/glib-2.0/schemas; Debian's libglib trigger recompiles the
# schemas when a package installs or removes one, so only a direct --system run compiles.
schema_default() {
    local name=$1
    put_text 644 "/usr/share/glib-2.0/schemas/50_copland-os-$name.gschema.override"
    if on_live_root && have glib-compile-schemas; then run glib-compile-schemas /usr/share/glib-2.0/schemas || true; fi
}

sys_theme() {
    put_tree "$ASSETS/themes/CoplandOS" "$SYS_THEME"
    schema_default theme <<'EOF'
[org.gnome.desktop.interface]
gtk-theme='CoplandOS'
color-scheme='prefer-dark'
font-name='Nimbus Sans 10'
EOF
}

sys_icons() {
    put_tree "$ASSETS/icons/NineIcons" /usr/share/icons/NineIcons
    if on_live_root && have gtk-update-icon-cache; then run gtk-update-icon-cache -f -q /usr/share/icons/NineIcons || true; fi
    schema_default icons <<'EOF'
[org.gnome.desktop.interface]
icon-theme='NineIcons'
EOF
}

sys_cursors() {
    put_tree "$ASSETS/cursors/$CURSOR_THEME" "/usr/share/icons/$CURSOR_THEME"
    schema_default cursors <<EOF
[org.gnome.desktop.interface]
cursor-theme='$CURSOR_THEME'
cursor-size=24
EOF
}

sys_wallpaper() {
    put_file 644 "$ASSETS/backgrounds/CoplandOS.png" "$SYS_WALL"
    # xfdesktop shows /usr/share/backgrounds/xfce/xfce-x.svg on any monitor that has no
    # wallpaper set yet (it ignores desktop-base's alternative), so ours takes its place
    divert /usr/share/backgrounds/xfce/xfce-x.svg /usr/share/backgrounds/xfce/xfce-x.svg.debian
    run install -d -m 755 "$TGT/usr/share/backgrounds/xfce"
    run ln -sfn "$SYS_WALL" "$TGT/usr/share/backgrounds/xfce/xfce-x.svg"
    record /usr/share/backgrounds/xfce/xfce-x.svg
}

sys_panel() {
    # the menu shows each user's picture (~/.face): new users start with the Copland logo
    set_face
    note "the bar is applied to users who log in to XFCE for the first time"
}

sys_terminal() {
    put_file 644 "$CONFIG/fastfetch/config.jsonc" /etc/skel/.config/fastfetch/config.jsonc
    # the version fastfetch shows on its first line (the package and the ISO ship it too)
    printf '%s\n' "$(copland_version)" | put_text 644 /usr/share/copland-os/version
    # btop: the theme in btop's own system folder (every account can pick it), the
    # settings for new accounts
    put_file 644 "$CONFIG/btop/copland.theme" /usr/share/btop/themes/copland.theme
    put_file 644 "$CONFIG/btop/btop.conf" /etc/skel/.config/btop/btop.conf
    put_text 644 /etc/copland-os/bashrc <<'EOF'
# Copland OS: show fastfetch in new interactive terminals (sourced from ~/.bashrc)
if [[ $- == *i* ]] && [ -z "${CLAUDECODE:-}" ] && command -v fastfetch >/dev/null; then
    fastfetch
fi
EOF
    local skel="$TGT/etc/skel/.bashrc"
    if [ -f "$skel" ] && ! grep -q '^# >>> copland-os >>>$' "$skel"; then
        if [ "$DRY" -eq 1 ]; then
            printf '      %s[dry-run]%s append copland-os block to %s\n' "$DM" "$R" "$skel"
        else
            printf '# >>> copland-os >>>\n[ -r /etc/copland-os/bashrc ] && . /etc/copland-os/bashrc\n# <<< copland-os <<<\n' >> "$skel"
            record "block:/etc/skel/.bashrc"
        fi
    fi
}

sys_layers() {
    # the four named workspaces are XFCE defaults, written by sys_xdg from settings.tsv.
    # Earlier versions also sorted apps into layers with devilspie2: remove those files.
    local f
    for f in /etc/xdg/autostart/copland-devilspie2.desktop /etc/skel/.config/devilspie2/layers.lua \
             /etc/copland-os/layers.conf /usr/share/applications/copland-layers.desktop \
             /usr/local/bin/copland-layers /usr/bin/copland-layers; do
        [ -e "$TGT$f" ] || continue
        run rm -f "$TGT$f"
        if [ "$DRY" -eq 0 ] && [ -f "$MANIFEST" ]; then
            grep -vxF "$f" "$MANIFEST" > "$MANIFEST.tmp" || true
            mv "$MANIFEST.tmp" "$MANIFEST"
        fi
    done
    [ "$DRY" -eq 0 ] && [ -d "$TGT/etc/skel/.config/devilspie2" ] && rmdir "$TGT/etc/skel/.config/devilspie2" 2>/dev/null
    note "Layer:01-04 are set with the other XFCE defaults"
}

sys_keys() {
    put_file 755 "$BINSRC/copland-goto" "$SYS_BIN/copland-goto"
    put_file 755 "$BINSRC/copland-send" "$SYS_BIN/copland-send"
}

sys_browsers() {
    local d
    for d in "${BROWSER_POLICY_DIRS[@]}"; do
        put_file 644 "$CORE/browsers/copland-theme.json" "$d/copland-theme.json"
    done
    # optional apps and developer tools, themed (the ISO's installer pages use it too)
    put_file 755 "$BINSRC/copland-extras" "$SYS_BIN/copland-extras"
    note "Chromium-family browsers get the Copland colour; Firefox follows the GTK theme"
    note "More apps and developer tools, in the Copland look: sudo copland-extras --list"
}

sys_greeter() {
    local cursor icons
    cursor="$CURSOR_THEME"; icons=NineIcons
    # its own picture: navy, the logo above the box, the name below (tools/artwork.py)
    put_file 644 "$ASSETS/backgrounds/CoplandOS-login.png" /usr/share/backgrounds/CoplandOS-login.png
    put_text 644 /etc/lightdm/lightdm-gtk-greeter.conf.d/50-copland.conf <<EOF
# Copland OS login screen (read after Debian's 01_debian.conf, so these win)
[greeter]
theme-name = CoplandOS
icon-theme-name = $icons
cursor-theme-name = $cursor
cursor-theme-size = 24
background = /usr/share/backgrounds/CoplandOS-login.png
user-background = false
font-name = C059 Bold Italic 11
clock-format = %a %d %b  %H:%M
EOF
    # the main file is read last and wins: drop the block older installers put there
    remove_old_greeter_block
    # XFCE 4.20's Wayland session needs a compositor Debian does not install by default:
    # log in to X11, and hide the Wayland entry so it cannot be picked by mistake
    put_text 644 /etc/lightdm/lightdm.conf.d/50-copland.conf <<'EOF'
# Copland OS: start the X11 XFCE session by default
[Seat:*]
user-session=xfce
EOF
    if [ -e "$TGT/usr/share/wayland-sessions/xfce-wayland.desktop" ]; then
        divert /usr/share/wayland-sessions/xfce-wayland.desktop /usr/share/wayland-sessions/xfce-wayland.desktop.copland-hidden
    fi
}

remove_old_greeter_block() {
    local conf="$TGT$GREETER"
    [ -f "$conf" ] && grep -q '^# copland-begin$' "$conf" || return 0
    if [ "$DRY" -eq 1 ]; then
        printf '      %s[dry-run]%s remove the copland block from %s\n' "$DM" "$R" "$conf"; return 0
    fi
    sed -i '/^# copland-begin$/,/^# copland-end$/d' "$conf"
    echo "removed the old copland block from $GREETER"
}

# automatic login belongs to one account: not part of a system-wide install
sys_autologin() {
    skip "per account: run ./install.sh --only autologin as the user who should log in"
}

sys_boot() {
    local src="${COPLAND_PLYMOUTH_SRC:-}" tmp=""
    if [ -z "$src" ]; then
        have git || skip "git is not installed (needed to fetch the boot animation)"
        tmp="$(mktemp -d)"
        run git clone -q "$PLYMOUTH_REPO" "$tmp/repo"
        run git -C "$tmp/repo" -c advice.detachedHead=false checkout -q "$PLYMOUTH_COMMIT"
        src="$tmp/repo/copland"
    fi
    if [ "$DRY" -eq 0 ]; then
        [ -f "$src/copland.plymouth" ] || { [ -n "$tmp" ] && rm -rf "$tmp"; echo "no copland.plymouth in $src"; exit 1; }
    fi
    put_tree "$src" "$PLY_DIR"
    [ -n "$tmp" ] && rm -rf "$tmp"
    # full-screen version of the animation script (frames scaled to cover any screen)
    if [ -f "$CORE/boot/plymouth/script.script" ]; then
        put_file 644 "$CORE/boot/plymouth/script.script" "$PLY_DIR/script.script"
    fi
    # Plymouth's own tool sets the theme (/etc/plymouth/plymouthd.conf belongs to the package)
    if on_live_root && [ -x /usr/sbin/plymouth-set-default-theme ]; then
        local prev
        prev="$(/usr/sbin/plymouth-set-default-theme 2>/dev/null || true)"
        if [ "$DRY" -eq 0 ] && [ -n "$prev" ] && [ "$prev" != copland ]; then
            install -d -m 755 "$TGT$SYS_STATE"; printf '%s\n' "$prev" > "$TGT$SYS_STATE/previous-plymouth-theme"
        fi
        run /usr/sbin/plymouth-set-default-theme copland
        record "plymouth:copland"
    else
        echo "plymouth-set-default-theme not available here: set the theme with it after installing plymouth"
    fi
    write_grub_dropin
    set_console_font
    set_issue
    if on_live_root && [ "$NO_REBUILD" -eq 0 ]; then
        have update-initramfs && run update-initramfs -u -k all
        have update-grub && run update-grub
        note "installed; it shows on the next reboot"
    else
        note "installed; initramfs and GRUB are rebuilt later (--no-rebuild or --root)"
    fi
}

# text console (TTYs and the boot log) in Terminus 10x20; console-setup re-applies it at
# boot because the file is newer than its cache, so no initramfs step is needed
set_console_font() {
    local f="$TGT/etc/default/console-setup"
    [ -f "$f" ] || { echo "no /etc/default/console-setup: console font unchanged"; return 0; }
    if [ "$DRY" -eq 1 ]; then
        printf '      %s[dry-run]%s set FONTFACE=Terminus FONTSIZE=10x20 in %s\n' "$DM" "$R" "$f"; return 0
    fi
    install -d -m 755 "$TGT$SYS_STATE"
    [ -f "$TGT$SYS_STATE/console-setup.orig" ] || cp -a "$f" "$TGT$SYS_STATE/console-setup.orig"
    sed -i -E 's/^FONTFACE=.*/FONTFACE="Terminus"/; s/^FONTSIZE=.*/FONTSIZE="10x20"/' "$f"
    grep -q '^FONTFACE=' "$f" || printf 'FONTFACE="Terminus"\n' >> "$f"
    grep -q '^FONTSIZE=' "$f" || printf 'FONTSIZE="10x20"\n' >> "$f"
    record "console:/etc/default/console-setup"
}

# text console login line: "Copland OS Enterprise (Debian 13) <host> tty1". The Debian
# number is agetty's \S{VERSION_ID}, read from os-release at each login, so it stays right
# after a release upgrade. /etc/issue belongs to base-files (a conffile): the original is
# kept for --uninstall, and dpkg asks about the file when base-files ships a new one.
# /etc/os-release is never changed: apt, the installer and lib/common.sh read ID from it.
set_issue() {
    local f="$TGT/etc/issue"
    [ -f "$f" ] || { echo "no /etc/issue: console login text unchanged"; return 0; }
    if [ "$DRY" -eq 1 ]; then
        printf '      %s[dry-run]%s write the Copland login line to %s\n' "$DM" "$R" "$f"; return 0
    fi
    install -d -m 755 "$TGT$SYS_STATE"
    [ -f "$TGT$SYS_STATE/issue.orig" ] || cp -a "$f" "$TGT$SYS_STATE/issue.orig"
    cat "$CONFIG/issue" > "$f"
    record "issue:/etc/issue"
}

# /etc/skel/.face, the picture new accounts start with. On Debian it is a configuration
# file of desktop-base, which may not be diverted: keep the original for --uninstall,
# as with /etc/issue. The Debian package does not ship it for the same reason.
set_face() {
    local f="$TGT/etc/skel/.face" src="$ASSETS/themes/CoplandOS/assets/copland-logo-128.png"
    if [ "$DRY" -eq 1 ]; then
        printf '      %s[dry-run]%s copy the Copland logo to %s\n' "$DM" "$R" "$f"; return 0
    fi
    install -d -m 755 "$TGT$SYS_STATE" "$(dirname "$f")"
    [ -f "$f" ] && [ ! -f "$TGT$SYS_STATE/face.orig" ] && cp -a "$f" "$TGT$SYS_STATE/face.orig"
    install -m 644 "$src" "$f"
    record "face:/etc/skel/.face"
}

# /etc/default/grub.d/copland.cfg: splash, Copland name and theme, console colours
write_grub_dropin() {
    local theme_line="" vt
    vt='vt.default_red=16,224,95,230,25,154,70,204,74,255,138,245,90,184,143,255'
    vt="$vt vt.default_grn=24,80,215,210,122,124,186,221,92,112,240,230,168,160,214,255"
    vt="$vt vt.default_blu=56,122,167,138,186,240,239,255,154,150,200,168,232,255,250,255"
    if build_grub_theme; then
        theme_line="GRUB_THEME=$GRUB_THEME_DIR/theme.txt
GRUB_BACKGROUND=$GRUB_THEME_DIR/background.png"
    fi
    put_text 644 /etc/default/grub.d/copland.cfg <<EOF
# Copland OS boot menu and boot screen (Debian's /etc/default/grub stays untouched)
GRUB_DISTRIBUTOR="Copland OS Enterprise"
# One resolution from the menu to the desktop: "auto" is the screen's own preferred
# mode (from its EDID; 800x600 if the firmware gives none), and "keep" hands that same
# mode to Linux instead of setting it again, so the boot animation starts without a
# mode change
GRUB_GFXMODE=auto
GRUB_GFXPAYLOAD_LINUX=keep
GRUB_CMDLINE_LINUX_DEFAULT="\$GRUB_CMDLINE_LINUX_DEFAULT splash $vt"
$theme_line
EOF
}

# GRUB theme from core/boot/grub/copland, with fonts made by grub-mkfont and the
# animation's first frame as background. Returns 1 (no theme) when a piece is missing.
build_grub_theme() {
    local g="$CORE/boot/grub/copland" fonts=1
    [ -f "$g/theme.txt" ] || { echo "no GRUB theme in core/boot/grub/copland"; return 1; }
    if [ "$DRY" -eq 1 ]; then
        printf '      %s[dry-run]%s build GRUB theme into %s\n' "$DM" "$R" "$TGT$GRUB_THEME_DIR"; return 0
    fi
    have grub-mkfont || { echo "grub-mkfont not found: boot menu keeps Debian's look"; return 1; }
    local tmp; tmp="$(mktemp -d)"
    # background.png is the-blue-spyduck's orb on black, made by tools/artwork.py
    cp "$g"/* "$tmp"/
    # fonts from the target, or from this machine when building into a staging folder
    local c059=/usr/share/fonts/opentype/urw-base35/C059-BdIta.otf mono=/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf
    [ -f "$TGT$c059" ] && c059="$TGT$c059"
    [ -f "$TGT$mono" ] && mono="$TGT$mono"
    grub-mkfont -s 26 -o "$tmp/c059-26.pf2" "$c059" 2>/dev/null || fonts=0
    grub-mkfont -s 14 -o "$tmp/mono-14.pf2" "$mono" 2>/dev/null || fonts=0
    [ "$fonts" -eq 1 ] || echo "a GRUB font could not be built; the theme falls back to GRUB's font"
    rm -rf "$TGT$GRUB_THEME_DIR"
    install -d -m 755 "$TGT$GRUB_THEME_DIR"
    install -m 644 "$tmp"/* "$TGT$GRUB_THEME_DIR"/
    rm -rf "$tmp"
    local f
    for f in "$TGT$GRUB_THEME_DIR"/*; do record "${f#$TGT}"; done
    record "$GRUB_THEME_DIR/"
    return 0
}

# always last: XFCE defaults for every selected component, and the search path for them
sys_xdg() {
    local comps="" id
    for id in "${SEL_SYS[@]}"; do comps="$comps,$id"; done
    if [ "$DRY" -eq 1 ]; then
        printf '      %s[dry-run]%s tools/xfconf-xml.py -> %s (components%s)\n' "$DM" "$R" "$TGT$SYS_XDG" "${comps//,/ }"
    else
        rm -rf "$TGT$SYS_XDG"
        local f
        while IFS= read -r f; do record "${f#$TGT}"; done < <(python3 -I "$SRC/tools/xfconf-xml.py" "$CORE/settings.tsv" \
            "$TGT$SYS_XDG" --theme "$SYS_THEME" --bin "$SYS_BIN" --components "${comps#,}")
        record "$SYS_XDG/"
    fi
    put_text 644 /etc/X11/Xsession.d/55copland-os <<'EOF'
# Copland OS: read its XFCE defaults before Debian's (/etc/xdg). Users' own settings still win.
case ":${XDG_CONFIG_DIRS:-}:" in
    *:/etc/xdg/copland-os:*) ;;
    *) XDG_CONFIG_DIRS="/etc/xdg/copland-os:${XDG_CONFIG_DIRS:-/etc/xdg}"; export XDG_CONFIG_DIRS ;;
esac
# Qt apps (VLC, KeePassXC...) draw with the GTK theme, so they are in Copland colours too.
# Qt 6 does this by itself on XFCE; Qt 5 needs to be told. Only when the plugin is there.
if [ -z "${QT_QPA_PLATFORMTHEME:-}" ]; then
    for f in /usr/lib/*/qt5/plugins/platformthemes/libqgtk3.so /usr/lib/*/qt6/plugins/platformthemes/libqgtk3.so; do
        if [ -e "$f" ]; then QT_QPA_PLATFORMTHEME=gtk3; export QT_QPA_PLATFORMTHEME; break; fi
    done
fi
EOF
}

# ------------------------------------------------------------------ uninstall
system_uninstall() {
    local list="$TGT$SYS_STATE/manifest" p
    [ -f "$list" ] || die "Nothing to uninstall: $list not found."
    on_live_root && ! as_root && die "Run it with sudo."
    info "Removing the files listed in $list"
    tac "$list" | sort -u -r | while IFS= read -r p; do
        case "$p" in
            divert:*) p=${p#divert:}
                      rm -f "$TGT$p"
                      if [ -n "$TGT" ]; then dpkg-divert --root "$TGT" --rename --remove "$p" >/dev/null || true
                      else dpkg-divert --rename --remove "$p" >/dev/null || true; fi ;;
            block:*)  p=${p#block:}; [ -f "$TGT$p" ] && sed -i '/^# >>> copland-os >>>$/,/^# <<< copland-os <<<$/d' "$TGT$p" ;;
            console:*) p=${p#console:}
                       [ -f "$TGT$SYS_STATE/console-setup.orig" ] && cp -a "$TGT$SYS_STATE/console-setup.orig" "$TGT$p" \
                           && rm -f "$TGT$SYS_STATE/console-setup.orig" ;;
            face:*)   p=${p#face:}
                      if [ -f "$TGT$SYS_STATE/face.orig" ]; then
                          cp -a "$TGT$SYS_STATE/face.orig" "$TGT$p" && rm -f "$TGT$SYS_STATE/face.orig"
                      else
                          rm -f "$TGT$p"
                      fi ;;
            issue:*)  p=${p#issue:}
                      [ -f "$TGT$SYS_STATE/issue.orig" ] && cp -a "$TGT$SYS_STATE/issue.orig" "$TGT$p" \
                          && rm -f "$TGT$SYS_STATE/issue.orig" ;;
            plymouth:*) if on_live_root && [ -x /usr/sbin/plymouth-set-default-theme ]; then
                            /usr/sbin/plymouth-set-default-theme "$(cat "$SYS_STATE/previous-plymouth-theme" 2>/dev/null || echo text)" || true
                        fi ;;
            */)       rm -rf "${TGT}${p%/}" ;;
            *)        rm -f "$TGT$p" ;;
        esac
    done
    rm -f "$list"
    # our own folders, if nothing else lives in them now
    local d
    for d in /etc/copland-os "$SYS_XDG" "${BROWSER_POLICY_DIRS[@]}"; do
        rmdir -p --ignore-fail-on-non-empty "$TGT$d" 2>/dev/null || true
    done
    if on_live_root && have glib-compile-schemas; then glib-compile-schemas /usr/share/glib-2.0/schemas || true; fi
    if on_live_root && [ "$NO_REBUILD" -eq 0 ]; then
        have update-initramfs && update-initramfs -u -k all || true
        have update-grub && update-grub || true
    fi
    info "Done. Users keep any settings they changed themselves."
}

# ------------------------------------------------------------------ main for --system
system_main() {
    TGT="${ROOT_DIR%/}"
    STATE="$TGT$SYS_STATE"
    LOG="$STATE/install-$STAMP.log"
    MANIFEST="$STATE/manifest"
    preflight_system
    [ "$UNINSTALL" -eq 1 ] && { system_uninstall; exit 0; }

    local id total idx=0
    SEL_SYS=()
    if [ -n "$ONLY" ]; then
        local IFS=','
        for id in $ONLY; do [ -n "${TITLE[$id]:-}" ] || die "Unknown component: $id (see --list)"; SEL_SYS+=("$id"); done
        unset IFS
    else
        SEL_SYS=("${IDS[@]}")
    fi
    TITLE[xdg]="XFCE defaults"
    local steps=("${SEL_SYS[@]}" xdg)
    total=${#steps[@]}

    banner
    info "System-wide install into ${B}${TGT:-/}${R} (${total} steps)"
    [ "$DRY" -eq 1 ] && warn "Dry run: commands are shown, nothing is changed."
    if [ "$YES" -eq 0 ] && [ "$DRY" -eq 0 ]; then
        confirm "Install Copland OS for every user on this system?" || { say " Nothing installed."; exit 0; }
    fi
    if [ "$DRY" -eq 0 ]; then
        mkdir -p "$STATE"; : > "$LOG"; touch "$MANIFEST"
        REASON_FILE="$(mktemp "$STATE/.reason.XXXXXX")"
    else
        REASON_FILE="$(mktemp)"
    fi
    STEP_PREFIX=sys
    for id in "${steps[@]}"; do
        idx=$((idx + 1))
        run_step "$id" "$idx" "$total"
    done
    if [ "$DRY" -eq 0 ]; then sort -u -o "$MANIFEST" "$MANIFEST"; fi
    local rc=0
    summary_system || rc=1
    exit "$rc"
}

summary_system() {
    local id ok=0 sk=0 fl=0
    for id in "${!RESULT[@]}"; do
        case "${RESULT[$id]}" in ok) ok=$((ok + 1)) ;; skip) sk=$((sk + 1)) ;; fail) fl=$((fl + 1)) ;; esac
    done
    say; rule
    printf '  %s%s %s done%s   %s%s %s skipped%s   %s%s %s failed%s\n' \
        "$GN" "$G_OK" "$ok" "$R" "$YL" "$G_SKIP" "$sk" "$R" "$RD" "$G_FAIL" "$fl" "$R"
    if [ "$DRY" -eq 1 ]; then say; info "Dry run: nothing was changed."; return 0; fi
    printf '  %sLog:%s      %s\n' "$DM" "$R" "$LOG"
    printf '  %sManifest:%s %s\n' "$DM" "$R" "$MANIFEST"
    say
    info "New users get Copland OS at their first login. Existing users keep their own"
    info "settings; run ./install.sh (without --system) as that user to switch them too."
    [ "$fl" -eq 0 ]
}
