#!/usr/bin/env python3
"""Copland OS asset tools (standard library + GdkPixbuf from python3-gi).

  icons   <Papirus> <Papirus-Dark> <dest>   build a blue duotone icon theme
  cursors <src-cursors-dir> <dest-dir>      re-tint an Xcursor set to Copland cyan
  pngs    <dir>                             re-tint theme widget PNGs in place (run once)
  preview <xcursor-file> <out.png>          dump the largest image of a cursor
"""
import colorsys, os, pathlib, re, shutil, struct, sys

# luminance -> colour ramp, built around the colours sampled from the boot frame
RAMP = [(0.00, (0x0c, 0x14, 0x36)), (0.25, (0x1a, 0x4f, 0x9c)), (0.50, (0x19, 0x7a, 0xba)),
        (0.75, (0x46, 0xba, 0xef)), (1.00, (0xe8, 0xf4, 0xff))]
CYAN_HUE = 199 / 360
KEEP_RED_DIRS = ('status', 'emblems', 'panel')


def duotone(r, g, b):
    y = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255
    for (x0, c0), (x1, c1) in zip(RAMP, RAMP[1:]):
        if y <= x1:
            t = (y - x0) / (x1 - x0)
            return tuple(round(a + t * (z - a)) for a, z in zip(c0, c1))
    return RAMP[-1][1]


def is_red(r, g, b):
    h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
    return s > 0.5 and (h < 0.04 or h > 0.94) and 0.25 < l < 0.75


HEX = re.compile(r'(?<=[:"\s])#([0-9a-fA-F]{6}|[0-9a-fA-F]{3})(?![0-9a-zA-Z_-])')


def duotone_svg(text, keep_red):
    def sub(m):
        if text[max(0, m.start() - 6):m.start()].endswith('href="'):
            return m.group(0)
        v = m.group(1)
        if len(v) == 3:
            v = ''.join(c * 2 for c in v)
        rgb = (int(v[0:2], 16), int(v[2:4], 16), int(v[4:6], 16))
        if keep_red and is_red(*rgb):
            return m.group(0)
        return '#%02x%02x%02x' % duotone(*rgb)
    return HEX.sub(sub, text)


def build_icons(papirus, dark, dest):
    papirus, dark, dest = map(pathlib.Path, (papirus, dark, dest))
    if dest.exists():
        sys.exit('destination exists: %s' % dest)
    shutil.copytree(papirus, dest, symlinks=True)
    # overlay Papirus-Dark: real files and links that stay inside Papirus-Dark
    for root, dirs, files in os.walk(dark):
        rel = pathlib.Path(root).relative_to(dark)
        keep = []
        for d in dirs:
            src = pathlib.Path(root) / d
            if src.is_symlink():
                target = os.readlink(src)
                if 'Papirus/' in target:          # points back at Papirus: already copied
                    continue
                dst = dest / rel / d
                if not dst.exists() and not dst.is_symlink():
                    os.symlink(target, dst)
            else:
                (dest / rel / d).mkdir(exist_ok=True)
                keep.append(d)
        dirs[:] = keep
        for f in files:
            src = pathlib.Path(root) / f
            dst = dest / rel / f
            if src.is_symlink():
                target = os.readlink(src)
                if 'Papirus/' in target:
                    continue
                if dst.exists() or dst.is_symlink():
                    dst.unlink()
                os.symlink(target, dst)
            elif f.endswith('.svg'):
                if dst.exists() or dst.is_symlink():
                    dst.unlink()
                shutil.copyfile(src, dst)
    n = 0
    for root, dirs, files in os.walk(dest):
        keep_red = any(part in KEEP_RED_DIRS for part in pathlib.Path(root).parts[-2:])
        for f in files:
            p = pathlib.Path(root) / f
            if p.is_symlink() or not f.endswith('.svg'):
                continue
            old = p.read_text(encoding='utf-8', errors='surrogateescape')
            new = duotone_svg(old, keep_red)
            if new != old:
                p.write_text(new, encoding='utf-8', errors='surrogateescape')
                n += 1
    cache = dest / 'icon-theme.cache'
    if cache.exists():
        cache.unlink()
    idx = dest / 'index.theme'
    t = idx.read_text()
    t = re.sub(r'^Name=.*$', 'Name=CoplandOS', t, count=1, flags=re.M)
    t = re.sub(r'^Comment=.*$', 'Comment=Copland OS Enterprise (blue duotone of Papirus)', t, count=1, flags=re.M)
    t = re.sub(r'^Inherits=.*$', 'Inherits=hicolor', t, count=1, flags=re.M)
    idx.write_text(t)
    print('svg files recoloured:', n)


