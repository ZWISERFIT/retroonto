#!/bin/bash
# C-INFO-CHAIN-FOUR-CHECKS: info-chain-four-gate-checks (IMPLEMENTED 2026-07-10)
# 严重程度: 🟡
# 约束: 信息处理必须经过写盘/调度/检索/覆盖四链检查
# 来源: ERR-006 (2026-06-30 信息断链四模式)
# 生成: 2026-07-10
set -euo pipefail

echo "🔍 约束检查: C-INFO-CHAIN-FOUR-CHECKS - info-chain-four-gate-checks"
echo "   约束: 信息处理必须通过四链检查 — 写盘/调度/检索/覆盖"
echo "   来源: ERR-006 (2026-06-30 信息断链四模式)"
echo ""

PASSED=0
FAILED=0

# === 检查1: 写盘检查 ===
echo "  [1/4] 写盘检查 — 关键信息是否已写入磁盘..."
CREDENTIALS_DIR="/home/agentuser/.openclaw/workspace/data/ZWISERFIT/credentials"
if [ -d "$CREDENTIALS_DIR" ] && [ "$(ls -A "$CREDENTIALS_DIR" 2>/dev/null | wc -l)" -gt 0 ]; then
    echo "    ✅ 凭据目录已存在且非空 (文件数: $(ls "$CREDENTIALS_DIR" | wc -l))"
    PASSED=$((PASSED + 1))
else
    echo "    🔴 凭据目录为空或不存在"
    FAILED=$((FAILED + 1))
fi

# === 检查2: 调度检查 (cron任务) ===
echo "  [2/4] 调度检查 — 是否有cron机制保障执行..."
CRON_COUNT=$(openclaw cron list 2>/dev/null | grep -c "enabled" || echo 0)
if [ "$CRON_COUNT" -gt 0 ]; then
    echo "    ✅ Cron任务存在: ${CRON_COUNT}个活跃"
    PASSED=$((PASSED + 1))
else
    echo "    🟡 未检测到活跃Cron任务"
    FAILED=$((FAILED + 1))
fi

# === 检查3: 检索检查 ===
echo "  [3/4] 检索检查 — 关键信息是否结构化存储..."
MEMORY_MD="/home/agentuser/.openclaw/workspace/MEMORY.md"
if [ -f "$MEMORY_MD" ] && [ "$(wc -l < "$MEMORY_MD")" -gt 50 ]; then
    echo "    ✅ MEMORY.md存在且丰富 ($(wc -l < "$MEMORY_MD") 行)"
    PASSED=$((PASSED + 1))
else
    echo "    🟡 MEMORY.md不存在或过于精简"
    FAILED=$((FAILED + 1))
fi

# === 检查4: 覆盖检查 ===
echo "  [4/4] 覆盖检查 — 信息是否融入知识体系..."
PERMANENT_KNOWLEDGE="/home/agentuser/shared/permanent-knowledge"
if [ -d "$PERMANENT_KNOWLEDGE" ] && [ "$(ls -A "$PERMANENT_KNOWLEDGE" 2>/dev/null | wc -l)" -gt 0 ]; then
    echo "    ✅ 永久知识库存在且非空 (文件数: $(ls "$PERMANENT_KNOWLEDGE" | wc -l))"
    PASSED=$((PASSED + 1))
else
    echo "    🟡 永久知识库为空或不存在"
    FAILED=$((FAILED + 1))
fi

echo ""
echo "  📋 结果: ${PASSED}/4 通过, ${FAILED}/4 失败"
if [ "$FAILED" -gt 2 ]; then
    echo "  🔴 信息链断裂风险高 — 需手工修复"
    exit 1
fi
echo "  ✅ 信息链基本完整"
exit 0
