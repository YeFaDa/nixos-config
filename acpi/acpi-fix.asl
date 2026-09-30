DefinitionBlock ("ACDCFIX", "SSDT", 2, "YEFD", "HONORACP", 0x00000001)
{
    External (\_SB.ACDC, DeviceObj)

    /*
     * HONOR HGE-WX6 firmware 7.5 omits the ACDC namespace entirely, while
     * AMD's Microsoft Modern Standby PEP._DSM unconditionally reads
     * \_SB.ACDC.RTAC during resume. Supplying the missing integer objects
     * lets the PEP method finish; the zero values select its safe no-AC
     * event-mask branch.
     */
    Scope (\_SB)
    {
        If (CondRefOf (\_SB.ACDC))
        {
            // A future firmware update may provide the real namespace.
        }
        Else
        {
            Device (ACDC)
            {
                Name (_HID, "HGEW0001")
                Name (RTAC, Zero)
                Name (YARR, Zero)
                Name (MONR, Zero)
            }
        }
    }
}
