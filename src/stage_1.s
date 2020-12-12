.section .boot-first-stage, "awx"
.global _start
.intel_syntax noprefix
.code16

# This stage initializes the stack, enables the A20 line, loads the rest of
# the bootloader from disk, and jumps to stage_2.
_start:
.fill 200, 1, 0


_init_core:
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
    call smp_wait

enable_a20:
    # enable A20-Line via IO-Port 92, might not work on all motherboards
    in al, 0x92
    test al, 2
    jnz enable_a20_after
    or al, 2
    and al, 0xFE
    out 0x92, al
enable_a20_after:

enter_protected_mode:
    push ds
    push es

    lgdt [gdt32info]

    mov eax, cr0
    or al, 1    # set protected mode bit
    mov cr0, eax

    jmp protected_mode                # tell 386/486 to not crash

protected_mode:
    mov bx, 0x10
    mov ds, bx # set data segment
    mov es, bx # set extra segment

    and al, 0xfe    # clear protected mode bit
    mov cr0, eax

unreal_mode:
    pop es # get back old extra segment
    pop ds # get back old data segment
    sti

    # back to real mode, but internal data segment register is still loaded
    # with gdt segment -> we can access the full 4GiB of memory

    mov bx, 0x0f01         # attrib/char of smiley
    mov eax, 0xb8f00       # note 32 bit offset
    mov word ptr ds:[eax], bx

    # Check if this is the first time we boot
    mov bx, word ptr [_first_boot]
    test bx, bx
    jz stage_2_second_boot

load_rest_of_bootloader_from_disk:
    lea eax, _rest_of_bootloader_start_addr

    # dap buffer segment
    mov ebx, eax
    shr ebx, 4 # divide by 16
    mov [dap_buffer_seg], bx

    # buffer offset
    shl ebx, 4 # multiply by 16
    sub eax, ebx
    mov [dap_buffer_addr], ax

    lea eax, _rest_of_bootloader_start_addr

    # number of disk blocks to load
    lea ebx, _rest_of_bootloader_end_addr
    sub ebx, eax # end - start
    shr ebx, 9 # divide by 512 (block size)
    mov [dap_blocks], bx

    # number of start block
    lea ebx, _start
    sub eax, ebx
    shr eax, 9 # divide by 512 (block size)
    mov [dap_start_lba], eax

    lea si, dap
    mov ah, 0x42
    int 0x13

    # reset segment to 0
    mov word ptr [dap_buffer_seg], 0

jump_to_second_stage:
    lea eax, [stage_2]
    jmp eax

spin:
    jmp spin

smp_wait:
    push bx
    mov bx, word ptr [_stage_counter]
    test bx, bx
    jz .ret
    inc word ptr [_stage_counter]
    jmp spin
    .ret:
    pop bx
    ret

gdt32info:
   .word gdt32_end - gdt32 - 1  # last byte in table
   .word gdt32                  # start of table

gdt32:
    # entry 0 is always unused
    .quad 0
codedesc:
    .byte 0xff
    .byte 0xff
    .byte 0
    .byte 0
    .byte 0
    .byte 0x9a
    .byte 0xcf
    .byte 0
datadesc:
    .byte 0xff
    .byte 0xff
    .byte 0
    .byte 0
    .byte 0
    .byte 0x92
    .byte 0xcf
    .byte 0
gdt32_end:

dap: # disk access packet
    .byte 0x10 # size of dap
    .byte 0 # unused
dap_blocks:
    .word 0 # number of sectors
dap_buffer_addr:
    .word 0 # offset to memory buffer
dap_buffer_seg:
    .word 0 # segment of memory buffer
dap_start_lba:
    .quad 0 # start logical block address

_first_boot:
    .word 1
_stage_counter:
    .word 0

.org 510
.word 0xaa55 # magic number for bootable disk
