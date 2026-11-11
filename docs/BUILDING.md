# Building CoplandOS.iso

CoplandOS.iso is Debian 13 (trixie) with a lean XFCE desktop, Copland OS applied
system-wide, and the Calamares installer branded as Copland OS. It is built with
Debian's own tool, live-build, from the files in `iso/`.

## Requirements

- A Debian 13 machine (or VM) with root access and a network connection.
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

Results in `iso/out/`:

| File | What it is |
|---|---|
| `CoplandOS-<date>-amd64.iso` | the image (BIOS and UEFI, USB or DVD) |
| `CoplandOS-<date>-amd64.iso.sha256` | its checksum |
| `CoplandOS-<date>-amd64.build-info.txt` | repo commit, whether the working copy had changes, tool versions, boot animation pin |
| `CoplandOS-<date>-amd64.packages` | every package in the image, with its version |
| `CoplandOS-<date>-amd64.build.log` | the full live-build log |

`sudo ./iso/build.sh --clean` removes the work folder, including the package cache.

## What the build does

1. Checks the tools, free space and the work folder.
2. Copies `iso/auto` and `iso/config` into the work folder (keeping the package cache from an
   earlier build).
3. Copies the repo (without `.git`, `iso/` and `docs/`) into the image at `/usr/share/copland-os`,
   the installer branding next to it, and the boot animation from its pinned commit.
4. `lb config` (options in `iso/auto/config`), then `lb build`. Inside the image:
   - `config/package-lists/copland.list.chroot` installs the desktop and tools;
   - hook `0500-copland` runs `install.sh --system --no-packages --no-rebuild --root /`,
     the same code as `sudo ./install.sh --system` on a real machine;
   - hook `0510-copland-installer` brands Calamares (diverting Debian's settings and launcher);
   - `config/bootloaders/` gives the image's own boot menu the Copland look.
5. Renames the image, writes the checksum and the build record.

## Repeating a build

The same commit of this repo always runs the same steps, and the boot animation is
pinned. Debian packages are not: a later build picks up trixie's point releases and
security updates, so two builds a month apart differ in package versions. The
`.packages` file next to each image lists exactly what went in.

## Live session

User `lain`, password `live` (live-config's default), hostname `coplandos`, X11 XFCE
session, US keyboard and English locale unless changed at the boot menu (press Tab /
`e` and add for example `locales=fr_FR.UTF-8 keyboard-layouts=fr`).
