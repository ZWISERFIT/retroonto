#!/bin/bash
# C-DDL-DISPATCH-BAN: ddl-dispatch-same-action (IMPLEMENTED 2026-07-10)
# 严重程度: 🔴
# 约束: 收到DDL指令后，归档+分派必须在同一动作完成
# 来源: ERR-007 (2026-06-20/23 DDL执行断链两次)
# 生成: 2026-07-10
set -euo pipefail

echo "🔍 约束检查: C-DDL-DISPATCH-BAN - ddl-dispatch-same-action"
echo "   约束: DDL指令必须归档+分派同一动作完成,禁止分两段"
echo "   来源: ERR-007 (2026-06-20/23 DDL执行断链两轮)"
echo ""

HITS=0

# === 检查1: 扫描今日是否有未闭环的DDL ===
echo "  [1/2] DDL闭环扫描..."
TODAY=$(date '+%Y-%m-%d')
MESSAGES_1_1="/home/agentuser/.openclaw/workspace/memory/founder-transcripts/${TODAY}.md"
DDL_PATTERNS=(
  "DDL"
  "deadline"
  "截止"
  "前完成"
  "内完成"
  "必须.*前"
)

if [ -f "$MESSAGES_1_1" ]; then
    for pattern in "${DDL_PATTERNS[@]}"; do
        matches=$(grep -inE "$pattern" "$MESSAGES_1_1" 2>/dev/null || true)
        if [ -n "$matches" ]; then
            echo "    ⚠️  发现DDL关键词 '$pattern':"
            echo "$matches" | head -3 | sed 's/^/      /'
            HITS=$((HITS + 1))
        fi
    done
else
    echo "    🟢 今日无创始人消息文件"
fi

# === 检查2: DDL前2h预警cron是否存在 ===
echo "  [2/2] DDL预警cron检查..."
CRON_LIST=$(openclaw cron list 2>/dev/null || true)
if echo "$CRON_LIST" | grep -qi "ddl\|deadline\|预警"; then
    echo "    ✅ DDL预警cron存在"
else
    echo "    🟡 未检测到DDL预警cron — 如今日有DDL，可能需要手动设置"
fi

echo ""
if [ "$HITS" -gt 0 ]; then
    echo "  🟡 发现 ${HITS} 个DDL关键词 — 请确认是否已分派+归档"
    echo "  铁律: 归档+分派 = 同一动作，禁止分两段"
fi
echo "  📋 约束检查完成"
exit 0
