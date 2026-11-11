#!/usr/bin/env bash
# Build the copland-os-desktop Debian package (no root needed).
#
#   ./packaging/build-deb.sh          -> packaging/out/copland-os-desktop_<version>_all.deb
#
# The files come from the same code as "sudo ./install.sh --system": it is run with
# --root into a staging folder. The steps that must act on the target system
# (diversions, the .bashrc line, the console font, the boot theme) are in
# packaging/debian/{preinst,postinst,postrm}.
# Version: packaging/VERSION plus the Debian release from iso/release.conf,
# for example 0.1.0+deb13.
set -Eeuo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
OUT="$HERE/out"
PKG=copland-os-desktop

say() { printf ' > %s\n' "$*"; }
die() { printf '\n x %s\n' "$*" >&2; exit 1; }

command -v dpkg-deb >/dev/null || die "dpkg-deb is required."
[ -f "$HERE/VERSION" ] || die "packaging/VERSION is missing."
# shellcheck source=/dev/null
. "$REPO/iso/release.conf"
VERSION="$(tr -d ' \n' < "$HERE/VERSION")+deb${DEBIAN_VERSION}"
case "$VERSION" in *[!0-9A-Za-z.+~-]*) die "Bad version: $VERSION" ;; esac

STAGE="$(mktemp -d "${TMPDIR:-/tmp}/copland-deb.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
ROOT="$STAGE/root"
mkdir -p "$ROOT"

say "Staging files with install.sh --system --root (helpers in /usr/bin)"
NO_COLOR=1 COPLAND_SYS_BIN=/usr/bin "$REPO/install.sh" --root "$ROOT" --yes --no-packages --no-rebuild \
    --only theme,icons,cursors,wallpaper,panel,terminal,layers,keys,browsers,greeter,boot > "$STAGE/stage.log" 2>&1 \
    || { cat "$STAGE/stage.log"; die "Staging failed."; }
grep -q 'failed' "$STAGE/stage.log" && grep -q '✖ [1-9]' "$STAGE/stage.log" && { cat "$STAGE/stage.log"; die "A component failed while staging."; }

# the installer's own records are not part of the package
rm -rf "$ROOT/var/lib/copland-os"
rmdir "$ROOT/var/lib" "$ROOT/var" 2>/dev/null || true
# GRUB reads its theme from /boot; ship it under /usr/share, postinst copies it
if [ -d "$ROOT/boot/grub/themes/copland" ]; then
    mkdir -p "$ROOT/usr/share/copland-os"
    mv "$ROOT/boot/grub/themes/copland" "$ROOT/usr/share/copland-os/grub-theme"
    rm -rf "$ROOT/boot"
fi
[ -L "$ROOT/usr/share/backgrounds/xfce/xfce-x.svg" ] || die "Wallpaper link missing from staging."

# licence and credits
DOC="$ROOT/usr/share/doc/$PKG"
mkdir -p "$DOC"
{
    echo "Copland OS ($PKG $VERSION)"
    echo "Source: https://github.com/anas1412/copland-os"
    echo
    echo "A non-commercial fan project. Third-party parts and their terms:"
    sed -n '/^## Credits/,$p' "$REPO/README.md" | sed '1d'
    echo
    echo "Retrosmart cursors: GPL-3.0, full text in /usr/share/common-licenses/GPL-3."
} > "$DOC/copyright"

# control files
mkdir -p "$ROOT/DEBIAN"
SIZE=$(du -sk --exclude=DEBIAN "$ROOT" | cut -f1)
sed -e "s/@VERSION@/$VERSION/" -e "s/@SIZE@/$SIZE/" -e "s/@DEBIAN_VERSION@/$DEBIAN_VERSION/" \
    "$HERE/debian/control.in" > "$ROOT/DEBIAN/control"
install -m 755 "$HERE/debian/preinst" "$HERE/debian/postinst" "$HERE/debian/postrm" "$ROOT/DEBIAN/"
# every file under /etc is a configuration file: local edits survive upgrades
(cd "$ROOT" && find etc -type f | sed 's|^|/|' | sort) > "$ROOT/DEBIAN/conffiles"
# permissions: no group or world write anywhere
chmod -R go-w "$ROOT"

mkdir -p "$OUT"
DEB="$OUT/${PKG}_${VERSION}_all.deb"
dpkg-deb --root-owner-group -Zxz --build "$ROOT" "$DEB" >/dev/null
say "Built $DEB ($(du -h "$DEB" | cut -f1), $(wc -l < "$ROOT/DEBIAN/conffiles") configuration files)"
