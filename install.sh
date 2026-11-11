#!/usr/bin/env bash
# Copland OS Enterprise — dotfiles installer for Debian + XFCE.
#
#   curl -fsSL https://raw.githubusercontent.com/anas1412/copland-os-dotfiles/main/install.sh | bash
#                             one-liner: downloads everything, then opens the menu
#   ./install.sh              interactive menu (from a clone)
#   ./install.sh --yes        install the default selection without asking
#   ./install.sh --dry-run    show every change, make none
#   ./install.sh --only a,b   pick components by id (see --list)
#   ./install.sh --list       list components
#   ./install.sh --restore    put back the settings saved by the last run
#   ./install.sh --force      rebuild things that already exist (icons, cursors)
#
# Safe by design: never runs as root, backs up before it changes anything,
# runs every component on its own (one failure does not stop the rest),
# and writes a full log.
set -Eeuo pipefail

VERSION="1.0"
REPO_SLUG="anas1412/copland-os-dotfiles"
# When run as a one-liner there is no script file, so this resolves to the current folder;
# bootstrap() then downloads the rest.
SRC="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || pwd)"
FILES="$SRC/files"
STATE="${XDG_DATA_HOME:-$HOME/.local/share}/copland-os"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$STATE/backups/$STAMP"
LOG="$STATE/install-$STAMP.log"
REASON_FILE=""
DRY=0; YES=0; FORCE=0; ONLY=""

THEME_DIR="$HOME/.themes/CoplandOS"
ICON_DIR="$HOME/.icons/CoplandOS"
WALL="$HOME/.local/share/backgrounds/CoplandOS.png"
XML_DIR="$HOME/.config/xfce4/xfconf/xfce-perchannel-xml"
CHANNELS=(xsettings xfwm4 xfce4-panel xfce4-desktop xfce4-terminal xfce4-keyboard-shortcuts xfce4-notifyd)
GREETER=/etc/lightdm/lightdm-gtk-greeter.conf
GRUB=/etc/default/grub
CURSOR_THEME="retrosmart-xcursor-mac-ish-classic"
CHICAGO95_REPO="https://github.com/grassmunk/Chicago95.git"
CHICAGO95_COMMIT="5da19b8b1e2a886ebf6628403023d5fac3acc3ee"   # pinned
PLYMOUTH_REPO="https://github.com/faisalhsn/copland-plymouth-theme.git"
PLYMOUTH_COMMIT="4e336d9e264723634ae1ed5dd38888cd2ab37c52"   # pinned: the repo is third-party

PACKAGES=(xfce4-whiskermenu-plugin xfce4-pulseaudio-plugin xfce4-terminal xfce4-notifyd
          papirus-icon-theme adwaita-icon-theme fonts-urw-base35 fonts-dejavu-core
          fonts-dejavu-mono gtk2-engines-murrine libgtk-3-bin python3 fastfetch devilspie2)

# ---------------------------------------------------------------- components
IDS=(packages theme icons iconsblue icons95 cursors cursorscyan wallpaper panel terminal layers keys greeter boot)
declare -A TITLE DESC ON SUDO RESULT NOTE
TITLE[packages]="Packages";        DESC[packages]="install the missing apt packages";              ON[packages]=1;  SUDO[packages]=1
TITLE[theme]="Theme";              DESC[theme]="GTK, window borders, notifications";               ON[theme]=1;     SUDO[theme]=0
TITLE[icons]="Icons";              DESC[icons]="Mac OS 9 icons (NineIcons), bundled";              ON[icons]=1;     SUDO[icons]=0
TITLE[iconsblue]="Blue icons";     DESC[iconsblue]="instead: blue duotone built from Papirus";     ON[iconsblue]=0; SUDO[iconsblue]=0
TITLE[icons95]="Win95 icons";      DESC[icons95]="instead: Chicago95 (downloads ~30 MB)"     ;    ON[icons95]=0;   SUDO[icons95]=0
TITLE[cursors]="Cursors";          DESC[cursors]="classic Mac pixel cursors (Retrosmart)";         ON[cursors]=1;   SUDO[cursors]=0
TITLE[cursorscyan]="Cyan cursors"; DESC[cursorscyan]="instead: Adwaita cursors tinted cyan";       ON[cursorscyan]=0; SUDO[cursorscyan]=0
TITLE[wallpaper]="Wallpaper";      DESC[wallpaper]="Copland OS Enterprise boot frame";             ON[wallpaper]=1; SUDO[wallpaper]=0
TITLE[panel]="Top bar";            DESC[panel]="replaces your panel layout (backed up)";           ON[panel]=1;     SUDO[panel]=0
TITLE[terminal]="Terminal";        DESC[terminal]="palette, font, fastfetch";                      ON[terminal]=1;  SUDO[terminal]=0
TITLE[layers]="Layers";            DESC[layers]="4 workspaces; you choose which apps go where";               ON[layers]=1;    SUDO[layers]=0
TITLE[keys]="Shortcuts";           DESC[keys]="Super menu, Super+1-4 go, +Shift send";                ON[keys]=1;      SUDO[keys]=0
TITLE[greeter]="Login screen";     DESC[greeter]="LightDM greeter in the same theme";              ON[greeter]=0;   SUDO[greeter]=1
TITLE[boot]="Boot animation";      DESC[boot]="Plymouth theme, third-party, experimental";         ON[boot]=0;      SUDO[boot]=1

