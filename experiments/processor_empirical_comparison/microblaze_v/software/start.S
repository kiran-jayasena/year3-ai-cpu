.section .text.start
.globl _start
.type _start,@function
_start:
  la sp, _stack_top
  call main
1: wfi
  j 1b
