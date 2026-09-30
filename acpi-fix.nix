{ pkgs, ... }:
let
  acpiTables =
    pkgs.runCommandLocal "honor-hge-wx6-acpi-tables"
      {
        nativeBuildInputs = [
          pkgs.acpica-tools
          pkgs.cpio
        ];
      }
      ''
        cp ${./acpi/SSDT11-fixed.dsl} SSDT11-fixed.dsl
        cp ${./acpi/acpi-fix.asl} acpi-fix.asl

        iasl -sa -p SSDT11-fixed SSDT11-fixed.dsl
        iasl -sa -p acpi-fix acpi-fix.asl

        mkdir -p kernel/firmware/acpi
        cp SSDT11-fixed.aml kernel/firmware/acpi/
        cp acpi-fix.aml kernel/firmware/acpi/

        find kernel -print0 \
          | sort -z \
          | cpio --null --create --format=newc --reproducible > "$out"
      '';
in
{
  # Linux loads these AML tables from the first, uncompressed initrd archive
  # before the firmware ACPI namespace is initialized.
  #
  # SSDT11-fixed upgrades AMD/EXTGPP00 revision 1 to revision 2 after removing
  # duplicate GPP0/GPP2 _PRW objects already defined by the DSDT.
  #
  # acpi-fix supplies the missing HONOR ACDC namespace used unconditionally by
  # AMD's Microsoft Modern Standby PEP._DSM during resume. Its CondRefOf guard
  # becomes a no-op if a future BIOS provides the real namespace.
  #
  # Review or remove this module after a BIOS update that fixes these tables.
  boot.initrd.prepend = [ "${acpiTables}" ];
}
