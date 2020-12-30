#![allow(dead_code)]
#![allow(unused_variables)]
use crate::gdt;

use x86_64::structures::idt::{InterruptDescriptorTable, InterruptStackFrame};

// Offset the PICs to avoid index collision with
// exceptions in the IDT
pub const PIC_1_OFFSET: u8 = 32;
pub const PIC_2_OFFSET: u8 = PIC_1_OFFSET + 8;

// IDT index numbers
#[derive(Debug, Clone, Copy)]
#[repr(u8)]
pub enum InterruptIndex {
    LegacyTimer = PIC_1_OFFSET,
    Keyboard, // 33
    Reserved0,
    COM2,
    COM1,
    IRQ5, // 37
    FloppyController,
    MasterPicSpurious, // or parallel port interrupt
    RtcTimer,
    ACPI,
    ScsiNic1,
    ScsiNic2,
    Mouse,
    MathCoProcessor,
    AtaChannel1,
    AtaChannel2,
    IRQ16,
    SlavePicSpurious,
    Timer = 0xe0,
    Spurious = 0xff,
}

impl InterruptIndex {
    pub fn as_u8(self) -> u8 {
        self as u8
    }

    pub fn as_usize(self) -> usize {
        usize::from(self.as_u8())
    }
    pub fn as_pic_enable_mask(self) -> u8 {
        let diff = self.as_usize() - InterruptIndex::LegacyTimer.as_usize();
        let mask = 0xff & !(1 << diff);
        mask as u8
    }
}

static mut IDT: Option<InterruptDescriptorTable> = None;

pub unsafe fn load_idt() {
    use uart_16550::SerialPort;
    use core::fmt::Write;
    let mut serial_port = SerialPort::new(0x3F8);
    serial_port.init();
    serial_port.write_str("Hello World\n").unwrap();
    let mut idt = InterruptDescriptorTable::new();
    idt.simd_floating_point.set_handler_fn(simd_floatingpoint_handler);
    idt.security_exception.set_handler_fn(security_handler);
    idt.virtualization.set_handler_fn(virtualization_handler);
    idt.machine_check.set_handler_fn(machine_check_handler);
    idt.alignment_check.set_handler_fn(alignment_handler);
    idt.x87_floating_point.set_handler_fn(x87_floatingpoint_handler);
        idt.page_fault.set_handler_fn(page_fault_handler)
        // Use a different stack in case of kernel stack overflow
        .set_stack_index(gdt::PAGE_FAULT_IST_INDEX);
    idt.general_protection_fault.set_handler_fn(general_prot_handler);
    idt.stack_segment_fault.set_handler_fn(stack_segment_handler);
    idt.segment_not_present.set_handler_fn(segment_not_present_handler);
    idt.invalid_tss.set_handler_fn(invalid_tss_handler);
        idt.double_fault.set_handler_fn(double_fault_handler)
        // Use a different stack in case of kernel stack overflow
        .set_stack_index(gdt::DOUBLE_FAULT_IST_INDEX);
    idt.device_not_available.set_handler_fn(device_not_available_handler);
    idt.invalid_opcode.set_handler_fn(invalid_op_handler);
    idt.bound_range_exceeded.set_handler_fn(bound_range_handler);
    idt.overflow.set_handler_fn(overflow_handler);
    idt.breakpoint.set_handler_fn(breakpoint_handler);
    idt.non_maskable_interrupt.set_handler_fn(non_maskable_handler);
    idt.debug.set_handler_fn(debug_handler);
    idt.divide_error.set_handler_fn(divide_error_handler);

    // crate::default_interrupt::init_default_handlers(&mut idt);

    // User defined
    idt[InterruptIndex::Timer.as_usize()]
        .set_handler_fn(timer_interrupt_handler);
    idt[InterruptIndex::COM2.as_usize()]
        .set_handler_fn(serial_handler);
    idt[InterruptIndex::COM1.as_usize()]
        .set_handler_fn(serial_handler);
    idt[InterruptIndex::Spurious.as_usize()]
        .set_handler_fn(spurious_handler);
    idt[InterruptIndex::SlavePicSpurious.as_usize()]
        .set_handler_fn(spurious_handler);
    idt[InterruptIndex::MasterPicSpurious.as_usize()]
        .set_handler_fn(spurious_handler);

    IDT = Some(idt);
    IDT.as_mut().unwrap().load();
}

use x86_64::structures::idt::PageFaultErrorCode;

extern "x86-interrupt" fn page_fault_handler(
    stack_frame: &mut InterruptStackFrame,
    error_code: PageFaultErrorCode,
) {
    panic!("page fault exception {:#?}", stack_frame);
}

