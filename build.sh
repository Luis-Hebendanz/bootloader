#!/usr/bin/env bash

export KERNEL="../../target/x86_64-os/debug/svm_kernel"
export KERNEL_MANIFEST="../../Cargo.toml"
cargo build --features=binary,map_physical_memory,sse --release
/home/lhebendanz/.rustup/toolchains/nightly-x86_64-unknown-linux-gnu/lib/rustlib/x86_64-unknown-linux-gnu/bin/llvm-objcopy -I elf64-x86-64 -O binary --binary-architecture=i386:x86-64 \
  target/x86_64-bootloader/release/bootloader target/x86_64-bootloader/release/bootloader.bin

qemu-kvm -cpu host -smp cores=4 -drive format=raw,file=target/x86_64-bootloader/release/bootloader.bin -serial stdio -display none -m 1G
