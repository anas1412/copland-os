# Copland OS design system

The look starts from the Copland OS Enterprise image on lain.wiki
(`File:CoplandOS.png`, 996×625; the wiki does not say where it comes from): deep navy,
a glowing cyan eye, a serif italic wordmark. In *Serial Experiments Lain*, Copland OS
Enterprise is the system on the NAVI computers, made by Tachibana General Laboratories,
in blue (lain.wiki/wiki/Copland_OS). Everything else is classic
Mac (late-1990s) shapes on top of that palette. This page is the reference; when a
value changes, change it here and in the files listed next to it. Every choice here
states its reason; a value without one is an open question, not a decision.

## What the product is

Copland OS is an operating system: **CoplandOS.iso** (upstream Debian 13 "trixie" +
XFCE, live and installable) is the product. Every package but one comes from Debian's
own servers and the installed system follows trixie's updates and security fixes; the
one is `copland-os-desktop`, the look, from Copland's own signed apt repository, so
`apt upgrade` updates Debian and Copland together. The installer in this repo is secondary: it brings the
same look to people who already run Debian XFCE. Wording follows that order: the ISO
first, the installer as "optional" (README, GitHub description). Why: the look depends
on system-wide pieces (login screen, boot menu, boot animation, defaults for every
account) that only a full system ships reliably.

## Palette

Sampled from the wallpaper (`core/assets/backgrounds/CoplandOS.png`).

| Token | Hex | Role | Used in |
|---|---|---|---|
| `navy` | `#25346a` | the wallpaper's background, the brand colour | browser policy (`core/browsers/copland-theme.json`), GTK theme base |
| `navy-deep` | `#101838` | panels, terminal background, installer sidebar | panel (`rgba(16,24,56,0.90)`), whisker menu (`0.96`), notifications (`0.94`), terminal, Calamares sidebar |
| `navy-ink` | `#141c3a` | darkest surface, terminal colour 0 | terminal palette, notifications, live boot menu progress bar |
| `navy-raised` | `#1c2852` | raised surfaces | GRUB menu, notifications |
| `cyan` | `#46baef` | the eye's glow: accents, focus, active items, borders | panel active/underline, menu border, tooltips, cursor in terminal, GRUB selection, live boot menu title |
| `blue` | `#197aba` | the eye's darker ring: selection, buttons, borders | panel checked buttons (`rgba(25,122,186,0.35)`), selection, Calamares current step |
| `text` | `#ccddff` | body text on navy | panel labels, terminal foreground, notifications, GRUB items |
| `text-dim` | `#738dc1` | secondary text | GRUB help line, disabled labels |
| `white` | `#ffffff` | panel icons, emphasis | panel glyphs (power, tray), selected text |

Hover on navy: `rgba(70,186,239,0.18)` (cyan at 18 %).

### Terminal and console (16 colours)

`#141c3a #e0507a #5fd7a7 #e6d28a #197aba #9a7cf0 #46baef #c5cfee`
`#4a5c9a #ff7096 #8af0c8 #f5e6a8 #5aa8e8 #b8a0ff #8fd6fa #ffffff`

Same order as ANSI 0–15, named `term0` to `term15` where other files refer to them. Source: `core/settings.tsv` (`terminal`), and the text
console's `vt.default_red/grn/blu` in `lib/system.sh` (background `#101838` first).
Red, green and yellow keep their meaning (errors, success, warnings) in a cooler,
softer form.

### btop

`core/config/btop/copland.theme` uses only the tokens above; each line in the file
names its token. Roles follow the desktop's: box outlines `cyan` (borders), selection
`blue` with `white` text, secondary text `text-dim`, empty meter bars `navy` (they read
as background), divider lines and the start of cached memory `term8` (the terminal's
own faint colour). Graphs fade `blue` to `cyan` to `term14`; memory in use goes
`term5` violet to `term1` red (taken); available memory is green (success).
`btop.conf` sets only five things: the theme; no background, so the terminal's
transparency shows through; 24-bit colour for the gradients; square corners, matching
the fastfetch frame; braille graphs, the finest btop has.

## Typography

