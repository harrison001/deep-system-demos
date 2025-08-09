#!/bin/bash

# Support Method A/B selection via parameter
METHOD=${1:-A}

if [[ "$METHOD" != "A" && "$METHOD" != "B" ]]; then
    echo "Usage: $0 [A|B]"
    echo "  A - Method A (Runtime GDT patching) [default]"
    echo "  B - Method B (Flat addressing)"
    exit 1
fi

echo "Building Protected Mode Bootloader (Method $METHOD) with Custom Interrupt Demo..."

# Assemble both stages
echo "Assembling Stage1 (MBR bootloader)..."
nasm -f bin bootloader_stage1.asm -o bootloader_stage1.bin

echo "Assembling Stage2 (Protected mode with IDT) - Method $METHOD..."
if [[ "$METHOD" == "A" ]]; then
    nasm -f bin bootloader_stage2.asm -o bootloader_stage2.bin -dMETHOD_A
    echo "Using Method A: Runtime GDT patching, immediate jump"
else
    nasm -f bin bootloader_stage2.asm -o bootloader_stage2.bin -dMETHOD_B
    echo "Using Method B: Flat addressing, indirect jump"
fi

# Check if assembly succeeded
if [ $? -eq 0 ]; then
    echo "Both stages assembled successfully!"
    
    # Show file sizes
    echo "File sizes:"
    ls -la bootloader_stage1.bin bootloader_stage2.bin
    
    echo "Creating hard disk image..."
    
    # Create 10MB hard disk image
    dd if=/dev/zero of=bootloader.img bs=512 count=20480 2>/dev/null
    
    # Write stage1 to boot sector (sector 0)
    dd if=bootloader_stage1.bin of=bootloader.img conv=notrunc bs=512 seek=0 2>/dev/null
    echo "Stage1 (MBR) written to sector 0"
    
    # Write stage2 to sectors 1-6 (stage2 needs ~6 sectors)
    dd if=bootloader_stage2.bin of=bootloader.img conv=notrunc bs=512 seek=1 2>/dev/null
    echo "Stage2 (Protected Mode + IDT) written to sectors 1-6"
    
    echo ""
    echo "Bootloader ready: bootloader.img"
    echo "Test with: qemu-system-i386 -drive file=bootloader.img,format=raw"
else
    echo "Assembly failed!"
    exit 1
fi