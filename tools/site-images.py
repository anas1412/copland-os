#!/usr/bin/env python3
"""Cut the website's pictures out of the two screenshots in docs/.

    tools/site-images.py OUTDIR

The site shows parts of the real desktop (top bar, layers, terminal, btop) instead of
drawings, so each picture is a rectangle of docs/screenshot-desktop.png or
docs/screenshot-apps.png (both 1600x900). Cutting them at publish time keeps one source
image: a new screenshot updates every picture. packaging/publish-repo.sh runs this.
Needs python3-gi with GdkPixbuf (installed with any GTK desktop).
"""
import os
import sys

import gi

gi.require_version("GdkPixbuf", "2.0")
from gi.repository import GdkPixbuf  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
DOCS = os.path.join(HERE, "..", "docs")

# name: (source screenshot, x, y, width, height)
CROPS = {
    "bar-left":   ("screenshot-desktop.png", 0, 0, 150, 31),     # Copland OS menu button
    "bar-right":  ("screenshot-desktop.png", 960, 0, 640, 31),   # Layer:01-04, tray, clock, power
    "icons":      ("screenshot-desktop.png", 14, 40, 104, 300),  # Home, File System, Trash (NineIcons)
    "fastfetch":  ("screenshot-apps.png", 135, 38, 781, 430),    # terminal window with fastfetch
    "colours":    ("screenshot-apps.png", 135, 492, 781, 128),   # the 16 terminal colours
    "btop":       ("screenshot-apps.png", 930, 38, 654, 835),    # btop window
}


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    cache = {}
    for name, (src, x, y, w, h) in CROPS.items():
        if src not in cache:
            cache[src] = GdkPixbuf.Pixbuf.new_from_file(os.path.join(DOCS, src))
        img = cache[src]
        if x + w > img.get_width() or y + h > img.get_height():
            sys.exit(f"{name}: rectangle is outside {src} ({img.get_width()}x{img.get_height()})")
        img.new_subpixbuf(x, y, w, h).savev(os.path.join(out, f"{name}.png"), "png", ["compression"], ["9"])
        print(f"{name}.png {w}x{h}")


if __name__ == "__main__":
    main()