| Use | Font | Size | Where set |
|---|---|---|---|
| Brand: menu button, layer names, window titles, clock, login screen | C059 Bold Italic (URW, `fonts-urw-base35`) | 10–11 (titles 10, clock and greeter 11) | `settings.tsv`, `gtk.css`, greeter drop-in |
| Interface: menus, labels, window list, file manager | Nimbus Sans (URW Helvetica clone, same package) | 10 | `settings.tsv` (`/Gtk/FontName`) |
| Terminal | DejaVu Sans Mono | 9 | `settings.tsv` (`terminal`) |
| Boot menu (installed system) | C059 Bold Italic 26 / DejaVu Sans Mono 14 | built with `grub-mkfont` | `core/boot/grub/copland/theme.txt` |
| Text console | Terminus | 10x20 | `/etc/default/console-setup` (`--system`) |

Rule: **serif italic for identity, sans for everything you read at length.** On the
bar, the Copland OS button, the layer names and the clock are C059 italic: they are
short, fixed words that carry the brand ("Layer" is the show's own word for its
episodes). The window list, menus and app text are Nimbus Sans, because they hold
changing, longer text that has to be read quickly. Do not set body text in italic
serif. (Decided 2026-11-11 after trying the layer names in both fonts.)

Smoothing: antialias on, hinting slight, RGB subpixel (`settings.tsv`, `theme`).

## Logo and wallpaper

- **Logo:** the Navi eye, "Copland Os Enterprise Icon" by PsyBear (credit required).
  Files: `core/assets/themes/CoplandOS/assets/copland-logo-{24,48,128}.png`, transparent.
  Used for the menu button (48), the user picture (`~/.face`, 128), the installer and
  launchers (128). Keep it on navy; don't recolour it or put it on light backgrounds.
- **Wallpaper:** the Copland OS Enterprise image from lain.wiki (source not stated there), 996×625, scaled to fill. Its eye and wordmark sit in
  the centre.
