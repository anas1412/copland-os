# shellcheck shell=bash
# Copland OS installer: the component list and one step_<id> function per component
# Sourced by install.sh; not meant to be run on its own.

# ---------------------------------------------------------------- components
IDS=(packages theme icons cursors wallpaper panel terminal layers keys browsers greeter boot)
declare -A TITLE DESC ON SUDO RESULT NOTE
TITLE[packages]="Packages";        DESC[packages]="install the missing apt packages";              ON[packages]=1;  SUDO[packages]=1
TITLE[theme]="Theme";              DESC[theme]="GTK, window borders, notifications";               ON[theme]=1;     SUDO[theme]=0
TITLE[icons]="Icons";              DESC[icons]="Mac OS 9 icons (NineIcons)"         ;              ON[icons]=1;     SUDO[icons]=0
TITLE[cursors]="Cursors";          DESC[cursors]="classic Mac pixel cursors (Retrosmart)";         ON[cursors]=1;   SUDO[cursors]=0
TITLE[wallpaper]="Wallpaper";      DESC[wallpaper]="Copland OS Enterprise boot frame";             ON[wallpaper]=1; SUDO[wallpaper]=0
TITLE[panel]="Top bar";            DESC[panel]="replaces your panel layout (backed up)";           ON[panel]=1;     SUDO[panel]=0
TITLE[terminal]="Terminal";        DESC[terminal]="palette, font, fastfetch";                      ON[terminal]=1;  SUDO[terminal]=0
TITLE[layers]="Layers";            DESC[layers]="4 workspaces; you choose which apps go where";               ON[layers]=1;    SUDO[layers]=0
TITLE[keys]="Shortcuts";           DESC[keys]="Super menu, Super+1-4 go, +Shift send";                ON[keys]=1;      SUDO[keys]=0
TITLE[browsers]="Browsers";       DESC[browsers]="Copland colour for Chromium-family browsers";  ON[browsers]=0;  SUDO[browsers]=1
TITLE[greeter]="Login screen";     DESC[greeter]="LightDM greeter in the same theme";              ON[greeter]=0;   SUDO[greeter]=1
TITLE[boot]="Boot animation";      DESC[boot]="Plymouth theme, third-party, experimental";         ON[boot]=0;      SUDO[boot]=1

# --------------------------------------------------------------- components
step_packages() {
    have apt-get || skip "apt-get not found"
    local p missing=() avail=() gone=()
    for p in "${PACKAGES[@]}"; do pkg_installed "$p" || missing+=("$p"); done
    [ "${#missing[@]}" -eq 0 ] && { note "all ${#PACKAGES[@]} packages already installed"; return 0; }
    run sudo apt-get update -q || echo "apt-get update failed; continuing with the current package lists"
    for p in "${missing[@]}"; do
        if apt-cache show "$p" >/dev/null 2>&1; then avail+=("$p"); else gone+=("$p"); fi
    done
    if [ "${#avail[@]}" -gt 0 ]; then
        run sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${avail[@]}"
    fi
    if [ "${#gone[@]}" -gt 0 ]; then
        note "installed ${#avail[@]}; not in your repos: ${gone[*]}"
    else
        note "installed ${#avail[@]} packages"
    fi
}

step_theme() {
    if [ -d "$THEME_DIR" ] && [ "$DRY" -eq 0 ]; then
        mkdir -p "$BACKUP"; mv "$THEME_DIR" "$BACKUP/theme-CoplandOS"
    fi
    run mkdir -p "$HOME/.themes"
    run cp -a "$ASSETS/themes/CoplandOS" "$THEME_DIR"
    apply_settings theme
    if have gsettings; then
        run gsettings set org.gnome.desktop.interface gtk-theme CoplandOS || true
        run gsettings set org.gnome.desktop.interface color-scheme prefer-dark || true
        run gsettings set org.gnome.desktop.interface font-name "Nimbus Sans 10" || true
    fi
    local fonts=""
    if have fc-list; then fonts="$(fc-list 2>/dev/null || true)"; fi
    if have fc-list && [[ "$fonts" != *C059* ]]; then
        note "installed; fonts-urw-base35 (C059, Nimbus Sans) is missing, so the default fonts are used"
    fi
}

step_icons() {
    local dest="$HOME/.icons/NineIcons"
    if [ -e "$dest" ] && [ "$DRY" -eq 0 ]; then mkdir -p "$BACKUP"; mv "$dest" "$BACKUP/icons-NineIcons"; fi
    run mkdir -p "$HOME/.icons"
    run cp -a "$ASSETS/icons/NineIcons" "$dest"
    apply_settings icons
    if have gsettings; then run gsettings set org.gnome.desktop.interface icon-theme NineIcons || true; fi
    [ -d /usr/share/icons/Adwaita ] || note "installed; adwaita-icon-theme is missing, so some icons will be blank"
}

