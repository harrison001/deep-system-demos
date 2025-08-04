source oe-init-build-env 
# 进入 Yocto build 目录
cd ~/yocto-arm64/poky/build

# 1. 打开内核配置菜单
bitbake virtual/kernel -c menuconfig

# 2. 保存后生成 fragment.cfg
bitbake -c diffconfig virtual/kernel

# 3. 覆盖 debug-info.cfg（挂钩的配置片段）
cp tmp/work/qemuarm64-poky-linux/linux-yocto/*/fragment.cfg \
   ../meta/recipes-kernel/linux/linux-yocto/qemuarm64/debug-info.cfg

# 4. 重编内核
bitbake virtual/kernel -c cleanall
bitbake virtual/kernel
# 5.更新rootfs
###
cd poky/meta/recipes-core/images
ls
##
bitbake core-image-minimal
# rootfs 也会更新