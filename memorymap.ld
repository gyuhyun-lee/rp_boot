MEMORY
{
    /* NOTE(gh) Since the UF2 file controls where the binary should be stored.
     make sure to change the addres within makeuf2.c for now. Hopefully we can
     ignore all these once we have our USB bootloader... */
    flash : ORIGIN = 0x20080000, LENGTH = 0x10000
}
SECTIONS
{
    .text   : { *(.text*)   } > flash
}
