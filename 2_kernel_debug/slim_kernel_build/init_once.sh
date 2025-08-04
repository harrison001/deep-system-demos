# 进入 Yocto 根目录
cd ~/yocto-arm64

# 建立 qemuarm64 专用目录（存放 fragment.cfg）
mkdir -p poky/meta/recipes-kernel/linux/linux-yocto/qemuarm64

# 写一次 bbappend，让 Yocto 永久附加 debug-info.cfg
cat > poky/meta/recipes-kernel/linux/linux-yocto_%.bbappend <<'EOF'
FILESEXTRAPATHS:prepend := "${THISDIR}/linux-yocto/qemuarm64:"
SRC_URI += "file://debug-info.cfg"
EOF

# 确认 layer.conf 已支持 .bbappend 文件
grep BBFILES poky/meta/conf/layer.conf || echo '⚠ BBFILES 未配置，请手动检查'

# 验证 Yocto 能看到 bbappend
cd poky/build
bitbake-layers show-appends | grep linux-yocto