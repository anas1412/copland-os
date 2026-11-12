# shellcheck shell=bash
# Copland OS installer: error handling, helpers, checks, backups, runner, restore
# Sourced by install.sh; not meant to be run on its own.

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
# copland_version: the Copland OS version this copy of the repo installs (iso/release.conf),
# or the build's own label when a package or image build sets COPLAND_BUILD_VERSION
copland_version() {
    if [ -n "${COPLAND_BUILD_VERSION:-}" ]; then printf '%s' "$COPLAND_BUILD_VERSION"; return; fi
    ( . "$SRC/iso/release.conf" 2>/dev/null && printf '%s' "${COPLAND_VERSION:-}" )
}

# run: execute a command, or only print it in --dry-run
run() {
    if [ "$DRY" -eq 1 ]; then printf '      %s[dry-run]%s %s\n' "$DM" "$R" "$*"; else "$@"; fi
}
# skip: leave a component early with a reason (runs inside the component's subshell)
skip() { printf '%s' "$*" > "$REASON_FILE"; echo "SKIP: $*"; exit 3; }
note() { printf '%s' "$*" > "$REASON_FILE"; [ "$DRY" -eq 1 ] || echo "NOTE: $*"; }
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
# apply_settings <component> [skip-regex]: apply that component's rows of core/settings.tsv
# to the current user with xfconf-query. Placeholders: @THEME@, @BIN@.
apply_settings() {
    local comp=$1 skip_re=${2:-} c ch prop type val parts=()
    while IFS=$'\t' read -r -u 3 c ch prop type val; do
        [ -n "$c" ] && [ "${c:0:1}" != "#" ] && [ "$c" = "$comp" ] || continue
        if [ -n "$skip_re" ] && [[ "$prop" =~ $skip_re ]]; then continue; fi
        val=${val//@THEME@/$THEME_DIR}
        val=${val//@BIN@/$BIN_DIR}
        if [ "${type#array:}" != "$type" ]; then
            IFS='|' read -r -a parts <<< "$val"
            xf_arr "$ch" "$prop" "${type#array:}" "${parts[@]}"
        else
            xf "$ch" "$prop" "$type" "$val"
        fi
    done 3< "$CORE/settings.tsv"
}
pkg_installed() { [ "$(dpkg-query -W -f='${db:Status-Abbrev}' "$1" 2>/dev/null)" = "ii " ]; }
plugin_exists() { compgen -G "/usr/lib/*/xfce4/panel/plugins/lib$1.so" >/dev/null; }

# ---------------------------------------------------------------- preflight
preflight() {
    [ "${BASH_VERSINFO[0]}" -ge 4 ] || die "bash 4 or newer is required."
    [ "$EUID" -ne 0 ] || die "Do not run this as root. Run it as your own user; it asks for sudo only where needed."
    local f
    for f in assets/themes/CoplandOS/gtk-3.0/gtk.css assets/themes/CoplandOS/xfwm4/themerc assets/backgrounds/CoplandOS.png \
             assets/icons/NineIcons/index.theme "assets/cursors/$CURSOR_THEME/index.theme" \
             config/fastfetch/config.jsonc bin/copland-goto bin/copland-send bin/copland-extras; do
        [ -e "$CORE/$f" ] || die "The Copland OS folder is incomplete: core/$f is missing."
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
    [ -f "$HOME/.config/btop/btop.conf" ] && cp -a "$HOME/.config/btop/btop.conf" "$BACKUP/btop.conf"
    printf 'Copland OS installer backup, %s\nRestore with: %s/install.sh --restore\n' "$STAMP" "$SRC" > "$BACKUP/README"
    ln -sfn "$BACKUP" "$STATE/backups/latest"
    info "Backup saved: ${DM}$BACKUP${R}"
}

# ------------------------------------------------------------------- runner
run_step() {
    local id=$1 idx=$2 total=$3 rc=0 pid i=0 label
    label="$(printf '[%02d/%02d] %-15s' "$idx" "$total" "${TITLE[$id]}")"
    : > "$REASON_FILE"
    if [ "$DRY" -eq 1 ]; then
        printf '\n %s%s%s\n' "$CY" "$label" "$R"
        ( "${STEP_PREFIX}_$id" ) || rc=$?
    else
        printf '\n==== %s (%s) ====\n' "$id" "$(date +%T)" >> "$LOG"
        # background subshell: 'set -e' stays active inside it, and one failure cannot stop the others
        ( trap - ERR INT TERM; set -Eeuo pipefail; "${STEP_PREFIX}_$id" ) >> "$LOG" 2>&1 &
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

# Copland OS once sorted apps into layers with devilspie2 and a picker, copland-layers.
# That feature is gone; remove what an older install left, and only our own files: the
# rules file and the autostart entry are checked for their Copland header first.
remove_old_layer_rules() {
    local cfg="${XDG_CONFIG_HOME:-$HOME/.config}" f stop=0
    f="$cfg/devilspie2/layers.lua"
    if [ -f "$f" ] && head -1 "$f" | grep -q '^-- Copland OS layers'; then run rm -f "$f"; fi
    f="$cfg/autostart/devilspie2.desktop"
    if [ -f "$f" ] && grep -q '^Name=Copland OS layers$' "$f"; then run rm -f "$f"; stop=1; fi
    for f in "$HOME/.local/bin/copland-layers" "$HOME/.local/share/applications/copland-layers.desktop" "$cfg/copland-os/layers.conf"; do
        if [ -e "$f" ]; then run rm -f "$f"; fi
    done
    if [ "$stop" -eq 1 ] && [ "$DRY" -eq 0 ]; then pkill -u "$EUID" -x devilspie2 2>/dev/null || true; fi
    return 0
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
    [ -f "$src/btop.conf" ] && cp -a "$src/btop.conf" "$HOME/.config/btop/btop.conf"
    remove_old_layer_rules
    if [ -f "$GREETER.copland-bak" ] && confirm "Also restore the login screen config (sudo)?"; then
        sudo cp -a "$GREETER.copland-bak" "$GREETER" && info "Login screen restored."
    fi
    if [ -f "$AUTOLOGIN_DROPIN" ] && confirm "Also turn off automatic login (sudo)?"; then
        sudo rm -f "$AUTOLOGIN_DROPIN" && info "Automatic login off from the next startup."
    fi
    if [ -f "$GRUB.copland-bak" ] && confirm "Also restore the boot settings (sudo, rebuilds the initramfs)?"; then
        sudo cp -a "$GRUB.copland-bak" "$GRUB"
        sudo /usr/sbin/plymouth-set-default-theme -R "$(cat /etc/copland-prev-plymouth 2>/dev/null || echo text)"
        sudo /usr/sbin/update-grub && info "Boot settings restored."
    fi
    say; info "Done. Log out and back in to load the restored settings."
}
