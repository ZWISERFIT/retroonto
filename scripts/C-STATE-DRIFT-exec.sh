#!/bin/bash
#===============================================================================
# C-STATE-DRIFT-exec.sh — 地面真相验证脚本
# 扫描 Agent 报告中是否包含禁止的计数器模式
# 运行: 每次心跳第一条 / 战报编译前 / 任何对外报告前
#===============================================================================
set -euo pipefail

REPORTS_DIR="/home/agentuser/.openclaw/workspace/data/ZWISERFIT/AIreports/reports"
PROGRESS_FILE="/home/agentuser/.openclaw/workspace/daily_progress.json"
HITS=0
NOW=$(date '+%Y-%m-%d %H:%M:%S')

# === 检查1: 禁止 D+N 计数器格式 ===
echo "=== C-STATE-DRIFT 扫描 ($NOW) ==="

# 扫描战报中的禁止模式
PATTERNS=(
  "D[0-9]+过期"
  "D[0-9]+.*授权"
  "D[0-9]+.*断联"
  "[0-9]+h.*活跃"
  "[0-9]+h前.*产出"
  "D[0-9]+.*空窗"
  "D[0-9]+.*瘫痪"
  "[0-9]+天.*未"
)

for pattern in "${PATTERNS[@]}"; do
  matches=$(grep -rn "$pattern" "$REPORTS_DIR"/*.md 2>/dev/null | grep -v "C-STATE-DRIFT" | grep -v "# " || true)
  if [ -n "$matches" ]; then
    echo "🔴 命中: $pattern"
    echo "$matches" | head -5
    HITS=$((HITS + 1))
  fi
done

# === 检查2: 关键外部系统状态是否带实测标记 ===
# MCP状态检查
if grep -q "MCP" "$REPORTS_DIR"/2026-07-10-每日战报.md 2>/dev/null; then
  if ! grep -q "实测\|errcode\|验证" <(grep "MCP" "$REPORTS_DIR"/2026-07-10-每日战报.md 2>/dev/null); then
    echo "🟡 警告: MCP状态未附带实测标记"
    HITS=$((HITS + 1))
  fi
fi

# === 结果 ===
if [ "$HITS" -eq 0 ]; then
  echo "✅ C-STATE-DRIFT 全绿·无禁止模式"
  echo "CLEAN"
else
  echo "🔴 C-STATE-DRIFT: ${HITS}项命中·需纠正"
  echo "HITS=${HITS}"
fi