# -------------------------------------------------------------------- colour
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    CY=$'\e[38;2;70;186;239m'; BL=$'\e[38;2;25;122;186m'; TX=$'\e[38;2;204;221;255m'
    DM=$'\e[38;2;90;108;170m'; RD=$'\e[38;2;224;80;122m'; GN=$'\e[38;2;95;215;167m'
    YL=$'\e[38;2;230;210;138m'; HL=$'\e[48;2;22;40;92m'; B=$'\e[1m'; I=$'\e[3m'; R=$'\e[0m'
else
    CY=""; BL=""; TX=""; DM=""; RD=""; GN=""; YL=""; HL=""; B=""; I=""; R=""
fi
case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in
    *UTF-8*|*utf8*) G_ON="◆"; G_OFF="◇"; G_PTR="▸"; G_OK="✔"; G_FAIL="✖"; G_SKIP="●"; G_LINE="─"; SPIN=("◐" "◓" "◑" "◒") ;;
    *)              G_ON="*"; G_OFF="."; G_PTR=">"; G_OK="ok"; G_FAIL="XX"; G_SKIP="--"; G_LINE="-"; SPIN=("|" "/" "-" "\\") ;;
esac

say()  { printf '%s\n' "$*"; }
info() { printf ' %s%s%s %s\n' "$CY" "$G_PTR" "$R" "$*"; }
warn() { printf ' %s!%s %s\n' "$YL" "$R" "$*"; }
die()  { printf '\n %s%s %s%s\n' "$RD" "$G_FAIL" "$*" "$R" >&2; exit 1; }
rule() { local i s=""; for ((i = 0; i < 62; i++)); do s+="$G_LINE"; done; printf ' %s%s%s\n' "$BL" "$s" "$R"; }

banner() {
    printf '%s' "$CY"
    cat <<'EOF'

                         .   ·   .
                    .-==============-.
          .:===:  .'    .--------.    '.  :===:.
        (===:    /     (   (())   )     \    :===)
          ':===:  '.    '--------'    .'  :===:'
                    '-=====    =====-'
             o           ||    ||           o
                    ====='      '=====
EOF
    printf '%s\n' "$R"
    printf '        %s%sC O P L A N D   O S   E N T E R P R I S E%s\n' "$B" "$TX" "$R"
    printf '        %sTachibana General Laboratories %s·%s dotfiles installer v%s%s\n\n' "$DM" "$BL" "$DM" "$VERSION" "$R"
}

# ------------------------------------------------------------ error handling
cleanup() {
    if [ -t 1 ]; then printf '\e[?25h'; fi          # cursor back
    [ -n "$REASON_FILE" ] && rm -f "$REASON_FILE"
    return 0
}
on_err() {
    local code=$? line=$1 cmd=$2
    printf '\n %s%s Unexpected error (exit %s) at line %s:%s %s\n' "$RD" "$G_FAIL" "$code" "$line" "$R" "$cmd" >&2
    [ "$DRY" -eq 0 ] && [ -f "$LOG" ] && printf '   Log: %s\n' "$LOG" >&2
    exit "$code"
}
trap cleanup EXIT
trap 'on_err "$LINENO" "$BASH_COMMAND"' ERR
trap 'printf "\n %sInterrupted. Nothing further was changed.%s\n" "$YL" "$R"; exit 130' INT TERM

# ------------------------------------------------------------------ helpers
# run: execute a command, or only print it in --dry-run
run() {
    if [ "$DRY" -eq 1 ]; then printf '      %s[dry-run]%s %s\n' "$DM" "$R" "$*"; else "$@"; fi
}
# skip: leave a component early with a reason (runs inside the component's subshell)
skip() { printf '%s' "$*" > "$REASON_FILE"; echo "SKIP: $*"; exit 3; }
note() { printf '%s' "$*" > "$REASON_FILE"; [ "$DRY" -eq 1 ] || echo "NOTE: $*"; }
have() { command -v "$1" >/dev/null 2>&1; }
# xf <channel> <property> <type> <value>: set one xfconf property, creating it if needed
xf()   { run xfconf-query -c "$1" -p "$2" -n -t "$3" -s "$4"; }
# xf_arr <channel> <property> <type> <v1> [v2 ...]: set an array property
xf_arr() {
    local ch=$1 prop=$2 type=$3 args=() v; shift 3
    for v in "$@"; do args+=(-t "$type" -s "$v"); done
    if [ "$DRY" -eq 0 ]; then xfconf-query -c "$ch" -p "$prop" -r 2>/dev/null || true; fi
    run xfconf-query -c "$ch" -p "$prop" -n -a "${args[@]}"
}
# spawn: start a long-running desktop program from the home folder, detached, without
# leaking the environment of an AI coding session (it would be inherited by every app
# launched from the panel)
spawn() {
    local v drop=()
    for v in $(compgen -e); do
        case "$v" in CLAUDE*|ANTHROPIC*) drop+=(-u "$v") ;; esac
    done
    ( cd "$HOME" && env "${drop[@]}" setsid -f "$@" >/dev/null 2>&1 ) || true
}
pkg_installed() { [ "$(dpkg-query -W -f='${db:Status-Abbrev}' "$1" 2>/dev/null)" = "ii " ]; }
plugin_exists() { compgen -G "/usr/lib/*/xfce4/panel/plugins/lib$1.so" >/dev/null; }

