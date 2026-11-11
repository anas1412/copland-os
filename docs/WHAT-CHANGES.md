# What the installer changes

Every change, per component: what you get, which files and settings it touches,
and how to undo it. Read this before you run `install.sh`.

Before any component runs, the installer copies your current settings to
`~/.local/share/copland-os/backups/<timestamp>/`:

- the XFCE settings channels `xsettings`, `xfwm4`, `xfce4-panel`, `xfce4-desktop`,
  `xfce4-terminal`, `xfce4-keyboard-shortcuts` and `xfce4-notifyd`
- `~/.bashrc`
- `~/.config/fastfetch/config.jsonc` and `~/.config/devilspie2/layers.lua`, if present

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
| `xfwm4 /general/button_layout` | `O|SHMC` |
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

You get the Copland OS Enterprise boot frame as your wallpaper.

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

You get the Copland colours in xfce4-terminal, plus a fastfetch banner in each new terminal.

| Changes | Value |
|---|---|
| `xfce4-terminal` | background `#101838`, text `#ccddff`, cursor `#46baef`, 16-colour palette, transparent background at darkness 0.92, `DejaVu Sans Mono 9`, `120x34` |
| `~/.config/fastfetch/config.jsonc` | replaced |
| `~/.bashrc` | appends a marked `copland-os fastfetch` block, unless fastfetch is already there |

### `layers` (on)

You get four workspaces named Layer:01–04, and a picker that decides which
app opens on which layer.

| Changes | Value |
|---|---|
| `xfwm4` | 4 workspaces, named `Layer:01`–`Layer:04`; `activate_action` set to `switch` |
| `~/.config/devilspie2/layers.lua` | window rules |
| `~/.local/bin/copland-layers` | the picker |
| `~/.config/copland-os/layers.conf` | created only if missing; no app is assigned to a layer |
| `~/.local/share/applications/copland-layers.desktop` | menu entry |
| `~/.config/autostart/devilspie2.desktop` | starts devilspie2 at login |

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
| `/etc/lightdm/lightdm-gtk-greeter.conf` | a `# copland-begin` / `# copland-end` block under `[greeter]`. A `.copland-bak` copy is made first |

### `boot` (off)

You get the Copland boot animation (a third-party Plymouth theme, pinned to one commit).

| Changes | Value |
|---|---|
| `/usr/share/plymouth/themes/copland/` | the theme |
| `/etc/copland-prev-plymouth` | the name of your previous boot theme, kept for restore |
| `/etc/default/grub` | `splash` added to the kernel command line. A `.copland-bak` copy is made first |
| initramfs | rebuilt for every installed kernel |

## In the repo, not yet run by `install.sh`

These are finished and tested on one machine. The installer does not run them yet.

### `files/boot/copland-boot.sh` (sudo, needs `boot` first)

You get:

- the boot animation filling the whole screen, with no black bars
- a Copland GRUB menu that says "Copland OS Enterprise" instead of Debian
- the text console (TTYs, and the boot log behind `Esc`) in Copland colours with the Terminus font

| Changes | Value |
|---|---|
| `/usr/share/plymouth/themes/copland/script.script` | replaced; the original is kept as `script.script.orig` |
| `/boot/grub/themes/copland/` | the GRUB theme. Its fonts and background are built on your machine from installed files |
| `/etc/default/grub` | a `# copland-boot-begin` / `# copland-boot-end` block at the end of the file. A `.copland-boot-bak` copy is made first. The block sets `GRUB_DISTRIBUTOR`, `GRUB_THEME`, `GRUB_BACKGROUND`, and adds the console colours (`vt.default_red/grn/blu`) to the kernel command line |
| `/etc/default/console-setup` | `FONTFACE="Terminus"`, `FONTSIZE="10x20"`. A `.copland-bak` copy is made first |
| initramfs and GRUB config | rebuilt |

GRUB writes the menu entry as "Copland OS Enterprise GNU/Linux": its own
script appends "GNU/Linux" to any name that doesn't end in it.

Undo with `files/boot/copland-boot.sh --undo`.

### `files/brave/` (Brave, or any Chromium browser)

You get navy and cyan tabs and toolbar.

To load it:

1. Open `brave://extensions`.
2. Turn on Developer mode.
3. Click "Load unpacked" and choose this folder.

To remove it, open Settings → Appearance → Reset to default.

### Font smoothing

`xsettings /Xft/Antialias` `1`, `/Xft/Hinting` `1`, `/Xft/HintStyle`
`hintslight`, `/Xft/RGBA` `rgb`. These make text crisper on most LCD screens.
To undo, set them back to `-1`, `-1`, `hintnone` and `none`.
