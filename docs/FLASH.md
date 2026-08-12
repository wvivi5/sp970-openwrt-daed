# FLASH.md — SP970 刷机指南（含分区表铁证）

> ⚠️ 刷机有变砖风险。**第一步必须全盘备份**。SP970 是 eMMC 版。

---

## 🚧 待办（2026-08-12 定的方向，明天做）：改「ext4 单分区版」免动分区表

用户要求：**保持设备现有分区表 100% 不变**，别用 EDL 重写 GPT。方案已验证可行——
复刻 3 号机现状（`/dev/mmcblk0p14 on / type ext4 (rw)`，单块 ext4 可写根，无 rootfs_data）：

- 改 Device 的 `IMAGES`：从 `squashfs 双分区 + gpt_both0.bin` → **ext4 单分区**（不再生成 gpt/rootfs_data）
- boot cmdline 保持 `root=/dev/mmcblk0p14 rw rootwait`（与 3 号一致）
- 刷法：`fastboot flash boot boot.img` + `fastboot flash rootfs rootfs.ext4`（或 SSH 内 `dd` 到 p14），**分区表一字不动，可回滚**
- 待办：① 改 `.github/workflows/build.yml` 里 uz801 Device 的 IMAGES 为 ext4 单分区；② 触发 CI 出固件（盯 BTF/BPF 工具链坑）；③ 打包双击即刷包。

> 依据：3 号(同款SP970V3)实测 `mount`/`cmdline` 就是单块 ext4；新固件内核 cmdline 本就是 `root=/dev/mmcblk0p14`，只是编译框架默认多生成了双分区 gpt。改单分区即彻底免动分区表。

---

## 🔑 参考：为什么默认的双分区版必须 EDL（分区表铁证）

**结论：从 HandsomeMod / 原厂状态刷本固件，必须走 EDL，纯 fastboot 不行。**

原因是**分区表结构不同**。用 3 号机（SP970V3，与 2 号同款，跑 HandsomeMod 5.10）实测 `cat /proc/partitions` 对照本项目编译产物 `gpt_both0.bin`：

| 分区 | 设备现状 (HandsomeMod 5.10) | 本项目固件 (uz801 6.12) | 一致? |
| --- | --- | --- | --- |
| boot | `mmcblk0p12` = 64MB | boot = 64MB | ✅ |
| rootfs | `mmcblk0p14` = **单块 ≈3.32GB** | **rootfs 128MB + rootfs_data 3398MB** | ❌ 结构不同 |
| fsc/fsg/modem/modemst1/2/persist/sbl1/tz/aboot/hyp/rpm/sec | 标准 msm8916 | 位置大小一致 | ✅ |

**差异点**：设备现在是**单块大 rootfs**，本固件要的是 **rootfs + rootfs_data 双分区**。
- **fastboot 改不了分区表** → 硬刷 rootfs 会因布局对不上而变砖。
- **只有 EDL 能写新 GPT** 重新划分区 → 所以必须 EDL。

> 上游作者也正因如此，只提供 `flash.sh`（EDL 全流程），不给 fastboot 脚本。

### 什么时候能用 fastboot？
仅当设备**已经刷过本套双分区 OpenWrt**（分区表已是 rootfs+rootfs_data），做**同版更新**时，才能 fastboot 单刷 boot/rootfs。**首次从 HandsomeMod/安卓迁移，不行。**

---

## 方式一（推荐）：EDL 9008 一键刷

### 1. 装 edl 工具

Windows（CMD，不是 Git Bash）：
```
pip install edl
```
（无 pip 先装 Python，安装勾选 Add Python to PATH）
Linux：
```
git clone https://github.com/bkerler/edl && cd edl && pip install -r requirements.txt
```

### 2. 进 EDL 模式（9008）
- 从 OpenWrt：`edl e boot`（擦 boot）后重插，通常掉进 EDL；或
- 从 fastboot：`fastboot oem reboot-edl`；或
- 插入时短接测试点 / 按住按键（不同批次略有差异）

确认：`lsusb` 出现 `05c6:9008 ... QDLoader 9008`（Windows 设备管理器显示 `Qualcomm HS-USB QDLoader 9008`）。
Windows 若 edl 抓不到设备，用 **Zadig** 给该设备换 `libusb-win32` 驱动。

### 3. 全盘备份（务必！）
```bash
edl rf backup_sp970_full.bin          # 整盘备份，最保险
# 或至少关键分区：
edl r modem modem.bin
edl r fsg   fsg.bin                    # WiFi/modem 校准，丢了没网
edl r boot  boot.bin
edl r rootfs rootfs.bin
```

### 4. 刷入（用固件自带脚本，自动备份 radio→写 GPT→刷固件→还原 radio）
把这 4 个文件放同一目录，运行 `flash.sh`：
- `*-squashfs-gpt_both0.bin`（新分区表）
- `*-squashfs-boot.img`
- `*-squashfs-system.img`
- `*-firmware.zip`（内含 aboot/hyp/rpm/sbl1/tz .mbn）

```bash
./openwrt-msm89xx-msm8916-*-flash.sh
```
脚本会自动：备份 fsc/fsg/modemst1/2/modem/persist/sec → 写 GPT（裸扇区三段写）→ 刷 aboot/hyp/rpm/sbl1/tz/boot/rootfs → 擦 rootfs_data → 还原 radio → 重启。

### 5. 首启
- 首启格式化 overlay 并扩容，稍等 1-2 分钟。
- 默认 LAN `192.168.1.1`，SSH/LuCI 进入。
- 跑 BUILD.md 三门槛验证（BTF / clsact / daed）。

### 6. 回滚
```bash
edl w rootfs rootfs.bin        # 单分区回滚
edl wf backup_sp970_full.bin   # 整盘回滚
```

---

## 方式二：Windows 零安装一键包（内置 edl，双击即刷）

为免装 Python，提供打包好的一键包（见 Releases / 附件），内含 Windows 版 edl 与固件，双击 `FLASH.bat` 按提示即可。
> ⚠️ 中文文件名 + `chcp 65001` 会导致部分中文系统双击闪退，脚本一律用**英文文件名 + 纯 ASCII 内容**。

---

## 常见问题
- **双击 bat 闪退**：文件名/内容含中文或 `chcp 65001` 所致 → 用英文名纯 ASCII 版本。
- **edl 找不到设备**：没进 9008 模式，或 Windows 缺 libusb 驱动（用 Zadig 换）。
- **modem 一直搜索无信号**：多为 MCFG 配置问题，刷对应区域 `MCFG_SW.MBN`；确认 fsg/modemst 已正确还原。
- **fastboot 刷完起不来**：正是分区表不匹配（本文档开头的坑），改用 EDL 重写 GPT。
