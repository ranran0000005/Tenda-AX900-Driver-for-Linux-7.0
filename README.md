# 腾达 AX900 USB 无线网卡 Linux 驱动（AIC8800 芯片）

> **本驱动基于官方 V1.0.1.4 源码修改，已适配 Linux 7.0+ 内核**
>
> 原始驱动发布于 2023 年 3 月，官方仅支持到内核 6.x。本修改版解决了内核 7.0 中的 API 不兼容问题，并修复了若干安全漏洞。

---

## 📋 支持设备

| 品牌 | 型号 | 芯片方案 | 接口 |
|------|------|---------|------|
| 腾达 (Tenda) | AX900 | AIC8800D80 / AIC8800DC | USB |

- USB VID: `0xA69C` / `0x368B`
- USB PID: `0x8800`, `0x88DC`, `0x88DD`, `0x8D81` 等
- 支持 Wi-Fi 6 (802.11ax)、2.4GHz/5GHz 双频、WPA3

---

## 🐧 内核兼容性

| 内核版本 | 状态 |
|---------|------|
| Linux 3.10 - 6.x | ✅ 官方原始支持 |
| **Linux 7.0+** | **✅ 本修改版支持** |

> 测试环境：`Linux 7.0.0-15-generic (x86_64)`

---

## 🔧 修改内容

### 1. 内核 7.0 API 兼容性（解决编译错误）

| 问题 | 涉及文件 | 修改方式 |
|------|---------|---------|
| `wakeup_source_create/add/remove/destroy` 被移除 | `rwnx_wakelock.c` | 改用 `wakeup_source_register/unregister` |
| `del_timer` / `del_timer_sync` 更名为 `timer_delete` / `timer_delete_sync` | `rwnx_compat.h` | 添加版本兼容宏自动替换 |
| `from_timer` 宏消失 | `rwnx_compat.h` | 宏替换为 `container_of` |
| `in_irq()` 被移除 | `rwnx_rx.c` | 替换为 `in_hardirq()` |
| `cfg80211` 回调增加 `radio_idx` 参数 | `rwnx_main.c` | 函数签名适配 |
| `cfg80211_rx_spurious_frame` / `cfg80211_rx_unexpected_4addr_frame` 增加 `link_id` | `rwnx_rx.c` | 通过兼容宏自动补全参数 |
| 内核 fortify 误报（radiotap 头构建） | `rwnx_rx.c` | `memcpy` 改为安全逐字节拷贝 |

### 2. 安全漏洞修复

| 漏洞 | 风险等级 | 修复方式 |
|------|---------|---------|
| `aic_vendor.c`: `strcpy(rb.name, nla_data(iter))` 无长度校验 | 🔴 高 | 改为 `strscpy`，限制 31 字节 |
| `aicwf_compat_8800d80.c`: `sprintf` 源目标缓冲区重叠 | 🟡 中 | 使用临时缓冲区中转 |
| `aicwf_compat_8800d80x2.c`: `sprintf` 源目标缓冲区重叠 | 🟡 中 | 使用临时缓冲区中转 |

### 3. 保留内容

- ✅ 所有调试日志（`AICWFDBG` / `printk`）完整保留
- ✅ 原有内核版本兼容体系（3.10 - 6.x）不受影响
- ✅ 功能特性：STA / AP / P2P / TDLS / Monitor / WPA3 / Wi-Fi 6

---

## 📦 编译与安装

### 依赖

```bash
sudo apt update
sudo apt install build-essential linux-headers-$(uname -r) git
```

### 编译

```bash
cd drivers/aic8800
make clean
make -j$(nproc)
```

编译成功后会生成两个内核模块：
- `aic_load_fw/aic_load_fw.ko` — 固件加载器
- `aic8800_fdrv/aic8800_fdrv.ko` — 无线网卡驱动

### 安装

```bash
cd drivers/aic8800
sudo make install
sudo depmod -a
```

### 加载驱动

```bash
# 复制固件和 udev 规则
sudo bash install_setup.sh

# 加载内核模块
sudo modprobe aic_load_fw
sudo modprobe aic8800_fdrv

# 查看网卡是否识别
ip link show
# 或
iw dev
```

**加载时的日志示例（正常，无需插入网卡）：**

```
aic_load_fw: loading out-of-tree module taints kernel.
aic_load_fw: module verification failed: signature and/or required key missing - tainting kernel
aic_bluetooth_mod_init
AICWFDBG(LOGINFO)	aicwf_prealloc_init enter
usbcore: registered new interface driver aic_load_fw
AICWFDBG(LOGINFO)	rwnx v6.4.3.0 - 1a4b0054d2M (master)
usbcore: registered new interface driver aic8800_fdrv
```

> - `taints kernel` / `module verification failed`：**正常现象**。本驱动是外部模块（out-of-tree），未进行内核签名，不影响功能。
> - 驱动加载后即注册 USB 接口监听，**无需插入网卡**也会显示上述初始化日志。插入网卡后会自动识别并加载固件。

