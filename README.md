# omen16-s5-fix

Su HP OMEN 16-ap0xxx (scheda 8E35) con Linux, a PC spento la scheda video NVIDIA resta alimentata e scarica la batteria (~20 W).

`install.sh` legge la DSDT del BIOS, aggiunge a `_PTS(5)` lo spegnimento della dGPU (`pts-s5.asl`), la ricompila e la fa caricare da GRUB a ogni avvio come override ACPI (`omen-acpi.cfg`). Il BIOS non viene modificato.

```
sudo ./install.sh     # installa o ricontrolla, rilanciabile
sudo ./uninstall.sh   # rimuove tutto
```

File creati: `/boot/acpi-omen-s5.cpio`, `/boot/acpi-omen-s5.bios`, `/etc/default/grub.d/omen-acpi.cfg`.

Requisiti: Ubuntu/Debian con GRUB.

Dopo un aggiornamento del BIOS: `uninstall.sh`, riavvio, `install.sh`.

## Secure Boot

Con Secure Boot attivo il kernel va in lockdown e ignora l'override: `install.sh` si ferma.
Per avere Secure Boot attivo (es. anti-cheat su Windows) e il fix su Linux, disattivare la verifica di shim:

```
sudo mokutil --disable-validation   # conferma al riavvio in MokManager
```

Windows vede Secure Boot attivo; l'avvio di Linux non è più verificato.

Basato su [paolo-de-marinis/omen-acpi](https://github.com/paolo-de-marinis/omen-acpi).