def tint_pixel(r, g, b):
    """cursor tint: the black body becomes logo cyan, the white outline deep navy.
    Coloured pixels (red "forbidden", green "copy") keep their meaning."""
    h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
    if s > 0.35 and 0.15 < l < 0.85:
        return r, g, b
    body, edge = (0x46, 0xba, 0xef), (0x0c, 0x14, 0x36)
    return tuple(round(a + l * (z - a)) for a, z in zip(body, edge))


def xcursor_images(data):
    magic, hsize, version, ntoc = struct.unpack_from('<4sIII', data, 0)
    if magic != b'Xcur':
        raise ValueError('not an Xcursor file')
    for i in range(ntoc):
        ctype, subtype, pos = struct.unpack_from('<III', data, hsize + 12 * i)
        if ctype != 0xfffd0002:
            continue
        chdr, _t, _s, _v, w, h, xhot, yhot, delay = struct.unpack_from('<9I', data, pos)
        yield pos + chdr, w, h


def tint_cursor(data):
    buf = bytearray(data)
    cache = {}
    for off, w, h in xcursor_images(data):
        for i in range(off, off + 4 * w * h, 4):
            b, g, r, a = buf[i], buf[i + 1], buf[i + 2], buf[i + 3]
            if a == 0:
                continue
            key = (b, g, r, a)
            out = cache.get(key)
            if out is None:
                ur, ug, ub = (min(255, round(c * 255 / a)) for c in (r, g, b))   # un-premultiply
                nr, ng, nb = tint_pixel(ur, ug, ub)
                out = bytes((round(nb * a / 255), round(ng * a / 255), round(nr * a / 255), a))
                cache[key] = out
            buf[i:i + 4] = out
    return bytes(buf)


def build_cursors(src, dest):
    src, dest = pathlib.Path(src), pathlib.Path(dest)
    dest.mkdir(parents=True, exist_ok=True)
    n = 0
    for p in sorted(src.iterdir()):
        d = dest / p.name
        if d.exists() or d.is_symlink():
            d.unlink()
        if p.is_symlink():
            os.symlink(os.readlink(p), d)
        else:
            d.write_bytes(tint_cursor(p.read_bytes()))
            n += 1
    print('cursor files re-tinted:', n)


def pixbuf_io():
    import gi
    gi.require_version('GdkPixbuf', '2.0')
    from gi.repository import GdkPixbuf, GLib
    return GdkPixbuf, GLib


def preview(cursor, out):
    GdkPixbuf, GLib = pixbuf_io()
    data = pathlib.Path(cursor).read_bytes()
    off, w, h = max(xcursor_images(data), key=lambda t: t[1])
    rgba = bytearray()
    for i in range(off, off + 4 * w * h, 4):
        b, g, r, a = data[i:i + 4]
        if a:
            r, g, b = (min(255, round(c * 255 / a)) for c in (r, g, b))
        rgba += bytes((r, g, b, a))
    pb = GdkPixbuf.Pixbuf.new_from_bytes(GLib.Bytes.new(bytes(rgba)), GdkPixbuf.Colorspace.RGB, True, 8, w, h, 4 * w)
    bg = pb.composite_color_simple(w * 3, h * 3, GdkPixbuf.InterpType.NEAREST, 255, 8, 0x233266, 0x1c2852)
    bg.savev(out, 'png', [], [])
    print('preview', w, 'x', h, '->', out)


def tint_pngs(folder):
    sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
    from recolor import remap
    GdkPixbuf, GLib = pixbuf_io()
    n = 0
    for p in sorted(pathlib.Path(folder).rglob('*.png')):
        pb = GdkPixbuf.Pixbuf.new_from_file(str(p))
        if not pb.get_has_alpha():
            pb = pb.add_alpha(False, 0, 0, 0)
        w, h, rs = pb.get_width(), pb.get_height(), pb.get_rowstride()
        px = bytearray(pb.get_pixels())
        cache = {}
        for y in range(h):
            for x in range(w):
                i = y * rs + 4 * x
                if px[i + 3] == 0:
                    continue
                key = (px[i], px[i + 1], px[i + 2])
                out = cache.get(key)
                if out is None:
                    out = cache[key] = remap(*key)
                px[i], px[i + 1], px[i + 2] = out
        new = GdkPixbuf.Pixbuf.new_from_bytes(GLib.Bytes.new(bytes(px)), GdkPixbuf.Colorspace.RGB, True, 8, w, h, rs)
        new.savev(str(p), 'png', [], [])
        n += 1
    print('png files re-tinted:', n)


if __name__ == '__main__':
    cmd, args = sys.argv[1], sys.argv[2:]
    {'icons': build_icons, 'cursors': build_cursors, 'pngs': tint_pngs, 'preview': preview}[cmd](*args)