# ---------------------------------------------------------------- preflight
preflight() {
    [ "${BASH_VERSINFO[0]}" -ge 4 ] || die "bash 4 or newer is required."
    [ "$EUID" -ne 0 ] || die "Do not run this as root. Run it as your own user; it asks for sudo only where needed."
    local f
    for f in themes/CoplandOS/gtk-3.0/gtk.css themes/CoplandOS/xfwm4/themerc backgrounds/CoplandOS.png icons/NineIcons/index.theme "cursors/$CURSOR_THEME/index.theme" \
             fastfetch/config.jsonc devilspie2/layers.lua bin/copland-layers bin/copland-goto bin/copland-send tools/copland_assets.py; do
        [ -e "$FILES/$f" ] || die "The dotfiles folder is incomplete: files/$f is missing."
    done
    local like=""
    [ -r /etc/os-release ] && like="$(. /etc/os-release; echo "${ID:-} ${ID_LIKE:-}")"
    case " $like " in
        *" debian "*|*" ubuntu "*) ;;
        *) warn "This does not look like a Debian-based system (${like:-unknown}). Package names may differ." ;;
    esac
    have apt-get || warn "apt-get not found: the Packages component will be skipped."
    if [ "$DRY" -eq 0 ]; then
        have xfconf-query || die "xfconf-query not found. This installer is for XFCE."
        [ -n "${DISPLAY:-}" ] && pgrep -u "$EUID" -x xfce4-session >/dev/null \
            || die "Run this inside your XFCE session (a terminal on the desktop), not over plain SSH or a TTY."
        xfconf-query -c xsettings -l >/dev/null 2>&1 || die "Cannot reach the XFCE settings daemon (xfconfd)."
    fi
}

# --------------------------------------------------------------------- menu
draw_menu() {
    local cur=$1 i id mark row tag
    printf '\e[H\e[2J'
    banner
    rule
    for i in "${!IDS[@]}"; do
        id=${IDS[$i]}
        if [ "${ON[$id]}" -eq 1 ]; then mark="${CY}${G_ON}${R}"; else mark="${DM}${G_OFF}${R}"; fi
        tag=""; [ "${SUDO[$id]}" -eq 1 ] && tag="${YL}sudo${R}"
        if [ "$i" -eq "$cur" ]; then
            row="${HL}${CY}${B} ${G_PTR} ${R}${HL} ${mark}${HL}  ${TX}${B}$(printf '%-15s' "${TITLE[$id]}")${R}${HL}${TX}$(printf '%-44s' "${DESC[$id]}")${R}"
        else
            row="    ${mark}  ${TX}$(printf '%-15s' "${TITLE[$id]}")${R}${DM}$(printf '%-44s' "${DESC[$id]}")${R}"
        fi
        printf ' %s %s\n' "$row" "$tag"
    done
    rule
    printf '  %s↑ ↓%s move   %sspace%s toggle   %sa%s all   %sn%s none   %senter%s install   %sq%s quit\n' \
        "$CY" "$DM" "$CY" "$DM" "$CY" "$DM" "$CY" "$DM" "$CY" "$DM" "$CY" "$R"
}

menu() {
    local cur=0 n=${#IDS[@]} key rest id
    printf '\e[?25l'
    while :; do
        draw_menu "$cur"
        IFS= read -rsn1 key || { key=q; }
        case "$key" in
            $'\e')
                rest=""; IFS= read -rsn2 -t 0.05 rest || true
                case "$rest" in
                    '[A') cur=$(( (cur - 1 + n) % n )) ;;
                    '[B') cur=$(( (cur + 1) % n )) ;;
                esac ;;
            k) cur=$(( (cur - 1 + n) % n )) ;;
            j) cur=$(( (cur + 1) % n )) ;;
            ' ') id=${IDS[$cur]}; ON[$id]=$(( 1 - ON[$id] )) ;;
            a) for id in "${IDS[@]}"; do ON[$id]=1; done ;;
            n) for id in "${IDS[@]}"; do ON[$id]=0; done ;;
            '') break ;;
            q) printf '\e[?25h\n'; say " Nothing installed."; exit 0 ;;
        esac
    done
    printf '\e[?25h\e[H\e[2J'
}

confirm() {
    local ans
    printf ' %s%s%s [y/N] ' "$TX" "$1" "$R"
    IFS= read -r ans || ans=""
    case "$ans" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}

# ------------------------------------------------------------------ backups
make_backup() {
    [ "$DRY" -eq 1 ] && { info "dry-run: no backup needed"; return 0; }
    mkdir -p "$BACKUP/xfconf"
    local ch
    for ch in "${CHANNELS[@]}"; do
        [ -f "$XML_DIR/$ch.xml" ] && cp -a "$XML_DIR/$ch.xml" "$BACKUP/xfconf/"
    done
    [ -f "$HOME/.bashrc" ] && cp -a "$HOME/.bashrc" "$BACKUP/bashrc"
    [ -f "$HOME/.config/fastfetch/config.jsonc" ] && cp -a "$HOME/.config/fastfetch/config.jsonc" "$BACKUP/fastfetch-config.jsonc"
    [ -f "$HOME/.config/devilspie2/layers.lua" ] && cp -a "$HOME/.config/devilspie2/layers.lua" "$BACKUP/layers.lua"
    printf 'Copland OS installer backup, %s\nRestore with: %s/install.sh --restore\n' "$STAMP" "$SRC" > "$BACKUP/README"
    ln -sfn "$BACKUP" "$STATE/backups/latest"
    info "Backup saved: ${DM}$BACKUP${R}"
}

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
    run cp -a "$FILES/themes/CoplandOS" "$THEME_DIR"
    xf xsettings /Net/ThemeName string CoplandOS
    xf xfwm4 /general/theme string CoplandOS
    xf xfwm4 /general/title_font string "C059 Bold Italic 10"
    xf xfwm4 /general/title_alignment string center
    xf xfwm4 /general/button_layout string "O|SHMC"
    xf xfce4-notifyd /theme string CoplandOS
    if have gsettings; then
        run gsettings set org.gnome.desktop.interface gtk-theme CoplandOS || true
        run gsettings set org.gnome.desktop.interface color-scheme prefer-dark || true
    fi
    local fonts=""
    if have fc-list; then fonts="$(fc-list 2>/dev/null || true)"; fi
    if have fc-list && [[ "$fonts" != *C059* ]]; then
        note "installed; font C059 (fonts-urw-base35) is missing, titles fall back to the default font"
    fi
}

