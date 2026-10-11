import re
import sys
from pathlib import Path

here = Path(__file__).parent
src, dst = sys.argv[1], sys.argv[2]
dsl = Path(src).read_text()

header = re.compile(r'(DefinitionBlock \("", "DSDT", \d+, "HPQOEM", "8E35    ", )0x([0-9A-Fa-f]{8})\)')
if len(header.findall(dsl)) != 1:
    sys.exit("intestazione DSDT inattesa")
dsl = header.sub(lambda m: f"{m.group(1)}0x{int(m.group(2), 16) + 1:08X})", dsl)

pegp = "    External (_SB_.PCI0.GPP0.PEGP, DeviceObj)\n"
if dsl.count(pegp) != 1:
    sys.exit("External di PEGP non trovato")
dsl = dsl.replace(pegp, pegp + (here / "externals.asl").read_text())

npts = "            \\_SB.PCI0.NPTS (Arg0)\n        }\n    }\n\n    Method (_WAK"
if dsl.count(npts) != 1:
    sys.exit("struttura di _PTS inattesa")
dsl = dsl.replace(npts, npts.replace("\n        }", "\n" + (here / "pts-s5.asl").read_text() + "        }", 1))

Path(dst).write_text(dsl)
