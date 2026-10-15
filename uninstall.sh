#!/usr/bin/env bash
set -euo pipefail

[ "$(id -u)" -eq 0 ] || exec sudo "$0" "$@"

REPO="$(cd "$(dirname "$0")" && pwd)"
NAME=omen-s5
VER="$(sed -n 's/^PACKAGE_VERSION="\(.*\)"$/\1/p' "$REPO/src/dkms.conf")"

dkms remove "$NAME/$VER" --all >/dev/null 2>&1 || true
rm -rf "/usr/src/$NAME-$VER"
rm -f /etc/modules-load.d/omen-s5.conf /usr/local/bin/omen-s5-check /etc/xdg/autostart/omen-s5-check.desktop

echo "rimosso: il modulo resta attivo fino al riavvio"