step_icons() {
    local dest="$HOME/.icons/NineIcons"
    if [ -e "$dest" ] && [ "$DRY" -eq 0 ]; then mkdir -p "$BACKUP"; mv "$dest" "$BACKUP/icons-NineIcons"; fi
    run mkdir -p "$HOME/.icons"
    run cp -a "$FILES/icons/NineIcons" "$dest"
    xf xsettings /Net/IconThemeName string NineIcons
    if have gsettings; then run gsettings set org.gnome.desktop.interface icon-theme NineIcons || true; fi
    [ -d /usr/share/icons/Adwaita ] || note "installed; adwaita-icon-theme is missing, so some icons will be blank"
}

step_iconsblue() {
    have python3 || skip "python3 is not installed"
    [ -d /usr/share/icons/Papirus ] && [ -d /usr/share/icons/Papirus-Dark ] || skip "papirus-icon-theme is not installed"
    local built=0
    if [ -f "$ICON_DIR/index.theme" ] && [ -d "$ICON_DIR/16x16" ] && [ "$FORCE" -eq 0 ]; then
        echo "icon theme already built; keeping it (use --force to rebuild)"
    else
        local tmp="$ICON_DIR.new.$$"
        run rm -rf "$tmp"
        run mkdir -p "$HOME/.icons"
        run python3 -I "$FILES/tools/copland_assets.py" icons /usr/share/icons/Papirus /usr/share/icons/Papirus-Dark "$tmp"
        if [ "$DRY" -eq 0 ]; then
            # keep cursors that are already there, then swap the new theme in
            if [ -d "$ICON_DIR/cursors" ] && [ ! -e "$tmp/cursors" ]; then mv "$ICON_DIR/cursors" "$tmp/cursors"; fi
            if [ -e "$ICON_DIR" ]; then mkdir -p "$BACKUP"; mv "$ICON_DIR" "$BACKUP/icons-CoplandOS"; fi
            mv "$tmp" "$ICON_DIR"
        fi
        built=1
    fi
    # panel icons white instead of light blue, and a white power button
    if [ "$DRY" -eq 0 ]; then
        local s
        for s in 16x16 22x22 24x24; do
            [ -d "$ICON_DIR/$s/panel" ] || continue
            find "$ICON_DIR/$s/panel" -type f -name '*.svg' -exec \
                sed -i 's/\.ColorScheme-Text { color:#97d7f7; }/.ColorScheme-Text { color:#ffffff; }/' {} +
            if [ -e "$ICON_DIR/$s/panel/system-shutdown-panel.svg" ] && [ -d "$ICON_DIR/$s/apps" ]; then
                ln -sfn ../panel/system-shutdown-panel.svg "$ICON_DIR/$s/apps/xfsm-shutdown.svg"
            fi
        done
        if have gtk-update-icon-cache; then gtk-update-icon-cache -f -q "$ICON_DIR" || true; fi
    else
        run sed -i "panel icons -> white" "$ICON_DIR/{16x16,22x22,24x24}/panel/*.svg"
    fi
    xf xsettings /Net/IconThemeName string CoplandOS
    if have gsettings; then run gsettings set org.gnome.desktop.interface icon-theme CoplandOS || true; fi
    [ "$built" -eq 1 ] || note "already built, kept (use --force to rebuild)"
}

step_icons95() {
    have git || skip "git is not installed"
    local dest="$HOME/.icons/Chicago95" tmp
    if [ -f "$dest/index.theme" ] && [ "$FORCE" -eq 0 ]; then
        note "already installed, kept (use --force to download again)"
    else
        tmp="$(mktemp -d)"
        run git clone -q "$CHICAGO95_REPO" "$tmp/repo"
        run git -C "$tmp/repo" -c advice.detachedHead=false checkout -q "$CHICAGO95_COMMIT"
        if [ "$DRY" -eq 0 ]; then
            [ -f "$tmp/repo/Icons/Chicago95/index.theme" ] || { rm -rf "$tmp"; echo "unexpected layout in the Chicago95 repo"; exit 1; }
            mkdir -p "$HOME/.icons"
            if [ -e "$dest" ]; then mkdir -p "$BACKUP"; mv "$dest" "$BACKUP/icons-Chicago95"; fi
            cp -a "$tmp/repo/Icons/Chicago95" "$dest"
            if have gtk-update-icon-cache; then gtk-update-icon-cache -f -q "$dest" || true; fi
        fi
        rm -rf "$tmp"
    fi
    xf xsettings /Net/IconThemeName string Chicago95
    if have gsettings; then run gsettings set org.gnome.desktop.interface icon-theme Chicago95 || true; fi
}

step_cursors() {
    local dest="$HOME/.icons/$CURSOR_THEME"
    if [ -e "$dest" ] && [ "$DRY" -eq 0 ]; then mkdir -p "$BACKUP"; mv "$dest" "$BACKUP/cursors-$CURSOR_THEME"; fi
    run mkdir -p "$HOME/.icons"
    run cp -a "$FILES/cursors/$CURSOR_THEME" "$dest"
    xf xsettings /Gtk/CursorThemeName string "$CURSOR_THEME"
    xf xsettings /Gtk/CursorThemeSize int 24
    if have gsettings; then run gsettings set org.gnome.desktop.interface cursor-theme "$CURSOR_THEME" || true; fi
    note "apps that are already open keep the old cursor until restarted"
}

