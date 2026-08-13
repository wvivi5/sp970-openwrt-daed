# SP970 ext4 编译轮询状态

## 当前 (2026-08-13 05:53 CST)
- 目标 run: **31644460314** (in_progress, glob 修复后重跑)
- 上一 run 31634725918: success 但 artifact 缺核心 rootfs 镜像

## 第9坑：upload glob 不匹配 .gz
- ext4 镜像实际产物是 gzip: `ext4-boot.img.gz` / `ext4-system.img.gz` / `ext4-sysupgrade.bin.gz`
- build.yml upload-artifact 的 path glob 写的是无 `.gz` 名 → 三个核心镜像全部漏传
- `if-no-files-found: warn` → run 仍标 success，掩盖了漏传
- 修复 3d96aec: glob 结尾加 `*` 匹配 .gz；`if-no-files-found: error` 防再次静默漏传
- daed 已确认在 manifest (daed 2026.08.05-r8, docker 27.3.1, luci-app-daede)，但需从实际 rootfs 镜像核验 /usr/bin/daed

## 踩坑历史
1-6. BTF/BPF 工具链 (clang/pahole/config choice/磁盘)
7. ext4: yiming-uz801v3-images 规则缺失 (未开 EXT4FS) → e5b9111
8. ext4: make_ext4fs out-of-space (104MB PARTSIZE) → 7fcb64f 固化 512MB
9. upload glob 不匹配 .gz → 3d96aec

## 注意
- isolated cron run 无法 update 自身 payload（restricted）。payload 内硬编码 run id 已过期。
- **以 POLL_TARGET.txt 的 CURRENT_POLL_TARGET_RUN 为准**（本文件同步）。
