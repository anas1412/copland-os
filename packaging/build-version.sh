#!/usr/bin/env bash
# Print the version a build is labelled with. One version, one build: two different
# packages must never carry the same version, or apt (and the update icon) sees one as
# an update of the other forever.
#
#   packaging/build-version.sh          0.1.3~git202611121530.225d1f1   (a test build)
#   COPLAND_RELEASE=1 packaging/...     0.1.3                           (the release build)
#
# A test build is COPLAND_VERSION (iso/release.conf, the next release) with
# "~git<commit time, UTC>.<commit>": Debian sorts "~" before everything, so it is newer
# than the last release and older than the coming one, and the release replaces it with
# a normal update. ".dirty" marks a build with uncommitted changes.
# Only the CI build of a version tag sets COPLAND_RELEASE=1 (.github/workflows/iso.yml);
# its package is the one published to the apt repository (packaging/publish-repo.sh).
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
. "$REPO/iso/release.conf"
[[ "${COPLAND_VERSION:-}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "iso/release.conf: bad COPLAND_VERSION" >&2; exit 1; }

g() { git -c safe.directory="$REPO" -C "$REPO" "$@"; }

if [ "${COPLAND_RELEASE:-0}" = 1 ]; then
    if [ -n "$(g status --porcelain 2>/dev/null)" ]; then
        echo "A release is built from a clean checkout of its tag (uncommitted changes found)." >&2
        exit 1
    fi
    printf '%s\n' "$COPLAND_VERSION"
    exit 0
fi

if commit="$(g rev-parse --short=7 HEAD 2>/dev/null)"; then
    when="$(TZ=UTC g log -1 --format=%cd --date=format-local:%Y%m%d%H%M HEAD)"
    dirty=""
    [ -z "$(g status --porcelain 2>/dev/null)" ] || dirty=".dirty"
    printf '%s~git%s.%s%s\n' "$COPLAND_VERSION" "$when" "$commit" "$dirty"
else
    # no git (an unpacked tarball): still below the release
    printf '%s~dev\n' "$COPLAND_VERSION"
fi
