#!/usr/bin/env python3
"""Copland OS: make the installer's settings.conf from Debian's.

    patch-settings.py /etc/calamares/settings.conf.debian /etc/calamares/settings.conf

Debian's file, with four changes, each required to match exactly once (a Debian update
that moves things stops the ISO build instead of shipping a broken installer):
  - the Copland branding folder
  - two checklist pages, "Apps" and "Developer tools" (packagechooserq-*.conf, the QML
    package chooser: real checkboxes, choose-*.qml in the branding folder)
  - those pages shown right after Users, before Summary
  - the copland-extras job right after sources-final, which writes Debian's online
    sources: before it, apt in the new system only sees the ISO
"""
import re
import sys

src, dst = sys.argv[1], sys.argv[2]
text = open(src).read()


def once(pattern, repl):
    global text
    text, n = re.subn(pattern, repl, text, count=1, flags=re.M)
    if n != 1:
        sys.exit("settings.conf: expected one match for %r, found %d" % (pattern, n))


once(r"^branding: .*$", "branding: copland")
once(r"^sequence:",
     "instances:\n"
     "- id: apps\n  module: packagechooserq\n  config: packagechooserq-apps.conf\n"
     "- id: dev\n  module: packagechooserq\n  config: packagechooserq-dev.conf\n"
     "\nsequence:")
once(r"^(  - users\n)(  - summary\n)", r"\1  - packagechooserq@apps\n  - packagechooserq@dev\n\2")
once(r"^(  - sources-final\n)", r"\1  - copland-extras\n")

open(dst, "w").write(text)
