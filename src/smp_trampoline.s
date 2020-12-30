.section .smp_trampoline, "awx"
.global _smp_trampoline
.intel_syntax noprefix
.align 4096
.code16

_smp_trampoline:
   cli
   jmp smp_after_stack
   smp_start_stack:
        .fill 64, 1,0

   smp_after_stack:

   # Wait for the shared early boot stack to be available for use
   wait_for_stack:
     pause
     xor  al, al
     lock xchg byte ptr [stack_avail], al
     test al, al
     jz   short wait_for_stack

   lgdt [smp_gdt32info]
   lea esp, [smp_start_stack]

   mov eax, cr0
   or al, 1    # set protected mode bit
   mov cr0, eax

   mov bx, 0x10
   mov ds, bx # set data segment
   mov es, bx # set extra segment
   mov ss, bx # set stack segment

   push 0x8
   lea eax, [check_cpu]
   push eax
   retf
   hlt



smp_gdt32info:
   .word smp_gdt32_end - smp_gdt32 - 1  # last byte in table
   .word smp_gdt32                  # start of table

smp_gdt32:
    # entry 0 is always unused
    .quad 0
smp_codedesc:
    .byte 0xff
    .byte 0xff
    .byte 0
    .byte 0
    .byte 0
    .byte 0x9a
    .byte 0xcf
    .byte 0
smp_datadesc:
    .byte 0xff
    .byte 0xff
    .byte 0
    .byte 0
    .byte 0
    .byte 0x92
    .byte 0xcf
    .byte 0
smp_gdt32_end:


stack_avail: .byte 1
