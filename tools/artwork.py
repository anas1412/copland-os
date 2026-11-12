#!/usr/bin/env python3
"""Make the Copland OS backgrounds and installer pictures from their sources.

    tools/artwork.py

One picture per moment, so the wallpaper's eye is not repeated on every screen:

  boot menus     the-blue-spyduck's scanline orb on black, menu text below it
                 core/boot/grub/copland/background.png         installed system, 1920x1080
                 iso/config/bootloaders/grub-pc/splash.png      live ISO (UEFI), 1920x1080
                 iso/config/bootloaders/syslinux_common/splash.png  live ISO (BIOS), 640x480
  login screen   navy with scanlines, hasecilu's vector logo above the login box and the
                 wordmark below it          core/assets/backgrounds/CoplandOS-login.png
  installer      welcome picture: logo and wordmark      iso/branding/welcome.png
                 slides: the two screenshots in docs/    iso/branding/slide1.png, slide2.png

Sources and their licences: core/assets/sources/CREDITS. The boot animation and the
desktop wallpaper are not made here. Needs python3-gi with GdkPixbuf (SVG loader),
cairo and Pango, all present on an XFCE desktop.
"""
import math
import os

import cairo
import gi

gi.require_version("GdkPixbuf", "2.0")
gi.require_version("Gdk", "3.0")
gi.require_version("Pango", "1.0")
gi.require_version("PangoCairo", "1.0")
from gi.repository import Gdk, GdkPixbuf, GLib, Pango, PangoCairo  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SRC = os.path.join(ROOT, "core", "assets", "sources")
ORB = os.path.join(SRC, "copland-orb-the-blue-spyduck.png")
LOGO = os.path.join(SRC, "copland-logo-hasecilu.svg")

# palette tokens (docs/DESIGN.md)
NAVY, NAVY_DEEP, NAVY_RAISED = "#25346a", "#101838", "#1c2852"
CYAN, TEXT, TEXT_DIM, WHITE = "#46baef", "#ccddff", "#738dc1", "#ffffff"


def rgb(h):
    return tuple(int(h[i:i + 2], 16) / 255 for i in (1, 3, 5))


