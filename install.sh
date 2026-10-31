#!/usr/bin/env bash
set -euo pipefail

[ "$(id -u)" -eq 0 ] || exec sudo "$0" "$@"

REPO="$(cd "$(dirname "$0")" && pwd)"
NAME=omen-s5
VER="$(sed -n 's/^PACKAGE_VERSION="\(.*\)"$/\1/p' "$REPO/src/dkms.conf")"
KVER="$(uname -r)"
SRC="/usr/src/$NAME-$VER"

die() { echo "errore: $*" >&2; exit 1; }

secure_boot() {
    [ "$(od -An -t u1 -j4 -N1 /sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c 2>/dev/null | tr -d ' ')" = 1 ]
}

# chiavi con cui DKMS può aver firmato il modulo
certs() {
    sed -n 's/^mok_certificate=//p' /etc/dkms/framework.conf /etc/dkms/framework.conf.d/*.conf 2>/dev/null | tr -d "\"'"
    echo /var/lib/shim-signed/mok/MOK.der
    echo /var/lib/dkms/mok.pub
}

echo "== 1/6 controlli"
[ "$(cat /sys/class/dmi/id/board_name)" = "8E35" ] || die "scheda madre diversa da 8E35 (HP OMEN 16-ap0xxx)"
if command -v pacman >/dev/null && pacman -Q omen-s5-dkms >/dev/null 2>&1; then
    die "il modulo è già installato dal pacchetto omen-s5-dkms: aggiornalo o rimuovilo con pacman"
fi
[ -d "/lib/modules/$KVER" ] || die "i moduli del kernel $KVER non ci sono più (kernel aggiornato?): riavvia e rilancia"
# il kernel accetta solo moduli firmati: Secure Boot con lockdown (shim), o module.sig_enforce=1.
# Con Secure Boot senza lockdown (es. sbctl senza shim) la firma non serve.
SIGNED_ONLY=
if [ "$(cat /sys/module/module/parameters/sig_enforce 2>/dev/null)" = Y ]; then
    SIGNED_ONLY=1
elif secure_boot && ! grep -qsF '[none]' /sys/kernel/security/lockdown; then
    SIGNED_ONLY=1
fi

echo "== 2/6 dipendenze"
if command -v pacman >/dev/null; then
    PM="pacman -S --needed --noconfirm"
    HEADERS="$(sed 's/$/-headers/' /lib/modules/*/pkgbase 2>/dev/null | sort -u)"
elif command -v apt-get >/dev/null; then
    PM="apt-get install -y"
    HEADERS="linux-headers-$KVER"
elif command -v dnf >/dev/null; then
    PM="dnf install -y"
    HEADERS="kernel-devel-$KVER"
elif command -v zypper >/dev/null; then
    PM="zypper --non-interactive install"
    HEADERS="kernel-${KVER##*-}-devel"
else
    PM=
    HEADERS="header del kernel $KVER"
fi
PKGS=()
command -v dkms >/dev/null || PKGS+=(dkms)
# shellcheck disable=SC2206  # su Arch un pacchetto di header per ogni kernel installato
[ -d "/lib/modules/$KVER/build" ] || PKGS+=($HEADERS)
[ -z "$SIGNED_ONLY" ] || command -v mokutil >/dev/null || PKGS+=(mokutil)
if [ ${#PKGS[@]} -gt 0 ]; then
    [ -n "$PM" ] || die "installa: ${PKGS[*]}"
    $PM "${PKGS[@]}"
fi
[ -d "/lib/modules/$KVER/build" ] || die "header del kernel $KVER non trovati: aggiorna il sistema, riavvia e rilancia"

echo "== 3/6 compilazione e installazione"
# anche le versioni precedenti
for d in /usr/src/"$NAME"-*; do
    [ -d "$d" ] || continue
    dkms remove "$NAME/${d#/usr/src/"$NAME"-}" --all >/dev/null 2>&1 || true
    rm -rf "$d"
done
install -d "$SRC"
install -m 0644 "$REPO"/src/{omen_s5.c,os5f_aml.h,Makefile,dkms.conf} "$SRC/"
dkms add "$NAME/$VER" >/dev/null
dkms install "$NAME/$VER" -k "$KVER" >/dev/null || die "compilazione fallita, vedi /var/lib/dkms/$NAME/$VER/build/make.log"
# anche per gli altri kernel installati (es. linux-lts accanto a linux)
for d in /lib/modules/*/build; do
    k="$(basename "$(dirname "$d")")"
    [ -d "$d" ] && [ "$k" != "$KVER" ] || continue
    dkms install "$NAME/$VER" -k "$k" >/dev/null 2>&1 || echo "avviso: compilazione fallita per il kernel $k"
done

echo "== 4/6 firma"
SIGNER="$(modinfo -k "$KVER" -F signer omen_s5)"
CERT=
if [ -n "$SIGNER" ]; then
    while read -r c; do
        [ -f "$c" ] && openssl x509 -inform der -in "$c" -noout -subject 2>/dev/null | grep -qF "$SIGNER" && CERT=$c && break
    done < <(certs)
    echo "firmato da: $SIGNER${CERT:+ ($CERT)}"
elif [ -n "$SIGNED_ONLY" ]; then
    die "DKMS non ha firmato il modulo: imposta mok_signing_key e mok_certificate in /etc/dkms/framework.conf"
else
    echo "modulo non firmato: il kernel non lo richiede"
fi

echo "== 5/6 Secure Boot"
ENROLL=
if [ -n "$SIGNED_ONLY" ]; then
    [ -n "$CERT" ] || die "certificato di firma non trovato, impossibile registrarlo in MOK"
    if mokutil --test-key "$CERT" | grep -q 'not enrolled'; then
        echo "la chiave di firma va registrata in MOK: scegli una password temporanea"
        mokutil --import "$CERT"
        ENROLL=1
    else
        echo "chiave di firma già registrata"
    fi
elif secure_boot; then
    echo "Secure Boot attivo senza lockdown: nessuna chiave da registrare"
else
    echo "Secure Boot disattivato"
fi

echo "== 6/6 caricamento all'avvio"
echo omen_s5 > /etc/modules-load.d/omen-s5.conf
install -m 0755 "$REPO/tools/omen-s5-check" /usr/local/bin/omen-s5-check
install -d /etc/xdg/autostart
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