step_cursors() {
    local dest="$HOME/.icons/$CURSOR_THEME"
    if [ -e "$dest" ] && [ "$DRY" -eq 0 ]; then mkdir -p "$BACKUP"; mv "$dest" "$BACKUP/cursors-$CURSOR_THEME"; fi
    run mkdir -p "$HOME/.icons"
    run cp -a "$ASSETS/cursors/$CURSOR_THEME" "$dest"
    apply_settings cursors
    if have gsettings; then run gsettings set org.gnome.desktop.interface cursor-theme "$CURSOR_THEME" || true; fi
    note "apps that are already open keep the old cursor until restarted"
}

step_wallpaper() {
    run install -D -m 644 "$ASSETS/backgrounds/CoplandOS.png" "$WALL"
    local props p n=0
    props="$(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep '/last-image$' || true)"
    while IFS= read -r p; do
        [ -n "$p" ] || continue
        xf xfce4-desktop "$p" string "$WALL"
        xf xfce4-desktop "${p%/last-image}/image-style" int 5
        n=$((n + 1))
    done <<< "$props"
    if have xfdesktop; then run xfdesktop --reload || true; fi
    [ "$n" -gt 0 ] || note "copied; no monitor entry found yet. Open Desktop settings once, then run again"
}

step_panel() {
    plugin_exists whiskermenu || skip "xfce4-whiskermenu-plugin is not installed"
    local audio=1
    plugin_exists pulseaudio-plugin || audio=0
    [ -f "$THEME_DIR/assets/copland-logo-48.png" ] || echo "logo not found yet; the menu button will have no icon until Theme is installed"

    if pgrep -u "$EUID" -x xfce4-panel >/dev/null; then
        run xfce4-panel --quit || true
        # wait for it to exit: a new panel started too early sees the old one and quits
        if [ "$DRY" -eq 0 ]; then
            local w=0
            while pgrep -u "$EUID" -x xfce4-panel >/dev/null && [ "$w" -lt 50 ]; do sleep 0.2; w=$((w + 1)); done
        fi
    fi
    if [ "$DRY" -eq 0 ]; then
        xfconf-query -c xfce4-panel -p /panels -rR 2>/dev/null || true
        xfconf-query -c xfce4-panel -p /plugins -rR 2>/dev/null || true
    else
        run xfconf-query -c xfce4-panel -p /panels -rR
        run xfconf-query -c xfce4-panel -p /plugins -rR
    fi

    # the menu shows your profile picture (~/.face): use the Copland logo
    if [ -f "$THEME_DIR/assets/copland-logo-128.png" ] || [ "$DRY" -eq 1 ]; then
        if [ -e "$HOME/.face" ] && [ "$DRY" -eq 0 ]; then mkdir -p "$BACKUP"; cp -a "$HOME/.face" "$BACKUP/face"; fi
        run cp "$THEME_DIR/assets/copland-logo-128.png" "$HOME/.face"
    fi

    if [ "$audio" -eq 1 ]; then
        apply_settings panel
    else
        apply_settings panel '^/plugins/plugin-7'
        xf_arr xfce4-panel /panels/panel-1/plugin-ids int 1 2 3 4 5 6 8 9 10
    fi

    if [ "$DRY" -eq 0 ]; then
        spawn xfce4-panel
        local w=0
        until pgrep -u "$EUID" -x xfce4-panel >/dev/null || [ "$w" -ge 50 ]; do sleep 0.2; w=$((w + 1)); done
        if ! pgrep -u "$EUID" -x xfce4-panel >/dev/null; then
            spawn xfce4-panel          # one retry
            sleep 3
        fi
        pgrep -u "$EUID" -x xfce4-panel >/dev/null || { echo "the panel did not come back; start it with: xfce4-panel &"; exit 1; }
    else
        run xfce4-panel
    fi
    [ "$audio" -eq 1 ] || note "installed without the volume button (xfce4-pulseaudio-plugin is missing)"
}

step_terminal() {
    apply_settings terminal

    run install -D -m 644 "$CONFIG/fastfetch/config.jsonc" "$HOME/.config/fastfetch/config.jsonc"
    if [ -f "$HOME/.bashrc" ] && grep -q 'fastfetch' "$HOME/.bashrc"; then
        echo "~/.bashrc already runs fastfetch; left alone"
    elif [ "$DRY" -eq 0 ]; then
        cat >> "$HOME/.bashrc" <<'EOF'

# >>> copland-os fastfetch >>>
if [[ $- == *i* ]] && [ -z "${CLAUDECODE:-}" ] && command -v fastfetch >/dev/null; then
    fastfetch
fi
# <<< copland-os fastfetch <<<
EOF
    else
        run append-fastfetch-hook "$HOME/.bashrc"
    fi
    local logos=""
    if have fastfetch; then logos="$(fastfetch --list-logos 2>/dev/null || true)"; fi
    if ! have fastfetch; then
        note "installed; fastfetch itself is missing, so new terminals show no banner"
    elif [[ "$logos" != *LainOS* ]]; then
        note "installed; this fastfetch has no LainOS logo, it will fall back to your distro logo"
    fi
}

