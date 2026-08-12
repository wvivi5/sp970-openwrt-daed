# SP970 ext4 编译轮询状态

> 轮询 cron 无法自改 payload（restricted），故用本文件记录当前真实目标 run。

## 当前目标 run
- **RUN_ID = 31634725918**（ext4 PARTSIZE=512MB 修复重试，2026-08-12 19:51Z 触发）
- 轮询时优先信任 `gh run list --workflow=build.yml --limit 1` 的最新 run。

## 历史
- run **31612183682**: FAILED @ 编译。已修复（commit e5b9111：启用 EXT4FS）。
- run **31623649459**: FAILED @ 编译 image 阶段 `make_ext4fs: out of space`（rootfs 104MB 默认装不下 daed+Docker+BTF）。
- 修复 commit `7fcb64f`: 固化 `CONFIG_TARGET_ROOTFS_PARTSIZE=512`（MB），并加校验门禁。触发 → run 31634725918。

## success 时动作（针对最新 run）
1. `gh run download <RUN_ID> -D /tmp/sp970-ext4/`
2. ext4 rootfs 核验 `/usr/bin/daed` 存在
3. 确认 boot cmdline = `root=/dev/mmcblk0p14 rootfstype=ext4 rw`
4. 打包双击即刷零安装包（ext4 单分区免动分区表）
5. 汇报用户 + 附包路径
6. 删除本轮询 cron（name=SP970 ext4编译轮询）
