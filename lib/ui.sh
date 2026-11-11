# shellcheck shell=bash
# Copland OS installer: banner, menu and prompts
# Sourced by install.sh; not meant to be run on its own.

rule() { local i s=""; for ((i = 0; i < 62; i++)); do s+="$G_LINE"; done; printf ' %s%s%s\n' "$BL" "$s" "$R"; }

banner() {
    # the LainOS logo (Navi eye) from fastfetch, MIT licence
    printf '%s' "$CY"
    cat <<'EOF'
                    /==\
                    \==/
               · · · · · · ·
            · · · · · · · · · ·
           · · · .-======-.· · · ·
        .::. ·.-============-.· .::.
     .:==:· .:===:'. ·· .':===:. ·:==:.
  .:===: · :===. ·  .--.  · .===: · :===:.
 :===:· · :===. · .:====:. · .===: · ·:===:
(===:· · :===- ·  :======:  · -===: · ·:===)
 :===:· · :===. · ':====:' · .===: · ·:===:
  ':===: · :===. ·  '--'  · .===: · :===:'
     ':==:· ':===:.' ·· '.:===:' ·:==:'
        '::' · '===-.  .-===' · '::'
  /==\     · · · :===  ===: · · ·     /==\
  \==/      · · ·:=== ·===:· · ·      \==/
         .-.   · :===· ===: ·   .-.
         .===.   .===  ===.   .===.
           .========    ========.
             '''''        '''''
EOF
    printf '%s\n' "$R"
    printf '        %s%sC O P L A N D   O S   E N T E R P R I S E%s\n' "$B" "$TX" "$R"
    printf '        %sTachibana General Laboratories %s·%s dotfiles installer v%s%s\n\n' "$DM" "$BL" "$DM" "$VERSION" "$R"
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
