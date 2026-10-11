            If ((Arg0 == 0x05))
            {
                If (CondRefOf (\_SB.PCI0.GPP0.PEGP.OMPR))
                {
                    If (CondRefOf (\_SB.PCI0.GPP0.PEGP._PS3))
                    {
                        \_SB.PCI0.GPP0.PEGP.OMPR = 0x03
                        \_SB.PCI0.GPP0.PEGP._PS3 ()
                    }
                }
            }
