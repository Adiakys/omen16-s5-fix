# omen16-s5-fix

Su HP OMEN 16-ap0xxx (scheda 8E35) con Linux, a PC spento la scheda video NVIDIA resta alimentata e scarica la batteria (~20 W).

`install.sh` legge la DSDT del BIOS, aggiunge a `_PTS(5)` lo spegnimento della dGPU (`PEGP.OMPR = 3` + `PEGP._PS3()`), la ricompila e la fa caricare da GRUB a ogni avvio come override ACPI. Non tocca il BIOS.

```
sudo ./install.sh     # installa o ricontrolla, rilanciabile
sudo ./uninstall.sh   # rimuove tutto
```

Requisiti: Ubuntu/Debian con GRUB, Secure Boot disattivato.

Dopo un aggiornamento del BIOS: `uninstall.sh`, riavvio, `install.sh`.

Basato su [paolo-de-marinis/omen-acpi](https://github.com/paolo-de-marinis/omen-acpi).
