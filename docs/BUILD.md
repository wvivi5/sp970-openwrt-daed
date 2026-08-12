# BUILD.md — 编译带 BTF + daed 的 SP970 固件

## 0. 前置

- 一台 Linux（或 Docker）编译机，≥4 核、≥8G 内存、≥30G 空闲盘。
  （BTF 生成时 pahole 吃内存，内存太小会 OOM——见 KNOWN_ISSUES。）
- 网络能访问 GitHub / OpenWrt 源。

## 1. 拉上游编译环境（基于 hkfuertes/msm8916-openwrt）

```bash
git clone https://github.com/hkfuertes/msm8916-openwrt.git
cd msm8916-openwrt/devenv
docker compose build builder
docker compose run --rm builder
# 进容器后：
cp /repo/diffconfig_uz801 .config     # 先拿 uz801 当基线
make defconfig
```

上游默认：OpenWrt 25.12.x snapshot（内核 **6.12**）。

## 2. 叠加 BTF / eBPF / clsact 内核选项

把本仓库 `config/kernel-btf.config` 的内容合并进内核 config：

```bash
# 方式 A：menuconfig 手动勾（Kernel modules / Network / ...）
make menuconfig

# 方式 B：脚本批量 enable（在 build_dir 的内核 .config 上）
#   Kernel hacking -> Compile-time checks -> Debug information (BTF)
#   或直接编辑 target/linux/qualcommXX/config-6.12 追加：
#     CONFIG_DEBUG_INFO_BTF=y
#     # CONFIG_DEBUG_INFO_REDUCED is not set
```

确认 host 上 `pahole --version` ≥ 1.16（BTF 生成依赖，dwarves 包）。

## 3. 加 daed 包 feed

在 `feeds.conf.default` 追加：

```
src-git daede https://github.com/kenzok8/openwrt-daede
```

然后：

```bash
./scripts/feeds update daede
./scripts/feeds install -a -p daede
make menuconfig   # 勾 Network -> daed / luci-app-daed
# 同时确保勾上：kmod-sched-bpf, kmod-veth, kmod-sched-core
```

## 4. SP970 设备适配

SP970 实测 `compatible = handsome,openstick / qcom,msm8916`，eMMC 版，分区与 UZ801v3 高度同构。
若上游没有 openstick/sp970 的 target profile，需要：
- 确认 DTS：`qcom-msm8916-*.dts` 是否已含 openstick 节点（上游可能已有）
- 补 `image/` 里的设备定义或直接复用 uz801 的 image recipe（同 eMMC 布局）

> 先跑通 uz801 image，再对照 SP970 `cat /proc/partitions` 和 `/dev/disk/by-partlabel` 微调。

## 5. 编译

```bash
make -j$(nproc)
# 产物：bin/targets/qualcommXX/.../openwrt-*-sp970-*.bin + flash.sh
```

## 6. 验证（刷机后上机跑，三门槛必须全过）

```bash
ls /sys/kernel/btf/vmlinux                     # 存在 = BTF OK
ip link add t type dummy && tc qdisc add dev t clsact && echo CLSACT_OK
uname -r                                        # 应为 6.12.x
```

三样全过再装/起 daed。
