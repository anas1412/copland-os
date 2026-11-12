#!/usr/bin/env python3
"""Draw the CoplandOS window frame (xfwm4): square corners, a scanlined title bar,
a cyan edge and glow on the focused window only, and buttons drawn as the dots of the
Navi eye logo (close = pink dot, maximize = cyan ring, minimize = small cyan dot).

    tools/xfwm4-frame.py [XFWM4_DIR]

Writes the 57 pixmaps and themerc into XFWM4_DIR (default: the theme in this repo,
core/assets/themes/CoplandOS/xfwm4). The frame is generated, not drawn by hand, so
a palette change is one edit here and one run. Standard library only.
"""
import math, os, sys

X = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "core", "assets", "themes", "CoplandOS", "xfwm4")
os.makedirs(X, exist_ok=True)

W_BTN, H = 20, 24

# ---- palette (Copland tokens) ----
PAL = {
    "active": dict(edge="#46baef", glow="#2b6fae", t0="#233266", t1="#27386f", sep="#197aba"),
    "inactive": dict(edge="#34457e", glow="#1d2850", t0="#192346", t1="#1c274d", sep="#25335f"),
}
CYAN, GLOW, PINK, PINK_HI, BLUE, SLATE = "#46baef", "#8fd6fa", "#e0507a", "#ff7096", "#197aba", "#4a5c9a"


def hx(c):
    return tuple(int(c[i:i + 2], 16) for i in (1, 3, 5))


def mix(a, b, t):
    a, b = hx(a), hx(b)
    return "#%02x%02x%02x" % tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def row_color(state, y):
    p = PAL[state]
    if y == 0:
        return p["edge"]
    if y == 1:
        return p["glow"]
    if y == H - 1:
        return p["sep"]
    return p["t0"] if y % 2 == 0 else p["t1"]  # scanlines


