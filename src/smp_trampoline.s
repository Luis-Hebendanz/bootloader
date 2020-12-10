.section .smp_trampoline, "awx"
.global _smp_trampoline
.intel_syntax noprefix
.align 4096
.code16

_smp_trampoline:
    # Disable interrupts
    cli

    # zero segment registers
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov fs, ax
    mov gs, ax

    # clear the direction flag (e.g. go forward in memory when using
    # instructions like lodsb)
    cld

    # initialize stack
    mov sp, 0x7c00
		jmp _start_ap


.boot_msg: .asciz "Booting (first stage)... "
