# daed 掉线自愈看门狗（复用 H618 经验）
# 刷机跑通 daed 后部署：/usr/local/bin/daed-watchdog.sh (chmod 755)
# 配 cron 或 systemd timer 每 2min 跑一次。
#
# 逻辑：
#  1) daed 服务挂 -> 拉起
#  2) 探测代理节点 TCP 通不通，失败等 5s 重试一次防抖
#  3) 连续不通时，先确认本机有网(探 1.1.1.1/223.5.5.5:443)，
#     确有网才判隧道僵死并重启 daed；本机自己断网(4G/上级掉线)则跳过，不做无用重启

NODE_HOST="${NODE_HOST:-YOUR_NODE_IP}"   # 部署时用环境变量传入你的代理节点 IP，或直接改这里
NODE_PORT="${NODE_PORT:-YOUR_NODE_PORT}"   # 按实际节点端口改

tcp_ok(){ timeout 4 sh -c "echo > /dev/tcp/$1/$2" 2>/dev/null; }
# 注意：OpenWrt busybox ash 不支持 /dev/tcp！用 nc 代替：
tcp_ok_nc(){ nc -z -w4 "$1" "$2" >/dev/null 2>&1; }

svc_up(){ pgrep -x daed >/dev/null 2>&1; }

restart_daed(){
  logger -t daed-watchdog "restarting daed"
  /etc/init.d/daed restart 2>/dev/null || service daed restart 2>/dev/null
}

# 1) 服务存活
svc_up || { restart_daed; exit 0; }

# 2) 节点探测 + 防抖
if tcp_ok_nc "$NODE_HOST" "$NODE_PORT"; then exit 0; fi
sleep 5
if tcp_ok_nc "$NODE_HOST" "$NODE_PORT"; then exit 0; fi

# 3) 确认本机有网再重启（避免上级断网时空转）
if tcp_ok_nc 1.1.1.1 443 || tcp_ok_nc 223.5.5.5 443; then
  logger -t daed-watchdog "node down but host online -> tunnel stuck, restart daed"
  restart_daed
else
  logger -t daed-watchdog "host offline, skip"
fi
