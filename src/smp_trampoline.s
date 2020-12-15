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

    lgdt [gdt32info]

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


smp_enter_protected_mode_again:
    cli
    lgdt [gdt32info]
    mov eax, cr0
    or al, 1    # set protected mode bit
    mov cr0, eax

smp_stage_3:
    mov bx, 0x10
    mov ds, bx # set data segment
    mov es, bx # set extra segment
    mov ss, bx # set stack segment

    cli                   # disable interrupts

    lidt zero_idt         # Load a zero length IDT so that any NMI causes a triple fault.

smp_set_up_page_tables:
    # zero out buffer for page tables
    lea edi, [__page_table_start]
    lea ecx, [__page_table_end]
    sub ecx, edi
    shr ecx, 2 # one stosd zeros 4 bytes -> divide by 4
    xor eax, eax
    rep stosd

    # p4
    lea eax, [_p3]
    or eax, (1 | 2)
    mov [_p4], eax
    # p3
    lea eax, [_p2]
    or eax, (1 | 2)
    mov [_p3], eax
    # p2
    lea eax, [_p1]
    or eax, (1 | 2)
    mov [_p2], eax
    mov eax, (0x400000 | 1 | 2 | (1 << 7))
    mov ecx, 2
    lea edx, _kernel_size
    add edx, 0x400000 # start address
    add edx, 0x200000 - 1 # align up
    shr edx, 12 + 9 # end huge page number
    smp_map_p2_table:
    mov [_p2 + ecx * 8], eax
    add eax, 0x200000
    add ecx, 1
    cmp ecx, edx
    jb smp_map_p2_table
    # p1
    # start mapping from __page_table_start, as we need to be able to access
    # the p4 table from rust. stop mapping at __bootloader_end
    lea eax, __page_table_start
    and eax, 0xfffff000
    or eax, (1 | 2)
    lea ecx, __page_table_start
    shr ecx, 12 # start page number
    lea edx, __bootloader_end
    add edx, 4096 - 1 # align up
    shr edx, 12 # end page number
    smp_map_p1_table:
    mov [_p1 + ecx * 8], eax
    add eax, 4096
    add ecx, 1
    cmp ecx, edx
    jb smp_map_p1_table


smp_spin:
	jmp smp_spin

_first_boot:
	.word 1

.boot_msg: .asciz "Booting (first stage)... "
