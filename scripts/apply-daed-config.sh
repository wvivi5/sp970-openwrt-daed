#!/bin/sh
# apply-daed-config.sh
# 把 daed 所需内核选项叠加进 hkfuertes/msm8916-openwrt 的 msm89xx/config-6.12。
# 用法：在克隆好的 msm8916-openwrt 仓库根目录执行：
#   /path/to/sp970-openwrt-daed/scripts/apply-daed-config.sh
#
# 幂等：重复执行不会重复追加。已在内核 6.12 config 上实地验证（2026-08-11）。

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OVERLAY="$SCRIPT_DIR/../config/kernel-btf.config"

# ============================================================
# 模式 B：传入 openwrt 根目录参数 -> 只向 openwrt/.config 追加增量包，
#          不碰内核 config（内核 config 已在「挂 msm89xx target」那步应用过）。
# ============================================================
OPENWRT_DIR="$1"
if [ -n "$OPENWRT_DIR" ]; then
  [ -f "$OPENWRT_DIR/.config" ] || { echo "ERROR: 未找到 $OPENWRT_DIR/.config" >&2; exit 1; }
  PKGCFG="$SCRIPT_DIR/../config/packages-daed-passwall-docker.config"
  [ -f "$PKGCFG" ] || { echo "ERROR: 未找到 $PKGCFG" >&2; exit 1; }
  echo "[+] 追加 daed+Docker 增量包到 $OPENWRT_DIR/.config（v2：已去 Passwall）"
  grep -E '^CONFIG_' "$PKGCFG" | while read -r line; do
    key="${line%%=*}"
    grep -qE "^${key}=" "$OPENWRT_DIR/.config" || echo "$line" >> "$OPENWRT_DIR/.config"
  done
  echo "[+] 完成（后续 make defconfig 会解析依赖）"
  exit 0
fi

# ============================================================
# 模式 A：无参数 -> 在 msm8916-openwrt 仓库根目录，将 BTF 选项合进内核 config。
# ============================================================
CFG="msm89xx/config-6.12"

[ -f "$CFG" ] || { echo "ERROR: 未找到 $CFG，请在 msm8916-openwrt 仓库根目录运行" >&2; exit 1; }
[ -f "$OVERLAY" ] || { echo "ERROR: 未找到 overlay $OVERLAY" >&2; exit 1; }

cp "$CFG" "$CFG.bak.$(date +%Y%m%d_%H%M%S)"

# 1) 关掉与 BTF 互斥的 REDUCED
sed -i 's/^CONFIG_DEBUG_INFO_REDUCED=y/# CONFIG_DEBUG_INFO_REDUCED is not set/' "$CFG"

# 2) 删掉 "NET_SCHED is not set"（下面 overlay 会开它）
sed -i '/^# CONFIG_NET_SCHED is not set/d' "$CFG"

# 3) 追加 overlay 里的 CONFIG_ 行（跳过注释/空行，幂等去重）
#    确保文件以换行结尾，避免黏连
tail -c1 "$CFG" | od -An -c | grep -q '\\n' || echo "" >> "$CFG"
grep -E '^CONFIG_' "$OVERLAY" | while read -r line; do
  key="${line%%=*}"
  # 若该 key 已存在（=y 形式）则跳过；否则追加
  grep -qE "^${key}=" "$CFG" || echo "$line" >> "$CFG"
done

echo "[+] 已应用 daed 内核选项到 $CFG"
echo "[+] 校验关键项："
for k in CONFIG_DEBUG_INFO_BTF CONFIG_NET_SCHED CONFIG_NET_SCH_INGRESS \
         CONFIG_NET_CLS_ACT CONFIG_NET_CLS_BPF CONFIG_NET_ACT_BPF \
         CONFIG_BPF_SYSCALL CONFIG_VETH CONFIG_CGROUP_BPF; do
  grep -qE "^${k}=y" "$CFG" && echo "    OK  $k" || echo "    !!  $k 缺失"
done
grep -qE "^# CONFIG_DEBUG_INFO_REDUCED is not set" "$CFG" \
  && echo "    OK  DEBUG_INFO_REDUCED 已关" \
  || echo "    !!  DEBUG_INFO_REDUCED 未关（与 BTF 冲突）"
