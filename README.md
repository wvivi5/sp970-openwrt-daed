# sp970-openwrt-daed

> 📌 **刷机方式看这里 → [docs/FLASH.md](docs/FLASH.md)**（含 3 号机实测分区表铁证：从 HandsomeMod 刷本固件必须走 EDL，纯 fastboot 会变砖）

为 **Handsome OpenStick SP970**（高通 MSM8916 / 骁龙410 随身WiFi，eMMC 版）构建一版
**开启 BTF + eBPF + clsact** 的现代 OpenWrt 固件，目标是能原生跑 **daed（大鹅，dae 内核级透明代理）**。

> 现有 HandsomeMod 固件（内核 5.10.33）无法运行 daed：无 BTF、clsact 不可用、内核太老。
> 本项目基于上游活跃的 msm8916 OpenWrt 工程（内核 6.12），叠加 BTF/eBPF 编译选项 + SP970 设备适配 + daed 打包。
>
> **构建目标（用户需求）**：保留原作者全部功能（Docker/USB gadget/modem/WiFi）+ **daed** + **Passwall**，三套一起打进固件。

---

## 目标设备

| 项 | 值 |
| --- | --- |
| 型号 | Handsome OpenStick **SP970**（精确修订 SP970V3；板子丝印 **SP970-B-V5**） |
| SoC | Qualcomm **MSM8916**（Cortex-A53 x4, aarch64） |
| DTS compatible | `handsome,openstick` / `qcom,msm8916` |
| 存储 | **eMMC** `mmcblk0`（~3.8 GB），标准高通分区（aboot/boot/rootfs/modem/sbl1/tz…） |
| 内存 | 384 MB |
| WiFi | wcn36xx（AP 模式历史上锁 6.5M，见 KNOWN_ISSUES） |
| 引导 | lk2nd / aboot（`androidboot.emmc=true`），EDL 可刷 |

## 为什么能跑 daed —— 三道硬门槛

daed 是 eBPF CO-RE 程序，运行内核必须满足：

1. **BTF**：`/sys/kernel/btf/vmlinux` 存在 ← 需内核 `CONFIG_DEBUG_INFO_BTF=y`
2. **clsact / tc-bpf**：`tc qdisc add dev X clsact` 成功 ← 需 `CONFIG_NET_CLS_ACT` + `CONFIG_NET_SCH_INGRESS` + sched-bpf
3. **veth / bpf syscall**：`CONFIG_VETH` + `CONFIG_BPF_SYSCALL`

现有固件三样全缺；本项目通过内核 config 补齐。

## 路线图（Roadmap）

- [x] 1. 基于 `hkfuertes/msm8916-openwrt`（内核 6.12）建立可编译环境（Docker）— 上游已侦察
- [x] 2. 确认 SP970 设备树/分区与 UZ801v3 差异 — **见下「侦察结论」，SP970 可蹭 uz801 定义**
- [x] 3. 内核 config 叠加：BTF + clsact + veth + bpf — **已在上游 config-6.12 实地验证**（`config/kernel-btf.config` + `scripts/apply-daed-config.sh`）
- [ ] 4. 集成 daed 包（`kenzok8/openwrt-daede` feed）+ **Passwall**（`xiaorouji/openwrt-passwall`）+ **Docker** — 已写入 CI 与 `config/packages-daed-passwall-docker.config`
- [ ] 5. GitHub Actions 云端出固件（artifact）— 完整流程已就绪，待触发验证
- [ ] 6. EDL 刷机（需物理接设备）+ 首启验证三门槛
- [ ] 7. daed 节点/分流配置 + 看门狗（复用 H618 daed-watchdog 经验）

## 侦察结论（2026-08-11，纯查代码）

扒过上游 `hkfuertes/msm8916-openwrt` 后钉死几个关键点：

1. **编译框架现成**：target 定义在 `msm89xx/image/msm8916.mk`，内核 config 就一个文件 `msm89xx/config-6.12`（内核 6.12）。用主线 OpenWrt qcom DTS + 补丁方式，不自带 dts 文件。
2. **上游无 SP970/openstick 专属 Device 定义**，只有 `yiming-uz801v3` 和 `generic-uf02`。**但**——上游 uz801 的 cmdline 是 `root=/dev/mmcblk0p14`，**与 SP970 实测 cmdline 完全一致**（同 eMMC 分区布局、同 lk2nd 引导、同 512MB 档）。→ **SP970 大概率可直接借用 `yiming-uz801v3` 固件刷入，无需从零移植 DTS**（首版先试蹭，不行再补 openstick Device 条目）。
3. **BTF 现状**：上游 config 有 `CONFIG_DEBUG_INFO_REDUCED=y`（与 BTF 互斥）+ `# CONFIG_NET_SCHED is not set`（tc 全关）+ 无 BTF。已由 `config/kernel-btf.config` 补齐，实地改后 config 自洽无畸形（1013 行）。

工作量因此从「移植设备树」降到「**改 config 开 BTF + 加 daed 包 + 编译 + 刷 uz801 镜像**」。

## 现状快照（SP970 样机，2026-08-11 实测）

```
uname:   Linux OpenWrt 5.10.33 aarch64
系统:    HandsomeMod 21.03-Attila-SNAPSHOT r181-fa7f0be518
target:  msm89xx/msm8916 (aarch64_cortex-a53_neon)
BTF:     /sys/kernel/btf/vmlinux  -> 不存在  ❌
clsact:  FAIL                                ❌
kmod:    kmod-sched-core / kmod-veth 已装, 但无 sched-bpf / 无 BTF
```

## ⚠️ 风险

- **EDL 刷机有变砖风险**，务必先 `edl rf backup.bin` 全盘备份再刷。
- SP970 的 wcn36xx WiFi 在 AP 模式历史上锁 6.5M（内核换新未必解决），当旁路由/有线用不受影响。
- 384MB 内存偏小，daed + 面板需控制内存占用。

## 参考上游

- hkfuertes/msm8916-openwrt（内核 6.12，Docker 编译，EDL 刷机）
- ghosthgy/openwrt-msm8916 · r1bnc/msm8916-openwrtt（同类 msm8916 工程）
- kenzok8/openwrt-daede（daed/dae 的 OpenWrt luci 打包 feed）

详见 `docs/BUILD.md`、`docs/FLASH.md`、`docs/KNOWN_ISSUES.md`。
