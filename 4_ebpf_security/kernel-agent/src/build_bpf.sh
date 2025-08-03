#!/bin/bash

# eBPF Build Script
# Compiles all .bpf.c files to .bpf.o files in the current directory

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if clang is available
if ! command -v clang &> /dev/null; then
    echo -e "${RED}Error: clang not found. Please install clang.${NC}"
    exit 1
fi

# Check if vmlinux.h exists
if [ ! -f "vmlinux.h" ]; then
    echo -e "${RED}Error: vmlinux.h not found in current directory.${NC}"
    echo "Please generate vmlinux.h using: bpftool btf dump file /sys/kernel/btf/vmlinux format c > vmlinux.h"
    exit 1
fi

echo -e "${YELLOW}Building eBPF programs...${NC}"

# Detect target architecture
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        TARGET_ARCH="x86"
        ;;
    aarch64)
        TARGET_ARCH="arm64"
        ;;
    *)
        TARGET_ARCH="x86"  # Default to x86
        ;;
esac

# Clang flags for eBPF compilation
CLANG_FLAGS="-O2 -target bpf -c -g -D__TARGET_ARCH_${TARGET_ARCH}"
INCLUDE_FLAGS="-I. -I/usr/include/$(uname -m)-linux-gnu"

# Function to compile a single eBPF file
compile_bpf() {
    local input_file="$1"
    local output_file="${input_file%.c}.o"
    
    echo -e "Compiling ${input_file} -> ${output_file}"
    
    if clang $CLANG_FLAGS $INCLUDE_FLAGS "$input_file" -o "$output_file"; then
        echo -e "${GREEN}✓ Successfully compiled ${output_file}${NC}"
    else
        echo -e "${RED}✗ Failed to compile ${input_file}${NC}"
        return 1
    fi
}

# Find and compile all .bpf.c files
bpf_files_found=0
for file in *.bpf.c; do
    if [ -f "$file" ]; then
        compile_bpf "$file"
        bpf_files_found=$((bpf_files_found + 1))
    fi
done

if [ $bpf_files_found -eq 0 ]; then
    echo -e "${YELLOW}No .bpf.c files found in current directory.${NC}"
    exit 0
fi

echo -e "${GREEN}Build completed! Generated object files:${NC}"
ls -la *.bpf.o 2>/dev/null || echo "No .bpf.o files generated"

echo -e "${YELLOW}Note: Make sure to run this script with appropriate privileges if needed.${NC}"