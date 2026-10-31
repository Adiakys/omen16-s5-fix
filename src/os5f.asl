DefinitionBlock ("", "SSDT", 2, "OMENS5", "S5FIX", 0x00000002)
{
    External (NVDE, IntObj)
    External (_SB_.PCI0.GPP0.PEGP.OMPR, IntObj)
    External (_SB_.PCI0.GPP0.PEGP._PS3, MethodObj)

    // Returns 0 if the objects are missing, 1 if done, 2 if done after arming NVDE
    Method (\OS5F, 0, Serialized)
    {
        Local0 = One
        If (CondRefOf (\_SB.PCI0.GPP0.PEGP.OMPR))
        {
            If (CondRefOf (\_SB.PCI0.GPP0.PEGP._PS3))
            {
                // PG00._OFF does nothing unless NVDE == 1, which only the NVIDIA
                // driver's Optimus _DSM calls set: arm it for nouveau or no driver
                If (CondRefOf (\NVDE))
                {
                    If ((\NVDE != One))
                    {
                        \NVDE = One
                        Local0 = 0x02
                    }
                }

                \_SB.PCI0.GPP0.PEGP.OMPR = 0x03
                \_SB.PCI0.GPP0.PEGP._PS3 ()
                Return (Local0)
            }
        }

        Return (Zero)
    }
}
