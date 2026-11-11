#!/usr/bin/env python3
"""Recolour a copy of Greybird-dark into the Copland OS Enterprise palette.

Usage: recolor.py <theme-dir>
Run it ONCE on a fresh copy of /usr/share/themes/Greybird-dark (it is not
idempotent: running twice shifts the colours twice).

Palette sampled from the boot-screen frame on lain.wiki (CoplandOS.png):
  background navy  #25346a   (scanlines #223264 .. #27356c)
  logo cyan        #46baef
  logo dark blue   #197aba
  text             #ccddff
"""
import colorsys
import pathlib
import re
import sys

NAVY_HUE = 227 / 360      # hue of #25346a
LIGHT_HUE = 220 / 360     # hue of #ccddff
CYAN_HUE = 199 / 360      # hue of #46baef

# saturation of the navy ramp, by lightness (piecewise linear)
SAT_CURVE = [(0.0, 0.50), (0.35, 0.48), (0.60, 0.38), (0.85, 0.75), (1.0, 1.0)]


def lerp_curve(curve, x):
    for (x0, y0), (x1, y1) in zip(curve, curve[1:]):
        if x <= x1:
            t = (x - x0) / (x1 - x0) if x1 > x0 else 0
            return y0 + t * (y1 - y0)
    return curve[-1][1]


def remap(r, g, b):
    """r, g, b in 0..255 -> recoloured (r, g, b)."""
    h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
    if l < 0.02 or l > 0.985:
        return r, g, b                      # keep true black / white (shadows, highlights)
    if s < 0.15:                            # greys -> navy ramp
        l2 = l + 0.04 * (1 - l)
        h2 = NAVY_HUE if l2 < 0.5 else LIGHT_HUE
        s2 = lerp_curve(SAT_CURVE, l2)
    elif 0.44 <= h < 0.53:                  # teal accents -> logo cyan
        h2, l2, s2 = CYAN_HUE, min(1.0, l * 1.10), s
    elif 0.53 <= h <= 0.72:                 # Greybird blues -> Copland blues
        h2, l2, s2 = h - 0.02, min(1.0, l * 1.13), s
    else:                                   # red / green / orange status colours stay
        return r, g, b
    r2, g2, b2 = colorsys.hls_to_rgb(h2, l2, s2)
    return round(r2 * 255), round(g2 * 255), round(b2 * 255)


HEX6 = re.compile(r'(?<![0-9A-Za-z_-])#([0-9a-fA-F]{6})(?![0-9A-Za-z_-])')
HEX3 = re.compile(r'(?<=[:\s,("])#([0-9a-fA-F]{3})(?![0-9A-Za-z_-])')
RGBA = re.compile(r'rgb(a?)\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*')


def sub_hex6(m):
    v = m.group(1)
    rgb = remap(int(v[0:2], 16), int(v[2:4], 16), int(v[4:6], 16))
    out = '#%02x%02x%02x' % rgb
    return out.upper() if v.isupper() else out


def sub_hex3(m):
    v = m.group(1)
    rgb = remap(*(int(c * 2, 16) for c in v))
    return '#%02x%02x%02x' % rgb


def sub_rgba(m):
    rgb = remap(int(m.group(2)), int(m.group(3)), int(m.group(4)))
    return 'rgb%s(%d, %d, %d' % ((m.group(1),) + rgb)


def recolour_text(text):
    text = HEX6.sub(sub_hex6, text)
    text = HEX3.sub(sub_hex3, text)
    return RGBA.sub(sub_rgba, text)


def main():
    root = pathlib.Path(sys.argv[1])
    targets = [root / 'gtk-3.0' / 'gtk.css', root / 'gtk-3.0' / 'gtk-dark.css',
               root / 'gtk-2.0' / 'gtkrc', root / 'xfwm4' / 'themerc']
    targets += sorted((root / 'xfwm4').glob('*.xpm'))
    targets += sorted((root / 'gtk-3.0' / 'apps').glob('*.css'))
    targets += sorted((root / 'gtk-3.0' / 'assets').glob('*.svg'))
    changed = 0
    for path in targets:
        old = path.read_text(encoding='utf-8')
        new = recolour_text(old)
        if new != old:
            path.write_text(new, encoding='utf-8')
            changed += 1
    print('files recoloured: %d of %d' % (changed, len(targets)))
    for name, c in [('bg #3b3e3f', (0x3b, 0x3e, 0x3f)), ('base #2d2e30', (0x2d, 0x2e, 0x30)),
                    ('border #1d1f1f', (0x1d, 0x1f, 0x1f)), ('fg #eeeeec', (0xee, 0xee, 0xec)),
                    ('dim #959696', (0x95, 0x96, 0x96)), ('selected #145ba6', (0x14, 0x5b, 0xa6)),
                    ('teal #19b1a2', (0x19, 0xb1, 0xa2))]:
        print('  %-18s -> #%02x%02x%02x' % ((name,) + remap(*c)))


if __name__ == '__main__':
    main()