pub extern "x86-interrupt" fn default_handler<const N: usize>(
    stack_frame: &mut InterruptStackFrame,
) {
    panic!("Default interrupt handler {:?} num: {}", stack_frame, N);
}

extern "x86-interrupt" fn general_prot_handler(
    stack_frame: &mut InterruptStackFrame,
    error_code: u64,
) {
    panic!("general protection exception {:#?}", stack_frame);
}

extern "x86-interrupt" fn alignment_handler(
    stack_frame: &mut InterruptStackFrame,
    error_code: u64,
) {
    panic!("alignment exception {:#?}", stack_frame);
}

// Breakpoint handler
extern "x86-interrupt" fn breakpoint_handler(stack_frame: &mut InterruptStackFrame) {
    panic!("EXCEPTION: BREAKPOINT\n{:#?}", stack_frame);
}

// Double fault handler
extern "x86-interrupt" fn double_fault_handler(
    stack_frame: &mut InterruptStackFrame,
    _error_code: u64,
) -> ! {
    panic!("EXCEPTION: DOUBLE FAULT\n{:#?}", stack_frame);
}

extern "x86-interrupt" fn invalid_op_handler(stack_frame: &mut InterruptStackFrame) {
    panic!("INVALID OP HANDLER\n{:#?}", stack_frame);
}

// Serial handler
extern "x86-interrupt" fn serial_handler(stack_frame: &mut InterruptStackFrame) {
    panic!("serial handler {:?}", stack_frame);
}

// timer interrupt handler
extern "x86-interrupt" fn timer_interrupt_handler(stack_frame: &mut InterruptStackFrame) {
    panic!("timer interrupt {:?}", stack_frame);
}

extern "x86-interrupt" fn spurious_handler(stack_frame: &mut InterruptStackFrame) {
    panic!("SPURIOUS HANDLER");
}

/*
 *
 * Non populated cpu exceptions
 *
 */
extern "x86-interrupt" fn debug_handler(stack_frame: &mut InterruptStackFrame) {
    panic!("debug exception {:?}", stack_frame);
}

extern "x86-interrupt" fn divide_error_handler(stack_frame: &mut InterruptStackFrame) {
    panic!("divide error exception {:?}", stack_frame);
}

extern "x86-interrupt" fn non_maskable_handler(stack_frame: &mut InterruptStackFrame) {
    panic!("non maskable interrupt exception {:?}", stack_frame);
}

extern "x86-interrupt" fn overflow_handler(stack_frame: &mut InterruptStackFrame) {
    panic!("overflow exception {:?}", stack_frame);
}

extern "x86-interrupt" fn bound_range_handler(stack_frame: &mut InterruptStackFrame) {
    panic!("bound range exception {:?}", stack_frame);
}

extern "x86-interrupt" fn device_not_available_handler(stack_frame: &mut InterruptStackFrame) {
    panic!("device not available exception {:?}", stack_frame);
}

extern "x86-interrupt" fn invalid_tss_handler(
    stack_frame: &mut InterruptStackFrame,
    _error_code: u64,
) {
    panic!("invalid tss exception {:?}", stack_frame);
}

extern "x86-interrupt" fn segment_not_present_handler(
    stack_frame: &mut InterruptStackFrame,
    _error_code: u64,
) {
    panic!("segment not present exception {:?}", stack_frame);
}

extern "x86-interrupt" fn stack_segment_handler(
    stack_frame: &mut InterruptStackFrame,
    _error_code: u64,
) {
    panic!("stack segment fault exception {:?}", stack_frame);
}

extern "x86-interrupt" fn x87_floatingpoint_handler(stack_frame: &mut InterruptStackFrame) {
    panic!("x87_floatingpoint exceptio {:?}", stack_frame);
}

extern "x86-interrupt" fn machine_check_handler(stack_frame: &mut InterruptStackFrame) -> ! {
    panic!("Machine check exception {:?}", stack_frame);
}

extern "x86-interrupt" fn simd_floatingpoint_handler(stack_frame: &mut InterruptStackFrame) {
    panic!("Simd floatingpoint exception {:?}", stack_frame);
}

extern "x86-interrupt" fn virtualization_handler(stack_frame: &mut InterruptStackFrame) {
    panic!("virtualization exception {:?}", stack_frame);
}

extern "x86-interrupt" fn security_handler(
    stack_frame: &mut InterruptStackFrame,
    _error_code: u64,
) {
    panic!("security exception {:?}", stack_frame);
}

