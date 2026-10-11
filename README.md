# omen16-s5-fix

On the HP OMEN 16-ap0xxx (board 8E35) under Linux, the NVIDIA GPU stays powered after shutdown and drains the battery (~20 W).

`install.sh` reads the BIOS DSDT, adds a dGPU power-off to `_PTS(5)` (`pts-s5.asl`), recompiles it and has GRUB load it on every boot as an ACPI override (`omen-acpi.cfg`). The BIOS itself is not modified.

```
sudo ./install.sh     # install or re-check, safe to re-run
sudo ./uninstall.sh   # remove everything
```

Files created: `/boot/acpi-omen-s5.cpio`, `/boot/acpi-omen-s5.bios`, `/etc/default/grub.d/omen-acpi.cfg`.

Requirements: Ubuntu/Debian with GRUB.

Tested on OMEN 16-ap0004 (Ryzen 9 8940HX, RTX 5070), BIOS F.11, Ubuntu 26.04, kernel 7.0: power-off drain went from ~21 W to ~1 W. Experimental, use at your own risk.

After a BIOS update: `uninstall.sh`, reboot, `install.sh`.

## Secure Boot

With Secure Boot on, the kernel enters lockdown and ignores the override, so `install.sh` stops.
To keep Secure Boot on (e.g. for Windows anti-cheat) and still get the fix on Linux, disable shim validation:

```
sudo mokutil --disable-validation   # confirm in MokManager on reboot
```

Windows sees Secure Boot enabled; the Linux boot chain is no longer verified.

Based on [paolo-de-marinis/omen-acpi](https://github.com/paolo-de-marinis/omen-acpi).