step_cursorscyan() {
    have python3 || skip "python3 is not installed"
    [ -d /usr/share/icons/Adwaita/cursors ] || skip "adwaita-icon-theme (cursors) is not installed"
    if [ -d "$ICON_DIR/cursors" ] && [ "$FORCE" -eq 0 ]; then
        note "already built, kept (use --force to rebuild)"
    else
        run mkdir -p "$ICON_DIR"
        run python3 -I "$FILES/tools/copland_assets.py" cursors /usr/share/icons/Adwaita/cursors "$ICON_DIR/cursors"
    fi
    xf xsettings /Gtk/CursorThemeName string CoplandOS
    xf xsettings /Gtk/CursorThemeSize int 24
}

step_wallpaper() {
    run install -D -m 644 "$FILES/backgrounds/CoplandOS.png" "$WALL"
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

    if pgrep -u "$EUID" -x xfce4-panel >/dev/null; then run xfce4-panel --quit || true; [ "$DRY" -eq 1 ] || sleep 1; fi
    if [ "$DRY" -eq 0 ]; then
        xfconf-query -c xfce4-panel -p /panels -rR 2>/dev/null || true
        xfconf-query -c xfce4-panel -p /plugins -rR 2>/dev/null || true
    else
        run xfconf-query -c xfce4-panel -p /panels -rR
        run xfconf-query -c xfce4-panel -p /plugins -rR
    fi

    local P=xfce4-panel ids=(1 2 3 4 5 6)
    [ "$audio" -eq 1 ] && ids+=(7)
    ids+=(8 9 10)
    xf_arr $P /panels int 1
    xf $P /panels/dark-mode bool true
    xf $P /panels/panel-1/position string "p=6;x=0;y=0"
    xf $P /panels/panel-1/position-locked bool true
    xf $P /panels/panel-1/length double 100
    xf $P /panels/panel-1/size uint 30
    xf $P /panels/panel-1/icon-size uint 18
    xf $P /panels/panel-1/mode uint 0
    xf $P /panels/panel-1/enable-struts bool true
    xf $P /panels/panel-1/background-style uint 0
    xf_arr $P /panels/panel-1/plugin-ids int "${ids[@]}"

    xf $P /plugins/plugin-1 string whiskermenu
    xf $P /plugins/plugin-1/button-title string "Copland OS"
    xf $P /plugins/plugin-1/button-icon string "$THEME_DIR/assets/copland-logo-48.png"
    xf $P /plugins/plugin-1/show-button-title bool true
    xf $P /plugins/plugin-1/show-button-icon bool true
    xf $P /plugins/plugin-1/menu-width int 520
    xf $P /plugins/plugin-1/menu-height int 560
    xf $P /plugins/plugin-1/menu-opacity int 94

    # the menu shows your profile picture (~/.face): use the Copland logo
    if [ -f "$THEME_DIR/assets/copland-logo-128.png" ] || [ "$DRY" -eq 1 ]; then
        if [ -e "$HOME/.face" ] && [ "$DRY" -eq 0 ]; then mkdir -p "$BACKUP"; cp -a "$HOME/.face" "$BACKUP/face"; fi
        run cp "$THEME_DIR/assets/copland-logo-128.png" "$HOME/.face"
    fi

    xf $P /plugins/plugin-2 string tasklist
    xf $P /plugins/plugin-2/flat-buttons bool true
    xf $P /plugins/plugin-2/show-handle bool false
    xf $P /plugins/plugin-2/show-labels bool true
    xf $P /plugins/plugin-2/grouping uint 0
    xf $P /plugins/plugin-2/include-all-workspaces bool false

    xf $P /plugins/plugin-3 string separator
    xf $P /plugins/plugin-3/expand bool true
    xf $P /plugins/plugin-3/style uint 0

    xf $P /plugins/plugin-4 string pager
    xf $P /plugins/plugin-4/miniature-view bool false
    xf $P /plugins/plugin-4/rows uint 1

    xf $P /plugins/plugin-5 string separator
    xf $P /plugins/plugin-5/style uint 0

    xf $P /plugins/plugin-6 string systray
    xf $P /plugins/plugin-6/square-icons bool true

    if [ "$audio" -eq 1 ]; then
        xf $P /plugins/plugin-7 string pulseaudio
        xf $P /plugins/plugin-7/enable-keyboard-shortcuts bool true
    fi

    xf $P /plugins/plugin-8 string clock
    xf $P /plugins/plugin-8/mode uint 2
    xf $P /plugins/plugin-8/digital-layout uint 3
    xf $P /plugins/plugin-8/digital-time-format string "%H:%M"
    xf $P /plugins/plugin-8/digital-time-font string "C059 Bold Italic 11"
    xf $P /plugins/plugin-8/digital-date-format string "%d %b %Y"

    xf $P /plugins/plugin-9 string actions
    xf $P /plugins/plugin-9/appearance uint 0
    xf $P /plugins/plugin-9/button-title uint 3
    xf_arr $P /plugins/plugin-9/items string -lock-screen -switch-user -separator -suspend -hibernate \
        -hybrid-sleep -separator +shutdown -restart +separator -logout -logout-dialog

    xf $P /plugins/plugin-10 string separator
    xf $P /plugins/plugin-10/style uint 0

    if [ "$DRY" -eq 0 ]; then
        spawn xfce4-panel
        sleep 2
        pgrep -u "$EUID" -x xfce4-panel >/dev/null || { echo "the panel did not come back; start it with: xfce4-panel &"; exit 1; }
    else
        run xfce4-panel
    fi
    [ "$audio" -eq 1 ] || note "installed without the volume button (xfce4-pulseaudio-plugin is missing)"
}

