#!/usr/bin/env python3
"""Turn core/settings.tsv into XFCE system default files.

    xfconf-xml.py SETTINGS OUTDIR --theme DIR --bin DIR [--components a,b,...]

Writes, under OUTDIR:
  xfce4/xfconf/xfce-perchannel-xml/<channel>.xml   every channel except xfce4-panel
  xfce4/panel/default.xml                          the xfce4-panel channel

OUTDIR is meant to be placed first in XDG_CONFIG_DIRS (for example /etc/xdg/copland-os).
xfconf reads system files per property and the user's own value always wins.
The panel goes to panel/default.xml, not to an xfconf channel file: xfce4-panel copies
default.xml only for users who have no panel yet, and a system xfce4-panel.xml would
stop that from happening.

Standard library only, so it runs inside a build chroot.
"""
import argparse
import os
import sys
from xml.sax.saxutils import quoteattr

SCALARS = {"string", "int", "uint", "bool", "double"}


class Node:
    def __init__(self, name):
        self.name = name
        self.type = None      # scalar type, "array", or None for a branch
        self.value = None     # scalar value, or list of (type, value) for arrays
        self.children = {}    # name -> Node, in insertion order

    def child(self, name):
        if name not in self.children:
            self.children[name] = Node(name)
        return self.children[name]


def read_rows(path, components):
    rows = []
    with open(path, encoding="utf-8") as fh:
        for lineno, line in enumerate(fh, 1):
            line = line.rstrip("\n")
            if not line or line.startswith("#"):
                continue
            parts = line.split("\t")
            if len(parts) != 5:
                sys.exit("%s:%d: expected 5 tab-separated fields, got %d" % (path, lineno, len(parts)))
            comp, channel, prop, typ, value = parts
            if components and comp not in components:
                continue
            if not prop.startswith("/"):
                sys.exit("%s:%d: property must start with /" % (path, lineno))
            base = typ[len("array:"):] if typ.startswith("array:") else typ
            if base not in SCALARS:
                sys.exit("%s:%d: unknown type %r" % (path, lineno, typ))
            rows.append((comp, channel, prop, typ, value))
    return rows


def expand_shortcuts(rows):
    """Keyboard shortcuts: Debian's system file defines only /commands/default, and XFCE
    reads /commands/custom only once a user has changed a shortcut (custom/override).
    A new user must get ours either way, so each custom row is also written to default."""
    out = []
    for row in rows:
        out.append(row)
        comp, channel, prop, typ, value = row
        if channel == "xfce4-keyboard-shortcuts" and prop.startswith("/commands/custom/"):
            out.append((comp, channel, "/commands/default/" + prop[len("/commands/custom/"):], typ, value))
    return out


def build(rows, theme, bindir):
    channels = {}
    for _comp, channel, prop, typ, value in expand_shortcuts(rows):
        value = value.replace("@THEME@", theme).replace("@BIN@", bindir)
        root = channels.setdefault(channel, Node(channel))
        node = root
        for name in prop.strip("/").split("/"):
            node = node.child(name)
        if typ.startswith("array:"):
            base = typ[len("array:"):]
            node.type = "array"
            node.value = [(base, v) for v in value.split("|")]
        else:
            node.type = typ
            node.value = value
    return channels


def emit(node, indent, out):
    pad = "  " * indent
    typ = node.type or "empty"
    if typ == "array":
        out.append("%s<property name=%s type=\"array\">" % (pad, quoteattr(node.name)))
        for vtype, v in node.value:
            out.append("%s  <value type=%s value=%s/>" % (pad, quoteattr(vtype), quoteattr(v)))
        for c in node.children.values():
            emit(c, indent + 1, out)
        out.append("%s</property>" % pad)
        return
    attrs = "name=%s type=%s" % (quoteattr(node.name), quoteattr(typ))
    if typ != "empty":
        attrs += " value=%s" % quoteattr(node.value)
    if node.children:
        out.append("%s<property %s>" % (pad, attrs))
        for c in node.children.values():
            emit(c, indent + 1, out)
        out.append("%s</property>" % pad)
    else:
        out.append("%s<property %s/>" % (pad, attrs))


def render(root):
    out = ['<?xml version="1.0" encoding="UTF-8"?>',
           "<!-- Copland OS: generated from core/settings.tsv by tools/xfconf-xml.py; do not edit -->",
           "",
           '<channel name=%s version="1.0">' % quoteattr(root.name)]
    for c in root.children.values():
        emit(c, 1, out)
    out.append("</channel>")
    return "\n".join(out) + "\n"


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("settings")
    ap.add_argument("outdir")
    ap.add_argument("--theme", required=True, help="CoplandOS theme folder, replaces @THEME@")
    ap.add_argument("--bin", required=True, help="folder holding copland-goto/send, replaces @BIN@")
    ap.add_argument("--components", default="", help="comma-separated component ids (default: all)")
    args = ap.parse_args()

    comps = {c for c in args.components.split(",") if c}
    channels = build(read_rows(args.settings, comps), args.theme, args.bin)
    written = []
    for name, root in channels.items():
        if name == "xfce4-panel":
            path = os.path.join(args.outdir, "xfce4", "panel", "default.xml")
        else:
            path = os.path.join(args.outdir, "xfce4", "xfconf", "xfce-perchannel-xml", name + ".xml")
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(render(root))
        written.append(path)
    for p in written:
        print(p)


if __name__ == "__main__":
    main()
