#!/usr/bin/env bash
set -euo pipefail

[ "$(id -u)" -eq 0 ] || exec sudo "$0" "$@"

rm -f /etc/default/grub.d/omen-acpi.cfg /etc/grub.d/42_omen_acpi_test /boot/acpi-omen-s5.cpio /boot/acpi-omen-s5.bios
update-grub >/dev/null 2>&1

echo "rimosso: riavvia"
