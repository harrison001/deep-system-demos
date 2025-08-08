qemu-system-x86_64   -kernel arch/x86/boot/bzImage   -drive file=rootfs.img,format=raw   -append "root=/dev/sda console=ttyS0 nokaslr"   -nographic -s -S
