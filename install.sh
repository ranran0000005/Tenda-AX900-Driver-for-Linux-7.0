#!/bin/bash
set -e

KVER=$(uname -r)
SIGN_TOOL="/usr/src/linux-headers-${KVER}/scripts/sign-file"
MOD_DEST="/lib/modules/${KVER}/kernel/drivers/net/wireless/aic8800"

echo "========================================"
echo "AIC8800 Driver Install Script"
echo "========================================"

# 1. 编译
echo "[1/6] Compiling modules..."
cd "$(dirname "$0")/drivers/aic8800/aic_load_fw"
make clean >/dev/null 2>&1
make -j$(nproc)
cd "../aic8800_fdrv"
make clean >/dev/null 2>&1
cp ../aic_load_fw/Module.symvers . || true
make -j$(nproc)
cd "$(dirname "$0")"

# 2. 签名
echo "[2/6] Signing modules..."
if [ -f MOK.priv ] && [ -f MOK.der ]; then
    sudo "${SIGN_TOOL}" sha256 MOK.priv MOK.der drivers/aic8800/aic_load_fw/aic_load_fw.ko
    sudo "${SIGN_TOOL}" sha256 MOK.priv MOK.der drivers/aic8800/aic8800_fdrv/aic8800_fdrv.ko
    echo "      Signed with existing MOK key."
else
    echo "      WARNING: MOK key not found (MOK.priv / MOK.der)."
    echo "      If Secure Boot is enabled, modules will be rejected."
    echo "      See README.md -> Secure Boot section."
fi

# 3. 安装固件
echo "[3/6] Installing firmware..."
sudo mkdir -p /lib/firmware/aic8800D80
sudo mkdir -p /lib/firmware/aic8800DC
sudo cp -rf fw/aic8800D80/*.bin fw/aic8800D80/*.txt /lib/firmware/aic8800D80/ 2>/dev/null || true
sudo cp -rf fw/aic8800DC/*.bin fw/aic8800DC/*.txt /lib/firmware/aic8800DC/ 2>/dev/null || true

# 4. 安装 udev 规则
echo "[4/6] Installing udev rules..."
sudo cp tools/aic.rules /etc/udev/rules.d/
sudo udevadm control --reload
sudo udevadm trigger

# 5. 安装内核模块
echo "[5/6] Installing kernel modules..."
sudo mkdir -p "${MOD_DEST}"
sudo cp drivers/aic8800/aic_load_fw/aic_load_fw.ko "${MOD_DEST}/"
sudo cp drivers/aic8800/aic8800_fdrv/aic8800_fdrv.ko "${MOD_DEST}/"
sudo depmod -a

# 6. 配置开机自动加载
echo "[6/6] Configuring auto-load..."
if [ ! -f /etc/modules-load.d/aic8800.conf ]; then
    printf "aic_load_fw\naic8800_fdrv\n" | sudo tee /etc/modules-load.d/aic8800.conf >/dev/null
fi

echo "========================================"
echo "Install complete!"
echo ""
echo "Next steps:"
echo "  1. If this is the first install with Secure Boot,"
echo "     generate and enroll MOK key (see README.md)."
echo "  2. Load the drivers: sudo modprobe aic_load_fw && sudo modprobe aic8800_fdrv"
echo "  3. Insert the USB adapter."
echo "========================================"
