# Building CoplandOS.iso

CoplandOS.iso is upstream Debian (the release named in `iso/release.conf`, currently
13 "trixie") with a lean XFCE desktop, Copland OS applied
system-wide, and the Calamares installer branded as Copland OS. It is built with
Debian's own tool, live-build, from the files in `iso/`.

## Requirements

- A Debian machine (or VM) with root access and a network connection. The builds so
  far were prepared on Debian 13; building a newer release may need a newer
  `live-build` and `debootstrap` (the build checks that debootstrap knows the release).
- About 20 GB free on the disk holding the work folder (default `/var/tmp/coplandos-build`;
  set `COPLAND_ISO_WORK=/path` to change it; it must not be a tmpfs).
- The tools: `sudo apt install live-build debootstrap wget git`

`./iso/build.sh --check` runs the checks without root.

With less than 6 GB of RAM the build limits the final image compression to 2 threads
and 768 MB (`MKSQUASHFS_OPTIONS`); it is slower but fits a 4 GB machine. Close other
apps while it runs. Set `MKSQUASHFS_OPTIONS` yourself to override.

## Build

```bash
git clone https://github.com/anas1412/copland-os.git
cd copland-os
sudo ./iso/build.sh
```

Results in `iso/out/`, named from `iso/release.conf` (for example
`CoplandOS-0.1.0-deb13-amd64.iso`):

| File | What it is |
|---|---|
| `CoplandOS-<version>-deb<debian>-amd64.iso` | the image (BIOS and UEFI, USB or DVD) |
| `CoplandOS-<version>-deb<debian>-amd64.iso.sha256` | its checksum |
| `CoplandOS-<version>-deb<debian>-amd64.build-info.txt` | repo commit, whether the working copy had changes, tool versions, boot animation pin |
| `CoplandOS-<version>-deb<debian>-amd64.packages` | every package in the image, with its version |
| `CoplandOS-<version>-deb<debian>-amd64.build.log` | the full live-build log |

`sudo ./iso/build.sh --clean` removes the work folder, including the package cache.

## What the build does

1. Checks the tools, free space, the work folder, and that the apt repository is
   published at `COPLAND_APT_URL` with an `InRelease` signed by
   `packaging/copland-os-archive-keyring.gpg`. The image's apt source points there, so
   an unpublished repository would break `apt update` (live-build itself runs it at the
   end of the build).
2. Copies `iso/auto` and `iso/config` into the work folder (keeping the package cache from an
   earlier build).
