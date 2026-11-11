#!/usr/bin/env bash
# Build CoplandOS.iso: Debian 13 (trixie) + XFCE, with Copland OS applied system-wide.
#
#   sudo ./iso/build.sh              build iso/out/CoplandOS-<date>-amd64.iso (+ .sha256)
#   sudo ./iso/build.sh --clean      remove the work folder, including its package cache
#   ./iso/build.sh --check           only run the checks, no root needed
#
# Needs: root, live-build, debootstrap, wget, about 20 GB free and a network
# connection. The work folder is /var/tmp/coplandos-build (override with
# COPLAND_ISO_WORK=/path); it is reused, so a second build downloads much less.
set -Eeuo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
WORK="${COPLAND_ISO_WORK:-/var/tmp/coplandos-build}"
OUT="$HERE/out"
NEED_GB=20
PLYMOUTH_REPO="https://github.com/faisalhsn/copland-plymouth-theme.git"
PLYMOUTH_COMMIT="4e336d9e264723634ae1ed5dd38888cd2ab37c52"   # same pin as install.sh

say()  { printf ' > %s\n' "$*"; }
die()  { printf '\n x %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

checks() {
    local missing=() p
    for p in lb debootstrap wget git tar; do have "$p" || missing+=("$p"); done
    if [ "${#missing[@]}" -gt 0 ]; then
        die "Missing tools: ${missing[*]}. Install them with:  sudo apt install live-build debootstrap wget git"
    fi
    [ -f "$REPO/install.sh" ] && [ -d "$REPO/core" ] && [ -d "$REPO/lib" ] || die "Run this from the copland-os-dotfiles repository."
    mkdir -p "$WORK" 2>/dev/null || true
    local dir="$WORK"; [ -d "$dir" ] || dir="$(dirname "$WORK")"
    local free_gb
    free_gb=$(( $(df -Pk "$dir" | awk 'NR==2 {print $4}') / 1024 / 1024 ))
    [ "$free_gb" -ge "$NEED_GB" ] || die "Only ${free_gb} GB free at $dir; the build needs about ${NEED_GB} GB."
    case "$(findmnt -n -o FSTYPE -T "$dir" 2>/dev/null || true)" in
        tmpfs) die "$dir is in memory (tmpfs). Set COPLAND_ISO_WORK to a folder on disk." ;;
    esac
    case "$(findmnt -n -o OPTIONS -T "$dir" 2>/dev/null || true)" in
        *noexec*|*nodev*) die "$dir is mounted noexec or nodev; live-build needs both allowed." ;;
    esac
    say "Checks passed: tools present, ${free_gb} GB free at $dir"
}

stage() {
    local inc="$WORK/config/includes.chroot_after_packages"
    say "Preparing $WORK"
    # keep live-build's package cache between builds, refresh everything else
    if [ -d "$WORK/cache" ]; then mv "$WORK/cache" "$WORK.cache"; fi
    rm -rf "$WORK"
    mkdir -p "$WORK"
    if [ -d "$WORK.cache" ]; then mv "$WORK.cache" "$WORK/cache"; fi
    cp -a "$HERE/auto" "$HERE/config" "$WORK"/

    say "Copying the Copland OS installer into the image (/usr/share/copland-os)"
    mkdir -p "$inc/usr/share/copland-os"
    tar -C "$REPO" --exclude=.git --exclude=iso --exclude=docs -cf - . | tar -C "$inc/usr/share/copland-os" -xf -

    say "Fetching the boot animation (pinned commit ${PLYMOUTH_COMMIT:0:7})"
    local src="$inc/usr/share/copland-os/plymouth-src"
    git clone -q "$PLYMOUTH_REPO" "$src.git"
    git -C "$src.git" -c advice.detachedHead=false checkout -q "$PLYMOUTH_COMMIT"
    [ -f "$src.git/copland/copland.plymouth" ] || die "Unexpected layout in $PLYMOUTH_REPO"
    mkdir -p "$src"
    cp -a "$src.git/copland" "$src/copland"
    rm -rf "$src.git"
}

build() {
    cd "$WORK"
    say "lb config"
    lb config
    say "lb build (this takes a while; the log is $WORK/build.log)"
    lb build
    local iso="$WORK/CoplandOS-amd64.hybrid.iso"
    [ -f "$iso" ] || die "The build finished without an ISO. Read $WORK/build.log."
    mkdir -p "$OUT"
    local name
    name="CoplandOS-$(date +%Y%m%d)-amd64.iso"
    mv "$iso" "$OUT/$name"
    (cd "$OUT" && sha256sum "$name" > "$name.sha256")
    # give the result to the user who ran sudo
    if [ -n "${SUDO_UID:-}" ]; then chown -R "$SUDO_UID:${SUDO_GID:-$SUDO_UID}" "$OUT"; fi
    local size
    size=$(du -h "$OUT/$name" | cut -f1)
    say "Done: $OUT/$name ($size)"
    say "Checksum: $OUT/$name.sha256"
    local bytes
    bytes=$(stat -c %s "$OUT/$name")
    if [ "$bytes" -ge $((2 * 1024 * 1024 * 1024)) ]; then
        say "Note: the image is 2 GiB or larger, above GitHub's per-file release limit."
    fi
}

case "${1:-}" in
    --check) checks; exit 0 ;;
    --clean)
        [ "$EUID" -eq 0 ] || die "Run with sudo."
        if [ -d "$WORK" ]; then (cd "$WORK" && lb clean --purge >/dev/null 2>&1 || true); rm -rf "$WORK"; fi
        say "Removed $WORK"; exit 0 ;;
    "") ;;
    -h|--help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "Unknown option: $1 (try --help)" ;;
esac

[ "$EUID" -eq 0 ] || die "Building an image needs root:  sudo ./iso/build.sh"
checks
stage
build
