#!/usr/bin/env bash
# CI: build the copland-os-desktop package alone, for a patch release (no image), inside
# a clean Debian container (see .github/workflows/iso.yml). Runs as root in the
# container with the repository at /src; the package lands in packaging/out/.
# Installs the same tools iso/ci-build.sh gives packaging/build-deb.sh.
set -Eeuo pipefail
trap 'rc=$?; [ -z "${HOST_UID:-}" ] || chown -R "$HOST_UID:${HOST_GID:-$HOST_UID}" /src/packaging/out 2>/dev/null || true; exit $rc' EXIT

export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get install -y -q --no-install-recommends \
    apt-utils bzip2 file rsync wget xz-utils cpio \
    git ca-certificates python3 grub-common fonts-urw-base35 fonts-dejavu-core fonts-dejavu-mono

git config --global --add safe.directory /src
/src/packaging/build-deb.sh
