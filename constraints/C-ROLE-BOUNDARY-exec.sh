#!/bin/bash
#===============================================================================
# C-ROLE-BOUNDARY-exec.sh — Shuyu操作边界扫描
# 扫描Shuyu session日志中是否有越权操作
# 运行: 每次心跳 / Stella审计时
#===============================================================================
set -euo pipefail

NOW=$(date '+%Y-%m-%d %H:%M:%S')
HITS=0

# 禁止模式（Shuyu不得执行的命令）
FORBIDDEN=(
  "ssh.*SuzanneMok"
  "netsh "
  "net stop"
  "net start"
  "docker push"
  "docker login"
  "systemctl.*restart"
  "iptables"
  "ufw "
  "tailscale serve"
  "tailscale up"
  "nginx -s"
)

echo "=== C-ROLE-BOUNDARY 扫描 ($NOW) ==="

# 扫描今天的journal日志
for pattern in "${FORBIDDEN[@]}"; do
  matches=$(journalctl --user --since "today" --no-pager 2>/dev/null | grep -i "$pattern" | grep "agent:shuyu" | head -3 || true)
  if [ -n "$matches" ]; then
    echo "🔴 越权检测: $pattern"
    echo "$matches"
    HITS=$((HITS + 1))
  fi
done

# 扫描最近的exec命令记录
if [ -f /tmp/shuyu-exec-audit.log ]; then
  for pattern in "${FORBIDDEN[@]}"; do
    matches=$(grep -i "$pattern" /tmp/shuyu-exec-audit.log 2>/dev/null | head -3 || true)
    if [ -n "$matches" ]; then
      echo "🔴 越权检测(audit): $pattern"
      echo "$matches"
      HITS=$((HITS + 1))
    fi
  done
fi

if [ "$HITS" -eq 0 ]; then
  echo "✅ C-ROLE-BOUNDARY 全绿·无越权操作"
  echo "CLEAN"
else
  echo "🔴 C-ROLE-BOUNDARY: ${HITS}项越权·需Stella审计"
  echo "VIOLATIONS=${HITS}"
fi