step_terminal() {
    local T=xfce4-terminal
    xf $T /color-background string "#101838"
    xf $T /color-foreground string "#ccddff"
    xf $T /color-cursor string "#46baef"
    xf $T /color-palette string "#141c3a;#e0507a;#5fd7a7;#e6d28a;#197aba;#9a7cf0;#46baef;#c5cfee;#4a5c9a;#ff7096;#8af0c8;#f5e6a8;#5aa8e8;#b8a0ff;#8fd6fa;#ffffff"
    xf $T /background-mode string TERMINAL_BACKGROUND_TRANSPARENT
    xf $T /background-darkness double 0.92
    xf $T /font-use-system bool false
    xf $T /font-name string "DejaVu Sans Mono 9"
    xf $T /misc-default-geometry string "120x34"

    run install -D -m 644 "$FILES/fastfetch/config.jsonc" "$HOME/.config/fastfetch/config.jsonc"
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
    xf xfwm4 /general/workspace_count int 4
    xf_arr xfwm4 /general/workspace_names string "Layer:01" "Layer:02" "Layer:03" "Layer:04"
    # when an app asks for attention, go to its layer instead of dragging its window to yours
    xf xfwm4 /general/activate_action string switch
    run install -D -m 644 "$FILES/devilspie2/layers.lua" "$HOME/.config/devilspie2/layers.lua"
    run install -D -m 755 "$FILES/bin/copland-layers" "$HOME/.local/bin/copland-layers"
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
    # a tap of Super opens the Copland menu
    xf xfce4-keyboard-shortcuts /commands/custom/Super_L string xfce4-popup-whiskermenu
    # Super+1..4 jump to Layer:01..04. They run a small command instead of xfwm4's own
    # workspace keys, which did not fire on the machine this was built on.
    # Bound on the number row, the numpad (NumLock on) and AZERTY's unshifted number row.
    run install -D -m 755 "$FILES/bin/copland-goto" "$HOME/.local/bin/copland-goto"
    run install -D -m 755 "$FILES/bin/copland-send" "$HOME/.local/bin/copland-send"
    local i k azerty=(ampersand eacute quotedbl apostrophe)
    for i in 1 2 3 4; do
        for k in "$i" "KP_$i" "${azerty[$((i - 1))]}"; do
            xf xfce4-keyboard-shortcuts "/commands/custom/<Super>$k" string "$HOME/.local/bin/copland-goto $i"
        done
    done
    # Super+Shift+1..4 send the focused window to that layer. With Shift held the number
    # row produces ! @ # $ on US layouts and the digits on AZERTY, so both are bound.
    local shifted=(exclam at numbersign dollar)
    for i in 1 2 3 4; do
        for k in "${shifted[$((i - 1))]}" "$i"; do
            xf xfce4-keyboard-shortcuts "/commands/custom/<Shift><Super>$k" string "$HOME/.local/bin/copland-send $i"
        done
    done
}

step_greeter() {
    [ -f "$GREETER" ] || skip "lightdm-gtk-greeter is not installed ($GREETER not found)"
    grep -q '^\[greeter\]' "$GREETER" || skip "no [greeter] section in $GREETER"
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
    [ -f "$GREETER.copland-bak" ] || run sudo cp -a "$GREETER" "$GREETER.copland-bak"
    run sudo sed -i '/^# copland-begin$/,/^# copland-end$/d' "$GREETER"
    run sudo sed -i '0,/^\[greeter\]/s//[greeter]\n# copland-begin\ntheme-name = CoplandOS\nicon-theme-name = '"$icons"'\ncursor-theme-name = '"$cursor"'\ncursor-theme-size = 24\nbackground = \/usr\/share\/backgrounds\/CoplandOS.png\nuser-background = false\nfont-name = C059 Bold Italic 11\nclock-format = %H:%M\n# copland-end/' "$GREETER"
    [ "$DRY" -eq 1 ] || grep -q '^theme-name = CoplandOS$' "$GREETER" || { echo "greeter config was not updated"; exit 1; }
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

# ------------------------------------------------------------------- runner
run_step() {
    local id=$1 idx=$2 total=$3 rc=0 pid i=0 label
    label="$(printf '[%02d/%02d] %-15s' "$idx" "$total" "${TITLE[$id]}")"
    : > "$REASON_FILE"
    if [ "$DRY" -eq 1 ]; then
        printf '\n %s%s%s\n' "$CY" "$label" "$R"
        ( "step_$id" ) || rc=$?
    else
        printf '\n==== %s (%s) ====\n' "$id" "$(date +%T)" >> "$LOG"
        # background subshell: 'set -e' stays active inside it, and one failure cannot stop the others
        ( trap - ERR INT TERM; set -Eeuo pipefail; "step_$id" ) >> "$LOG" 2>&1 &
        pid=$!
        while kill -0 "$pid" 2>/dev/null; do
            printf '\r %s%s%s %s%s%s ' "$TX" "$label" "$R" "$CY" "${SPIN[$((i % ${#SPIN[@]}))]}" "$R"
            i=$((i + 1)); sleep 0.12
        done
        wait "$pid" || rc=$?
        printf '\r\e[K'
    fi
    NOTE[$id]="$(cat "$REASON_FILE" 2>/dev/null || true)"
    case "$rc" in
        0) RESULT[$id]=ok;   printf ' %s%s%s %s%s%s %s%s%s\n' "$TX" "$label" "$R" "$GN" "$G_OK" "$R" "$DM" "${NOTE[$id]}" "$R" ;;
        3) RESULT[$id]=skip; printf ' %s%s%s %s%s skipped:%s %s\n' "$TX" "$label" "$R" "$YL" "$G_SKIP" "$R" "${NOTE[$id]}" ;;
        *) RESULT[$id]=fail; printf ' %s%s%s %s%s failed%s (exit %s)\n' "$TX" "$label" "$R" "$RD" "$G_FAIL" "$R" "$rc" ;;
    esac
}

