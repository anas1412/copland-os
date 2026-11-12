# Changelog

What changed in each Copland OS release, newest first. Each section is also the text of
that version's GitHub release (the release workflow copies it), so a version cannot be
released without one. Written for people who use Copland OS; the commits have the rest.

Versions: `x.y.0` brings a new ISO, `x.y.z` is an update of the desktop package only,
delivered by the update icon (docs/BUILDING.md, "Releasing a version").

## [Unreleased]

## [0.2.0] - 2026-11-12

### Added
- **Apps and Developer tools in the installer.** Two optional checklist pages after
  Users: Brave Origin, LibreOffice, Thunderbird, GIMP, VLC, OBS Studio, KeePassXC and
  Flathub; VS Code, Python, Node.js, Go, Rust, Java, C and C++, Docker and Podman. Each
  is the current, supported version, installed at the end of the install and set to the
  Copland look where the app allows it. Nothing is ticked by default, and without an
  internet connection the install still finishes.
- **`copland-extras`**: the same list on an installed system, `sudo copland-extras --list`.
- **A tour while it installs**: seven slides on layers, the menu, updates, more
  software, the terminal and where to get help.
- Qt apps such as VLC and KeePassXC follow the Copland colours.

### Fixed
- **Shutdown of the live session no longer looks frozen.** It waits for you to remove
  the USB stick and press Enter; the boot screen now shows that message, and a
  disk-encryption password prompt would show too.
- **The update icon no longer offers the same update forever.** The ISO and the apt
  repository now carry the very same package for each version.
- The installer slideshow moves on by itself and its text no longer gets cut off.

### Changed
- "Present day, present time" appears only where something starts: a new terminal and
  the login screen.

## [0.1.2] - 2026-11-12

### Added
- An update icon in the top bar: it checks once a day and installs Debian's and
  Copland's updates in one click.
- fastfetch shows the Copland OS version.
- New boot menu, login screen and installer pictures.

### Changed
- A new Copland window frame.
- The menu's defaults (favourites and layout) were reworked.
- Apps are no longer moved to fixed layers; Layer:01 to Layer:04 stay, you choose.

### Fixed
- New accounts now get the wallpaper.
- Firefox follows the dark theme from the first start.

## [0.1.1] - 2026-11-12

The first released ISO.

### Added
- CoplandOS.iso: Debian 13 with XFCE in the Copland OS look, live and installable,
  with a Copland-branded installer.
- The look as a Debian package, `copland-os-desktop`, from Copland's own signed apt
  repository, updated with the rest of the system.
- The same resolution from the boot menu to the desktop.
- Optional automatic login.

### Fixed
- The package installs cleanly next to Debian's desktop-base (0.1.0, published only to
  apt, could not be installed).
