KERNEL_PHYS_START = 1M;
KERNEL_STACK_SIZE = 0x4000;

SECTIONS {
    . = KERNEL_PHYS_START;
    .text : ALIGN(4K) {
        *(.text*)
    }
    .rodata : ALIGN(4K) {
        *(.rodata*)
    }
    .data : ALIGN(4K) {
        *(.data*)
    }
    .bss : ALIGN(4K) {
        *(COMMON)
        *(.bss*)
        . = ALIGN(16);
        . += KERNEL_STACK_SIZE;
    }
}