- **One picture per moment** (decided 2026-11-12): the eye-and-wordmark wallpaper was on the
  boot menu, the login screen, the installer and the desktop, so it stopped meaning
  anything. Now each moment has its own, all made by `tools/artwork.py` from the sources
  in `core/assets/sources/` (credits and licences in its `CREDITS`):
  - **Boot menus** (installed and live): the-blue-spyduck's scanline orb (CC BY-NC-SA 3.0)
    on black, edges faded, the menu below it. A firmware screen should look technical and
    quiet. The 800×600 rendition is used at its own size, never enlarged.
  - **Boot animation:** the eye, unchanged (faisalhsn; the one moment the logo moves).
  - **Login:** navy with the website's scanlines, hasecilu's vector logo (CC BY-NC-SA 4.0)
    recoloured to `cyan` with a soft glow above the box, "Copland OS Enterprise" and
    "Present day, present time." below it. The eye was just on screen during boot.
  - **Installer:** the welcome picture is the same vector logo and wordmark; the slides
    show real screenshots, so people see what they are installing (see "Installer
    slideshow").
  - **Desktop:** the eye wallpaper, unchanged: it is what people know and share.
  Rerun `tools/artwork.py` after changing a source, a screenshot or the palette.
- **One resolution from boot menu to desktop:** GRUB runs at the screen's preferred
  mode (`GRUB_GFXMODE=auto`, from the screen's EDID) and hands that mode to Linux
  (`GRUB_GFXPAYLOAD_LINUX=keep`); the live image's menu does the same
  (`iso/config/bootloaders/grub-pc/config.cfg`, where live-build's default is 800×600).
  Why: every mode change blanks the screen, and between the menu and the boot
  animation that reads as a glitch. Backgrounds use `crop` scaling, so any resolution
  keeps their proportions. Limit: firmware that reports no EDID gets 800×600 in GRUB,
  and the graphics driver then switches to the native mode once. The BIOS live menu
  (syslinux) stays 640×480.
- **fastfetch / installer banner:** fastfetch's built-in `LainOS` eye, in `blue`/`cyan`.

## Icons and cursor

- Icons: NineIcons (Mac OS 9, from Platinum9), unmodified colours. Apps it doesn't
  cover keep their own icons.
- Panel glyphs: white, flat (`xfsm-shutdown` glyph drawn for the theme, tray icons
  follow their apps).
- Cursor: Retrosmart Mac-ish classic (black with white outline, pixel art), 24 px.

## Layout

- **Top bar:** 30 px, full width, `navy-deep` at 90 %. Left to right: Copland OS menu
  (logo + C059 label), window list (current layer only), spacer, Layer:01–04, spacer,
  tray, volume, clock (`Wed 11 Nov  13:08`), power. No borders; active items get a
  2 px `cyan` underline.
- **Copland OS menu (Whisker menu):** 520×560, 92 % opaque, names shown next to apps and
  categories, categories switch on hover, the alternate positions for categories,
  profile and search. Taken as a whole from Anas's own menu (2026-11-12): the menu as
  it is used every day, not a guess. The recent-apps list is left out: it is one
  person's history. Rows in `core/settings.tsv` (`panel`, `plugin-1`).
- **Updates icon (ISO):** `package-update-indicator` checks once a day and shows a tray icon
  when updates are ready; clicking it opens Debian's updater (`gpk-update-viewer`). Why:
  the people this is for should never need a terminal to stay safe, and XFCE has no
  update notifier of its own (the package says so in its description).
- **Gaps:** 6/4 px margins around the menu button, 2 px between layer buttons, 4 px
  around the clock, spacers at both outer edges (`gtk.css` "panel spacing").
- **Window titles:** centred, C059 Bold Italic 10, white when focused, `text-dim` when not.
- **Window frame** (`core/assets/themes/CoplandOS/xfwm4/`, generated by
  `tools/xfwm4-frame.py`; edit the script, never the pixmaps):
  - square corners: the rounded Greybird corners left a black notch at the top right;
  - a scanlined title bar, the same CRT lines as the wallpaper and the website;
  - the focused window alone gets a cyan edge, a blue glow row and a blue separator, so
    the active window is clear at a glance; unfocused windows are slate;
  - the buttons are the dots of the Navi eye logo: close is the pink dot (term1), maximize
    the cyan ring, minimize the small cyan dot; they turn slate when unfocused, gain a
    halo on hover and darken when pressed;
  - the app icon sits at the top left (`show_app_icon=true` must be in `themerc`: xfwm4
    4.20 reads it only when a theme loads), 16 px, with 8 px margins left and right;
    icon, title and buttons share one centre line;
  - buttons `O|HMC` (menu icon; minimize, maximize, close): no shade button, which few
    people use and which would crowd the three dots.
  Shades used only here, mixed between palette navys because a scanline needs two
  nearly equal tones: title lines `#233266`/`#27386f` (focused) and `#192346`/`#1c274d`
  (unfocused), glow `#2b6fae`, unfocused edge `#34457e`, pressed close `#a83a5c`.
- **Layers shown as text, not icons:** the workspace switcher has no icon option, and
  icons would claim a purpose the neutral layers don't have; "Layer:01" is the show's
  own wording and pairs with Super+1. Symbols in the names would depend on font
  coverage that C059 and Nimbus Sans lack.
- **Layers:** four workspaces named `Layer:01`–`Layer:04`. Why four:
  - it is XFCE's own default (`workspace_count=4` in `/usr/share/xfwm4/defaults`), so
    XFCE users keep the number they know;
  - it maps to four common kinds of app: web, work or editor, terminal, chat and media;
  - Super+1–4 sit under the left hand next to Super, on QWERTY and AZERTY; 5 and up
    means stretching;
  - the bar still has room: at 1366×768 the four labels and two open windows leave
    about 300 px of the window list free (checked in a test session, 2026-11-11).
  The count and names are one row in `core/settings.tsv`; only Super+1–4 are bound.
- **No per-app layer rules** (removed 2026-11-12): apps open on the layer you are on.
  Sorting them into fixed layers with devilspie2 moved windows people did not expect
  to move, and needed an extra program running all the time.

## Voice and wording

| String | Where |
|---|---|
| Copland OS Enterprise | product name: wallpaper, installer, boot menus, GRUB entries |
| Copland OS | the project's name (repo, README title, GitHub description) and the short name on screen: menu button, launcher ("Install Copland OS") |
| Produced By Tachibana Lab / Tachibana General Laboratories | credits line (wallpaper, fastfetch, installer banner) |
| Layer:01 … Layer:04 | workspaces (the show's episodes are "Layers") |
| Present day, present time | only where something opens: the fastfetch title line (every new terminal) and the login screen. On the website it is the title of Layer:01, PRESENT DAY |
| Close the world, Open the nExt | sign-off (fastfetch, end of the installer output, website); the slogan of the 1998 *Serial Experiments Lain* PlayStation game (Wikipedia) |
| Copland OS Enterprise <version> (Debian 13) | installer title and launcher (`versionedName`); short form "Copland OS <version>" |
| Copland OS Enterprise (Debian 13) | text console login line (`/etc/issue`) |

Tone: short, calm, a little cryptic; English UI text stays plain and functional.

**"Present day, present time." opens things, nothing else** (decided 2026-11-12). In the
show the line is spoken at the start of every episode (lain.wiki), so here it appears
only where something starts: a new terminal (fastfetch), a login (the login screen), the
website (as Layer:01, PRESENT DAY). Never twice on one screen, and not where nothing
opens: it was taken off the installer slide and from under the website's title.

No em dashes anywhere (docs, UI strings, descriptions): use a colon, a comma or a
full stop instead.

### fastfetch labels

The first line names the system and its version, `COPLAND OS ENTERPRISE 0.1.2`, read at
each run from `~/.local/share/copland-os/version` (per-user install) or
`/usr/share/copland-os/version` (ISO, package, `--system`), both written from
`COPLAND_VERSION`. `BASE` below it names the Debian release, so both versions show.

Twelve keys, in `core/config/fastfetch/config.jsonc`. Show terms where the show has one,
plain words where it doesn't, so every line still reads at a glance:

| Key | Shows | Why this word |
|---|---|---|
| NAVI | host name | the show's word for a personal computer |
| BASE | Debian release | what Copland OS is built on |
| PROTOCOL | kernel | Protocol 7 is the show's network layer |
| ONLINE | uptime | time connected |
| MODULES | packages | installed parts |
| LAYER | desktop | the show's episodes are Layers, as are the workspaces |
| SHELL | shell | plain: no show term fits |
| TERM | terminal | plain |
| PSYCHE | CPU | the Psyche processor chip in Lain's NAVI |
| MEMORY | RAM | plain |
| STORAGE | disk | plain |
| WIRED | local IP | the show's network |

### Spelling

| Form | Where | Why |
|---|---|---|
| Copland OS | text people read: README, docs, UI strings, descriptions | the show's own spelling |
| CoplandOS | theme name, branded file names (`CoplandOS.png`), the ISO file name; volume label `COPLANDOS` | names that cannot hold a space; the volume label is upper case because ISO 9660 labels are |
| `copland` (lower case) | every command, config file, folder and package the project installs: `copland-goto`, `copland-send`, `copland.cfg`, `copland-theme.json`, `/etc/copland-os`, `copland-os-desktop` | Unix names are lower case; one prefix makes every installed piece easy to find and remove |

### Version and Debian base

- **Copland OS version:** `COPLAND_VERSION` in `iso/release.conf`, major.minor.patch.
  It names the ISO (for example `CoplandOS-0.1.2-deb13-amd64.iso`), the installer text and the
  package (`copland-os-desktop_0.1.2+deb13_all.deb`; a `+`, never a `:`, because a
  colon is a Debian epoch). Why: without it, two images of the same Debian release
  could not be told apart, and the package and the ISO would not say they match.
- **Debian is named, never hidden:** "(Debian 13)" follows the product name in the
  installer and at the console login. `/etc/os-release` stays Debian's: apt, the
  installer and `lib/common.sh` read `ID=debian` from it, and the project is honest
  about its base.
- **Console login line:** `/etc/issue` says
  `Copland OS Enterprise (Debian \S{VERSION_ID}) \n \l`, set by `--system` and the
  ISO. The Debian number comes from os-release at each login, so it stays right after
  a release upgrade. `/etc/issue` belongs to Debian's `base-files` package, so dpkg
  asks about it when a new Debian release ships its own; the Debian package
  (`copland-os-desktop`) leaves it alone, because a package may not change another
  package's configuration file.
- **Login session name stays "Xfce Session":** a separate "Copland OS" session would
  either sit next to Xfce's own entry (two entries that start the same desktop) or need
  Xfce's entry hidden, which breaks the session that existing accounts have saved. The
  look already comes from `/etc/xdg/copland-os`, whichever session starts.
- **Not added on purpose:** Knights, Cyberia, Accela or episode titles as layer
  subtitles. None of them maps to a real part of the desktop, and they would break the
  plain-and-functional rule above.

## Installer slideshow

`iso/branding/show.qml`, shown by Calamares while it copies the system. A short tour,
one topic per slide, like Ubuntu's and EndeavourOS's installer slides (read 2026-11-12).

| Slide | Says | Picture |
|---|---|---|
| Welcome to Copland OS Enterprise | built on Debian 13, runs by itself, a few minutes | the desktop |
| Four layers | Super+1 to 4 switches, Super+Shift+1 to 4 moves the window; Super is the Windows key | the top bar on Layer:02 |
| The menu | Super opens it; the apps the ISO ships (`copland.list.chroot`) | the menu |
| Updates | daily check, notification and top-bar icon, one click; or `sudo apt update && sudo apt upgrade` | none |
| More software | everything in Debian, one command | a terminal with `sudo apt install libreoffice gimp vlc` typed, not run |
| The terminal | fastfetch on every new terminal, btop | btop |
| Help | website, GitHub issues, debian.org/doc; the sign-off | none |

- **Every line is true of the installed system.** Check the repo before changing one:
  the shortcuts are in `lib/components.sh` (`keys`), the apps and the update icon in
  `iso/config/package-lists/copland.list.chroot`.
- **Pictures are real and sharp:** 1:1 crops of real screenshots (`docs/screenshot-*.png`,
  and `docs/installer/*.png`, taken in a fresh account at 1280x720), made by
  `tools/artwork.py`. No picture is drawn to look like a screen. A slide without a real
  picture has none (Updates: the icon only shows when updates are waiting).
- **Fits any window:** each slide fills the panel and the picture shrinks to the room
  left by the heading and the text (Calamares' `Slide` sits 20 % down by default, which
  cut the text off). Checked at 840x480, the panel in a 1280x800 VM, and 600x400.
- **Moves by itself, never runs away:** 25 s a slide (two lines take about 10 s to read),
  only while the install page is shown (Qt's `Timer` does not run by default; Calamares'
  example binds it to `activatedInCalamares`). A click, the arrow keys or a dot move on,
  and the next slide gets its full 25 s. It starts from the first slide every time.
- Navy-deep panel like the sidebar; headings in C059 Bold Italic, text in Nimbus Sans,
  commands in DejaVu Sans Mono and `cyan`; dots `cyan` (here) and `term8`.

## Installer extras (Apps and Developer tools)

Two optional pages after Users (`iso/calamares/packagechooser-{apps,dev}.conf`); what is
ticked is installed by `core/bin/copland-extras`, run inside the new system by the
`copland-extras` job right after `sources-final` (Debian's online sources). Before that
step apt only sees the ISO. The same tool is in the package: `sudo copland-extras`.

- **Nothing ticked by default.** The plain install stays as small as before and works
  offline. Offline, the job installs nothing, never fails the install, and leaves
  `~/Extra software.txt` with the command to run later.
- **Current and supported, from the nearest trustworthy source.** Debian first. When
  Debian's version is past its maker's end of life, the next source: Node.js 24 from
  NodeSource (Debian has 20, end of life 2026-04-30), Go from Debian backports (Debian
  has 1.24, end of life 2026-02-10), Docker from Docker (Debian has 26.1, end of life
  2025-02-17), Rust through Debian's rustup. Checked 2026-11-12 (nodejs/Release,
  endoflife.date, qa.debian.org/madison).
- **Outside repositories only when ticked**, under their makers' own file names (so the
  vendor's package does not add a second copy), each key checked against a pinned
  fingerprint before apt trusts it: Brave `DBF1A116...`, Microsoft `BC528686...`,
  NodeSource `6F71F525...`, Docker `9DC85822...` (full values in the script).
- **The Copland look wherever the app has a way in**, never over a user's own file:

| App | How |
|---|---|
| Brave Origin | `BrowserThemeColor` policy (`navy`), like every Chromium browser |
| VS Code | `settings.json`: palette colours, the 16 terminal colours, native title bar (the xfwm4 frame), DejaVu Sans Mono |
| OBS Studio | `Copland.ovt`, a variant of OBS's Yami theme with the navies in Yami's grey order, chosen in `global.ini` |
| GIMP 3 | its "System" theme, which draws with the GTK theme |
| LibreOffice | `libreoffice-gtk3`: drawn with the GTK theme |
| Thunderbird | GTK theme and dark scheme, like Firefox |
| VLC, KeePassXC | Qt's GTK platform theme; `55copland-os` sets `QT_QPA_PLATFORMTHEME=gtk3` for Qt 5 (Qt 6 picks it on XFCE by itself) |
| Flatpak apps | dark scheme through `xdg-desktop-portal-gtk` only: Flatpak apps cannot see the system GTK theme |

- **Sizes on each item's card** (`tools/artwork.py`, `CHOICES`): download and disk,
  measured 2026-11-12 with apt against the 0.1.2 ISO's own package list, so they are
  what a fresh install really fetches. Items share parts (Python, Rust and C all pull
  gcc), so several together download less than their sum. Rust's disk size is an estimate:
  the unpacked toolchain was not measured. Re-measure when versions move.

## Website

`site/index.html`, published with the apt repository (`packaging/publish-repo.sh`). For
people who use computers, not for builders: build and packaging details stay on GitHub.

- **Sections are Layers.** The show titles its episodes `Layer:01 WEIRD` (colon, two
  digits, title in capitals). The site's five cards use that format with the project's
  own fastfetch words, so the site and the system speak one language: PRESENT DAY (why it
  exists), NAVI (what you get), PROTOCOL (what it's for), PSYCHE (what it runs on), WIRED
  (get it). Each card has a plain subtitle for people who never saw the show.
- **Facts only, each with its source.** Requirements and dates from Debian, show facts
  from lain.wiki; a link sits next to each. Hardware figures are Debian 13's own
  (decided 2026-11-12).
- **The download button finds the newest release itself.** It links to GitHub's
  `releases/latest`; a script asks GitHub's API for that release and points the button
  at its `.iso`, with version, date and size underneath. With no release yet, it says
  so; without JavaScript, the link opens the release page. A release never needs an
  edit to the site.
- **No version numbers of apps or of the ISO.** Debian updates the apps all the time;
  a number on the page would be wrong within weeks. The page names only what changes
  with a new Debian release (Debian 13, XFCE 4.20), and the release checklist in
  BUILDING.md includes the site.
- **Real pictures, explained.** "What you get" is the two full screenshots in `docs/`,
  clean (no numbers or marks on them, because they are what people share), each followed
  by a list naming every part, where it is and what it does; no drawings of the product
  and no cut-outs (decided 2026-11-12). The desktop screenshot is also the link preview
  (Open Graph image).
- **Atmosphere, drawn by us:** power lines with a pole between sections (the show's best
  known motif) in its power-line navy `#394f70`; a red dot on each title card (the red
  marks in the show's shadows); faint static scanlines (gone under `prefers-contrast:
  more`); the fastfetch words drifting behind the title, like the show's floating text
  (still under `prefers-reduced-motion`); a one-second boot screen once per visit,
  skippable, never with reduced motion, added by script so the page reads without it.
- **Readability:** text-dim only on navy-deep (contrast 5.2), never on cards (4.3);
  blue never as text (3.7).

## Open issues

- **Wallpaper resolution:** 996×625 is soft on large screens; kept by choice for now.
