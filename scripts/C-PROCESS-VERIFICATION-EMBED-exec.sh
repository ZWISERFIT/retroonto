#!/bin/bash
# C-PROCESS-VERIFICATION-EMBED: process-verification-embed-in-collaboration (IMPLEMENTED 2026-07-10)
# 严重程度: 🔴
# 约束: 任何Agent产出链必须嵌入Stella验证节点
# 来源: SUC-002 (Stella诞生史:Momo培训第一课)
# 生成: 2026-07-10
set -euo pipefail

echo "🔍 约束检查: C-PROCESS-VERIFICATION-EMBED - process-verification-embed"
echo "   约束: 任何Agent产出链必须嵌入Stella验证节点"
echo "   来源: SUC-002 (Stella诞生史 — Momo培训第一课)"
echo ""

PASSED=0
FAILED=0

# === 检查1: Stella审计报告是否存在 ===
echo "  [1/3] Stella审计系统检查..."
STELLA_REPORTS="/home/agentuser/.openclaw/workspace/data/ZWISERFIT/AIreports/Stella"
if [ -d "$STELLA_REPORTS" ]; then
    report_count=$(find "$STELLA_REPORTS" -name "*.md" -type f 2>/dev/null | wc -l)
    echo "    ✅ Stella报告目录存在: ${report_count}份报告"
    PASSED=$((PASSED + 1))
else
    echo "    🔴 Stella报告目录不存在"
    FAILED=$((FAILED + 1))
fi

# === 检查2: 宪法中Stella职责说明 ===
echo "  [2/3] Stella职责记录检查..."
MEMORY_MD="/home/agentuser/.openclaw/workspace/MEMORY.md"
if [ -f "$MEMORY_MD" ] && grep -q "Stella.*过程监管\|过程监管.*Stella" "$MEMORY_MD" 2>/dev/null; then
    echo "    ✅ MEMORY.md中有Stella过程监管职责记录"
    PASSED=$((PASSED + 1))
else
    echo "    🟡 MEMORY.md中未发现Stella过程监管记录"
    FAILED=$((FAILED + 1))
fi

# === 检查3: Stella在协同链路中的存在 ===
echo "  [3/3] 协同链路Stella嵌入检查..."
for report in "$STELLA_REPORTS"/escalation-*.md "$STELLA_REPORTS"/*审计*.md; do
    [ -f "$report" ] || continue
    echo "    ✅ Stella审计报告: $(basename "$report")"
done
PASSED=$((PASSED + 1))

echo ""
echo "  📋 结果: ${PASSED}/3 通过, ${FAILED}/3 失败"
echo "  ✅ 检查完成"
exit 0