step_layers() {
    # 4 named workspaces; an app asking for attention takes you to its layer
    apply_settings layers
    run install -D -m 644 "$CONFIG/devilspie2/layers.lua" "$HOME/.config/devilspie2/layers.lua"
    run install -D -m 755 "$BINSRC/copland-layers" "$HOME/.local/bin/copland-layers"
    # a neutral starting point: no app is assigned until you choose
    local conf="${XDG_CONFIG_HOME:-$HOME/.config}/copland-os/layers.conf"
    if [ -f "$conf" ]; then
        echo "keeping your existing layer choices: $conf"
    elif [ "$DRY" -eq 0 ]; then
        mkdir -p "$(dirname "$conf")"
        printf '# Copland OS layers. Edit with: copland-layers\nfollow = true\ndefault = 0\n' > "$conf"
    else
        run write "$conf"
    fi
    if [ "$DRY" -eq 0 ]; then
        mkdir -p "$HOME/.local/share/applications"
        cat > "$HOME/.local/share/applications/copland-layers.desktop" <<LAUNCHER
[Desktop Entry]
Type=Application
Name=Copland Layers
Comment=Choose which apps open on which layer
Exec=xfce4-terminal --title="Copland Layers" --geometry=84x34 -x $HOME/.local/bin/copland-layers
Icon=$THEME_DIR/assets/copland-logo-128.png
Categories=Settings;DesktopSettings;
Terminal=false
LAUNCHER
    else
        run write "$HOME/.local/share/applications/copland-layers.desktop"
    fi
    if [ "$DRY" -eq 0 ]; then
        mkdir -p "$HOME/.config/autostart"
        cat > "$HOME/.config/autostart/devilspie2.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Copland OS layers
Comment=Open each app on its own workspace (devilspie2)
Exec=devilspie2
OnlyShowIn=XFCE;
X-GNOME-Autostart-enabled=true
EOF
    else
        run write "$HOME/.config/autostart/devilspie2.desktop"
    fi
    have devilspie2 || { note "names set; devilspie2 is missing, so apps are not sorted into layers"; return 0; }
    if [ "$DRY" -eq 0 ]; then
        pkill -u "$EUID" -x devilspie2 2>/dev/null || true
        spawn devilspie2
    fi
    note "run 'copland-layers' (or Copland Layers in the menu) to choose your apps"
}

step_keys() {
    plugin_exists whiskermenu || skip "xfce4-whiskermenu-plugin is not installed"
    have python3 || skip "python3 is not installed"
    run install -D -m 755 "$BINSRC/copland-goto" "$BIN_DIR/copland-goto"
    run install -D -m 755 "$BINSRC/copland-send" "$BIN_DIR/copland-send"
    # Super opens the Copland menu; Super+1..4 (number row, numpad, AZERTY row) jump to a
    # layer and Super+Shift+1..4 send the focused window there. They call copland-goto/send
    # because xfwm4's own workspace keys did not fire on the machine this was built on.
    apply_settings keys
}

step_browsers() {
    [ -f "$CORE/browsers/copland-browsers.sh" ] || skip "core/browsers is missing"
    run bash "$CORE/browsers/copland-browsers.sh"
    note "Chromium-family browsers get the Copland colour; Firefox follows the GTK theme"
}

