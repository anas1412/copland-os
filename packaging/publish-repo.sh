#!/usr/bin/env bash
# Publish the Copland OS apt repository (signed) to the gh-pages branch.
#
#   ./packaging/publish-repo.sh                 prepare and commit gh-pages locally
#   ./packaging/publish-repo.sh --dir DIR       build into DIR only (no git; for tests)
#   ./packaging/publish-repo.sh --key KEYID     sign with another key (tests only)
#
# It signs with the key in packaging/copland-os-archive-keyring.gpg (the one the ISO
# trusts), so that key's secret half must be in your gpg keyring.
#
# Takes every .deb in packaging/out/, adds it to the repository's pool (older versions
# stay), regenerates the indexes, and signs them with your key (gpg asks for its
# passphrase, if it has one). It never pushes: it prints the push command for you to run.
#
# Layout served by GitHub Pages (COPLAND_APT_URL in iso/release.conf is its apt/ folder):
#   index.html, assets/                 the project website, from site/
#   copland-os-archive-keyring.gpg      public key (binary), for Signed-By
#   copland-os-archive-keyring.asc      the same key, ASCII
#   apt/pool/main/c/copland-os-desktop/*.deb
#   apt/dists/<codename>/{InRelease,Release,Release.gpg}
#   apt/dists/<codename>/main/binary-{amd64,all}/Packages{,.gz}
# The suite is the Debian codename from iso/release.conf, so each Debian release
# gets its own packages.
set -Eeuo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
KEYRING="$HERE/copland-os-archive-keyring.gpg"
KEY=""; DIR=""; USE_GIT=1

say() { printf ' > %s\n' "$*"; }
die() { printf '\n x %s\n' "$*" >&2; exit 1; }

while [ $# -gt 0 ]; do
    case "$1" in
        --key) shift; KEY="${1:-}" ;;
        --dir) shift; DIR="${1:-}"; USE_GIT=0 ;;
        -h|--help) awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"; exit 0 ;;
        *) die "Unknown option: $1" ;;
    esac
    shift
done
if [ -z "$KEY" ]; then
    [ -f "$KEYRING" ] || die "packaging/copland-os-archive-keyring.gpg is missing."
    KEY="$(gpg --show-keys --with-colons "$KEYRING" | awk -F: '/^fpr/ {print $10; exit}')"
fi
for t in apt-ftparchive gpg gzip; do command -v "$t" >/dev/null || die "$t is required (sudo apt install apt-utils gnupg)."; done
gpg --list-secret-keys "$KEY" >/dev/null 2>&1 || die "No secret key $KEY in your gpg keyring (restore it from your backup: docs/BUILDING.md, 'apt repository')."

# shellcheck source=/dev/null
. "$REPO/iso/release.conf"
SUITE="$DEBIAN_CODENAME"
PAGES_URL="${COPLAND_APT_URL%/apt}"
shopt -s nullglob
DEBS=("$HERE"/out/*.deb)
[ "${#DEBS[@]}" -gt 0 ] || die "No .deb in packaging/out/. Run ./packaging/build-deb.sh first."

if [ "$USE_GIT" -eq 1 ]; then
    command -v git >/dev/null || die "git is required."
    DIR="$HERE/out/gh-pages"
    if [ ! -d "$DIR/.git" ] && [ ! -f "$DIR/.git" ]; then
        git -C "$REPO" fetch -q origin gh-pages 2>/dev/null || true
        if git -C "$REPO" rev-parse -q --verify origin/gh-pages >/dev/null; then
            git -C "$REPO" worktree add -q -B gh-pages "$DIR" origin/gh-pages
        else
            git -C "$REPO" worktree add -q --orphan -b gh-pages "$DIR"
        fi
    fi
fi
mkdir -p "$DIR"
APT="$DIR/apt"

say "Adding ${#DEBS[@]} package(s) to the pool"
POOL="$APT/pool/main/c/copland-os-desktop"
mkdir -p "$POOL"
for d in "${DEBS[@]}"; do
    name="$(basename "$d")"
    case "$name" in *"+deb${DEBIAN_VERSION}_"*) ;; *) die "$name was not built for Debian $DEBIAN_VERSION ($SUITE)." ;; esac
    # a published version never changes: apt clients and mirrors already hold its checksum
    if [ -f "$POOL/$name" ]; then
        cmp -s "$d" "$POOL/$name" || { say "$name is already published; keeping the published file (raise COPLAND_VERSION for a new one)"; }
        continue
    fi
    cp "$d" "$POOL/$name"
done

say "Writing indexes for $SUITE"
DISTS="$APT/dists/$SUITE"
rm -rf "$DISTS"
for arch in amd64 all; do
    mkdir -p "$DISTS/main/binary-$arch"
    (cd "$APT" && apt-ftparchive packages pool) > "$DISTS/main/binary-$arch/Packages"
    gzip -9n -k "$DISTS/main/binary-$arch/Packages"
done
(cd "$DISTS" && apt-ftparchive \
    -o APT::FTPArchive::Release::Origin="Copland OS" \
    -o APT::FTPArchive::Release::Label="Copland OS" \
    -o APT::FTPArchive::Release::Suite="$SUITE" \
    -o APT::FTPArchive::Release::Codename="$SUITE" \
    -o APT::FTPArchive::Release::Architectures="amd64 all" \
    -o APT::FTPArchive::Release::Components="main" \
    -o APT::FTPArchive::Release::Description="Copland OS packages for Debian $DEBIAN_VERSION ($SUITE)" \
    release . ) > "$DISTS/Release.tmp"
mv "$DISTS/Release.tmp" "$DISTS/Release"

say "Signing with key $KEY"
gpg --yes --local-user "$KEY" --clearsign -o "$DISTS/InRelease" "$DISTS/Release"
gpg --yes --local-user "$KEY" --armor --detach-sign -o "$DISTS/Release.gpg" "$DISTS/Release"
gpg --export "$KEY" > "$DIR/copland-os-archive-keyring.gpg"
gpg --armor --export "$KEY" > "$DIR/copland-os-archive-keyring.asc"
gpgv --keyring "$DIR/copland-os-archive-keyring.gpg" "$DISTS/InRelease" >/dev/null 2>&1 \
    || die "The new InRelease does not verify against the exported key."

# GitHub Pages must serve files as they are
touch "$DIR/.nojekyll"
# the project website (site/), with its images taken from where the repo keeps them
[ -f "$REPO/site/index.html" ] || die "site/index.html is missing."
cp "$REPO/site/index.html" "$DIR/index.html"
mkdir -p "$DIR/assets"
cp "$REPO/core/assets/themes/CoplandOS/assets/copland-logo-128.png" "$DIR/assets/copland-logo.png"
cp "$REPO/docs/screenshot-desktop.png" "$DIR/assets/"
rm -f "$DIR/assets/screenshot-apps.png"   # the page shows parts of it (assets/shots/) instead
"$REPO/tools/site-images.py" "$DIR/assets/shots" >/dev/null || die "Could not cut the website pictures (tools/site-images.py)."

say "Repository ready in $DIR"
if [ "$USE_GIT" -eq 1 ]; then
    git -C "$DIR" add -A
    if git -C "$DIR" diff --cached --quiet; then
        say "Nothing changed."
    else
        git -C "$DIR" commit -q -m "Publish $(cd "$POOL" && ls | tr '\n' ' ')for $SUITE"
        say "Committed on gh-pages. To publish, push it:"
        printf '\n    git -C %q push origin gh-pages\n\n' "$DIR"
    fi
fi
say "Users add it with the commands in README.md ('Install with apt'); base URL $PAGES_URL/apt"
