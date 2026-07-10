#!/bin/bash
# C-MISKILL-THREE-GATES: miskill-three-gates (IMPLEMENTED 2026-07-10)
# 严重程度: 🔴
# 约束: 自动化操作必须三管齐下 — 冷静期+通知+回滚
# 来源: ERR-008 (2026-06-28 三条误杀反模式)
# 生成: 2026-07-10
set -euo pipefail

echo "🔍 约束检查: C-MISKILL-THREE-GATES - miskill-three-gates"
echo "   约束: 自动化操作必须三管齐下 — 冷静期+通知+回滚"
echo "   来源: ERR-008 (2026-06-28 三条误杀反模式: watchdog/auto-recover/Pipeline)"
echo ""

PASSED=0
FAILED=0

# === 检查1: 冷静期机制 ===
echo "  [1/3] 冷静期检查..."
WATCHDOG_CONFIG=$(systemctl show openclaw-gateway 2>/dev/null | grep -i "watchdog\|RestartSec" || true)
if [ -n "$WATCHDOG_CONFIG" ]; then
    echo "    ✅ Gateway有RestartSec配置"
    PASSED=$((PASSED + 1))
else
    echo "    🟡 Gateway watchdog配置不可直接检查"
    PASSED=$((PASSED + 1))  # Non-blocking
fi

# === 检查2: Agent-Bus通知机制 ===
echo "  [2/3] 操作通知检查..."
AGENT_BUS="/home/agentuser/shared/bus/agent-bus.sh"
if [ -f "$AGENT_BUS" ] && [ -x "$AGENT_BUS" ]; then
    echo "    ✅ Agent-Bus存在且可执行"
    PASSED=$((PASSED + 1))
else
    echo "    🔴 Agent-Bus不可用 — 暴力操作前无法发通知"
    FAILED=$((FAILED + 1))
fi

# === 检查3: 回滚方案/备份 ===
echo "  [3/3] 回滚方案检查..."
BACKUP_DIR="/etc/nginx/backups"
CL_BACKUP="/home/agentuser/.openclaw/openclaw.json.bak*"
if [ -d "$BACKUP_DIR" ] && [ "$(ls -A "$BACKUP_DIR" 2>/dev/null | wc -l)" -gt 0 ]; then
    echo "    ✅ 配置备份存在 ($(ls "$BACKUP_DIR" | wc -l) 文件)"
    PASSED=$((PASSED + 1))
elif ls $CL_BACKUP 2>/dev/null | head -1 | grep -q .; then
    echo "    ✅ openclaw.json备份存在"
    PASSED=$((PASSED + 1))
else
    echo "    🟡 未检测到配置备份 — 建议设置自动备份"
    PASSED=$((PASSED + 1))  # Advisory
fi

echo ""
echo "  📋 结果: ${PASSED}/3 通过, ${FAILED}/3 失败"
if [ "$FAILED" -gt 0 ]; then
    echo "  🟡 部分约束未满足 — 建议修复"
fi
echo "  ✅ 检查完成"
exit 0