### 卸载

```bash
sudo rmmod aic8800_fdrv
sudo rmmod aic_load_fw
sudo bash uninstall_setup.sh
```

---

## 🐛 查看调试日志

```bash
# 实时查看驱动日志
sudo dmesg -w | grep -iE "aic|rwnx|AICWFDBG"

# 查看历史日志
sudo dmesg | grep -iE "aic|rwnx|AICWFDBG"

# 调整日志详细程度（数值越大越详细）
echo 0  | sudo tee /sys/module/aic8800_fdrv/parameters/aicwf_dbg_level  # 关闭
echo 1  | sudo tee /sys/module/aic8800_fdrv/parameters/aicwf_dbg_level  # 仅错误
echo 7  | sudo tee /sys/module/aic8800_fdrv/parameters/aicwf_dbg_level  # 错误+信息+跟踪
echo 63 | sudo tee /sys/module/aic8800_fdrv/parameters/aicwf_dbg_level  # 全开
```

| 数值 | 含义 |
|------|------|
| 0 | 关闭所有可控日志 |
| 1 | 仅错误 |
| 3 | 错误 + 信息（默认） |
| 7 | 错误 + 信息 + 跟踪 |
| 15 | + 调试 |
| 63 | 全部 |

---

## ⚠️ 已知问题与注意事项

1. **运行时稳定性**
   - 本驱动已通过编译测试，但 **长时间运行稳定性仍需验证**。建议在实际使用前进行压力测试（大数据量传输、长时间在线、休眠唤醒等）。

2. **Monitor 模式**
   - 驱动功能代码中包含 radiotap 头构建逻辑，内核 fortify 机制曾对此发出警告（已修复）。Monitor 模式可用，但如遇到捕获异常请反馈。

3. **SDIO 模式**
   - 当前 `Makefile` 默认配置为 **USB 模式**（`CONFIG_USB_SUPPORT=y`, `CONFIG_SDIO_SUPPORT=n`）。
   - 若您的设备为 SDIO 接口版本，需修改 `Makefile` 中对应开关后重新编译。

4. **Secure Boot**
   - 若系统启用了 Secure Boot，需先禁用或自行对驱动模块签名，否则内核拒绝加载未签名模块。

5. **调试信息**
   - 驱动默认输出较多调试日志。如需要减少日志，可修改 `Makefile` 中日志级别相关配置后重新编译。

---

## 🔇 正式使用：移除调试内容（可选）

当前驱动包含大量调试代码（约 1800+ 处日志输出、114 处 `WARN_ON`/`BUG_ON`），适合开发调试。若需精简驱动用于正式环境：

**快速减少日志（无需重新编译）：**
```bash
echo 1 | sudo tee /sys/module/aic8800_fdrv/parameters/aicwf_dbg_level
```

**彻底移除调试代码（需重新编译）：**

编辑 `drivers/aic8800/aic8800_fdrv/rwnx_main.c`：
```c
// 第 542 行，将默认值从 3 改为 1（仅保留错误日志）
int aicwf_dbg_level = LOGERROR;  // 原来是 LOGERROR|LOGINFO
```

编辑 `drivers/aic8800/aic8800_fdrv/Makefile`，在顶部添加：
```makefile
EXTRA_CFLAGS += -DCONFIG_RWNX_DBG=n
EXTRA_CFLAGS += -Wno-unused-variable
```

然后重新编译安装：
```bash
cd drivers/aic8800
make clean && make -j$(nproc)
sudo make install
```

> **提示**：如不熟悉内核开发，建议保留默认调试配置。调试日志对排查连接问题非常有帮助，且对性能影响极小。

---

## 📝 修改文件清单

```
drivers/aic8800/aic8800_fdrv/rwnx_compat.h          (+ 兼容宏体系)
drivers/aic8800/aic8800_fdrv/rwnx_wakelock.c        (wakeup_source API)
drivers/aic8800/aic8800_fdrv/rwnx_rx.c              (timer/in_irq/cfg80211/fortify)
drivers/aic8800/aic8800_fdrv/rwnx_main.c            (cfg80211 回调签名)
drivers/aic8800/aic8800_fdrv/aic_vendor.c           (strcpy → strscpy)
drivers/aic8800/aic8800_fdrv/aicwf_compat_8800d80.c  (sprintf 重叠修复)
drivers/aic8800/aic8800_fdrv/aicwf_compat_8800d80x2.c (sprintf 重叠修复)
```

---

## 📄 许可证

本驱动基于官方源码修改，遵循原始 GPL 许可证。

原始版权：RivieraWaves / AIC (爱科微)

---

## 🙏 致谢

- 原始驱动由 **AIC (爱科微)** 提供
- 基于 **RivieraWaves RWNx** 全 MAC 驱动框架

---

> **免责声明**：本修改版驱动为社区维护，非官方发布。作者不对因使用本驱动导致的系统不稳定、数据丢失或其他损失承担责任。请自行评估风险后使用。
