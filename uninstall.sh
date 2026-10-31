#!/usr/bin/env bash
set -euo pipefail

[ "$(id -u)" -eq 0 ] || exec sudo "$0" "$@"

NAME=omen-s5

if command -v pacman >/dev/null && pacman -Q omen-s5-dkms >/dev/null 2>&1; then
    echo "errore: il modulo è installato dal pacchetto omen-s5-dkms, rimuovilo con  pacman -R omen-s5-dkms" >&2
    exit 1
fi

# anche le versioni precedenti
for d in /usr/src/"$NAME"-*; do
    [ -d "$d" ] || continue
    dkms remove "$NAME/${d#/usr/src/"$NAME"-}" --all >/dev/null 2>&1 || true
    rm -rf "$d"
done
rm -f /etc/modules-load.d/omen-s5.conf /usr/local/bin/omen-s5-check /etc/xdg/autostart/omen-s5-check.desktop

echo "rimosso: il modulo resta attivo fino al riavvio"
