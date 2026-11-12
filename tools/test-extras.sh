#!/usr/bin/env bash
# Test core/bin/copland-extras for real: install every item into a clean Debian system
# and check what each one leaves behind. Meant for a throwaway container (CI runs it in
# debian:trixie, .github/workflows/extras.yml); it changes the system it runs on.
#
#   tools/test-extras.sh            install everything, check it, run it again
#   tools/test-extras.sh --offline  only check that it stops cleanly without a network
set -uo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
TOOL="$HERE/core/bin/copland-extras"
U=tester
FAIL=0
ok()   { printf '  ok    %s\n' "$*"; }
bad()  { printf '  FAIL  %s\n' "$*"; FAIL=1; }
check() { local what=$1; shift; if "$@" >/dev/null 2>&1; then ok "$what"; else bad "$what"; fi; }

[ "$(id -u)" -eq 0 ] || { echo "run as root, in a throwaway system"; exit 2; }
export DEBIAN_FRONTEND=noninteractive

if [ "${1:-}" = --offline ]; then
    out="$(timeout 120 "$TOOL" python 2>&1)"; rc=$?
    echo "$out"
    [ $rc -eq 1 ] && ok "exits 1 without a network" || bad "exit code $rc without a network (want 1)"
    grep -q 'no internet connection' <<<"$out" && ok "says why" || bad "no 'no internet connection' message"
    grep -q 'Try again later with: sudo copland-extras python' <<<"$out" && ok "says what to run later" || bad "no retry command"
    exit $FAIL
fi

# a system like a fresh Copland install, as far as copland-extras needs: the tools it
# calls, a user account, Debian's online sources with backports (as the installer writes)
apt-get update -q
apt-get install -y -q --no-install-recommends ca-certificates curl gpg passwd sudo python3 dbus xdg-utils debconf-utils >/dev/null
cat > /etc/apt/sources.list.d/debian-backports.sources <<'EOF'
Types: deb
URIs: http://deb.debian.org/debian
Suites: trixie-backports
Components: main
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF
id "$U" >/dev/null 2>&1 || useradd -m -s /bin/bash "$U"
H=/home/$U

ALL="$("$TOOL" --list | awk 'NF > 1 && $1 != "Apps" && $1 != "Developer" {print $1}' | tr '\n' ' ')"
echo "== installing: $ALL"
"$TOOL" --user "$U" $ALL; rc=$?
echo "== copland-extras exited $rc"
[ $rc -eq 0 ] && ok "every item installed" || bad "copland-extras exited $rc"

echo "== packages"
for p in brave-origin libreoffice-writer libreoffice-calc libreoffice-impress libreoffice-gtk3 thunderbird gimp \
         vlc qt5-gtk-platformtheme obs-studio keepassxc qt6-gtk-platformtheme flatpak xdg-desktop-portal-gtk \
         code python3-pip python3-venv pipx nodejs golang-go rustup build-essential openjdk-25-jdk cmake gdb \
         docker-ce docker-compose-plugin docker-buildx-plugin podman podman-compose; do
    check "$p installed" dpkg-query -W -f='${Status}' "$p"
done

echo "== versions are the current ones"
node_major="$(node --version | sed 's/^v//; s/\..*//')"
[ "${node_major:-0}" -ge 24 ] && ok "node $(node --version)" || bad "node $(node --version 2>&1), want 24 or newer"
go_minor="$(go version | sed -n 's/.*go1\.\([0-9]*\).*/\1/p')"
[ "${go_minor:-0}" -ge 26 ] && ok "$(go version)" || bad "$(go version 2>&1), want go1.26 or newer (backports)"
check "rust toolchain for $U" runuser -u "$U" -- env HOME="$H" "$H/.cargo/bin/cargo" --version
runuser -u "$U" -- env HOME="$H" "$H/.cargo/bin/rustc" --version
java -version 2>&1 | head -1 | grep -q '"25' && ok "java 25" || bad "java: $(java -version 2>&1 | head -1)"
check "docker compose" docker compose version
check "podman-compose" podman-compose --version

echo "== sources: one per vendor, and apt is happy with them"
for v in brave-browser-apt-release.s3.brave.com packages.microsoft.com/repos/code deb.nodesource.com download.docker.com; do
    n="$(grep -rl "$v" /etc/apt/sources.list.d/ | wc -l)"
    [ "$n" -eq 1 ] && ok "$v: one source file" || bad "$v: $n source files"
done
upd="$(apt-get update 2>&1)"
grep -q -E '^(W|E):' <<<"$upd" && bad "apt-get update warns: $(grep -E '^(W|E):' <<<"$upd" | head -3)" || ok "apt-get update without warnings"

echo "== the Copland look"
check "Brave colour policy" grep -q '"BrowserThemeColor": "#25346a"' /etc/brave/policies/managed/copland-theme.json
check "Brave is x-www-browser" sh -c 'readlink -f /etc/alternatives/x-www-browser | grep -q brave'
check "links open in Brave ($U)" grep -q '^x-scheme-handler/https=brave' "$H/.config/mimeapps.list"
check "VS Code settings are valid JSON" python3 -c "import json; json.load(open('$H/.config/Code/User/settings.json'))"
check "VS Code uses the window frame" grep -q '"window.titleBarStyle": "native"' "$H/.config/Code/User/settings.json"
check "OBS Copland theme" grep -q "id: 'com.obsproject.Yami.Copland'" "$H/.config/obs-studio/themes/Copland.ovt"
check "OBS theme chosen" grep -q '^Theme=com.obsproject.Yami.Copland' "$H/.config/obs-studio/global.ini"
check "OBS has the theme Copland extends" test -e /usr/share/obs/obs-studio/themes/Yami.obt
check "GIMP System theme" grep -q '(theme "System")' "$H/.config/GIMP/3.0/gimprc"
check "GIMP has a System theme" test -d /usr/share/gimp/3.0/themes/System
check "$U owns its settings" sh -c "! find '$H' ! -user $U | grep -q ."
check "Flathub added" sh -c 'flatpak remotes --system | grep -q flathub'
check "$U is in the docker group" sh -c "id -nG $U | grep -qw docker"

echo "== a second run changes nothing it should not"
"$TOOL" --user "$U" vscode gimp > /tmp/second.log 2>&1; rc=$?
[ $rc -eq 0 ] && ok "second run exits 0" || bad "second run exited $rc"
check "keeps existing settings" grep -q "kept your $H/.config/Code/User/settings.json" /tmp/second.log

echo
[ $FAIL -eq 0 ] && echo "ALL CHECKS PASSED" || echo "SOME CHECKS FAILED"
exit $FAIL