3. Fetches the boot animation from its pinned commit and builds the `copland-os-desktop`
   package with it (`packaging/build-deb.sh`) into `config/packages.chroot/`. Adds the
   Copland apt source (`/etc/apt/sources.list.d/copland-os.sources`), its public key
   (`/usr/share/keyrings/copland-os-archive-keyring.gpg`), the console login line
   (`/etc/issue`, which belongs to base-files, so the package can't ship it) and the
   installer branding.
4. `lb config` (options in `iso/auto/config`), then `lb build`. Inside the image:
   - `config/package-lists/copland.list.chroot` installs the desktop and tools, and
     live-build installs `copland-os-desktop` from `config/packages.chroot` with apt, so
     dpkg owns every Copland file and `apt upgrade` updates them on installed systems;
   - hook `0500-copland` runs the package's install script once more, after every
     package is in (plymouth and console-setup are only recommended, so apt may have
     set them up after it), and checks the boot animation is the default;
   - hook `0510-copland-installer` brands Calamares (diverting Debian's settings and launcher);
   - `config/bootloaders/` gives the image's own boot menu the Copland look.
5. Renames the image, writes the checksum and the build record.

## Repeating a build

The same commit of this repo always runs the same steps, and the boot animation is
pinned. Debian packages are not: a later build picks up the release's point releases and
security updates, so two builds a month apart differ in package versions. The
`.packages` file next to each image lists exactly what went in.

The file name carries the Copland OS version and the Debian release, not the date, so
a published name always says what it is. Rebuilding the same version replaces the
earlier image in `iso/out/`; the build date is in its `.build-info.txt`. For a new
release, raise `COPLAND_VERSION` in `iso/release.conf` first.

## Live session

User `lain`, password `live` (live-config's default), hostname `coplandos`, X11 XFCE
session, US keyboard and English locale unless changed at the boot menu (press Tab /
`e` and add for example `locales=fr_FR.UTF-8 keyboard-layouts=fr`).

## Moving to a new Debian release

The release is set in one place, `iso/release.conf` (`DEBIAN_CODENAME`,
`DEBIAN_VERSION`, next to Copland's own `COPLAND_VERSION`). `build.sh` passes it to live-build and fills it into the
installer's branding and launcher. A new release is a deliberate, tested change, never
a floating "stable": a build should not change Debian versions on its own.

Start while the new release is still Debian's *testing* distribution, so breakage shows
up before release day.

1. **Branch and switch.** On a new branch, set both lines in `iso/release.conf`.
   `./iso/build.sh --check` confirms debootstrap knows the codename.
2. **Packages.** For every name in `iso/config/package-lists/copland.list.chroot` and
   `PACKAGES` in `install.sh`, check it still exists in the new release
   (`apt-cache policy` against its sources, or packages.debian.org). Replace renamed or
   dropped ones.
3. **live-build.** Read the new `live-build` changelog; run `lb config` with
   `iso/auto/config` in a scratch folder and confirm every option is still accepted.
4. **XFCE.** If XFCE's version changed, check:
   - panel plugin names and library paths (`plugin_exists` in `lib/common.sh`);
   - the GTK theme's panel and window selectors (`core/assets/themes/CoplandOS`);
   - that xfdesktop still falls back to `/usr/share/backgrounds/xfce/xfce-x.svg`
     (`lib/system.sh`, `sys_wallpaper`);
   - xfconf property names in `core/settings.tsv` (`xfconf-query -c <channel> -l`);
   - the Wayland session entry and LightDM greeter option names.
5. **Installer and boot.** Compare Debian's new `calamares-settings-debian`
   (`settings.conf`, the launcher) with what hook `0510-copland-installer` diverts, and
   live-build's boot menu templates with `iso/config/bootloaders/`.
6. **Tests, in this order:**
   - `./install.sh --dry-run --yes` on a machine running the new release;
   - `--system --root` into a scratch folder, then `--uninstall`;
   - the first-login test in a Xephyr window (fresh home, system defaults first);
   - the login screen in `lightdm --test-mode`;
   - build the ISO, then boot it in a VM (BIOS and UEFI): live session, install,
     second user.
7. **Text.** Update the release named in README.md, docs/DESIGN.md and the GitHub
   description, then merge and tag.

Installed systems move to the new release with Debian's own upgrade procedure (its
release notes). The Copland files belong to the `copland-os-desktop` package, whose
version carries the Debian release (`+deb13`), so publish the package built for the new
release before users upgrade; apt then replaces it like any other package. Machines
set up with `install.sh --system` instead run it again after upgrading.

## apt repository

The package is published as a signed apt repository on GitHub Pages (the `gh-pages`
branch, served at `COPLAND_APT_URL` from `iso/release.conf`). Every CoplandOS.iso
carries this source and its key, so installed systems get Copland updates with
`apt upgrade`; the ISO build refuses to start until the repository is published. Publishing is done by
hand from the maintainer's machine, so the signing key never leaves it: anyone holding
that key can ship code that runs as root on every machine using the repository.

### Once: create the signing key

```bash
gpg --quick-generate-key "Copland OS archive signing key" ed25519 sign 2y
```

gpg asks for a passphrase; choose a strong one. Then back up the secret key and the
revocation certificate gpg printed (under `~/.gnupg/openpgp-revocs.d/`) offline, for
example on a USB stick:

```bash
gpg --armor --export-secret-keys "Copland OS archive signing key" > copland-os-signing-key.asc
```

Put the public key in the repo, so the ISO build and `publish-repo.sh` use it:

```bash
gpg --export "Copland OS archive signing key" > packaging/copland-os-archive-keyring.gpg
gpg --armor --export "Copland OS archive signing key" > packaging/copland-os-archive-keyring.asc
```

If the key is lost, every user has to trust a new one by hand. Before it expires,
extend it with `gpg --quick-set-expire <fingerprint> 2y` and publish again.

### Once: turn on GitHub Pages

After the first push of `gh-pages`: repository Settings, Pages, source "Deploy from a
branch", branch `gh-pages`, folder `/ (root)`. Or with the GitHub CLI:

```bash
gh api -X POST repos/anas1412/copland-os/pages -f 'source[branch]=gh-pages' -f 'source[path]=/'
```

### Each release

```bash
./packaging/build-deb.sh
./packaging/publish-repo.sh
git -C packaging/out/gh-pages push origin gh-pages
```

`publish-repo.sh` signs with the key in `packaging/copland-os-archive-keyring.gpg`, so
its secret half must be in your gpg keyring. Publish before building an ISO of the
same version.

`publish-repo.sh` adds every `.deb` in `packaging/out/` to the pool (older versions
stay), rebuilds the indexes for the release in `iso/release.conf`, signs them (gpg asks
for the passphrase if the key has one), checks the signature, exports the public key, and commits on the
`gh-pages` branch in `packaging/out/gh-pages`. It never pushes by itself.

