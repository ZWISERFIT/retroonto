#!/bin/bash
# Ferrum 约束检测脚本 — 由 writeback.sh 自动生成
set -euo pipefail

# 约束: ERR-009
# 来源: /home/agentuser/.openclaw/workspace/tristan/tech_lead/retroonto/archive/errors/infrastructure/ERR-009-portproxy-false-fix.md
# 生成: 2026-07-10 21:32:12

check_violation() {
    local rule_name="$1"
    local check_cmd="$2"
    local fix_cmd="${3:-}"

    echo "🟡 检查: $rule_name"
    if eval "$check_cmd" 2>/dev/null; then
        echo "  ✅ 通过"
        return 0
    else
        echo "  🔴 违反: $rule_name"
        if [ -n "$fix_cmd" ]; then
            echo "  🔧 自动修复: $fix_cmd"
            eval "$fix_cmd" 2>/dev/null || true
        fi
        return 1
    fi
}

# === 约束检查点 ===
# 约束: 1. **README-BACK验证（C004）：** 任何网络/防火墙/代理操作声明"已完成"前，自动执行 `show/check/list` read-back 验证
# 约束: 2. **脚本干跑测试：** 保护脚本必须通过实际输出测试，不能仅靠语法检查
# 约束: 3. **创始人反馈升级协议：** "问题还在"反馈→自动升级P0→Agent-Bus广播→不能仅靠Agent自履约
