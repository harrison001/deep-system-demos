# eBPF Makefile for kernel-agent
# Compiles all .bpf.c files to .bpf.o files

# Detect target architecture
ARCH := $(shell uname -m)
ifeq ($(ARCH),x86_64)
    TARGET_ARCH = x86
else ifeq ($(ARCH),aarch64)
    TARGET_ARCH = arm64
else
    TARGET_ARCH = x86
endif

CC = clang
CFLAGS = -O2 -target bpf -c -g -D__TARGET_ARCH_$(TARGET_ARCH)
INCLUDES = -I. -I/usr/include/$(shell uname -m)-linux-gnu

# Find all .bpf.c files
BPF_SOURCES = $(wildcard *.bpf.c)
BPF_OBJECTS = $(BPF_SOURCES:.bpf.c=.bpf.o)

.PHONY: all clean help

all: $(BPF_OBJECTS)

# Rule to compile .bpf.c to .bpf.o
%.bpf.o: %.bpf.c vmlinux.h
	@echo "Compiling $< -> $@"
	$(CC) $(CFLAGS) $(INCLUDES) $< -o $@
	@echo "✓ Successfully compiled $@"

# Check if vmlinux.h exists
vmlinux.h:
	@if [ ! -f vmlinux.h ]; then \
		echo "Error: vmlinux.h not found."; \
		echo "Generate it using: bpftool btf dump file /sys/kernel/btf/vmlinux format c > vmlinux.h"; \
		exit 1; \
	fi

clean:
	rm -f *.bpf.o
	@echo "Cleaned all .bpf.o files"

help:
	@echo "eBPF Build System"
	@echo "=================="
	@echo "Targets:"
	@echo "  all     - Build all .bpf.c files to .bpf.o"
	@echo "  clean   - Remove all .bpf.o files"
	@echo "  help    - Show this help message"
	@echo ""
	@echo "Requirements:"
	@echo "  - clang compiler"
	@echo "  - vmlinux.h (generate with bpftool)"
	@echo ""
	@echo "Usage:"
	@echo "  make all    # Build all eBPF programs"
	@echo "  make clean  # Clean object files"