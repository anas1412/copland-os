# Copland OS Enterprise for XFCE

A Serial Experiments Lain desktop for Debian + XFCE: the Copland OS look from the
show, with one installer that sets up the whole thing, not just config files.

```
                         .   ·   .
                    .-==============-.
          .:===:  .'    .--------.    '.  :===:.
        (===:    /     (   (())   )     \    :===)
          ':===:  '.    '--------'    .'  :===:'
                    '-=====    =====-'
             o           ||    ||           o
                    ====='      '=====

        C O P L A N D   O S   E N T E R P R I S E
```

## Install

```bash
git clone git@github.com:anas1412/copland-os-dotfiles.git
cd copland-os-dotfiles
./install.sh
```

Run it from a terminal inside your XFCE session, as your own user. The menu lets
you pick components with the arrow keys and space; enter installs.

| Option | What it does |
|---|---|
| `./install.sh` | interactive menu |
| `./install.sh --yes` | install the default selection without asking |
| `./install.sh --dry-run` | print every command, change nothing |
| `./install.sh --only theme,icons` | install only the listed components |
| `./install.sh --list` | list component ids |
| `./install.sh --force` | rebuild icons and cursors even if they exist |
| `./install.sh --restore` | put back the settings saved by the last run |

## Components

| Id | Default | What you get |
|---|---|---|
| `packages` | on | installs the missing apt packages (sudo) |
| `theme` | on | CoplandOS GTK 2/3 theme, xfwm4 window borders, notification style |
| `icons` | on | blue duotone icon theme generated from Papirus, white panel icons |
| `cursors` | on | Adwaita cursors re-tinted Copland cyan |
| `wallpaper` | on | the Copland OS Enterprise boot frame |
| `panel` | on | top bar: Copland menu, window list, Layer:01–04, tray, clock, power. **Replaces your current panel layout** |
| `terminal` | on | xfce4-terminal palette and font, fastfetch config, `~/.bashrc` hook |
| `layers` | on | 4 workspaces named Layer:01–04 and devilspie2 rules: Claude, browser, terminals, everything else |
| `keys` | on | the Super (Windows) key opens the Copland menu |
| `greeter` | off | LightDM login screen in the same theme (sudo) |
| `boot` | off | Plymouth boot animation from a third-party repo (sudo, experimental) |

## Safety

- Refuses to run as root; asks for sudo only for `packages`, `greeter` and `boot`.
- Checks that it is inside an XFCE session before it touches anything.
- Saves your XFCE settings, `~/.bashrc` and existing configs to
  `~/.local/share/copland-os/backups/<timestamp>/` first. An existing theme or
  icon folder is moved there, not deleted.
- Each component runs on its own with `set -e`; a failure is reported and the
  others still run. The full output is in `~/.local/share/copland-os/install-<timestamp>.log`.
- Packages that your release does not have are skipped and named, not fatal.

## What was tested

Tested on Debian 13 (trixie) with XFCE 4.20: the menu, `--dry-run`, and a real
run of `theme`, `icons` (existing build kept), `cursors` (existing build kept),
`wallpaper`, `panel`, `terminal`, `layers` and `keys`.

Not tested: a from-scratch icon and cursor build through the installer,
`packages` on a system that is missing them, `greeter` and `boot` through the
installer, `--restore`, and any release other than Debian 13.

## Layout

```
install.sh                  the installer
files/themes/CoplandOS/     GTK theme, xfwm4 borders, notification style, logo
files/backgrounds/          wallpaper
files/fastfetch/            fastfetch config
files/devilspie2/           per-app workspace rules
files/tools/                generators: icon duotone, cursor tint, theme recolour
```

## Credits

- GTK and xfwm4 theme: a recolour of [Greybird](https://github.com/shimmerproject/Greybird) (GPL-2.0-or-later / CC-BY-SA-3.0).
- Icons: generated at install time from [Papirus](https://github.com/PapirusDevelopmentTeam/papirus-icon-theme) (GPL-3.0).
- Menu logo: "Copland Os Enterprise Icon" by PsyBear,
  <https://www.deviantart.com/psybear/art/Copland-Os-Enterprise-Icon-65838629>. Copyright PsyBear.
- Wallpaper: a frame from *Serial Experiments Lain*, via <https://lain.wiki/wiki/Copland_OS>.
  Copyright its owners; not covered by this repository's licence.
- fastfetch logo: the built-in `LainOS` logo of [fastfetch](https://github.com/fastfetch-cli/fastfetch).
- Boot animation (optional): <https://github.com/faisalhsn/copland-plymouth-theme>.
