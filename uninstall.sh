#!/usr/bin/env bash
set -euo pipefail

[ "$(id -u)" -eq 0 ] || exec sudo "$0" "$@"

rm -f /etc/grub.d/42_omen_s5_fix /etc/default/grub.d/omen-acpi.cfg /etc/grub.d/42_omen_nofix /boot/acpi-omen-s5.cpio /boot/acpi-omen-s5.bios \
      /usr/local/bin/omen-s5-check /etc/xdg/autostart/omen-s5-check.desktop
update-grub >/dev/null 2>&1

echo "rimosso: riavvia"
