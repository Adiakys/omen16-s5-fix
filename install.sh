#!/usr/bin/env bash
set -euo pipefail

[ "$(id -u)" -eq 0 ] || exec sudo "$0" "$@"

REPO="$(cd "$(dirname "$0")" && pwd)"
CPIO=/boot/acpi-omen-s5.cpio
STAMP=/boot/acpi-omen-s5.bios
CFG=/etc/default/grub.d/omen-acpi.cfg
BIOS="$(cat /sys/class/dmi/id/bios_version)"

die() { echo "errore: $*" >&2; exit 1; }

echo "== 1/6 controlli"
[ "$(cat /sys/class/dmi/id/board_name)" = "8E35" ] || die "scheda madre diversa da 8E35"
grep -q '^CONFIG_ACPI_TABLE_UPGRADE=y' "/boot/config-$(uname -r)" || die "kernel senza CONFIG_ACPI_TABLE_UPGRADE"
grep -q '\[none\]' /sys/kernel/security/lockdown 2>/dev/null || die "Secure Boot attivo: il kernel ignorerebbe il fix (vedi README)"
command -v update-grub >/dev/null || die "update-grub non trovato"

echo "== 2/6 dipendenze"
command -v iasl >/dev/null && command -v cpio >/dev/null || apt-get install -y acpica-tools cpio >/dev/null

echo "== 3/6 lettura tabelle ACPI del BIOS"
W="$(mktemp -d)"
trap 'rm -rf "$W"' EXIT
cd "$W"
cp /sys/firmware/acpi/tables/DSDT dsdt.aml
for t in /sys/firmware/acpi/tables/SSDT*; do cp "$t" "$(basename "$t").aml"; done
iasl -d dsdt.aml >/dev/null 2>&1
for s in SSDT*.aml; do iasl -e dsdt.aml -d "$s" >/dev/null 2>&1 || true; done
grep -q 'OMPR == 0x03' SSDT*.dsl && grep -q 'PG00._OFF ()' SSDT*.dsl || die "firmware non compatibile"

if grep -q 'PEGP.OMPR = 0x03' dsdt.dsl; then
    echo "== 4/6 DSDT già corretta (fix attivo), salto la ricompilazione"
    [ -f "$CPIO" ] && [ "$(cat "$STAMP" 2>/dev/null)" = "$BIOS" ] || die "BIOS cambiato o file mancanti: esegui uninstall.sh, riavvia e rilancia install.sh"
    echo "== 5/6 $CPIO già presente"
else
    echo "== 4/6 correzione e compilazione della DSDT"
    python3 -I "$REPO/patch-dsdt.py" dsdt.dsl fixed.dsl
    iasl -tc fixed.dsl >/dev/null 2>&1 || die "compilazione fallita"
    mkdir -p check root/kernel/firmware/acpi
    cp fixed.aml check/ && (cd check && iasl -d fixed.aml >/dev/null 2>&1)
    grep -q 'PEGP.OMPR = 0x03' check/fixed.dsl || die "verifica della DSDT compilata fallita"

    echo "== 5/6 copia di $CPIO"
    cp fixed.aml root/kernel/firmware/acpi/dsdt.aml
    (cd root && find kernel | cpio -H newc --create --quiet) > acpi.cpio
    install -m 0644 acpi.cpio "$CPIO"
    echo "$BIOS" > "$STAMP"
fi

echo "== 6/6 configurazione di GRUB"
install -D -m 0644 "$REPO/omen-acpi.cfg" "$CFG"
rm -f /etc/grub.d/42_omen_acpi_test
update-grub >/dev/null 2>&1
grep -q 'acpi-omen-s5.cpio' /boot/grub/grub.cfg || die "GRUB non carica il fix"

echo "fatto: riavvia e verifica con  journalctl -k -b | grep 'Table Upgrade'"
