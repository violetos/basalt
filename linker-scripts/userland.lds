ENTRY(_start)

PHDRS
{
    rodata  PT_LOAD  FILEHDR  PHDRS  FLAGS(1 << 2);              /* R-- */
    text    PT_LOAD                  FLAGS((1 << 0) | (1 << 2)); /* R-X */
    data    PT_LOAD                  FLAGS((1 << 1) | (1 << 2)); /* RW- */
    tls     PT_TLS                   FLAGS(1 << 2);              /* R-- */
}

SECTIONS
{
    . = 0x200000;

    . += SIZEOF_HEADERS;

    .rodata : ALIGN(16) {
        *(.rodata .rodata.*)
        *(.srodata .srodata.*)
        *(.data.rel.ro .data.rel.ro.*)
        *(.got .got.*)
    } :rodata

    . = ALIGN(CONSTANT(MAXPAGESIZE));

    .text : ALIGN(16) {
        *(.text .text.*)
        *(.plt .plt.* .iplt)
    } :text

    . = ALIGN(CONSTANT(MAXPAGESIZE));

    .tdata : ALIGN(16) {
        PROVIDE(__tdata_start = .);
        *(.tdata .tdata.* .gnu.linkonce.td.*)
        PROVIDE(__tdata_end = .);
    } :data :tls

    .tbss (NOLOAD) : ALIGN(16) {
        PROVIDE(__tbss_start = .);
        *(.tbss .tbss.* .gnu.linkonce.tb.*)
        *(.tcommon)
        PROVIDE(__tbss_end = .);
    } :tls

    .data : ALIGN(16) {
        KEEP(*(.init_array .init_array.*))
        KEEP(*(.fini_array .fini_array.*))
        *(.data .data.*)
        *(.sdata .sdata.* .sdata2 .sdata2.*)
    } :data

    .bss (NOLOAD) : ALIGN(16) {
        *(.sbss .sbss.* .scommon)
        *(.bss .bss.*)
        *(COMMON)
    } :data

    . = ALIGN(CONSTANT(MAXPAGESIZE));

    /DISCARD/ : {
        *(.eh_frame .eh_frame.*)
        *(.eh_frame_hdr)
        *(.gcc_except_table .gcc_except_table.*)
        *(.ARM.exidx .ARM.exidx.*)
        *(.ARM.extab .ARM.extab.*)
        *(.ARM.attributes)
        *(.riscv.attributes)
        *(.note .note.*)
        *(.comment)
        *(.interp)
        *(.dynamic)
        *(.dynsym)
        *(.dynstr)
        *(.hash)
        *(.gnu.hash)
    }
}
