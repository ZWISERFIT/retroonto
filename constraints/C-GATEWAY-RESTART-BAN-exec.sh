#!/bin/bash
# C-GATEWAY-RESTART-BAN: gateway-restart-fatal-ban (IMPLEMENTED 2026-07-10)
# 严重程度: 🔴
# 约束: 任何场景下禁止执行 gateway restart/stop 命令
# 来源: ERR-004 (2026-04-24 网关宕机)
# 生成: 2026-07-10
set -euo pipefail

echo "🔍 约束检查: C-GATEWAY-RESTART-BAN - gateway-restart-fatal-ban"
echo "   约束: 任何场景下禁止自行执行 gateway restart/stop 命令"
echo "   来源: ERR-004 (2026-04-24 网关宕机事件)"
echo ""

# === 检查1: 近期指令中是否包含违规重启命令 ===
echo "  [1/3] 扫描近期操作日志..."
VIOLATION=0
LOG_DIR="/home/agentuser/.openclaw/workspace/tristan"
BANNED_PATTERNS=(
  "gateway restart"
  "gateway stop"
  "openclaw gateway restart"
  "openclaw gateway stop"
)

for log_file in "$LOG_DIR"/memory/2026-07-*.md; do
    [ -f "$log_file" ] || continue
    for pattern in "${BANNED_PATTERNS[@]}"; do
        if grep -qiE "$pattern" "$log_file" 2>/dev/null; then
            echo "    🔴 违规: 检测到禁止命令 '$pattern' in $(basename "$log_file")"
            VIOLATION=1
        fi
    done
done

if [ "$VIOLATION" -eq 0 ]; then
    echo "    ✅ 无违规重启命令"
fi

# === 检查2: 涉及基础设施变更的操作是否先写了changelog ===
echo "  [2/3] 检查变更日志..."
CHANGELOG_DIR="/home/agentuser/shared/changelog"
if [ -d "$CHANGELOG_DIR" ]; then
    today_log="${CHANGELOG_DIR}/$(date '+%Y-%m-%d').md"
    echo "    CHANGELOG 目录存在: $CHANGELOG_DIR"
    if [ -f "$today_log" ]; then
        echo "    ✅ 今日变更日志存在"
    else
        echo "    🟡 今日变更日志未创建"
    fi
else
    echo "    🟡 CHANGELOG 目录不存在"
fi

# === 检查3: 是否有备份 ===
echo "  [3/3] 检查配置备份..."
BACKUP_DIR="/etc/nginx/backups"
if [ -d "$BACKUP_DIR" ]; then
    echo "    ✅ 备份目录存在: $BACKUP_DIR"
    backup_count=$(find "$BACKUP_DIR" -name "*.bak*" -type f 2>/dev/null | wc -l)
    echo "    备份数: ${backup_count}"
else
    echo "    🟡 备份目录不存在"
fi

echo ""
echo "  📋 结果: 约束检查完成"
if [ "$VIOLATION" -gt 0 ]; then
    echo "  🔴 发现违规 — Gateway重启禁令被违反!"
    exit 1
fi
echo "  ✅ 通过"
exit 0
