ENTRY(_start)
MEMORY { MEM (rwx) : ORIGIN = 0x00000000, LENGTH = 64K }
SECTIONS {
  .text : { *(.text.start) *(.text*) *(.rodata*) } > MEM
  .data : { *(.data*) } > MEM
  .bss : { *(.bss*) *(COMMON) } > MEM
  . = ALIGN(16);
  _stack_top = ORIGIN(MEM) + LENGTH(MEM) - 16;
}
