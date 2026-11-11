#!/usr/bin/env bash
# Copland OS installer for Debian XFCE.
#
#   curl -fsSL https://raw.githubusercontent.com/anas1412/copland-os/main/install.sh | bash
#                             one-liner: downloads everything, then opens the menu
#   ./install.sh              interactive menu (from a clone)
#   ./install.sh --yes        install the default selection without asking
#   ./install.sh --dry-run    show every change, make none
#   ./install.sh --only a,b   pick components by id (see --list)
#   ./install.sh --list       list components
#   ./install.sh --restore    put back the settings saved by the last run
#   sudo ./install.sh --system              install for every user (themes in /usr/share,
#                                           defaults in /etc/xdg/copland-os, /etc/skel)
#   sudo ./install.sh --system --uninstall  remove what --system installed
#
# Safe by design: never runs as root, backs up before it changes anything,
# runs every component on its own (one failure does not stop the rest),
# and writes a full log.
set -Eeuo pipefail

VERSION="1.0"
REPO_SLUG="anas1412/copland-os"
# When run as a one-liner there is no script file, so this resolves to the current folder;
# bootstrap() then downloads the rest.
SRC="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || pwd)"
CORE="$SRC/core"
BIN_DIR="$HOME/.local/bin"
ASSETS="$CORE/assets"
CONFIG="$CORE/config"
BINSRC="$CORE/bin"
STATE="${XDG_DATA_HOME:-$HOME/.local/share}/copland-os"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$STATE/backups/$STAMP"
LOG="$STATE/install-$STAMP.log"
REASON_FILE=""
DRY=0; YES=0; ONLY=""
SYSTEM=0; ROOT_DIR="/"; NO_PACKAGES=0; NO_REBUILD=0; UNINSTALL=0
STEP_PREFIX=step          # step_<id> per-user, sys_<id> with --system

THEME_DIR="$HOME/.themes/CoplandOS"
WALL="$HOME/.local/share/backgrounds/CoplandOS.png"
XML_DIR="$HOME/.config/xfce4/xfconf/xfce-perchannel-xml"
CHANNELS=(xsettings xfwm4 xfce4-panel xfce4-desktop xfce4-terminal xfce4-keyboard-shortcuts xfce4-notifyd)
GREETER=/etc/lightdm/lightdm-gtk-greeter.conf
GRUB=/etc/default/grub
CURSOR_THEME="retrosmart-xcursor-mac-ish-classic"
PLYMOUTH_REPO="https://github.com/faisalhsn/copland-plymouth-theme.git"
PLYMOUTH_COMMIT="4e336d9e264723634ae1ed5dd38888cd2ab37c52"   # pinned: the repo is third-party

PACKAGES=(xfce4-whiskermenu-plugin xfce4-pulseaudio-plugin xfce4-terminal xfce4-notifyd
          adwaita-icon-theme fonts-urw-base35 fonts-dejavu-core
          fonts-dejavu-mono gtk2-engines-murrine libgtk-3-bin python3 fastfetch devilspie2 btop)

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
have() { command -v "$1" >/dev/null 2>&1; }
die()  { printf '\n %s%s %s%s\n' "$RD" "$G_FAIL" "$*" "$R" >&2; exit 1; }
# ------------------------------------------------------------------- library
# Run from a clone or a downloaded copy: load the rest of the installer. Run as a
# one-liner (no files next to this script): main() downloads the repo first.
if [ -d "$SRC/lib" ]; then
    for _f in ui common components system; do
        # shellcheck source=/dev/null
        . "$SRC/lib/$_f.sh"
    done
    unset _f
fi

usage() {
    cat <<USAGE
Copland OS installer for Debian XFCE.

  curl -fsSL https://raw.githubusercontent.com/$REPO_SLUG/main/install.sh | bash
                            one-liner: downloads everything, then opens the menu
  ./install.sh              interactive menu (from a clone)
  ./install.sh --yes        install the default selection without asking
  ./install.sh --dry-run    show every change, make none
  ./install.sh --only a,b   pick components by id (see --list)
  ./install.sh --list       list components
  ./install.sh --restore    put back the settings saved by the last run

System-wide (every user; needs sudo; Debian-based systems):
  sudo ./install.sh --system               install, with the same component ids
  sudo ./install.sh --system --uninstall   remove what --system installed
  options: --root DIR (write under DIR), --no-packages, --no-rebuild (skip initramfs/GRUB)

With the one-liner, pass options after 'bash -s --':
  curl -fsSL .../install.sh | bash -s -- --dry-run
Set COPLAND_REF to install a tag or commit instead of main.
USAGE
}

# bootstrap: when started without the rest of the repo next to it (the curl one-liner),
# download the repository tarball and run the real copy from there.
bootstrap() {
    [ -d "$CORE" ] && return 0
    local ref="${COPLAND_REF:-main}" dest="$STATE/src" tmp
    have curl || die "curl is required to download Copland OS."
    have tar  || die "tar is required to unpack Copland OS."
    printf ' %s%s%s Downloading %s (%s)...\n' "$CY" "$G_PTR" "$R" "$REPO_SLUG" "$ref"
    mkdir -p "$STATE"
    tmp="$(mktemp -d "$STATE/.download.XXXXXX")"
    if [ -n "${COPLAND_TARBALL:-}" ]; then
        # testing aid: use a local archive instead of downloading
        cp "$COPLAND_TARBALL" "$tmp/src.tar.gz" || { rm -rf "$tmp"; die "Cannot read COPLAND_TARBALL=$COPLAND_TARBALL"; }
    elif ! curl -fsSL --retry 2 -o "$tmp/src.tar.gz" "https://codeload.github.com/$REPO_SLUG/tar.gz/$ref" 2>/dev/null; then
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
    [ -f "$tmp/src/install.sh" ] && [ -d "$tmp/src/core" ] \
        || { rm -rf "$tmp"; die "The download does not look like the Copland OS repository."; }
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
    case " $* " in *" -h "*|*" --help "*) ;; *) bootstrap "$@" ;; esac
    local id sel=() total idx=0 need_sudo=0
    while [ $# -gt 0 ]; do
        case "$1" in
            -y|--yes) YES=1 ;;
            -n|--dry-run) DRY=1 ;;
            --only) shift; [ $# -gt 0 ] || die "--only needs a list, for example: --only theme,icons"; ONLY="$1" ;;
            --only=*) ONLY="${1#--only=}" ;;
            --list) list; exit 0 ;;
            --restore) preflight; restore; exit 0 ;;
            --system) SYSTEM=1 ;;
            --root) shift; [ $# -gt 0 ] || die "--root needs a folder"; ROOT_DIR="$1"; SYSTEM=1 ;;
            --root=*) ROOT_DIR="${1#--root=}"; SYSTEM=1 ;;
            --no-packages) NO_PACKAGES=1 ;;
            --no-rebuild) NO_REBUILD=1 ;;
            --uninstall) UNINSTALL=1 ;;
            -h|--help) usage; exit 0 ;;
            *) die "Unknown option: $1 (try --help)" ;;
        esac
        shift
    done

    if [ "$SYSTEM" -eq 1 ]; then system_main; fi
    [ "$UNINSTALL" -eq 0 ] || die "--uninstall goes with --system (per-user: use --restore)."
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