summary() {
    local id ok=0 sk=0 fl=0
    for id in "${IDS[@]}"; do
        case "${RESULT[$id]:-}" in ok) ok=$((ok + 1)) ;; skip) sk=$((sk + 1)) ;; fail) fl=$((fl + 1)) ;; esac
    done
    say; rule
    printf '  %s%s %s done%s   %s%s %s skipped%s   %s%s %s failed%s\n' \
        "$GN" "$G_OK" "$ok" "$R" "$YL" "$G_SKIP" "$sk" "$R" "$RD" "$G_FAIL" "$fl" "$R"
    if [ "$DRY" -eq 1 ]; then
        say; info "Dry run: nothing was changed."
        return 0
    fi
    printf '  %sLog:%s    %s\n' "$DM" "$R" "$LOG"
    printf '  %sBackup:%s %s\n' "$DM" "$R" "$BACKUP"
    if [ "$fl" -gt 0 ]; then
        say; warn "Some components failed. The log has the exact command and error."
        for id in "${IDS[@]}"; do
            [ "${RESULT[$id]:-}" = fail ] && printf '     %s%s%s: %s\n' "$RD" "${TITLE[$id]}" "$R" "$(grep -A40 "^==== $id " "$LOG" | grep -v '^====' | tail -n 3 | tr '\n' ' ')"
        done
    fi
    say; info "Log out and back in so every app picks up the new look."
    printf '\n  %s%sClose the world, Open the nExt.%s\n\n' "$I" "$DM" "$R"
    [ "$fl" -eq 0 ]
}

# ------------------------------------------------------------------ restore
restore() {
    local src="$STATE/backups/latest" ch
    [ -d "$src/xfconf" ] || die "No backup found in $STATE/backups."
    src="$(readlink -f "$src")"
    banner
    info "Restoring settings from: $src"
    warn "This puts back your XFCE settings from before the last install. Theme and icon files stay on disk."
    confirm "Restore now?" || { say " Nothing changed."; exit 0; }
    # xfconfd writes its files on exit, so stop it first, then put the saved files back
    pkill -u "$EUID" -x xfconfd 2>/dev/null || true
    sleep 1
    for ch in "${CHANNELS[@]}"; do
        [ -f "$src/xfconf/$ch.xml" ] && cp -a "$src/xfconf/$ch.xml" "$XML_DIR/$ch.xml"
    done
    [ -f "$HOME/.bashrc" ] && sed -i '/^# >>> copland-os fastfetch >>>$/,/^# <<< copland-os fastfetch <<<$/d' "$HOME/.bashrc"
    [ -f "$src/face" ] && cp -a "$src/face" "$HOME/.face"
    [ -f "$src/fastfetch-config.jsonc" ] && cp -a "$src/fastfetch-config.jsonc" "$HOME/.config/fastfetch/config.jsonc"
    rm -f "$HOME/.config/autostart/devilspie2.desktop" "$HOME/.local/share/applications/copland-layers.desktop"
    pkill -u "$EUID" -x devilspie2 2>/dev/null || true
    if [ -f "$GREETER.copland-bak" ] && confirm "Also restore the login screen config (sudo)?"; then
        sudo cp -a "$GREETER.copland-bak" "$GREETER" && info "Login screen restored."
    fi
    if [ -f "$GRUB.copland-bak" ] && confirm "Also restore the boot settings (sudo, rebuilds the initramfs)?"; then
        sudo cp -a "$GRUB.copland-bak" "$GRUB"
        sudo /usr/sbin/plymouth-set-default-theme -R "$(cat /etc/copland-prev-plymouth 2>/dev/null || echo text)"
        sudo /usr/sbin/update-grub && info "Boot settings restored."
    fi
    say; info "Done. Log out and back in to load the restored settings."
}

usage() {
    cat <<USAGE
Copland OS Enterprise — dotfiles installer for Debian + XFCE.

  curl -fsSL https://raw.githubusercontent.com/$REPO_SLUG/main/install.sh | bash
                            one-liner: downloads everything, then opens the menu
  ./install.sh              interactive menu (from a clone)
  ./install.sh --yes        install the default selection without asking
  ./install.sh --dry-run    show every change, make none
  ./install.sh --only a,b   pick components by id (see --list)
  ./install.sh --list       list components
  ./install.sh --restore    put back the settings saved by the last run
  ./install.sh --force      rebuild things that already exist

With the one-liner, pass options after 'bash -s --':
  curl -fsSL .../install.sh | bash -s -- --dry-run
Set COPLAND_REF to install a tag or commit instead of main.
USAGE
}

