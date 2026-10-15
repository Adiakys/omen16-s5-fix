# omen16-s5-fix

On the HP OMEN 16-ap0xxx (board 8E35) under Linux, the NVIDIA GPU stays powered after shutdown and drains the battery (~20 W). Windows is not affected.

`omen_s5` is a small kernel module that turns the dGPU off at the end of the shutdown sequence, so the laptop really reaches S5. It works with Secure Boot enabled.

## Install

```
sudo ./install.sh     # build, install, sign; safe to re-run
sudo ./uninstall.sh   # remove everything
```

`install.sh`:

1. checks that the board is 8E35;
2. installs `dkms` and the kernel headers if missing (apt, dnf, pacman or zypper);
3. builds and installs the module with DKMS, which rebuilds it on every kernel update;
4. checks that DKMS signed it with the machine's key;
5. with Secure Boot on, enrolls that key in MOK if needed (`mokutil --import`: choose a temporary password, reboot, pick "Enroll MOK");
6. loads the module now and at every boot, and installs a login check that notifies if the module is not loaded.

## How it works

At load the module checks the board (DMI) and the firmware objects it needs, then adds a tiny ACPI method, `\OS5F` (`src/os5f.asl`):

```
\_SB.PCI0.GPP0.PEGP.OMPR = 3
\_SB.PCI0.GPP0.PEGP._PS3 ()
```

At power-off it runs `\OS5F` from a power-off-prepare handler that comes right after the firmware's `_PTS(5)`. The BIOS and its ACPI tables are not modified.

## Layout

```
install.sh, uninstall.sh
src/omen_s5.c        kernel module
src/os5f.asl         ACPI method source
src/os5f_aml.h       compiled method (make -C src aml, needs iasl and xxd)
src/Makefile         kbuild / out-of-tree build
src/dkms.conf
tools/omen-s5-check  login notification if the module is not loaded
```

## Tested

OMEN 16-ap0004 (Ryzen 9 8940HX, RTX 5070), BIOS F.11, Ubuntu 26.04, kernel 7.0, Secure Boot with shim validation on (kernel lockdown: integrity): the module loads signed and power-off drain dropped from ~21 W to roughly 1–2 W. Experimental, use at your own risk.

Based on the analysis in [paolo-de-marinis/omen-acpi](https://github.com/paolo-de-marinis/omen-acpi).
