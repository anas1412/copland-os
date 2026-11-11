#!/usr/bin/env bash
# Build CoplandOS.iso: upstream Debian (release set in iso/release.conf) + XFCE,
# with Copland OS installed as the copland-os-desktop package, so installed systems
# get Copland updates from its apt repository like any other package.
#
#   sudo ./iso/build.sh              build iso/out/CoplandOS-<version>-deb<debian>-amd64.iso (+ .sha256)
#   sudo ./iso/build.sh --clean      remove the work folder, including its package cache
#   ./iso/build.sh --check           only run the checks, no root needed
#
# Needs: root, live-build, debootstrap, wget, dpkg-deb, gpgv, about 20 GB free, a
# network connection, and the apt repository published (packaging/publish-repo.sh):
# the image's apt source points at it. The work folder is /var/tmp/coplandos-build (override with
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
have() { command -v "$1" >/dev/null 2>&1 || [ -x "/usr/sbin/$1" ] || [ -x "/sbin/$1" ]; }

load_release() {
    [ -f "$HERE/release.conf" ] || die "iso/release.conf is missing."
    # shellcheck source=/dev/null
    . "$HERE/release.conf"
    [ -n "${COPLAND_VERSION:-}" ] && [ -n "${DEBIAN_CODENAME:-}" ] && [ -n "${DEBIAN_VERSION:-}" ] && [ -n "${COPLAND_APT_URL:-}" ] \
        || die "iso/release.conf must set COPLAND_VERSION, DEBIAN_CODENAME, DEBIAN_VERSION and COPLAND_APT_URL."
    case "$DEBIAN_CODENAME$DEBIAN_VERSION" in *[!a-z0-9]*) die "iso/release.conf: unexpected characters." ;; esac
    [[ "$COPLAND_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "iso/release.conf: COPLAND_VERSION must look like 0.1.0."
    if [ -d /usr/share/debootstrap/scripts ] && [ ! -e "/usr/share/debootstrap/scripts/$DEBIAN_CODENAME" ]; then
        die "debootstrap does not know Debian '$DEBIAN_CODENAME'; update debootstrap or fix iso/release.conf."
    fi
}

checks() {
    local missing=() p
    for p in lb debootstrap wget git tar dpkg-deb gpgv; do have "$p" || missing+=("$p"); done
    if [ "${#missing[@]}" -gt 0 ]; then
        die "Missing tools: ${missing[*]}. Install them with:  sudo apt install live-build debootstrap wget git gpgv"
    fi
    [ -f "$REPO/install.sh" ] && [ -d "$REPO/core" ] && [ -d "$REPO/lib" ] || die "Run this from the copland-os repository."
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
    # small machines: the squashfs compression is the step that needs the most memory
    local mem_mb
    mem_mb=$(( $(awk '/^MemTotal:/ {print $2}' /proc/meminfo) / 1024 ))
    if [ "$mem_mb" -lt 6144 ]; then
        export MKSQUASHFS_OPTIONS="${MKSQUASHFS_OPTIONS:-} -processors 2 -mem 768M"
        say "Low memory (${mem_mb} MB): image compression limited to 2 threads and 768 MB; close other apps while it runs"
    fi
    # the image's apt source must work from the first boot (and live-build runs apt
    # update with it at the end): the repository has to be published and signed by the
    # key the image trusts
    local keyring="$REPO/packaging/copland-os-archive-keyring.gpg" rel
    [ -f "$keyring" ] || die "packaging/copland-os-archive-keyring.gpg is missing."
    rel="$(mktemp)"
    if ! wget -q -O "$rel" "$COPLAND_APT_URL/dists/$DEBIAN_CODENAME/InRelease"; then
        rm -f "$rel"
        die "The apt repository is not published at $COPLAND_APT_URL ($DEBIAN_CODENAME). Publish it first: docs/BUILDING.md, 'apt repository'."
    fi
    gpgv --keyring "$keyring" "$rel" >/dev/null 2>&1 || { rm -f "$rel"; die "$COPLAND_APT_URL serves an InRelease that packaging/copland-os-archive-keyring.gpg does not verify."; }
    rm -f "$rel"
    say "Checks passed: Copland OS $COPLAND_VERSION on Debian $DEBIAN_VERSION ($DEBIAN_CODENAME), tools present, apt repository signed and served, ${free_gb} GB free at $dir"
}

# fill FILE: put the release values from iso/release.conf into a staged file
fill() { sed -i -e "s/@COPLAND_VERSION@/$COPLAND_VERSION/g" -e "s/@DEBIAN_VERSION@/$DEBIAN_VERSION/g" "$1"; }

stage() {
    local inc="$WORK/config/includes.chroot_after_packages"
    say "Preparing $WORK"
    # keep live-build's package cache between builds, refresh everything else
    if [ -d "$WORK/cache" ]; then mv "$WORK/cache" "$WORK.cache"; fi
    rm -rf "$WORK"
    mkdir -p "$WORK"
    if [ -d "$WORK.cache" ]; then mv "$WORK.cache" "$WORK/cache"; fi
    cp -a "$HERE/auto" "$HERE/config" "$HERE/release.conf" "$WORK"/
    fill "$WORK/config/hooks/normal/0510-copland-installer.hook.chroot"

    say "Fetching the boot animation (pinned commit ${PLYMOUTH_COMMIT:0:7})"
    local ply="$WORK/plymouth-src"
    git clone -q "$PLYMOUTH_REPO" "$ply"
    git -C "$ply" -c advice.detachedHead=false checkout -q "$PLYMOUTH_COMMIT"
    [ -f "$ply/copland/copland.plymouth" ] || die "Unexpected layout in $PLYMOUTH_REPO"

    # the look goes in as the copland-os-desktop package: live-build installs every
    # .deb in config/packages.chroot with apt, so dpkg owns the files and apt can
    # update them later
    say "Building the copland-os-desktop package"
    mkdir -p "$WORK/config/packages.chroot"
    COPLAND_DEB_OUT="$WORK/deb" COPLAND_PLYMOUTH_SRC="$ply/copland" "$REPO/packaging/build-deb.sh"
    DEB="$(ls "$WORK"/deb/copland-os-desktop_*_all.deb)"
    cp "$DEB" "$WORK/config/packages.chroot/"

    say "Adding the Copland apt source, its key and the console login line"
    install -D -m 644 "$REPO/packaging/copland-os-archive-keyring.gpg" "$inc/usr/share/keyrings/copland-os-archive-keyring.gpg"
    mkdir -p "$inc/etc/apt/sources.list.d"
    printf 'Types: deb\nURIs: %s\nSuites: %s\nComponents: main\nSigned-By: /usr/share/keyrings/copland-os-archive-keyring.gpg\n' \
        "$COPLAND_APT_URL" "$DEBIAN_CODENAME" > "$inc/etc/apt/sources.list.d/copland-os.sources"
    # /etc/issue belongs to base-files, so the package leaves it alone; the image sets it
    install -D -m 644 "$REPO/core/config/issue" "$inc/etc/issue"

    # installer branding, used once by the 0510 hook and removed again
    mkdir -p "$inc/usr/share/copland-os/iso-branding"
    cp -a "$HERE/branding/." "$inc/usr/share/copland-os/iso-branding/"
    fill "$inc/usr/share/copland-os/iso-branding/branding.desc"
    if grep -rqE '@(COPLAND|DEBIAN)_VERSION@' "$WORK/config" "$inc/usr/share/copland-os/iso-branding"; then die "A release placeholder was left unfilled."; fi
}

# record_build NAME: what went into the image, next to it, so a build can be traced and repeated
record_build() {
    local name=$1 info="$OUT/${1%.iso}.build-info.txt" commit dirty="no"
    commit="$(git -c safe.directory="$REPO" -C "$REPO" rev-parse HEAD 2>/dev/null || echo unknown)"
    [ -z "$(git -c safe.directory="$REPO" -C "$REPO" status --porcelain 2>/dev/null)" ] || dirty="yes (uncommitted changes were included)"
    {
        echo "CoplandOS.iso build record"
        echo "image:          $name"
        echo "built:          $(date -u +%Y-%m-%dT%H:%MZ)"
        echo "repo commit:    $commit"
        echo "working copy:   ${dirty}"
        echo "live-build:     $(dpkg-query -W -f='${Version}' live-build 2>/dev/null || echo unknown)"
        echo "debootstrap:    $(dpkg-query -W -f='${Version}' debootstrap 2>/dev/null || echo unknown)"
        echo "copland os:     $COPLAND_VERSION, from iso/release.conf ($(basename "$DEB"))"
        echo "apt source:     $COPLAND_APT_URL $DEBIAN_CODENAME main"
        echo "debian release: $DEBIAN_VERSION ($DEBIAN_CODENAME), from iso/release.conf"
        echo "build host:     $(. /etc/os-release && echo "$PRETTY_NAME"), $(uname -m)"
        echo "boot animation: $PLYMOUTH_REPO @ $PLYMOUTH_COMMIT"
        echo "sha256:         $(cut -d' ' -f1 "$OUT/$name.sha256")"
        echo
        echo "Installed packages (name, version) are in ${name%.iso}.packages; the full build log is ${name%.iso}.build.log."
    } > "$info"
    [ -f "$WORK/CoplandOS-amd64.packages" ] && cp "$WORK/CoplandOS-amd64.packages" "$OUT/${name%.iso}.packages"
    [ -f "$WORK/build.log" ] && cp "$WORK/build.log" "$OUT/${name%.iso}.build.log"
    say "Build record: $info"
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
    name="CoplandOS-${COPLAND_VERSION}-deb${DEBIAN_VERSION}-amd64.iso"
    mv "$iso" "$OUT/$name"
    (cd "$OUT" && sha256sum "$name" > "$name.sha256")
    record_build "$name"
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
    --check) load_release; checks; exit 0 ;;
    --clean)
        [ "$EUID" -eq 0 ] || die "Run with sudo."
        if [ -d "$WORK" ]; then (cd "$WORK" && lb clean --purge >/dev/null 2>&1 || true); rm -rf "$WORK"; fi
        say "Removed $WORK"; exit 0 ;;
    "") ;;
    -h|--help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "Unknown option: $1 (try --help)" ;;
esac

[ "$EUID" -eq 0 ] || die "Building an image needs root:  sudo ./iso/build.sh"
load_release
checks
stage
build
