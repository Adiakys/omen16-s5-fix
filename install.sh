#!/usr/bin/env bash
set -euo pipefail

[ "$(id -u)" -eq 0 ] || exec sudo "$0" "$@"

REPO="$(cd "$(dirname "$0")" && pwd)"
NAME=omen-s5
VER="$(sed -n 's/^PACKAGE_VERSION="\(.*\)"$/\1/p' "$REPO/src/dkms.conf")"
KVER="$(uname -r)"
SRC="/usr/src/$NAME-$VER"

die() { echo "errore: $*" >&2; exit 1; }

echo "== 1/6 controlli"
[ "$(cat /sys/class/dmi/id/board_name)" = "8E35" ] || die "scheda madre diversa da 8E35 (HP OMEN 16-ap0xxx)"

echo "== 2/6 dipendenze"
if ! command -v dkms >/dev/null || [ ! -d "/lib/modules/$KVER/build" ]; then
    if command -v apt-get >/dev/null; then apt-get install -y dkms "linux-headers-$KVER"
    elif command -v dnf >/dev/null; then dnf install -y dkms "kernel-devel-$KVER"
    elif command -v pacman >/dev/null; then pacman -S --needed --noconfirm dkms linux-headers
    elif command -v zypper >/dev/null; then zypper install -y dkms kernel-devel
    else die "installa dkms e gli header del kernel $KVER"
    fi
fi

echo "== 3/6 compilazione e installazione"
dkms remove "$NAME/$VER" --all >/dev/null 2>&1 || true
rm -rf "$SRC"
install -d "$SRC"
install -m 0644 "$REPO"/src/{omen_s5.c,os5f_aml.h,Makefile,dkms.conf} "$SRC/"
dkms add "$NAME/$VER" >/dev/null
dkms install "$NAME/$VER" >/dev/null || die "compilazione fallita, vedi /var/lib/dkms/$NAME/$VER/build/make.log"

echo "== 4/6 firma"
SIGNER="$(modinfo -k "$KVER" -F signer omen_s5)"
[ -n "$SIGNER" ] || die "DKMS non ha firmato il modulo: imposta mok_signing_key e mok_certificate in /etc/dkms/framework.conf"
CERT=
for c in /var/lib/shim-signed/mok/MOK.der /var/lib/dkms/mok.pub; do
    [ -f "$c" ] && openssl x509 -inform der -in "$c" -noout -subject 2>/dev/null | grep -qF "$SIGNER" && CERT=$c && break
done
echo "firmato da: $SIGNER${CERT:+ ($CERT)}"

echo "== 5/6 Secure Boot"
ENROLL=
if mokutil --sb-state 2>/dev/null | grep -q 'SecureBoot enabled'; then
    [ -n "$CERT" ] || die "certificato di firma non trovato, impossibile registrarlo in MOK"
    if mokutil --test-key "$CERT" | grep -q 'not enrolled'; then
        echo "la chiave di firma va registrata in MOK: scegli una password temporanea"
        mokutil --import "$CERT"
        ENROLL=1
    else
        echo "chiave di firma già registrata"
    fi
else
    echo "Secure Boot disattivato"
fi

echo "== 6/6 caricamento all'avvio"
echo omen_s5 > /etc/modules-load.d/omen-s5.conf
install -m 0755 "$REPO/tools/omen-s5-check" /usr/local/bin/omen-s5-check
install -m 0644 "$REPO/tools/omen-s5-check.desktop" /etc/xdg/autostart/omen-s5-check.desktop
if [ -d /sys/module/omen_s5 ]; then
    echo "fatto: modulo già caricato, la nuova versione sarà attiva dal prossimo avvio"
elif modprobe omen_s5 2>/dev/null; then
    echo "fatto: modulo attivo"
elif [ -n "$ENROLL" ]; then
    echo "fatto: riavvia e in MokManager scegli 'Enroll MOK' con la password appena scelta"
else
    die "il modulo non si carica, vedi  journalctl -k -b | grep omen_s5"
fi
[ -n "$ENROLL" ] && [ -d /sys/module/omen_s5 ] && echo "al riavvio, in MokManager scegli 'Enroll MOK' con la password appena scelta"
exit 0
