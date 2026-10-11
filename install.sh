#!/usr/bin/env bash
set -euo pipefail

[ "$(id -u)" -eq 0 ] || exec sudo "$0" "$@"

CPIO=/boot/acpi-omen-s5.cpio
STAMP=/boot/acpi-omen-s5.bios
CFG=/etc/default/grub.d/omen-acpi.cfg

die() { echo "errore: $*" >&2; exit 1; }

[ "$(cat /sys/class/dmi/id/board_name)" = "8E35" ] || die "scheda madre diversa da 8E35"
grep -q '^CONFIG_ACPI_TABLE_UPGRADE=y' "/boot/config-$(uname -r)" || die "kernel senza CONFIG_ACPI_TABLE_UPGRADE"
if [ -r /sys/kernel/security/lockdown ] && ! grep -q '\[none\]' /sys/kernel/security/lockdown; then
    die "kernel lockdown attivo (Secure Boot): l'override ACPI verrebbe ignorato"
fi
command -v update-grub >/dev/null || die "update-grub non trovato"

BIOS="$(cat /sys/class/dmi/id/bios_version)"

if ! command -v iasl >/dev/null || ! command -v cpio >/dev/null; then
    apt-get install -y acpica-tools cpio >/dev/null
fi

W="$(mktemp -d)"
trap 'rm -rf "$W"' EXIT
cd "$W"

cp /sys/firmware/acpi/tables/DSDT dsdt.aml
for t in /sys/firmware/acpi/tables/SSDT*; do cp "$t" "$(basename "$t").aml"; done
iasl -d dsdt.aml >/dev/null 2>&1
for s in SSDT*.aml; do iasl -e dsdt.aml -d "$s" >/dev/null 2>&1 || true; done

grep -q 'OMPR == 0x03' SSDT*.dsl && grep -q 'PG00._OFF ()' SSDT*.dsl || die "firmware non compatibile (OMPR/PG00 non trovati)"

if grep -q 'PEGP.OMPR = 0x03' dsdt.dsl; then
    [ -f "$CPIO" ] && [ -f "$STAMP" ] || die "DSDT già modificata ma mancano $CPIO o $STAMP"
    [ "$(cat "$STAMP")" = "$BIOS" ] || die "BIOS aggiornato: esegui uninstall.sh, riavvia e rilancia install.sh"
    echo "override già attivo, ricontrollo solo la configurazione di GRUB"
else
    python3 -I - dsdt.dsl dsdt-s5.dsl <<'PY'
import re, sys
src, dst = sys.argv[1], sys.argv[2]
s = open(src).read()

hdr = re.compile(r'(DefinitionBlock \("", "DSDT", \d+, "HPQOEM", "8E35    ", )0x([0-9A-Fa-f]{8})\)')
m = hdr.search(s)
if not m or len(hdr.findall(s)) != 1:
    sys.exit("intestazione DSDT inattesa")
s = hdr.sub(lambda m: f"{m.group(1)}0x{int(m.group(2), 16) + 1:08X})", s, count=1)

ext = [
    "    External (_SB_.PCI0.GPP0.PEGP.OMPR, IntObj)\n",
    "    External (_SB_.PCI0.GPP0.PEGP._PS3, MethodObj)\n",
]
missing = "".join(e for e in ext if e.split(",")[0] not in s)
pegp = "    External (_SB_.PCI0.GPP0.PEGP, DeviceObj)\n"
pos = s.find(pegp) + len(pegp) if pegp in s else s.find("    External (")
if pos < 0:
    sys.exit("nessuna dichiarazione External")
s = s[:pos] + missing + s[pos:]

anchor = "            \\_SB.PCI0.NPTS (Arg0)\n        }\n    }\n\n    Method (_WAK"
if s.count(anchor) != 1 or s.find("Method (_PTS") > s.find(anchor):
    sys.exit("struttura di _PTS inattesa")
block = (
    "            \\_SB.PCI0.NPTS (Arg0)\n"
    "            If ((Arg0 == 0x05))\n"
    "            {\n"
    "                If (CondRefOf (\\_SB.PCI0.GPP0.PEGP.OMPR))\n"
    "                {\n"
    "                    If (CondRefOf (\\_SB.PCI0.GPP0.PEGP._PS3))\n"
    "                    {\n"
    "                        \\_SB.PCI0.GPP0.PEGP.OMPR = 0x03\n"
    "                        \\_SB.PCI0.GPP0.PEGP._PS3 ()\n"
    "                    }\n"
    "                }\n"
    "            }\n"
    "        }\n    }\n\n    Method (_WAK"
)
s = s.replace(anchor, block, 1)
open(dst, "w").write(s)
PY
    iasl -tc dsdt-s5.dsl >/dev/null 2>&1 || die "compilazione della DSDT fallita"
    mkdir check && cp dsdt-s5.aml check/ && (cd check && iasl -d dsdt-s5.aml >/dev/null 2>&1)
    grep -q 'PEGP.OMPR = 0x03' check/dsdt-s5.dsl || die "verifica della DSDT compilata fallita"

    mkdir -p root/kernel/firmware/acpi
    install -m 0644 dsdt-s5.aml root/kernel/firmware/acpi/dsdt.aml
    (cd root && find kernel | cpio -H newc --create --quiet) > acpi.cpio
    install -m 0644 acpi.cpio "$CPIO"
    echo "$BIOS" > "$STAMP"
fi

mkdir -p /etc/default/grub.d
echo 'GRUB_EARLY_INITRD_LINUX_CUSTOM="acpi-omen-s5.cpio"' > "$CFG"
rm -f /etc/grub.d/42_omen_acpi_test
update-grub >/dev/null 2>&1
grep -q 'acpi-omen-s5.cpio' /boot/grub/grub.cfg || die "GRUB non carica l'override"

echo "fatto: riavvia, poi verifica con: journalctl -k -b | grep 'Table Upgrade'"
