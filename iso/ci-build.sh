#!/usr/bin/env bash
# CI: build CoplandOS.iso inside a clean Debian container (see .github/workflows/iso.yml).
# Runs as root in the container; the repository is at /src, the work disk at /work (the build uses /work/build).
#
# Installs exactly what iso/build.sh and packaging/build-deb.sh need, runs the build,
# and then, even when the build failed: keeps one version of each cached .deb (the
# cache is restored into the next build) and hands every file back to the runner user.
set -Eeuo pipefail

cleanup() {
    local rc=$?
    # package cache: drop older versions of the same package, so it does not grow forever
    local d f name keep
    for d in /work/build/cache/packages.*; do
        [ -d "$d" ] || continue
        declare -A newest=()
        for f in "$d"/*.deb; do
            [ -e "$f" ] || continue
            name="$(basename "$f")"; name="${name%%_*}_${name##*_}"   # package + architecture
            keep="${newest[$name]:-}"
            if [ -z "$keep" ]; then newest[$name]="$f"; continue; fi
            local a b
            a="$(dpkg-deb -f "$f" Version)"; b="$(dpkg-deb -f "$keep" Version)"
            if dpkg --compare-versions "$a" gt "$b"; then rm -f "$keep"; newest[$name]="$f"; else rm -f "$f"; fi
        done
        unset newest
    done
    [ -f /work/build/build.log ] && mkdir -p /src/iso/out && cp /work/build/build.log /src/iso/out/build.log
    if [ -n "${HOST_UID:-}" ]; then
        chown -R "$HOST_UID:${HOST_GID:-$HOST_UID}" /src /work/build/cache 2>/dev/null || true
        [ -f /work/build/build.log ] && chown "$HOST_UID" /work/build/build.log
    fi
    exit "$rc"
}
trap cleanup EXIT

export DEBIAN_FRONTEND=noninteractive
apt-get update -q
# live-build and what it recommends for an ISO; git for the boot animation; python3 for
# the XFCE defaults; grub-common and the two font packages for the boot menu theme
apt-get install -y -q --no-install-recommends \
    live-build debootstrap apt-utils bzip2 file rsync wget xz-utils cpio \
    git ca-certificates python3 grub-common fonts-urw-base35 fonts-dejavu-core fonts-dejavu-mono

git config --global --add safe.directory /src
# a folder below the mount point: build.sh empties and recreates its work folder
COPLAND_ISO_WORK=/work/build /src/iso/build.sh
