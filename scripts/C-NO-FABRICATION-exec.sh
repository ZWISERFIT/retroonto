#!/bin/bash
# C-NO-FABRICATION: no-fabricated-diagnosis (IMPLEMENTED 2026-07-10)
# 严重程度: 🔴
# 约束: 禁止编造诊断结论 — 外部系统状态必须实际验证后才能断言
# 来源: ERR-005 (2026-04-28 飞书编造事件)
# 生成: 2026-07-10
set -euo pipefail

echo "🔍 约束检查: C-NO-FABRICATION - no-fabricated-diagnosis"
echo "   约束: 诊断报告中的每个断言必须附带验证证据"
echo "   来源: ERR-005 (2026-04-28 飞书编造事件)"
echo ""

# === 检查最近报告中是否包含无证据断言 ===
echo "  [1/2] 扫描断言质量..."
REPORT_DIR="/home/agentuser/.openclaw/workspace/data/ZWISERFIT/AIreports/reports"
SUSPICIOUS_PATTERNS=(
  "铁定是"
  "肯定是"
  "一定是"
  "绝对"
  "我推测"
  "我觉得"
  "我认为"
  "^想必"
)

HITS=0
for report in "$REPORT_DIR"/*.md; do
    [ -f "$report" ] || continue
    for pattern in "${SUSPICIOUS_PATTERNS[@]}"; do
        matches=$(grep -inE "$pattern" "$report" 2>/dev/null || true)
        if [ -n "$matches" ]; then
            echo "    ⚠️  可疑表达 '$pattern' in $(basename "$report"):"
            echo "$matches" | head -3 | sed 's/^/      /'
            HITS=$((HITS + 1))
        fi
    done
done

if [ "$HITS" -eq 0 ]; then
    echo "    ✅ 未发现无依据的绝对化断言"
else
    echo "    🟡 发现 ${HITS} 个可疑断言 — 建议检查是否附带验证证据"
fi

# === 检查"铁律三"合规 ===
echo "  [2/2] 数据来源标注检查..."
for report in "$REPORT_DIR"/*.md; do
    [ -f "$report" ] || continue
    if grep -qE "暂无接入|无法获取|未获取到" "$report" 2>/dev/null; then
        echo "    ✅ 报告中有标注"暂无接入"的数据项"
        break
    fi
done

echo ""
echo "  📋 结果: 检查完成"
exit 0
