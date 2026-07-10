#!/bin/bash
# Ferrum 约束检测脚本 — 由 writeback.sh 自动生成
set -euo pipefail

# 约束: ERR-001
# 来源: /home/agentuser/.openclaw/workspace/tristan/tech_lead/retroonto/archive/errors/infrastructure/portproxy-zombie-rule.md
# 生成: 2026-07-10 00:42:34

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
# 约束: **铁律3：Windows 代理修复必须先删除 portproxy 冲突规则**
# 约束: - 任何通过 SSH 操作 Windows 代理/weproxy/web3jsq 时
# 约束: - 必须执行：删除 `:7890` 和 `:22000` 的 portproxy 规则
# 约束: - 必须执行：安全网——删除规则后验证代理是否响应；不响应则禁用系统代理
# 约束: - 必须执行：部署自动保护脚本每5分钟巡检
# 约束: 编写日期 2026-07-09 写入 MEMORY.md + SOUL.md
