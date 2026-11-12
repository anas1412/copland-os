# What the installer changes

Every change, per component: what you get, which files and settings it touches,
and how to undo it. Read this before you run `install.sh`.

Before any component runs, the installer copies your current settings to
`~/.local/share/copland-os/backups/<timestamp>/`:

- the XFCE settings channels `xsettings`, `xfwm4`, `xfce4-panel`, `xfce4-desktop`,
  `xfce4-terminal`, `xfce4-keyboard-shortcuts` and `xfce4-notifyd`
- `~/.bashrc`
- `~/.config/fastfetch/config.jsonc` and `~/.config/btop/btop.conf`, if present

`./install.sh --restore` puts those back. Theme, icon and cursor folders stay on
disk; delete them by hand if you want them gone.

## Your home folder (no sudo)

### `theme` (on)

You get the CoplandOS look for GTK 2, 3 and 4 apps, window borders, and
notification bubbles. Window titles are in C059 Bold Italic and the interface
font is Nimbus Sans.

| Changes | Value |
|---|---|
| `~/.themes/CoplandOS/` | copied in; an existing copy is moved into the backup first |
| `xsettings /Net/ThemeName` | `CoplandOS` |
| `xsettings /Gtk/FontName` | `Nimbus Sans 10` |
| `xfwm4 /general/theme` | `CoplandOS` |
| `xfwm4 /general/title_font` | `C059 Bold Italic 10` |
| `xfwm4 /general/title_alignment` | `center` |
| `xfwm4 /general/button_layout` | `O|HMC` (app icon on the left; minimize, maximize, close on the right) |
| `xfce4-notifyd /theme` | `CoplandOS` |
| GNOME settings (if `gsettings` exists) | `gtk-theme`, `color-scheme prefer-dark`, `font-name` |

GTK 4 apps (for example the volume mixer, `pavucontrol`) use
`gtk-4.0/gtk.css`: GTK's own dark theme recoloured to the Copland palette. It
was generated from GTK 4.18; very different GTK versions may need it regenerated.

### `icons` (on)

You get Mac OS 9 style icons (NineIcons).

- Copies `~/.icons/NineIcons/`; an existing copy goes into the backup first.
- Sets `xsettings /Net/IconThemeName` to `NineIcons`, plus the GNOME `icon-theme` if `gsettings` exists.

### `cursors` (on)

You get classic Mac pixel cursors (Retrosmart).

- Copies `~/.icons/retrosmart-xcursor-mac-ish-classic/`.
- Sets `xsettings /Gtk/CursorThemeName` to that name, and `/Gtk/CursorThemeSize` to `24`.
- Apps that are already open keep the old cursor until you restart them.

### `wallpaper` (on)

You get the Copland OS Enterprise image (the eye and the wordmark) as your wallpaper.

- Copies `~/.local/share/backgrounds/CoplandOS.png`.
- Sets every monitor's `last-image` to that file, and `image-style` to `5`.

### `panel` (on)

**This replaces your whole panel layout.** You get one top bar holding:

- the Copland menu
- the window list
- Layer:01–04
- the tray
- volume
- a clock with the date
- a power button

| Changes | Value |
|---|---|
| `xfce4-panel` | all `/panels` and `/plugins` settings are reset, then rebuilt as above |
| `~/.face` | the Copland logo; your old picture goes into the backup |

### `terminal` (on)

You get the Copland colours in xfce4-terminal and btop, plus a fastfetch banner in each new terminal.

| Changes | Value |
|---|---|
| `xfce4-terminal` | background `#101838`, text `#ccddff`, cursor `#46baef`, 16-colour palette, transparent background at darkness 0.92, `DejaVu Sans Mono 9`, `120x34` |
| `~/.config/fastfetch/config.jsonc` | replaced |
| `~/.bashrc` | appends a marked `copland-os fastfetch` block, unless fastfetch is already there |
| `~/.config/btop/themes/copland.theme` | the Copland btop theme |
| `~/.config/btop/btop.conf` | created if missing; otherwise only `color_theme`, `theme_background`, `truecolor`, `rounded_corners` and `graph_symbol` are set, the rest is kept. Your old file goes into the backup |

