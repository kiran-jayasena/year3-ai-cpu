ENTRY(_start)
MEMORY { IMEM (rx) : ORIGIN = 0x00000000, LENGTH = 28K
         DMEM (rw) : ORIGIN = 0x00007000, LENGTH = 4K }
SECTIONS {
  .text : { *(.text.start) *(.text*) } > IMEM
  .rodata : { *(.rodata*) } > DMEM
  .data : { *(.data*) } > DMEM
  .bss : { *(.bss*) *(COMMON) } > DMEM
  . = ALIGN(16);
  _stack_top = ORIGIN(DMEM) + LENGTH(DMEM);
}
