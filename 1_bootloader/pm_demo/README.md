# Protected Mode Bootloader with Advanced System Features

## Overview
A professional two-stage bootloader demonstrating the transition from real mode to protected mode with advanced system features including exception handling, interrupt management, and integrity checking.

## File Structure
```
├── bootloader_stage1.asm    # Stage1: MBR bootloader (512 bytes)
├── bootloader_stage2.asm    # Stage2: Protected mode + advanced features
├── build_bootloader.sh      # Enhanced build script with feature flags
├── build_symbols.sh         # Debug symbol generation script
├── load_symbols.gdb         # GDB symbol loading script
└── README.md               # This document
```

## Core Features
- **Two-stage boot**: Stage1 loads Stage2 (up to 8 sectors/4KB), Stage2 enters protected mode
- **Dual addressing methods**: Method A (runtime GDT patching) vs Method B (flat addressing)
- **Protected mode transition**: Complete GDT setup and mode switching
- **Basic IDT**: Custom interrupt 0x30 demonstration

## Professional Features (Compilation Switches)

### 🚨 Exception Vector Handling (`ENABLE_EXC`)
- **Custom GDT control**: Demonstrates complete control over Global Descriptor Table setup and modification
- **Custom IDT implementation**: Shows how to override CPU hardware exception handling with custom interrupt system routing
- **ISR (Interrupt Service Routine) framework**: Implements proper exception interception and handling
- **CPU exception takeover**: Intercepts hardware exceptions (divide error, page fault, general protection, etc.) before they crash the system
- **Exception vector routing**: Redirects CPU exceptions through custom handlers, demonstrating OS-level interrupt management

### ⏱️ PIC Remapping + IRQ0 Timer (`ENABLE_PIC`)
- **Hardware interrupt system**: Demonstrates direct hardware interrupt handling beyond CPU exceptions
- **Timer controller integration**: Shows how OS intercepts and handles hardware timer updates from 8253 PIT (Programmable Interval Timer)
- **PIC (Programmable Interrupt Controller) management**: Complete reprogramming of interrupt controller hardware
- **Real-time hardware events**: Captures and processes actual hardware timer interrupts (~18.2 Hz)
- **System time foundation**: Shows the basis for OS timekeeping, task scheduling, and time-based services

### 🛡️ GDT/IDT Integrity Checking (`ENABLE_INTEGRITY`)
- **Boot-time system table validation**: Demonstrates OS startup verification methods using checksum algorithms
- **Real-time CRC calculation**: 16-bit checksum of critical GDT/IDT data blocks for integrity verification
- **SGDT/SIDT-based verification**: Uses CPU instructions to get actual table addresses, ensuring accurate validation
- **Tamper detection capability**: Foundation for detecting unauthorized system table modifications
- **Professional OS development**: Shows industry-standard boot-time security validation techniques

## Build and Run

### Basic Usage (Original Behavior)
```bash
# Default build - no extra features, preserves original video demo
./build_bootloader.sh A

# Method B with flat addressing
./build_bootloader.sh B
```

### Advanced Usage with Professional Features
```bash
# Exception handling only
./build_bootloader.sh A "EXC"

# PIC + timer interrupts only  
./build_bootloader.sh A "PIC"

# Integrity checking only
./build_bootloader.sh A "INTEGRITY"

# Multiple features
./build_bootloader.sh A "EXC PIC"
./build_bootloader.sh B "EXC PIC INTEGRITY"

# All features (full professional demo)
./build_bootloader.sh A "EXC PIC INTEGRITY"
```

### Testing
```bash
# Run with QEMU
qemu-system-i386 -drive file=bootloader.img,format=raw

# Debug mode with GDB support
qemu-system-i386 -drive file=bootloader.img,format=raw -s -S
```

## Expected Output by Configuration

### Default (No Features)
- **Row 0**: "METHOD A/B + IDT" (white)
- **Row 1**: "IDT SETUP" (yellow)
- **Row 2**: "INT 0x30 TRIGGERED" (red)
- **Row 3**: "HANDLER" (green)
- **Row 4**: "DONE - STOPPED" (cyan)

### With Exception Handling (`EXC`)
- Same as default, plus exception capability
- **If exception triggered**: Row 3 shows "EXC:XX" (red) with vector number

### With PIC Timer (`PIC`)
- Same as default behavior
- **Top-right corner**: "TICKS:XX" (yellow, incrementing)
- **Program continues**: No "STOPPED", responds to timer interrupts

### With Integrity Checking (`INTEGRITY`)
- Same as default
- **Row 1 middle**: "GDT:XXXX IDT:YYYY" (cyan) showing checksums

### All Features Combined
- All above displays simultaneously
- Professional system monitoring dashboard

## Professional Testing Scenarios

### 1. Exception Handling Test
```bash
# Compile with exception support
./build_bootloader.sh A "EXC"

# To trigger divide-by-zero exception, uncomment in bootloader_stage2.asm:
# xor edx, edx
# mov eax, 1234  
# div edx

# Rebuild and run - should show "EXC:00" (divide error)
```