def out(*parts):
    path = os.path.join(ROOT, *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    return path


def save(surface, path):
    surface.write_to_png(path)
    print("%-50s %dx%d" % (os.path.relpath(path, ROOT), surface.get_width(), surface.get_height()))


def pixbuf_surface(pb):
    """GdkPixbuf -> cairo surface (alpha kept)."""
    s = cairo.ImageSurface(cairo.FORMAT_ARGB32, pb.get_width(), pb.get_height())
    c = cairo.Context(s)
    Gdk.cairo_set_source_pixbuf(c, pb, 0, 0)
    c.paint()
    return s


def logo_surface(size):
    """hasecilu's logo, recoloured: its light strokes in cyan, its dark disc in navy-raised."""
    pb = GdkPixbuf.Pixbuf.new_from_file_at_size(LOGO, size, size)
    if not pb.get_has_alpha():
        pb = pb.add_alpha(False, 0, 0, 0)
    w, h, n, stride = pb.get_width(), pb.get_height(), pb.get_n_channels(), pb.get_rowstride()
    px = bytearray(pb.get_pixels())
    light, dark = [int(v * 255) for v in rgb(CYAN)], [int(v * 255) for v in rgb(NAVY_RAISED)]
    for y in range(h):
        for x in range(w):
            i = y * stride + x * n
            if px[i + 3] == 0:
                continue
            lum = 0.299 * px[i] + 0.587 * px[i + 1] + 0.114 * px[i + 2]
            px[i:i + 3] = bytes(light if lum > 70 else dark)
    pb = GdkPixbuf.Pixbuf.new_from_bytes(GLib.Bytes.new(bytes(px)), GdkPixbuf.Colorspace.RGB, True, 8, w, h, stride)
    return pixbuf_surface(pb)


def blurred(surf, factor):
    """a cheap soft blur: shrink by `factor`, then scale back up with smooth filtering"""
    w, h = surf.get_width(), surf.get_height()
    sw, sh = max(1, w // factor), max(1, h // factor)
    small = cairo.ImageSurface(cairo.FORMAT_ARGB32, sw, sh)
    c = cairo.Context(small)
    c.scale(sw / w, sh / h)
    c.set_source_surface(surf, 0, 0)
    c.get_source().set_filter(cairo.FILTER_GOOD)
    c.paint()
    big = cairo.ImageSurface(cairo.FORMAT_ARGB32, w, h)
    c = cairo.Context(big)
    c.scale(w / sw, h / sh)
    c.set_source_surface(small, 0, 0)
    c.get_source().set_filter(cairo.FILTER_BILINEAR)
    c.paint()
    return big


def draw_glow(c, surf, x, y, alpha=0.55):
    """the logo with a soft cyan halo behind it, like the eye's glow"""
    pad = surf.get_width() // 3
    w, h = surf.get_width() + 2 * pad, surf.get_height() + 2 * pad
    halo = cairo.ImageSurface(cairo.FORMAT_ARGB32, w, h)
    hc = cairo.Context(halo)
    hc.set_source_surface(surf, pad, pad)
    hc.paint()
    for factor, a in ((12, alpha), (6, alpha * 0.6)):
        c.set_source_surface(blurred(halo, factor), x - pad, y - pad)
        c.paint_with_alpha(a)
    c.set_source_surface(surf, x, y)
    c.paint()


def navy_field(c, w, h, lines=True):
    """navy-deep with a navy glow in the middle and faint scanlines (the website's)"""
    g = cairo.RadialGradient(w / 2, h * 0.45, 0, w / 2, h * 0.45, max(w, h) * 0.75)
    g.add_color_stop_rgb(0, *rgb(NAVY))
    g.add_color_stop_rgb(1, *rgb(NAVY_DEEP))
    c.set_source(g)
    c.paint()
    if lines:
        c.set_source_rgba(0, 0, 0, 0.16)
        for y in range(0, h, 3):
            c.rectangle(0, y, w, 1)
        c.fill()


def text(c, s, font, colour, cx, cy, alpha=1.0):
    layout = PangoCairo.create_layout(c)
    layout.set_font_description(Pango.FontDescription.from_string(font))
    layout.set_text(s, -1)
    tw, th = layout.get_pixel_size()
    c.set_source_rgba(*rgb(colour), alpha)
    c.move_to(cx - tw / 2, cy - th / 2)
    PangoCairo.show_layout(c, layout)


def boot_menu(w, h, orb_h, centre_y):
    """black screen, the orb centred above where the menu sits (scaled down only, never up)"""
    s = cairo.ImageSurface(cairo.FORMAT_RGB24, w, h)
    c = cairo.Context(s)
    c.set_source_rgb(0, 0, 0)
    c.paint()
    orb = cairo.ImageSurface.create_from_png(ORB)
    k = min(1.0, orb_h / orb.get_height())
    ow, oh = orb.get_width() * k, orb.get_height() * k
    ox, oy = w / 2 - ow / 2, centre_y - oh / 2
    # the source's background is near-black, not black: fade its edges out so no
    # rectangle shows on the black screen
    fade = cairo.RadialGradient(w / 2, centre_y, oh * 0.36, w / 2, centre_y, oh * 0.52)
    fade.add_color_stop_rgba(0, 0, 0, 0, 1)
    fade.add_color_stop_rgba(1, 0, 0, 0, 0)
    pat = cairo.SurfacePattern(orb)
    pat.set_matrix(cairo.Matrix(xx=1 / k, yy=1 / k, x0=-ox / k, y0=-oy / k))
    pat.set_filter(cairo.FILTER_BEST)
    c.set_source(pat)
    c.mask(fade)
    return s


def login(w=1920, h=1080):
    s = cairo.ImageSurface(cairo.FORMAT_RGB24, w, h)
    c = cairo.Context(s)
    navy_field(c, w, h)
    lg = logo_surface(round(h * 0.17))
    draw_glow(c, lg, w / 2 - lg.get_width() / 2, h * 0.215 - lg.get_height() / 2)
    # the greeter's box sits in the middle; the name goes under it
    text(c, "Copland OS Enterprise", "C059 Bold Italic %d" % round(h * 0.034), WHITE, w / 2, h * 0.79)
    text(c, "Present day, present time.", "C059 Italic %d" % round(h * 0.017), TEXT_DIM, w / 2, h * 0.84)
    return s


def welcome(w=467, h=293):
    s = cairo.ImageSurface(cairo.FORMAT_RGB24, w, h)
    c = cairo.Context(s)
    navy_field(c, w, h)
    lg = logo_surface(round(h * 0.52))
    draw_glow(c, lg, w / 2 - lg.get_width() / 2, h * 0.40 - lg.get_height() / 2)
    text(c, "Copland OS Enterprise", "C059 Bold Italic %d" % round(h * 0.075), WHITE, w / 2, h * 0.82)
    return s


def slide(shot, w=640, h=360):
    """a docs/ screenshot, scaled to the slide with a thin blue frame"""
    src = cairo.ImageSurface.create_from_png(os.path.join(ROOT, "docs", shot))
    s = cairo.ImageSurface(cairo.FORMAT_RGB24, w, h)
    c = cairo.Context(s)
    k = min(w / src.get_width(), h / src.get_height())
    c.scale(k, k)
    c.set_source_surface(src, 0, 0)
    c.get_source().set_filter(cairo.FILTER_BEST)
    c.paint()
    c.identity_matrix()
    c.set_source_rgb(*rgb("#197aba"))
    c.set_line_width(2)
    c.rectangle(1, 1, w - 2, h - 2)
    c.stroke()
    return s


def main():
    # installed GRUB menu: items at 77-92 % of the height, so the orb sits in the top 70 %
    save(boot_menu(1920, 1080, 600, round(1080 * 0.38)), out("core", "boot", "grub", "copland", "background.png"))
    # live UEFI menu: same layout (its theme puts the menu at the bottom too)
    save(boot_menu(1920, 1080, 600, round(1080 * 0.38)), out("iso", "config", "bootloaders", "grub-pc", "splash.png"))
    # live BIOS menu (syslinux, 640x480): a small orb at the top, the menu box below it
    save(boot_menu(640, 480, 180, 105), out("iso", "config", "bootloaders", "syslinux_common", "splash.png"))
    save(login(), out("core", "assets", "backgrounds", "CoplandOS-login.png"))
    save(welcome(), out("iso", "branding", "welcome.png"))
    save(slide("screenshot-desktop.png"), out("iso", "branding", "slide1.png"))
    save(slide("screenshot-apps.png"), out("iso", "branding", "slide2.png"))


if __name__ == "__main__":
    main()
