# SP970 ext4 编译轮询状态

> 轮询 cron 无法自改 payload（restricted），故用本文件记录当前真实目标 run。

## 当前目标 run
- **RUN_ID = 31623649459**（ext4 单分区修复重试，2026-08-12 17:38Z 触发）
- 轮询时优先信任 `gh run list --workflow=build.yml --limit 1` 的最新 run，而非 payload 里硬编码的旧 run 31612183682。

## 历史
- run **31612183682**: FAILED @ 编译步骤（exit 2）。已修复。
- 修复 commit `e5b9111`: 启用 `CONFIG_TARGET_ROOTFS_EXT4FS`，修复 `yiming-uz801v3-images` 缺失 + 上传 ext4 产物路径。
- 修复后触发重试 → run 31623649459（进行中，编译步骤，前置步骤全部 ✓）。

## success 时动作（针对最新 run）
1. `gh run download <RUN_ID> -D /tmp/sp970-ext4/`
2. ext4 rootfs 核验 `/usr/bin/daed` 存在
3. 确认 boot cmdline = `root=/dev/mmcblk0p14 rootfstype=ext4 rw`
4. 打包双击即刷零安装包（ext4 单分区免动分区表）
5. 汇报用户 + 附包路径
6. 删除本轮询 cron（name=SP970 ext4编译轮询）
