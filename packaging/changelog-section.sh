#!/bin/sh
# Print the CHANGELOG.md section of one version (its lines between "## [x.y.z]" and
# the next "## " heading), or fail when there is none: no release without a changelog.
#   packaging/changelog-section.sh 0.2.0
set -eu
v="${1:?usage: changelog-section.sh VERSION}"
f="$(dirname "$0")/../CHANGELOG.md"
out="$(awk -v head="## [$v]" 'index($0, head) == 1 { on = 1; next } on && /^## / { exit } on' "$f")"
if [ -z "$(printf '%s' "$out" | tr -d '[:space:]')" ]; then
    echo "CHANGELOG.md has no section for $v: add \"## [$v] - <date>\" with what changed." >&2
    exit 1
fi
printf '%s\n' "$out" | sed -e '/./,$!d'