### `layers` (on)

You get four workspaces named Layer:01–04. Apps open on the layer you are on.

| Changes | Value |
|---|---|
| `xfwm4` | 4 workspaces, named `Layer:01`–`Layer:04`; `activate_action` set to `switch` (an app asking for attention takes you to its layer) |

Earlier versions also sorted apps into layers with devilspie2 and a picker,
`copland-layers`. That feature is gone: running `layers` again, or `--restore`, removes
the files those versions left (`~/.config/devilspie2/layers.lua` and its autostart entry,
both only if they carry the Copland header, `~/.local/bin/copland-layers`, its menu entry
and `~/.config/copland-os/layers.conf`). `--system` removes the system-wide copies.

### `keys` (on)

You get these shortcuts:

- Super opens the Copland menu.
- Super+1–4 jump to that layer.
- Super+Shift+1–4 send the focused window there.

They are bound on the number row, the numpad, and AZERTY layouts.

- Adds `~/.local/bin/copland-goto` and `~/.local/bin/copland-send`.
- Adds custom shortcuts to `xfce4-keyboard-shortcuts`.

## System-wide (sudo)

### `packages` (on)

Installs whichever of the listed apt packages are missing. Packages your
release does not have are skipped and named.

### `greeter` (off)

You get the login screen in the same theme.

| Changes | Value |
|---|---|
| `/usr/share/themes/CoplandOS`, `/usr/share/icons/<icons>`, the cursor theme | copies; they are snapshots, so run `greeter` again after changing the theme |
| `/usr/share/backgrounds/CoplandOS.png` | the wallpaper |
| `/etc/lightdm/lightdm-gtk-greeter.conf.d/50-copland.conf` | a drop-in with the theme, icons, cursor, wallpaper, font and clock. Debian's `/etc/lightdm/lightdm-gtk-greeter.conf` is not edited; if an older version of this installer left a `# copland-begin` block there, it is removed (a `.copland-bak` copy is made first) |

### `boot` (off)

You get the Copland boot animation (a third-party Plymouth theme, pinned to one commit).

| Changes | Value |
|---|---|
| `/usr/share/plymouth/themes/copland/` | the theme |
| `/etc/copland-prev-plymouth` | the name of your previous boot theme, kept for restore |
| `/etc/default/grub` | `splash` added to the kernel command line. A `.copland-bak` copy is made first |
| initramfs | rebuilt for every installed kernel |

### `autologin` (off)

You are logged in to XFCE at startup, as the account that ran the installer, without
typing a password.

| Changes | Value |
|---|---|
| `/etc/lightdm/lightdm.conf.d/60-copland-autologin.conf` | `autologin-user=<you>`, `autologin-user-timeout=0`, `autologin-session=xfce`. Debian's `/etc/lightdm/lightdm.conf` is not edited |

Two consequences, which is why it is off by default:

- anyone who can switch the machine on gets your desktop;
- your login keyring (passwords saved by browsers and other apps) is normally unlocked
  by the password you type at login. With automatic login nothing unlocks it, so the
  first app that needs it asks for its password once per session.

`./install.sh --restore` offers to turn it off (it deletes the drop-in). `--system`
skips it: automatic login belongs to one account. On CoplandOS.iso the place for it is
the installer's own "Log in automatically" option (not yet checked: part of the VM test).

## System-wide install (`--system`)

`sudo ./install.sh --system` puts the same look in shared places for every
account; the README's "System-wide install" section lists them. Every file it
writes is recorded in `/var/lib/copland-os/manifest`, and
`sudo ./install.sh --system --uninstall` removes them, undoes the two
`dpkg-divert`s (`/usr/share/backgrounds/xfce/xfce-x.svg`,
`/usr/share/wayland-sessions/xfce-wayland.desktop`) and the marked block in
`/etc/skel/.bashrc`. It includes what `core/boot/copland-boot.sh` does, written as
`/etc/default/grub.d/copland.cfg` instead of editing `/etc/default/grub`, and sets the Terminus console font in `/etc/default/console-setup` (the original is kept in `/var/lib/copland-os/console-setup.orig` and put back by `--uninstall`). It also replaces the text console's login line, `/etc/issue`, with
`Copland OS Enterprise (Debian 13) <host> tty1` (the Debian number is read from
`/etc/os-release` at each login). The original is kept in
`/var/lib/copland-os/issue.orig` and put back by `--uninstall`. `/etc/issue` belongs to
Debian's `base-files`, so dpkg asks about it when a new Debian release ships its own;
the `copland-os-desktop` package does not change it. The same goes for `/etc/skel/.face`, the picture new accounts start with: it belongs to Debian's `desktop-base`, so `--system` keeps the original in `/var/lib/copland-os/face.orig` and `--uninstall` puts it back.

