DefinitionBlock ("", "SSDT", 2, "OMENS5", "S5FIX", 0x00000001)
{
    External (_SB_.PCI0.GPP0.PEGP.OMPR, IntObj)
    External (_SB_.PCI0.GPP0.PEGP._PS3, MethodObj)

    Method (\OS5F, 0, Serialized)
    {
        If (CondRefOf (\_SB.PCI0.GPP0.PEGP.OMPR))
        {
            If (CondRefOf (\_SB.PCI0.GPP0.PEGP._PS3))
            {
                \_SB.PCI0.GPP0.PEGP.OMPR = 0x03
                \_SB.PCI0.GPP0.PEGP._PS3 ()
                Return (One)
            }
        }
        Return (Zero)
    }
}