### 2. Timer Interrupt Performance
```bash
./build_bootloader.sh A "PIC"
# Watch tick counter increment ~18 times per second (8253 default rate)
```

### 3. Integrity Verification
```bash
./build_bootloader.sh A "INTEGRITY"
# Note GDT/IDT checksum values
# Rebuild with different features - checksums should change
```

## Demonstrated OS Concepts

### 1. Boot-time System Table Validation
This demo shows **industry-standard OS security practices**:
- **CRC/Checksum verification** of critical system structures (GDT/IDT) before OS handover
- **SGDT/SIDT instruction usage** to verify actual CPU-loaded table addresses
- **Integrity monitoring** to detect corruption or unauthorized modifications
- **Foundation for secure boot** and system integrity verification

### 2. CPU Exception Interception & Custom Routing
Demonstrates **OS-level interrupt system control**:
- **GDT customization** for complete memory segmentation control
- **IDT takeover** to intercept CPU hardware exceptions before system crash
- **Custom ISR (Interrupt Service Routine)** implementation
- **Exception vector redirection** from hardware defaults to OS handlers
- **Foundation for process isolation**, memory protection, and fault recovery

### 3. Hardware Interrupt System Programming
Shows **direct hardware programming** beyond CPU exceptions:
- **PIC (8259) reprogramming** to route hardware interrupts to custom vectors
- **Timer controller (8253 PIT) integration** for system timekeeping
- **Hardware event capture** demonstrating real-time interrupt processing
- **Foundation for multitasking**, device drivers, and hardware abstraction layers

## Technical Architecture

### Memory Layout
```
0x7C00:     Stage1 (MBR, 512 bytes)
0x60000:    Stage2 (Protected mode code, up to 4KB)
0x90000:    32-bit stack
0xB8000:    VGA text mode video memory
```

### Sector Allocation
- **Sector 0**: Stage1 (MBR bootloader)
- **Sectors 1-8**: Stage2 (up to 4096 bytes for full features)
- **Expandable**: Can accommodate future feature additions

### Feature Toggle Architecture
```assembly
; Feature compilation switches
%ifdef ENABLE_EXC          ; Exception vectors 0-19
%ifdef ENABLE_PIC          ; PIC remapping + IRQ0
%ifdef ENABLE_INTEGRITY    ; GDT/IDT checksums
```

### Addressing Methods
- **Method A**: Runtime GDT base patching (CS-relative addressing)
- **Method B**: Flat memory model (linear addressing)
- **Both methods**: Support all professional features

## File Size Comparison
```
bootloader_stage2_default.bin:    ~3.0KB (original features)
bootloader_stage2_exc.bin:        ~3.5KB (+ exception handling)
bootloader_stage2_pic.bin:        ~3.2KB (+ PIC/timer)
bootloader_stage2_integrity.bin:  ~3.2KB (+ integrity checking)
bootloader_stage2_all.bin:        ~3.9KB (all features)
```

## Debug Support
```bash
# Generate debug symbols
./build_symbols.sh bootloader_stage2.asm

# GDB debugging
qemu-system-i386 -drive file=bootloader.img,format=raw -s -S &
gdb -x load_symbols.gdb
```

## Development Insights

### Key Architectural Decisions
1. **Modular design**: Features can be enabled/disabled without affecting core functionality
2. **Backward compatibility**: Default build maintains original video demo behavior
3. **Professional scalability**: Framework supports additional system features
4. **Educational value**: Each feature demonstrates real OS development concepts

### Critical Implementation Notes
1. **Runtime address calculation**: Essential for bootloader operation, never "redundant"
2. **Segment vs linear addressing**: Both methods properly handle hardware addressing modes
3. **Interrupt handling**: Proper stack management and register preservation
4. **Hardware initialization**: Complete PIC setup following Intel specifications

### Performance Considerations
- **Minimal overhead**: Features only active when explicitly enabled
- **Efficient ISR design**: Fast interrupt handling with minimal context switching
- **Memory usage**: Optimized data structures for space-constrained bootloader environment

## Educational Value

### Core Operating System Concepts Demonstrated
1. **Boot Security & Integrity**: Industry-standard CRC validation of system tables
2. **Interrupt System Architecture**: Complete ISR framework from CPU exceptions to hardware interrupts
3. **Hardware Abstraction**: Direct PIC and timer controller programming
4. **Memory Management Foundations**: GDT control and segmentation
5. **System Programming Techniques**: SGDT/SIDT usage, real-time event handling

### Professional Applications
- **OS Development**: Foundation for bootloaders, kernels, and system software
- **Security Research**: Boot-time validation and integrity monitoring techniques
- **Embedded Systems**: Hardware interrupt handling and timer management
- **System Administration**: Understanding OS startup and hardware interaction
- **Academic Research**: Complete reference implementation for computer architecture courses

### Industry Relevance
This demo implements concepts used in:
- **Modern UEFI firmware** (integrity checking)
- **Operating system kernels** (interrupt management, hardware abstraction)
- **Hypervisors and virtual machines** (CPU exception handling)
- **Real-time systems** (hardware timer integration)
- **Security systems** (boot-time validation, tamper detection)

Perfect for computer science students, system programmers, OS developers, and security researchers.