# bootstrap: when started without the rest of the repo next to it (the curl one-liner),
# download the repository tarball and run the real copy from there.
bootstrap() {
    [ -d "$FILES" ] && return 0
    local ref="${COPLAND_REF:-main}" dest="$STATE/src" tmp
    have curl || die "curl is required to download the dotfiles."
    have tar  || die "tar is required to unpack the dotfiles."
    printf ' %s%s%s Downloading %s (%s)...\n' "$CY" "$G_PTR" "$R" "$REPO_SLUG" "$ref"
    mkdir -p "$STATE"
    tmp="$(mktemp -d "$STATE/.download.XXXXXX")"
    if ! curl -fsSL --retry 2 -o "$tmp/src.tar.gz" "https://codeload.github.com/$REPO_SLUG/tar.gz/$ref" 2>/dev/null; then
        # a private repository needs your GitHub login
        if have gh && gh auth status >/dev/null 2>&1 \
            && gh api "repos/$REPO_SLUG/tarball/$ref" > "$tmp/src.tar.gz" 2>/dev/null; then
            :
        else
            rm -rf "$tmp"
            die "Could not download $REPO_SLUG ($ref). Check your connection; a private repository also needs 'gh auth login'."
        fi
    fi
    mkdir -p "$tmp/src"
    tar -xzf "$tmp/src.tar.gz" -C "$tmp/src" --strip-components=1 --no-same-owner \
        || { rm -rf "$tmp"; die "The downloaded archive could not be unpacked."; }
    [ -f "$tmp/src/install.sh" ] && [ -d "$tmp/src/files" ] \
        || { rm -rf "$tmp"; die "The download does not look like the Copland OS dotfiles."; }
    rm -rf "$dest"
    mv "$tmp/src" "$dest"
    rm -rf "$tmp"
    printf ' %s%s%s Saved to %s\n' "$GN" "$G_OK" "$R" "$dest"
    exec bash "$dest/install.sh" "$@"
}
list()  { local id; for id in "${IDS[@]}"; do printf '  %-10s %-15s %s\n' "$id" "${TITLE[$id]}" "${DESC[$id]}"; done; }

# --------------------------------------------------------------------- main
main() {
    # 'curl ... | bash' leaves the script on stdin; the menu needs the keyboard
    if [ ! -t 0 ] && (: </dev/tty) 2>/dev/null; then exec </dev/tty; fi
    case " $* " in *" -h "*|*" --help "*|*" --list "*) ;; *) bootstrap "$@" ;; esac
    local id sel=() total idx=0 need_sudo=0
    while [ $# -gt 0 ]; do
        case "$1" in
            -y|--yes) YES=1 ;;
            -n|--dry-run) DRY=1 ;;
            -f|--force) FORCE=1 ;;
            --only) shift; [ $# -gt 0 ] || die "--only needs a list, for example: --only theme,icons"; ONLY="$1" ;;
            --only=*) ONLY="${1#--only=}" ;;
            --list) list; exit 0 ;;
            --restore) preflight; restore; exit 0 ;;
            -h|--help) usage; exit 0 ;;
            *) die "Unknown option: $1 (try --help)" ;;
        esac
        shift
    done

    preflight

    if [ -n "$ONLY" ]; then
        for id in "${IDS[@]}"; do ON[$id]=0; done
        local IFS=','
        for id in $ONLY; do
            [ -n "${TITLE[$id]:-}" ] || die "Unknown component: $id (see --list)"
            ON[$id]=1
        done
        unset IFS
    elif [ "$YES" -eq 0 ]; then
        [ -t 0 ] && [ -t 1 ] || die "No terminal for the menu. Use --yes, or --only <list>."
        menu
    fi

    for id in "${IDS[@]}"; do [ "${ON[$id]}" -eq 1 ] && sel+=("$id"); done
    [ "${#sel[@]}" -gt 0 ] || { say " Nothing selected."; exit 0; }
    total=${#sel[@]}

    banner
    info "Installing ${B}$total${R} component(s): ${CY}${sel[*]}${R}"
    [ "$DRY" -eq 1 ] && warn "Dry run: commands are shown, nothing is changed."
    for id in "${sel[@]}"; do [ "${SUDO[$id]}" -eq 1 ] && need_sudo=1; done
    if [ "$YES" -eq 0 ] && [ "$DRY" -eq 0 ]; then
        confirm "Go ahead?" || { say " Nothing installed."; exit 0; }
    fi

    if [ "$DRY" -eq 0 ]; then
        mkdir -p "$STATE"
        : > "$LOG"
        REASON_FILE="$(mktemp "$STATE/.reason.XXXXXX")"
        if [ "$need_sudo" -eq 1 ]; then
            info "Some components need administrator rights."
            if ! sudo -v; then
                warn "No sudo access: skipping the components that need it."
                for id in "${IDS[@]}"; do [ "${SUDO[$id]}" -eq 1 ] && ON[$id]=0; done
                sel=(); for id in "${IDS[@]}"; do [ "${ON[$id]}" -eq 1 ] && sel+=("$id"); done
                total=${#sel[@]}
                [ "$total" -gt 0 ] || die "Nothing left to install."
            fi
        fi
    else
        REASON_FILE="$(mktemp)"
    fi

    make_backup
    for id in "${sel[@]}"; do
        idx=$((idx + 1))
        run_step "$id" "$idx" "$total"
    done
    local rc=0
    summary || rc=1
    # offer the app picker right away when Layers was just installed interactively
    if [ "$DRY" -eq 0 ] && [ "$YES" -eq 0 ] && [ -z "$ONLY" ] && [ "${RESULT[layers]:-}" = ok ] \
        && [ -t 0 ] && [ -x "$HOME/.local/bin/copland-layers" ]; then
        if confirm "Choose which apps open on which layer now?"; then "$HOME/.local/bin/copland-layers" || true; fi
    fi
    exit "$rc"
}

main "$@"
