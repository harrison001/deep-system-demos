 
qemu-system-aarch64 \
  -machine virt \
  -cpu cortex-a57 \
  -smp 4 \
  -m 512 \
  -nographic \
  -kernel tmp/deploy/images/qemuarm64/Image \
  -drive file=$(ls -t tmp/deploy/images/qemuarm64/core-image-minimal-qemuarm64-*.rootfs.ext4 | head -1),format=raw,if=virtio \
  -append "console=ttyAMA0 root=/dev/vda rw nokaslr" \
  -s -S


 