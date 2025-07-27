# Deep System Demos

This repository contains **low-level system demos** for interview preparation.  
It showcases *boot process, kernel debugging, microarchitecture behaviors (OoO, fences), eBPF security monitoring, and Rust vs C assembly analysis.*

---

## 📂 Structure
deep-system-demos/
├── 1_bootloader/        # Custom bootloader + GDB debugging
├── 2_kernel_debug/      # Slimmed kernel build & remote debugging
├── 3_microarch_demos/   # Cache/TLB miss, NUMA, fences, OoO
├── 4_ebpf_security/     # Syscall/file monitor via eBPF
├── 5_rust_vs_c/         # Assembly-level Rust vs C comparison
└── demo_web/            # Simple HTML index for live demo

---

## 🚀 Demos

✅ Bootloader + password check before FreeDOS  
✅ Kernel build slim & GDB debug step  
✅ Cache/TLB miss demo + NUMA + fence/OoO analysis  
✅ eBPF syscall monitor & file protection  
✅ Rust vs C: generated assembly comparison  

---

## 📖 About

These demos are designed to show **deep system-level knowledge**:  

- Memory ordering & fences  
- CPU out-of-order execution & speculation  
- Microarchitecture performance (cache, TLB, NUMA)  
- Secure monitoring using eBPF  
- Bare-metal boot process understanding  

---

## 🛠 Build & Run

Each subfolder has its own **README** with build instructions.  
For a quick start:

```bash
# Clone and init
git clone https://github.com/harrison001/deep-system-demos.git
cd deep-system-demos

# Example: run bootloader demo
cd 1_bootloader
./run_qemu.sh
---
MIT License
