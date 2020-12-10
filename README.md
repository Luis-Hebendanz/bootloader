# bootloader

[![Build Status](https://dev.azure.com/rust-osdev/bootloader/_apis/build/status/rust-osdev.bootloader?branchName=master)](https://dev.azure.com/rust-osdev/bootloader/_build/latest?definitionId=1&branchName=master) [![Join the chat at https://gitter.im/rust-osdev/bootloader](https://badges.gitter.im/rust-osdev/bootloader.svg)](https://gitter.im/rust-osdev/bootloader?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

An experim

Written for the [second edition](https://github.com/phil-opp/blog_os/issues/360) of the [Writing an OS in Rust](https://os.phil-opp.com) series.

## Design

When you press the power button the computer loads the BIOS from some flash memory stored on the motherboard. The BIOS initializes and self tests the hardware then loads the first 512 bytes into memory from the media device (i.e. the cdrom or floppy disk). If the last two bytes equal 0xAA55 then the BIOS will jump to location 0x7C00 effectively transferring control to the bootloader. 
At this point the CPU is running in 16 bit mode, meaning only the 16 bit registers are available. Also since the BIOS only loads the first 512 bytes this means our bootloader code has to stay below that limit, otherwise we’ll hit uninitialised memory! Using [Bios interrupt calls](https://en.wikipedia.org/wiki/BIOS_interrupt_call) the bootloader prints debug information to the screen.

* stage_1.s
This stage initializes the stack, enables the A20 line, loads the rest of
the bootloader from disk, and jumps to stage_2.

* stage_2.s
This stage sets the target operating mode, loads the kernel from disk,
creates an e820 memory map, enters protected mode, and jumps to the
third stage.

* stage_3.s
This stage performs some checks on the CPU (cpuid, long mode), sets up an
initial page table mapping (identity map the bootloader, map the P4
recursively, map the kernel blob to 4MB), enables paging, switches to long
mode, and jumps to stage_4.

## Build chain
The file `.cargo/config` defines a llvm target file called `x86_64-bootloader.json`.
This file defines the architecture and tells llvm to use the linker script `linker.ld`.

The `build.rs` file execute the llvm tools with our kernel as input:
```bash
# Check size of .text section of kernel if too small throw error
llvm-size "../../target/x86_64-os/debug/svm_kernel"
# Strip debug symbols from kernel to make loading faster
llvm-objcopy "--strip-debug" "../../target/x86_64-os/debug/svm_kernel" "target/x86_64-bootloader/debug/build/bootloader-c8df27c930d8f65a/out/kernel_stripped-svm_kernel"
# Rename the .data section to .kernel in the stripped kernel and rename 
llvm-objcopy "-I" "binary" "-O" "elf64-x86-64" "--binary-architecture=i386:x86-64" "--rename-section" ".data=.kernel" "--redefine-sym" "_binary_kernel_stripped_svm_kernel_start=_kernel_start_addr" "--redefine-sym" "_binary_kernel_stripped_svm_kernel_end=_kernel_end_addr" "--redefine-sym" "_binary_kernel_stripped_svm_kernel_size=_kernel_size" "target/x86_64-bootloader/debug/build/bootloader-c8df27c930d8f65a/out/kernel_stripped-svm_kernel" "target/x86_64-bootloader/debug/build/bootloader-c8df27c930d8f65a/out/kernel_bin-svm_kernel.o"

# Now create a static library out of it
llvm-ar "crs" "bootloader/target/x86_64-bootloader/debug/build/bootloader-c8df27c930d8f65a/out/libkernel_bin-svm_kernel.a" "target/x86_64-bootloader/debug/build/bootloader-c8df27c930d8f65a/out/kernel_bin-svm_kernel.o"
```
Afterwards `build.rs` tells cargo to use the newly created static library to link against the bootloader, with the help of the linker script everything gets placed correctly in the
resulting ELF file.
The last step is to strip away the elf header so that the bios can jump directly to the bootloader `stage_1.s`. This is done with:
```bash
cargo objcopy -- -I elf64-x86-64 -O binary --binary-architecture=i386:x86-64 \
  target/x86_64-bootloader/release/bootloader target/x86_64-bootloader/release/bootloader.bin
```

## Configuration

The bootloader exposes a few variables which can be configured through the `Cargo.toml` of your kernel:

```toml
[package.metadata.bootloader]
# The address at which the kernel stack is placed. If not provided, the bootloader
# dynamically searches for a location.
kernel-stack-address = "0xFFFFFF8000000000"

# The size of the kernel stack, given in number of 4KiB pages. Defaults to 512.
kernel-stack-size = 128

# The virtual address offset from which physical memory is mapped, as described in
# https://os.phil-opp.com/paging-implementation/#map-the-complete-physical-memory
# Only applies if the `map_physical_memory` feature of the crate is enabled.
# If not provided, the bootloader dynamically searches for a location.
physical-memory-offset = "0xFFFF800000000000"

# The address at which the bootinfo struct will be placed. if not provided,
# the bootloader will dynamically search for a location.
boot-info-address = "0xFFFFFFFF80000000"
```

Note that the addresses **must** be given as strings (in either hex or decimal format), as [TOML](https://github.com/toml-lang/toml) does not support unsigned 64-bit integers.

## Requirements

You need a nightly [Rust](https://www.rust-lang.org) compiler and [cargo xbuild](https://github.com/rust-osdev/cargo-xbuild). You also need the `llvm-tools-preview` component, which can be installed through `rustup component add llvm-tools-preview`.

## Build

The simplest way to use the bootloader is in combination with the [bootimage](https://github.com/rust-osdev/bootimage) tool. This crate **requires at least bootimage 0.7.7**. With the tool installed, you can add a normal cargo dependency on the `bootloader` crate to your kernel and then run `bootimage build` to create a bootable disk image. You can also execute `bootimage run` to run your kernel in [QEMU](https://www.qemu.org/) (needs to be installed).

To compile the bootloader manually, you need to invoke `cargo xbuild` with two environment variables:
* `KERNEL`: points to your kernel executable (in the ELF format)
* `KERNEL_MANIFEST`: points to the `Cargo.toml` describing your kernel

For example: 
```
KERNEL=/path/to/your/kernel/target/debug/your_kernel KERNEL_MANIFEST=/path/to/your/kernel/Cargo.toml cargo xbuild
```

As an example, you can build the bootloader with example kernel from the `example-kernel` directory with the following commands:

```
cd example-kernel
cargo xbuild
cd ..
KERNEL=example-kernel/target/x86_64-example-kernel/debug/example-kernel KERNEL_MANIFEST=example-kernel/Cargo.toml cargo xbuild --release --features binary
```

The `binary` feature is required to enable the dependencies required for compiling the bootloader executable. The command results in a bootloader executable at `target/x86_64-bootloader.json/release/bootloader`. This executable is still an ELF file, which can't be run directly.

## Run

To run the compiled bootloader executable, you need to convert it to a binary file. You can use the `llvm-objcopy` tools that ships with the `llvm-tools-preview` rustup component. The easiest way to use this tool is using [`cargo-binutils`](https://github.com/rust-embedded/cargo-binutils), which can be installed through `cargo install cargo-binutils`. Then you can perform the conversion with the following command:

```
cargo objcopy -- -I elf64-x86-64 -O binary --binary-architecture=i386:x86-64 \
  target/x86_64-bootloader/release/bootloader target/x86_64-bootloader/release/bootloader.bin
```

You can run the `bootloader.bin` file using [QEMU](https://www.qemu.org/):

```
qemu-system-x86_64 -drive format=raw,file=target/x86_64-bootloader/release/bootloader.bin
```

Or burn it to an USB drive to boot it on real hardware:

```
dd if=target/x86_64-bootloader/release/bootloader.bin of=/dev/sdX && sync
```

Where sdX is the device name of your USB stick. **Be careful** to choose the correct device name, because everything on that device is overwritten.

## Features
The bootloader crate can be configured through some cargo features:

- `vga_320x200`: This feature switches the VGA hardware to mode 0x13, a graphics mode with resolution 320x200 and 256 colors per pixel. The framebuffer is linear and lives at address `0xa0000`.
- `recursive_page_table`: Maps the level 4 page table recursively and adds the [`recursive_page_table_address`](https://docs.rs/bootloader/0.4.0/bootloader/bootinfo/struct.BootInfo.html#structfield.recursive_page_table_addr) field to the passed `BootInfo`.
- `map_physical_memory`: Maps the complete physical memory in the virtual address space and passes a [`physical_memory_offset`](https://docs.rs/bootloader/0.4.0/bootloader/bootinfo/struct.BootInfo.html#structfield.physical_memory_offset) field in the `BootInfo`.
  - The virtual address where the physical memory should be mapped is configurable by setting the `physical-memory-offset` field in the kernel's `Cargo.toml`, as explained in [Configuration](#Configuration).

## Advanced Documentation
See these guides for advanced usage of this crate:

- [Chainloading](doc/chainloading.md)
- Higher Half Kernel - TODO

## License

Licensed under either of

- Apache License, Version 2.0 ([LICENSE-APACHE](LICENSE-APACHE) or
  http://www.apache.org/licenses/LICENSE-2.0)
- MIT license ([LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT)

at your option.

Unless you explicitly state otherwise, any contribution intentionally submitted for inclusion in the work by you, as defined in the Apache-2.0 license, shall be dual licensed as above, without any additional terms or conditions.