## In the repo, not yet run by the per-user `install.sh`

These are finished and were run on one machine. The installer does not run them yet.

### `core/boot/copland-boot.sh` (sudo, needs `boot` first)

You get:

- the boot animation filling the whole screen, with no black bars
- a Copland GRUB menu that says "Copland OS Enterprise" instead of Debian
- the text console (TTYs, and the boot log behind `Esc`) in Copland colours with the Terminus font

| Changes | Value |
|---|---|
| `/usr/share/plymouth/themes/copland/script.script` | replaced; the original is kept as `script.script.orig` |
| `/boot/grub/themes/copland/` | the GRUB theme. Its fonts and background are built on your machine from installed files |
| `/etc/default/grub` | a `# copland-boot-begin` / `# copland-boot-end` block at the end of the file. A `.copland-boot-bak` copy is made first. The block sets `GRUB_DISTRIBUTOR`, `GRUB_GFXMODE=auto` and `GRUB_GFXPAYLOAD_LINUX=keep` (the screen's own resolution, kept from the menu to the boot animation), `GRUB_THEME`, `GRUB_BACKGROUND`, and adds the console colours (`vt.default_red/grn/blu`) to the kernel command line |
| `/etc/default/console-setup` | `FONTFACE="Terminus"`, `FONTSIZE="10x20"`. A `.copland-bak` copy is made first |
| initramfs and GRUB config | rebuilt |

GRUB writes the menu entry as "Copland OS Enterprise GNU/Linux": its own
script appends "GNU/Linux" to any name that doesn't end in it.

Undo with `core/boot/copland-boot.sh --undo`.

### `core/browsers/copland-browsers.sh` (sudo; also the `browsers` component, off by default)

You get Copland navy in every Chromium-based browser (Brave, Chromium, Google
Chrome, Microsoft Edge), for every profile, from the first launch, with no
clicks. The browser builds its whole palette from one colour.

| Changes | Value |
|---|---|
| `copland-theme.json` in `/etc/brave/policies/managed/`, `/etc/chromium/policies/managed/`, `/etc/chromium-browser/policies/managed/`, `/etc/opt/chrome/policies/managed/`, `/etc/opt/edge/policies/managed/` | `BrowserThemeColor` = `#25346a`. The folders are created if missing, so a browser installed later is covered too |

It is a managed policy: while it is set, users cannot pick another browser
theme. `brave://policy` or `chrome://policy` shows whether it is active.

Undo with `core/browsers/copland-browsers.sh --undo`.

### Firefox

Nothing to install. Firefox draws its tabs and toolbar from the GTK theme, but it
picks light or dark from the GNOME setting `color-scheme`. The `theme` component
sets it to `prefer-dark` for your account, and `--system` (and so the ISO and the
package) makes it the default for every account with a GSettings override in
`/usr/share/glib-2.0/schemas/50_copland-os-theme.gschema.override`. Without it,
Firefox stays light under the dark theme: found on the first installed ISO, and
checked both ways with Firefox ESR 153 on a fresh profile. A profile that already
uses another Firefox theme keeps it.

### Font smoothing (now part of `theme`)

`xsettings /Xft/Antialias` `1`, `/Xft/Hinting` `1`, `/Xft/HintStyle`
`hintslight`, `/Xft/RGBA` `rgb`. These make text crisper on most LCD screens.
To undo, set them back to `-1`, `-1`, `hintnone` and `none`.
