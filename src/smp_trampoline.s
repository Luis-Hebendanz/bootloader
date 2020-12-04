.section .smp_trampoline, "awx"
.global _smp_trampoline
.intel_syntax noprefix
.align 4096
.code16

_smp_trampoline:
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

    #lea bx, _start
    #call smp_real_mode_print_hex
    #test bx, bx

    lea si, smp_boot_start_str
    call smp_real_mode_println

smp_enable_a20:
    # enable A20-Line via IO-Port 92, might not work on all motherboards
    in al, 0x92
    test al, 2
    jnz smp_enable_a20_after
    or al, 2
    and al, 0xFE
    out 0x92, al
smp_enable_a20_after:


smp_enter_protected_mode:
    # clear interrupts
    cli
    push ds
    push es

    lgdt [smp_gdt32info]

    mov eax, cr0
    or al, 1    # set protected mode bit
    mov cr0, eax

    jmp smp_protected_mode                # tell 386/486 to not crash

smp_protected_mode:
    mov bx, 0x10
    mov ds, bx # set data segment
    mov es, bx # set extra segment

    and al, 0xfe    # clear protected mode bit
    mov cr0, eax

smp_unreal_mode:
    pop es # get back old extra segment
    pop ds # get back old data segment
    sti

    # back to real mode, but internal data segment register is still loaded
    # with gdt segment -> we can access the full 4GiB of memory

    mov bx, 0x0f01         # attrib/char of smiley
    mov eax, 0xb8f00       # note 32 bit offset
    mov word ptr ds:[eax], bx

smp_check_int13h_extensions:
    mov ah, 0x41
    mov bx, 0x55aa
    # dl contains drive number
    int 0x13
    jc smp_no_int12h_extensions

smp_jump_to_second_stage:
    lea eax, [create_memory_map]
    jmp eax

smp_spin:
    jmp smp_spin

# print a string and a newline
# IN
#   si: points at zero-terminated String
# CLOBBER
#   ax
smp_real_mode_println:
    call smp_real_mode_print
    mov al, 13 # \r
    call smp_real_mode_print_char
    mov al, 10 # \n
    jmp smp_real_mode_print_char

# print a string
# IN
#   si: points at zero-terminated String
# CLOBBER
#   ax
smp_real_mode_print:
    cld
smp_real_mode_print_loop:
    # note: if direction flag is set (via std)
    # this will DECREMENT the ptr, effectively
    # reading/printing in reverse.
    lodsb al, BYTE PTR [si]
    test al, al
    jz smp_real_mode_print_done
    call smp_real_mode_print_char
    jmp smp_real_mode_print_loop
smp_real_mode_print_done:
    ret

# print a character
# IN
#   al: character to print
# CLOBBER
#   ah
smp_real_mode_print_char:
    mov ah, 0x0e
    int 0x10
    ret

# print a number in hex
# IN
#   bx: the number
# CLOBBER
#   al, cx
smp_real_mode_print_hex:
    mov cx, 4
smp_lp:
    mov al, bh
    shr al, 4

    cmp al, 0xA
    jb smp_below_0xA

    add al, 'A' - 0xA - '0'
smp_below_0xA:
    add al, '0'

    call smp_real_mode_print_char

    shl bx, 4
    loop smp_lp

    ret

smp_real_mode_error:
    call smp_real_mode_println
    jmp smp_spin

smp_no_int12h_extensions:
    lea si, smp_no_int13h_extension_str
    jmp smp_real_mode_error

smp_boot_start_str: .asciz "Booting (first stage)..."
smp_erro_str: .asciz "Error: "
smp_no_int13h_extension_str: .asciz "No support for int13h extensions"

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

smp_dap: # disk access packet
    .byte 0x10 # size of smp_dap
    .byte 0 # unused
smp_dap_blocks:
    .word 0 # number of sectors
smp_dap_buffer_addr:
    .word 0 # offset to memory buffer
smp_dap_buffer_seg:
    .word 0 # segment of memory buffer
smp_start_lba:
    .quad 0 # start logical block address


