# FLASH.md — SP970 EDL 刷机

> ⚠️ 刷机有变砖风险。**第一步必须全盘备份**。SP970 是 eMMC 版，走 EDL（9008）刷。

## 1. 装 edl 工具

```bash
git clone https://github.com/bkerler/edl && cd edl
pip install -r requirements.txt
```

## 2. 进 EDL 模式（9008）

SP970/OpenStick 参考 PostmarketOS「Zhihe series LTE dongles」进 flash 模式的做法：
- 从 OpenWrt：`edl e boot`（擦 boot 分区）后重插，通常掉进 EDL；或
- 从 fastboot：`fastboot oem reboot-edl`
- 插入时按住按钮进 fastboot / EDL（不同批次略有差异）

确认：`lsusb` 出现 `05c6:9008 Qualcomm ... QDLoader 9008`。

## 3. 全盘备份（务必！）

```bash
edl rf backup_sp970_full.bin          # 整盘备份
# 或至少备份关键分区：
edl r modem  modem.bin
edl r boot   boot.bin
edl r rootfs rootfs.bin
edl r fsg    fsg.bin                   # WiFi/modem 校准，别丢
```

把 backup 存到安全的地方（workspace 也放一份）。

## 4. 刷 OpenWrt

用上游 image 自带的 flash 脚本（EDL 全流程，自动备份 radio 分区、写 GPT/firmware/boot/rootfs 再恢复）：

```bash
./openwrt-msm89xx-msm8916-*-flash.sh
```

## 5. 首启

- 首启会格式化 overlay（ext4）并自动扩容，稍等。
- 默认 LAN `192.168.1.1`（以上游为准），SSH/LuCI 进去。
- 跑 BUILD.md 第 6 步的三门槛验证。

## 6. 出问题回滚

```bash
edl w rootfs rootfs.bin    # 或整盘 edl wf backup_sp970_full.bin
```

modem「一直搜索」多半是 MCFG 区域配置问题，见上游 README「No Network / Modem Stuck」章节，刷对应区域的 `MCFG_SW.MBN`。
