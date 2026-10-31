# omen16-s5-fix

On the HP OMEN 16-ap0xxx (board 8E35) under Linux, the NVIDIA GPU stays powered after shutdown and drains the battery (~20 W). Windows is not affected.

`omen_s5` is a small kernel module that turns the dGPU off at the end of the shutdown sequence, so the laptop really reaches S5. It works with Secure Boot enabled.

## Symptoms

- The battery drains while the laptop is shut down: a full charge is gone within a few hours, or the laptop is dead the next morning.
- Only after shutting down from Linux; after shutting down from Windows the charge holds.
- The laptop draws about 20 W while off, because the NVIDIA GPU stays powered after power-off.

It applies if this prints `8E35`:

```
cat /sys/class/dmi/id/board_name
```

## Install

### Any distro: `install.sh`

```
sudo ./install.sh     # build, install, sign; safe to re-run
sudo ./uninstall.sh   # remove everything
```

`install.sh`:

1. checks that the board is 8E35, and whether the kernel accepts only signed modules (Secure Boot with lockdown, as with shim, or `module.sig_enforce=1`);
2. installs `dkms`, the kernel headers and, if needed, `mokutil`, when missing:

   | Package manager | Headers installed |
   |---|---|
   | `pacman` (Arch, CachyOS, Manjaro, EndeavourOS, Omarchy) | `<kernel>-headers` for every installed kernel (`linux`, `linux-lts`, `linux-zen`, `linux-cachyos`…) |
   | `apt` (Debian, Ubuntu, Mint, Pop!_OS) | `linux-headers-$(uname -r)` |
   | `dnf` (Fedora, Nobara) | `kernel-devel-$(uname -r)` |
   | `zypper` (openSUSE) | `kernel-<flavor>-devel` |

   Elsewhere, install `dkms` and the headers yourself and re-run;
3. builds and installs the module with DKMS for every kernel that has headers; DKMS rebuilds it on every kernel update;
4. checks that DKMS signed it with the machine's key;
5. if the kernel accepts only signed modules, enrolls that key in MOK if needed (`mokutil --import`: choose a temporary password, reboot, pick "Enroll MOK"). With Secure Boot but no lockdown, as with `sbctl` and no shim, nothing needs enrolling;
6. loads the module now and at every boot (systemd `modules-load.d`), and installs a login check that notifies if the module is not loaded.

A BIOS update can wipe the enrolled MOK keys: the module then fails to load under Secure Boot. Re-run `install.sh` to enroll the key again.

### Arch: `omen-s5-dkms` package

[`packaging/arch/PKGBUILD`](packaging/arch/PKGBUILD) builds the `omen-s5-dkms` package from the release tag:

```
cd packaging/arch
makepkg -si           # DKMS builds the module for every installed kernel
sudo modprobe omen_s5 # or reboot
```

Remove it with `sudo pacman -R omen-s5-dkms`. The package does not touch Secure Boot: with shim and lockdown, enroll the DKMS key once with `sudo mokutil --import /var/lib/dkms/mok.pub`, then reboot and pick "Enroll MOK". Use either the package or `install.sh`, not both.

## How it works

At load the module checks the board (DMI) and the firmware objects it needs, then adds a tiny ACPI method, `\OS5F` (`src/os5f.asl`):

```
\NVDE = 1                          // only if not already 1
\_SB.PCI0.GPP0.PEGP.OMPR = 3
\_SB.PCI0.GPP0.PEGP._PS3 ()        // -> \_SB.PCI0.GPP0.PG00._OFF (): dGPU power rail off
```

At power-off it runs `\OS5F` from a power-off-prepare handler that comes right after the firmware's `_PTS(5)`. The BIOS and its ACPI tables are not modified.

`PG00._OFF` returns without doing anything unless `\NVDE` is 1, and only the NVIDIA driver sets it (through its Optimus `_DSM` calls). `\OS5F` sets it itself, so the fix also works with nouveau or with no driver bound to the dGPU. With the NVIDIA driver `\NVDE` is already 1 and nothing changes. By the time `\OS5F` runs, the kernel has run `_PTS(5)` and disabled all GPEs, and every driver has shut down, so the other firmware code that reads `\NVDE` (an EC event handler and a WMI method) is not reached.

## Layout

```
install.sh, uninstall.sh
packaging/arch/      PKGBUILD for the omen-s5-dkms package
src/omen_s5.c        kernel module
src/os5f.asl         ACPI method source
src/os5f_aml.h       compiled method (make -C src aml, needs iasl and xxd)
src/Makefile         kbuild / out-of-tree build
src/dkms.conf
tools/omen-s5-check  login notification if the module is not loaded
```

## Tested

OMEN 16-ap0004 (Ryzen 9 8940HX, RTX 5070), BIOS F.11, Ubuntu 26.04, kernel 7.0, Secure Boot with shim validation on (kernel lockdown: integrity): the module loads signed and power-off drain dropped from ~21 W to roughly 1–2 W. Tested with the NVIDIA driver; nouveau and no driver are not measured yet. Experimental, use at your own risk.

Based on the analysis in [paolo-de-marinis/omen-acpi](https://github.com/paolo-de-marinis/omen-acpi). [jacobdeanpugh/omen16-linux-fix](https://github.com/jacobdeanpugh/omen16-linux-fix) wraps this module for Arch, with an ACPI layout checker and a battery ledger that measures the power drawn while off.
