#!/usr/bin/env python3
# Copland OS installer job: install what was ticked on the "Apps" and "Developer tools"
# pages (packagechooser@apps, packagechooser@dev) with copland-extras, inside the new
# system. It runs after Debian's online sources are written, needs the internet, and
# never fails the install: whatever could not be installed is listed in a note in the
# new account's home, with the command that installs it later.

import os
import re
import shutil
import subprocess

import libcalamares


def pretty_name():
    return "Installing the extra software you picked"


def chosen():
    gs = libcalamares.globalstorage
    ids = []
    for key in ("packagechooser_apps", "packagechooser_dev"):
        value = gs.value(key) or ""
        ids += [i for i in str(value).split(",") if i]
    return ids


def note(root, user, text):
    """a plain text file in the new account's home, owned by the account"""
    home = os.path.join(root, "home", user)
    if not os.path.isdir(home):
        return
    path = os.path.join(home, "Extra software.txt")
    with open(path, "w") as f:
        f.write(text)
    subprocess.call(["chroot", root, "chown", user + ":", "/home/%s/Extra software.txt" % user])


def run():
    ids = chosen()
    if not ids:
        libcalamares.utils.debug("copland-extras: nothing picked")
        return None
    gs = libcalamares.globalstorage
    root = gs.value("rootMountPoint")
    user = gs.value("username") or ""
    tool = os.path.join(root, "usr/bin/copland-extras")
    later = "sudo copland-extras " + " ".join(ids)
    if not os.path.exists(tool):
        libcalamares.utils.warning("copland-extras is missing from the new system")
        note(root, user, "These were not installed: %s\n" % ", ".join(ids))
        return None

    # apt inside the new system needs a name server: lend it the live system's for now
    resolv = os.path.join(root, "etc/resolv.conf")
    saved = resolv + ".copland-extras"
    had = os.path.lexists(resolv)
    if had:
        os.rename(resolv, saved)
    try:
        shutil.copyfile("/etc/resolv.conf", resolv)
    except OSError as e:
        libcalamares.utils.warning("no resolv.conf to lend: %s" % e)

    cmd = ["chroot", root, "/usr/bin/copland-extras", "--from-installer"]
    if user:
        cmd += ["--user", user]
    cmd += ids
    libcalamares.utils.debug("running " + " ".join(cmd))
    step = re.compile(r"\[(\d+)/(\d+)\]")
    failed_line = ""
    try:
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                text=True, errors="replace",
                                env=dict(os.environ, DEBIAN_FRONTEND="noninteractive"))
        for line in proc.stdout:
            line = line.rstrip()
            libcalamares.utils.debug(line)
            m = step.search(line)
            if m:
                done, total = int(m.group(1)) - 1, int(m.group(2))
                libcalamares.job.setprogress(done / max(total, 1))
            if line.startswith("copland-extras: not installed:"):
                failed_line = line[len("copland-extras: "):]
        rc = proc.wait()
    finally:
        try:
            os.remove(resolv)
        except OSError:
            pass
        if had:
            os.rename(saved, resolv)

    libcalamares.job.setprogress(1.0)
    if rc != 0:
        libcalamares.utils.warning("copland-extras ended with %d" % rc)
        note(root, user, "Some of the software picked during the install could not be installed,\n"
                         "usually because there was no internet connection.\n\n%s\n\n"
                         "To install it now, open a terminal and run:\n\n    %s\n"
                         % (failed_line or "Picked: " + ", ".join(ids), later))
    return None
