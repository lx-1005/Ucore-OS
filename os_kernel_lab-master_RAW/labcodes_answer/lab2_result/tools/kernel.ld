/* Simple linker script for the ucore kernel.
   See the GNU ld 'info' manual ("info ld") to learn the syntax. */

OUTPUT_FORMAT("elf32-i386", "elf32-i386", "elf32-i386")
OUTPUT_ARCH(i386)
ENTRY(kern_entry)

SECTIONS {
    /* Load the kernel at this address: "." means the current address */
    . = 0xC0100000;

    .text : {
        *(.text .stub .text.* .gnu.linkonce.t.*)
    }

    PROVIDE(etext = .); /* Define the 'etext' symbol to this value */

    .rodata : {
        *(.rodata .rodata.* .gnu.linkonce.r.*)
    }

    /* Include debugging information in kernel memory */
    .stab : {
        PROVIDE(__STAB_BEGIN__ = .);
        *(.stab);
        PROVIDE(__STAB_END__ = .);
        BYTE(0)     /* Force the linker to allocate space
                   for this section */
    }

    .stabstr : {
        PROVIDE(__STABSTR_BEGIN__ = .);
        *(.stabstr);
        PROVIDE(__STABSTR_END__ = .);
        BYTE(0)     /* Force the linker to allocate space
                   for this section */
    }

    /* Adjust the address for the data segment to the next page */
    . = ALIGN(0x1000);

    /* The data segment */
    .data : {
        *(.data)
    }

    . = ALIGN(0x1000);
    .data.pgdir : {
        *(.data.pgdir)
    }

    PROVIDE(edata = .);     /* edata[]: kernel的data段结束地址 */

    .bss : {
        *(.bss)
    }

    PROVIDE(end = .); /* bss段的结束地址, 即整个kernel的结束地址 */

    /DISCARD/ : {
        *(.eh_frame .note.GNU-stack)
    }
}

/* 
.text表示代码段的起始地址
.edata表示kernel的data段起始地址（也就是代码段的结束地址）
.bss表示bss段的起始地址（同时也是data段的结束地址）
.end表示bss段的结束地址（即整个ucore kernel的结束地址）

*/