step_greeter() {
    [ -f "$GREETER" ] || skip "lightdm-gtk-greeter is not installed ($GREETER not found)"
    local f
    local icons
    icons="$(xfconf-query -c xsettings -p /Net/IconThemeName 2>/dev/null || echo NineIcons)"
    for f in "$THEME_DIR/gtk-3.0/gtk.css" "$HOME/.icons/$icons/index.theme" "$WALL"; do
        [ -e "$f" ] || [ "$DRY" -eq 1 ] || skip "install Theme, Icons and Wallpaper first (missing $f)"
    done
    # the greeter runs as user 'lightdm' and cannot read your home folder
    run sudo rm -rf /usr/share/themes/CoplandOS "/usr/share/icons/$icons"
    run sudo cp -a "$THEME_DIR" /usr/share/themes/CoplandOS
    run sudo cp -a "$HOME/.icons/$icons" "/usr/share/icons/$icons"
    run sudo chown -R root:root /usr/share/themes/CoplandOS "/usr/share/icons/$icons"
    run sudo chmod -R go-w /usr/share/themes/CoplandOS "/usr/share/icons/$icons"
    # the cursor theme lives in its own folder
    local cursor
    cursor="$(xfconf-query -c xsettings -p /Gtk/CursorThemeName 2>/dev/null || echo "$CURSOR_THEME")"
    if [ "$cursor" != "$icons" ] && [ -d "$HOME/.icons/$cursor/cursors" ]; then
        run sudo mkdir -p "/usr/share/icons/$cursor"
        run sudo rm -rf "/usr/share/icons/$cursor/cursors"
        run sudo cp -a "$HOME/.icons/$cursor/cursors" "/usr/share/icons/$cursor/cursors"
        if [ -f "$HOME/.icons/$cursor/index.theme" ] && [ ! -f "/usr/share/icons/$cursor/index.theme" ]; then
            run sudo cp -a "$HOME/.icons/$cursor/index.theme" "/usr/share/icons/$cursor/index.theme"
        fi
        run sudo chown -R root:root "/usr/share/icons/$cursor"
        run sudo chmod -R go-w "/usr/share/icons/$cursor"
    fi
    run sudo install -D -m 644 "$WALL" /usr/share/backgrounds/CoplandOS.png
    # a drop-in, read after Debian's 01_debian.conf; the packaged file is not edited
    local dropin=/etc/lightdm/lightdm-gtk-greeter.conf.d/50-copland.conf
    if [ "$DRY" -eq 1 ]; then
        run sudo tee "$dropin"
    else
        sudo install -d -m 755 "$(dirname "$dropin")"
        printf '%s\n' '# Copland OS login screen' '[greeter]' 'theme-name = CoplandOS' "icon-theme-name = $icons" \
            "cursor-theme-name = $cursor" 'cursor-theme-size = 24' 'background = /usr/share/backgrounds/CoplandOS.png' \
            'user-background = false' 'font-name = C059 Bold Italic 11' 'clock-format = %a %d %b  %H:%M' \
            | sudo tee "$dropin" >/dev/null
    fi
    # the main file is read last and wins: drop the block older versions of this installer put there
    if grep -q '^# copland-begin$' "$GREETER"; then
        [ -f "$GREETER.copland-bak" ] || run sudo cp -a "$GREETER" "$GREETER.copland-bak"
        run sudo sed -i '/^# copland-begin$/,/^# copland-end$/d' "$GREETER"
    fi
    [ "$DRY" -eq 1 ] || grep -q '^theme-name = CoplandOS$' "$dropin" || { echo "greeter drop-in was not written"; exit 1; }
    note "installed; it is a snapshot, so run this component again after changing the theme or icons"
}

step_boot() {
    have git || skip "git is not installed"
    [ -x /usr/sbin/plymouth-set-default-theme ] || skip "plymouth is not installed"
    have update-grub || [ -x /usr/sbin/update-grub ] || skip "update-grub not found (not a GRUB system)"
    [ -f "$GRUB" ] || skip "$GRUB not found"
    local tmp
    tmp="$(mktemp -d)"
    run git clone -q "$PLYMOUTH_REPO" "$tmp/repo"
    run git -C "$tmp/repo" -c advice.detachedHead=false checkout -q "$PLYMOUTH_COMMIT"
    if [ "$DRY" -eq 0 ]; then
        [ -f "$tmp/repo/copland/copland.plymouth" ] || { rm -rf "$tmp"; echo "unexpected layout in the Plymouth theme repo"; exit 1; }
    fi
    run sudo rm -rf /usr/share/plymouth/themes/copland
    run sudo cp -a "$tmp/repo/copland" /usr/share/plymouth/themes/copland
    run sudo chown -R root:root /usr/share/plymouth/themes/copland
    run sudo chmod -R go-w /usr/share/plymouth/themes/copland
    rm -rf "$tmp"
    if [ ! -f /etc/copland-prev-plymouth ] && [ "$DRY" -eq 0 ]; then
        /usr/sbin/plymouth-set-default-theme | sudo tee /etc/copland-prev-plymouth >/dev/null
    fi
    [ -f "$GRUB.copland-bak" ] || run sudo cp -a "$GRUB" "$GRUB.copland-bak"
    if ! grep -qE '^GRUB_CMDLINE_LINUX_DEFAULT=".*\bsplash\b' "$GRUB"; then
        run sudo sed -i -E 's/^(GRUB_CMDLINE_LINUX_DEFAULT=")([^"]*)"/\1\2 splash"/' "$GRUB"
    fi
    run sudo /usr/sbin/plymouth-set-default-theme -R copland     # -R rebuilds the initramfs
    run sudo /usr/sbin/update-grub
    note "installed; it shows on the next reboot (the initramfs of every kernel was rebuilt)"
}
