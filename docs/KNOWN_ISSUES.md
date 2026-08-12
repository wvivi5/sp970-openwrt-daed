# KNOWN_ISSUES.md — SP970 已知坑

## 1. wcn36xx WiFi AP 模式锁 6.5M（下行）

SP970 的 wcn36xx 在 **AP 模式**下 TX rate control 有 bug，下行锁死 `6.5 MBit/s MCS0`（上行正常 ~58M）。
- 社区实证（HandsomeMod issue #24）：多人 sp970/ufi001c 换 backports 5.15.33 驱动重编后 **AP 模式仍锁 6.5M**，集体翻车。
- **换到内核 6.12 未必解决**（wcn36xx 驱动 AP rate control 问题跨内核长期存在）。
- **STA/客户端模式正常**（收40M/发30M）。
- 结论：**SP970 当旁路由/有线服务器用不受影响**；别指望它当高速热点。daed 是透明代理，走有线/上游没问题。

## 2. wcn36xx 反复 wifi reload 会把射频搞进半死状态

反复切频段/reload 会让 beacon 停发（`tx_packets` 不涨），软重载无效，需 reboot 救活。
- 教训：**一次设好 + 长期不动**。刷新固件后 WiFi 配置定下来就别频繁折腾。

## 3. 384MB 内存偏小

daed 本身占用不大，但 + 面板 + Docker（如果还跑青龙）容易吃满。
- 建议：刷成 daed 专用旁路由后，别再在同机堆青龙/Docker，或严格限内存。

## 4. BTF 编译 OOM

`CONFIG_DEBUG_INFO_BTF=y` 编译时 pahole 吃内存，编译机内存 <4G 易 OOM（StackOverflow 实证）。
- 用 ≥8G 内存的编译机或 Docker，别在小板子上本地编。

## 5. EDL 刷机变砖风险

必须先 `edl rf backup.bin` 全盘备份。fsg/modem 分区（WiFi/蜂窝校准）丢了很难恢复。

## 6. 设备树适配未定

上游 hkfuertes 默认 target 是 uz801v3/uf02，SP970 compatible 是 `handsome,openstick`。
- 需确认上游 DTS 是否已含 openstick 节点；没有则要移植。这是本项目最大不确定项。
