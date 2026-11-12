#!/usr/bin/env bash
# Publish the Copland OS apt repository (signed) to the gh-pages branch.
#
#   ./packaging/publish-repo.sh                 the release's package and the website: commit gh-pages locally
#   ./packaging/publish-repo.sh --site-only     the website only; packages and signatures untouched
#   ./packaging/publish-repo.sh --dir DIR       build into DIR only (no git; for tests)
#   ./packaging/publish-repo.sh --local         take packaging/out/*.deb instead (tests, with --dir)
#   ./packaging/publish-repo.sh --retract X.Y.Z take version X.Y.Z out of the repository and
#                                               re-sign (a release that was withdrawn: it must
#                                               be gone before a new build of that version)
#   ./packaging/publish-repo.sh --key KEYID     sign with another key (tests only)
#
# It signs with the key in packaging/copland-os-archive-keyring.gpg (the one the ISO
# trusts), so that key's secret half must be in your gpg keyring.
#
# Downloads the copland-os-desktop package attached to the GitHub release of
# COPLAND_VERSION (iso/release.conf), the very file CI built for that release and put in
# its image, so the ISO and apt never carry two builds of one version. Adds it to the
# repository's pool (older versions stay), regenerates the indexes, and signs them with
# your key (gpg asks for its passphrase, if it has one). Test builds (versions with "~")
# are never published. It never pushes: it prints the push command for you to run.
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
KEY=""; DIR=""; USE_GIT=1; SITE_ONLY=0; LOCAL=0; RETRACT=""

say() { printf ' > %s\n' "$*"; }
die() { printf '\n x %s\n' "$*" >&2; exit 1; }

while [ $# -gt 0 ]; do
    case "$1" in
        --key) shift; KEY="${1:-}" ;;
        --dir) shift; DIR="${1:-}"; USE_GIT=0 ;;
        --site-only) SITE_ONLY=1 ;;
        --local) LOCAL=1 ;;
        --retract) shift; RETRACT="${1:-}"; [[ "$RETRACT" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "--retract needs a version like 0.2.0" ;;
        -h|--help) awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"; exit 0 ;;
        *) die "Unknown option: $1" ;;
    esac
    shift
done
# shellcheck source=/dev/null
. "$REPO/iso/release.conf"
SUITE="$DEBIAN_CODENAME"
PAGES_URL="${COPLAND_APT_URL%/apt}"

if [ "$SITE_ONLY" -eq 0 ]; then
if [ -z "$KEY" ]; then
    [ -f "$KEYRING" ] || die "packaging/copland-os-archive-keyring.gpg is missing."
    KEY="$(gpg --show-keys --with-colons "$KEYRING" | awk -F: '/^fpr/ {print $10; exit}')"
fi
for t in apt-ftparchive gpg gzip; do command -v "$t" >/dev/null || die "$t is required (sudo apt install apt-utils gnupg)."; done
gpg --list-secret-keys "$KEY" >/dev/null 2>&1 || die "No secret key $KEY in your gpg keyring (restore it from your backup: docs/BUILDING.md, 'apt repository')."

shopt -s nullglob
if [ -n "$RETRACT" ]; then
    DEBS=()
elif [ "$LOCAL" -eq 1 ]; then
    [ "$USE_GIT" -eq 0 ] || die "--local is for tests: use it with --dir."
    DEBS=("$HERE"/out/*.deb)
    [ "${#DEBS[@]}" -gt 0 ] || die "No .deb in packaging/out/. Run ./packaging/build-deb.sh first."
else
    command -v gh >/dev/null || die "gh (GitHub CLI) is required to fetch the release's package."
    FETCH="$(mktemp -d "${TMPDIR:-/tmp}/copland-release.XXXXXX")"
    trap 'rm -rf "$FETCH"' EXIT
    TAG="v$COPLAND_VERSION"
    say "Fetching the package of release $TAG"
    gh release download "$TAG" --repo anas1412/copland-os --pattern 'copland-os-desktop_*_all.deb' --dir "$FETCH" \
        || die "Release $TAG has no copland-os-desktop package yet (push the tag and wait for CI)."
    DEBS=("$FETCH"/*.deb)
    [ "${#DEBS[@]}" -eq 1 ] || die "Expected one package in release $TAG, found ${#DEBS[@]}."
    case "$(basename "${DEBS[0]}")" in
        "copland-os-desktop_${COPLAND_VERSION}+deb${DEBIAN_VERSION}_all.deb") ;;
        *) die "Release $TAG carries $(basename "${DEBS[0]}"), not version ${COPLAND_VERSION}+deb${DEBIAN_VERSION}." ;;
    esac
fi
for d in "${DEBS[@]}"; do
    case "$(basename "$d")" in *"~"*) die "$(basename "$d") is a test build: only release builds are published." ;; esac
done
# a package goes public the moment gh-pages is pushed: say exactly which ones are new
for d in "${DEBS[@]}"; do say "package to publish: $(basename "$d")"; done
fi

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
POOL="$APT/pool/main/c/copland-os-desktop"

if [ "$SITE_ONLY" -eq 0 ]; then

mkdir -p "$POOL"
if [ -n "$RETRACT" ]; then
    gone="$POOL/copland-os-desktop_${RETRACT}+deb${DEBIAN_VERSION}_all.deb"
    [ -f "$gone" ] || die "$(basename "$gone") is not in the repository."
    rm -f "$gone"
    say "Retracted $(basename "$gone"): apt no longer offers it once gh-pages is pushed"
fi
say "Adding ${#DEBS[@]} package(s) to the pool"
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
fi

# GitHub Pages must serve files as they are
touch "$DIR/.nojekyll"
# the project website (site/), with its images taken from where the repo keeps them
[ -f "$REPO/site/index.html" ] || die "site/index.html is missing."
cp "$REPO/site/index.html" "$DIR/index.html"
mkdir -p "$DIR/assets"
cp "$REPO/core/assets/themes/CoplandOS/assets/copland-logo-128.png" "$DIR/assets/copland-logo.png"
cp "$REPO/docs/screenshot-desktop.png" "$REPO/docs/screenshot-apps.png" "$DIR/assets/"
rm -rf "$DIR/assets/shots"   # cut-out pictures of an earlier version of the page

say "Repository ready in $DIR"
if [ "$USE_GIT" -eq 1 ]; then
    git -C "$DIR" add -A
    if git -C "$DIR" diff --cached --quiet; then
        say "Nothing changed."
    else
        if [ "$SITE_ONLY" -eq 1 ]; then
            git -C "$DIR" commit -q -m "Website"
        elif [ -n "$RETRACT" ]; then
            git -C "$DIR" commit -q -m "Retract copland-os-desktop $RETRACT for $SUITE"
        else
            git -C "$DIR" commit -q -m "Publish $(cd "$POOL" && ls | tr '\n' ' ')for $SUITE"
        fi
        say "Committed on gh-pages. To publish, push it:"
        printf '\n    git -C %q push origin gh-pages\n\n' "$DIR"
    fi
fi
say "Users add it with the commands in README.md ('Install with apt'); base URL $PAGES_URL/apt"