def write_xpm(name, pixels):
    """pixels: list of rows of '#rrggbb' or None (transparent)."""
    h, w = len(pixels), len(pixels[0])
    cols = sorted({c for r in pixels for c in r}, key=lambda c: (c is None, c or ""))
    pool = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    codes = {c: pool[i // len(pool)] + pool[i % len(pool)] for i, c in enumerate(cols)}
    lines = ['"%d %d %d 2",' % (w, h, len(cols))]
    lines += ['"%s\tc %s",' % (codes[c], c if c else "None") for c in cols]
    body = ['"%s"' % "".join(codes[c] for c in r) for r in pixels]
    ident = name.replace("-", "_")
    with open(os.path.join(X, name + ".xpm"), "w") as f:
        f.write("/* XPM */\nstatic char * %s_xpm[] = {\n%s\n%s};\n" % (ident, "\n".join(lines), ",\n".join(body)))


def coverage(fn, x, y, ss=4):
    """fraction of pixel (x,y) inside shape fn(px,py) via supersampling"""
    n = 0
    for i in range(ss):
        for j in range(ss):
            if fn(x + (i + .5) / ss, y + (j + .5) / ss):
                n += 1
    return n / (ss * ss)


CX, CY = W_BTN / 2, H / 2 + 0.5  # optical centre (below the glow rows)


def disk(r):
    return lambda px, py: (px - CX) ** 2 + (py - CY) ** 2 <= r * r


def ring(r, t):
    return lambda px, py: (r - t) ** 2 <= (px - CX) ** 2 + (py - CY) ** 2 <= r * r


def union(*fs):
    return lambda px, py: any(f(px, py) for f in fs)


def button(state, layers):
    """layers: list of (shape_fn, color, alpha) painted in order over the title rows"""
    px = []
    for y in range(H):
        row = []
        for x in range(W_BTN):
            c = row_color(state, y)
            if 1 < y < H - 1:
                for fn, col, a in layers:
                    cov = coverage(fn, x, y) * a
                    if cov > 0:
                        c = mix(c, col, cov)
            row.append(c)
        px.append(row)
    return px


def halo(r, col, strength=.35):
    # soft glow: three widening rings, fading out
    return [(disk(r + 2.5), col, strength * .35), (disk(r + 1.5), col, strength * .6)]


# glyphs ------------------------------------------------------------------------------
def glyph(kind, col):
    if kind == "close":     # the logo's filled node, in Lain pink
        return [(disk(4.2), col, 1)]
    if kind == "maximize":  # open ring: the logo's orbit
        return [(ring(4.6, 1.7), col, 1)]
    if kind == "hide":      # small node
        return [(disk(2.3), col, 1)]
    if kind == "menu":      # plain title bar: xfwm4 paints the app icon on top (show_app_icon=true)
        return []
    if kind == "shade":     # thin ring, smaller
        return [(ring(3.4, 1.2), col, 1)]
    if kind == "stick":
        return [(ring(3.4, 1.2), col, 1), (disk(1.2), col, 1)]
    raise ValueError(kind)


FG = {  # active colour, prelight colour, pressed colour
    "close": (PINK, PINK_HI, "#a83a5c"),
    "maximize": (CYAN, GLOW, BLUE),
    "hide": (CYAN, GLOW, BLUE),
    "menu": (CYAN, GLOW, BLUE),
    "shade": (CYAN, GLOW, BLUE),
    "stick": (CYAN, GLOW, BLUE),
}
GLYPH_R = {"close": 4.2, "maximize": 4.6, "hide": 2.3, "menu": 5.0, "shade": 3.4, "stick": 3.4}

# button widths: the menu button sets the app-icon size (xfwm4 uses min(w, h)),
# 16 gives a 16px icon with 4px above and below; 14 keeps the dots' padding small
# so the right margin matches the icon's left margin
BTN_W = {"menu": 16}
for kind, (act, pre, prs) in FG.items():
    W_BTN = BTN_W.get(kind, 14)
    CX = W_BTN / 2
    variants = {
        "active": button("active", glyph(kind, act)),
        "inactive": button("inactive", glyph(kind, SLATE)),
        "prelight": button("active", (halo(GLYPH_R[kind], pre) if kind != "menu" else []) + glyph(kind, pre)),
        "pressed": button("active", glyph(kind, prs)),
    }
    if kind == "menu":
        # 20x16: xfwm4 sizes the app icon to min(w, h) = 16 and centres it, leaving 2px
        # each side, so the left margin matches the dots' right margin. The button is
        # centred vertically at rows MENU_Y..MENU_Y+15, so its background continues the
        # title bar's scanlines from that row.
        MENU_W, MENU_H = 20, 16
        MENU_Y = (H - MENU_H + 1) // 2
        variants = {v: [[row_color("inactive" if v == "inactive" else "active", y + MENU_Y)] * MENU_W
                         for y in range(MENU_H)] for v in variants}
    for v, px in variants.items():
        write_xpm("%s-%s" % (kind, v), px)
        if kind in ("shade", "stick"):
            write_xpm("%s-toggled-%s" % (kind, v), px)

# title strips, corners, borders ---------------------------------------------------------
for state in ("active", "inactive"):
    col = [row_color(state, y) for y in range(H)]
    for i in range(1, 6):
        write_xpm("title-%d-%s" % (i, state), [[c, c] for c in col])
    e = PAL[state]["edge"]
    # square top corners: 1px edge down the outer column, title rows inside
    write_xpm("top-left-%s" % state, [[e] + [c] * 7 for c in col])
    write_xpm("top-right-%s" % state, [[c] * 7 + [e] for c in col])
    for part in ("left", "right", "bottom", "bottom-left", "bottom-right"):
        write_xpm("%s-%s" % (part, state), [[e]])

with open(os.path.join(X, "themerc"), "w") as f:
    f.write("""# CoplandOS window frame: square frame, scanlined title, Navi-dot buttons.
# Generated by tools/xfwm4-frame.py; edit that, not this file.
active_text_color=#ffffff
inactive_text_color=#738dc1
title_shadow_active=false
title_shadow_inactive=false
full_width_title=true
title_vertical_offset_active=1
title_vertical_offset_inactive=1
button_offset=6
button_spacing=6
shadow_delta_height=2
shadow_delta_width=0
shadow_delta_x=0
shadow_delta_y=-10
shadow_opacity=50
show_app_icon=true
""")
print("wrote", len(os.listdir(X)), "files to", X)
