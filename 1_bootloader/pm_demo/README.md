# Protected Mode Bootloader with Custom Interrupt Demo

## Overview
A two-stage bootloader that demonstrates the transition from real mode to protected mode and implements a custom interrupt handler.

## File Structure
```
├── bootloader_stage1.asm    # Stage1: MBR bootloader (512 bytes)
├── bootloader_stage2.asm    # Stage2: Protected mode + IDT + interrupt demo
├── build_bootloader.sh      # Build script
├── idt.asm                  # IDT reference code (backup)
└── README.md               # This document
```

## Features
- **Two-stage boot**: Stage1 loads Stage2, Stage2 enters protected mode
- **Protected mode transition**: Sets up GDT, switches from 16-bit real mode to 32-bit protected mode
- **IDT setup**: Creates Interrupt Descriptor Table supporting 256 interrupts
- **Custom interrupt**: Implements and demonstrates software interrupt 0x30
- **Visual demo**: Colored text display showing execution status at each stage

## Build and Run
```bash
# Build
./build_bootloader.sh

# Run with QEMU
qemu-system-i386 -drive file=bootloader.img,format=raw
```

## Expected Output
The program displays the following on screen:
- **Row 0**: "PROTECTED + IDT" (white) - Protected mode startup success
- **Row 1**: "IDT SETUP" (yellow) - IDT table setup complete
- **Row 2**: "INT 0x30 TRIGGERED" (red) - Interrupt triggered
- **Row 3**: "HANDLER" (green) - Interrupt handler executed
- **Row 4**: "DONE - STOPPED" (cyan) - Demo complete

## Problems Encountered and Solutions

### 1. File Size Calculation Error
**Problem**: Initially thought Stage2 (2870 bytes) could fit in 2 sectors (1024 bytes)
**Solution**: Correctly calculated need for 6 sectors (⌈2870 ÷ 512⌉ = 6), modified Stage1 to read 6 sectors

### 2. Screen Flickering Issue
**Problem**: Screen continuously flickered after enabling interrupts, unable to display stably
**Debug Process**:
- ✅ Minimal version (no IDT) → No flickering
- ✅ Setup IDT but don't enable interrupts → No flickering  
- ✅ Enable interrupts but don't trigger → No flickering
- ❌ Trigger software interrupt → Flickering

**Root Cause**: Overly complex interrupt handler containing:
- Excessive register save/restore operations (`pushad/popad`)
- Too many video memory write operations
- Possible address calculation errors

**Solution**:
- Simplified interrupt handler, removed `pushad/popad`
- Reduced video memory write operations
- Fixed address calculation, use relative offset instead of absolute address
- Used explicit segment registers `[ds:address]`

### 3. Interrupt Handler Address Calculation
**Problem**: Originally used `0x20000 + handler_offset` to calculate physical address
**Solution**: Since GDT code segment base is already set to 0x20000, just use the offset address directly

### 4. Screen Clearing Necessity
**Problem**: Removed screen clearing to avoid flickering, but caused display chaos
**Solution**: After fixing flickering issue, re-added screen clearing for clean display

### 5. **CRITICAL: Runtime Address Calculation Cannot Be Eliminated**
**Problem**: Attempted to simplify GDT/IDT loading by letting assembler calculate addresses, assuming it was "redundant code"
**Catastrophic Result**: System completely broke, continuous flickering, code non-functional

**Root Cause**: Fundamental misunderstanding of address calculation in protected mode:
- **Assembler symbols** ≠ **Physical memory addresses**
- Code loaded at `CS:0x2000` means physical address `0x20000`
- GDT/IDT descriptors require **physical addresses**, not symbolic addresses
- Runtime calculation `CS*16 + offset` is **essential**, not redundant

**Critical Lesson**: In bootloader/kernel development:
```assembly
; ❌ WRONG - This doesn't work in our memory model
lgdt [gdt_descriptor]  ; where gdt_descriptor contains symbolic address

; ✅ CORRECT - Runtime physical address calculation required
mov ax, cs              ; CS = 0x2000
mov dx, 16
mul dx                  ; AX = CS * 16 = 0x20000 (physical address)
add ax, gdt_start       ; Add structure offset
mov [gdt_descriptor + 2], ax    ; Store calculated physical address
lgdt [gdt_descriptor]
```

**Key Insight**: What appeared to be "redundant" was actually the **most critical part** of the bootloader. Never assume address calculations are unnecessary in low-level system code.

## Technical Details

### GDT Setup
```assembly
; Code segment: Base 0x20000, corresponding to Stage2 load address
; Data segment: Base 0x00000, flat memory model
```

### IDT Setup
```assembly
; 256 interrupt descriptors, 8 bytes each
; Interrupt 0x30: Points to custom handler
; Attributes: Interrupt gate, DPL=0, present bit=1
```

### Interrupt Handling Flow
1. `sti` enable interrupts
2. `int 0x30` trigger software interrupt
3. CPU automatically jumps to handler defined in IDT
4. Handler displays message then `iret` returns
5. `cli` disable interrupts, program ends

## Memory Layout
```
0x7C00:     Stage1 (MBR, 512 bytes)
0x20000:    Stage2 (Protected mode code, ~3KB)
0x90000:    Stack
0xB8000:    VGA text mode video memory
```

## Debugging Insights
1. **Divide and Conquer**: Gradually simplified code to isolate problem source
2. **State Isolation**: Separately tested IDT setup, interrupt enabling, interrupt triggering
3. **Visual Feedback**: Used colored text to show execution status for easier debugging
4. **Address Calculation**: In protected mode, pay attention to segment base and offset relationship
5. **Never Assume "Redundancy"**: In low-level code, what looks redundant might be essential
6. **Physical vs Logical Addresses**: Always understand the difference between assembler symbols and actual memory addresses
7. **Test Incrementally**: When "optimizing", test each change individually rather than making multiple changes at once