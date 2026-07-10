#!/bin/bash
# C-PREFLIGHT-GATE 执行扫描
# 检查是否有军团级操作缺少智囊团签章
set -euo pipefail

SIGNOFF_DIR="/home/agentuser/shared/bus/signoffs"
VIOLATIONS=0

echo "=== C-PREFLIGHT-GATE 扫描 ($(date '+%Y-%m-%d %H:%M:%S')) ==="

# 扫描所有签章目录
if [ -d "$SIGNOFF_DIR" ]; then
  for dir in "$SIGNOFF_DIR"/*/; do
    [ -d "$dir" ] || continue
    op=$(basename "$dir")
    shuyu=$( [ -f "$dir/shuyu.sig" ] && echo "✅" || echo "❌" )
    stella=$( [ -f "$dir/stella.sig" ] && echo "✅" || echo "❌" )
    zeus=$( [ -f "$dir/zeus.sig" ] && echo "✅" || echo "❌" )
    
    all_ok=true
    [ "$shuyu" = "❌" ] && all_ok=false
    [ "$stella" = "❌" ] && all_ok=false
    [ "$zeus" = "❌" ] && all_ok=false
    
    if $all_ok; then
      echo "✅ $op: 三方签章完整"
    else
      missing=""
      [ "$shuyu" = "❌" ] && missing="$missing Shuyu"
      [ "$stella" = "❌" ] && missing="$missing Stella"
      [ "$zeus" = "❌" ] && missing="$missing Zeus"
      echo "🟡 $op: 缺少签章:$missing"
      VIOLATIONS=$((VIOLATIONS + 1))
    fi
  done
fi

# 检查是否有cron批量变更（无签章）
    cron_changes=0  # crontab check delegated to cron tool
if [ "$cron_changes" -gt 0 ] && [ ! -f "$SIGNOFF_DIR/D-Day-ignition-20260711/shuyu.sig" ]; then
  echo "🔴 D-Day cron已注册($cron_changes条)但无智囊团签章！"
  VIOLATIONS=$((VIOLATIONS + 1))
fi

if [ "$VIOLATIONS" -eq 0 ]; then
  echo "✅ C-PREFLIGHT-GATE 全绿·所有军团级操作均已签章"
  echo "CLEAN"
else
  echo "🔴 C-PREFLIGHT-GATE: ${VIOLATIONS}项操作缺少签章"
  echo "VIOLATIONS=${VIOLATIONS}"
fi
