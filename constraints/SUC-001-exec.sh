#!/bin/bash
# Ferrum 约束检测脚本 — 由 writeback.sh 自动生成
set -euo pipefail

# 约束: SUC-001
# 来源: /home/agentuser/.openclaw/workspace/tristan/tech_lead/retroonto/archive/successes/infrastructure/syncthing-self-heal-chain.md
# 生成: 2026-07-10 21:32:11

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
# 约束: **Syncthing自愈模式重用约束：**
# 约束: 1. 任何systemd服务出现周期性崩溃时，执行分级诊断：L1-锁和KillSignal → L2-端口争用和双重服务 → L3-根本root cause
# 约束: 2. 不要满足于表面修复——加KillSignal=SIGKILL不是修复，是掩盖
# 约束: 3. 每次修复必须：文档同步至MEMORY.md + 全军根因模式库 + 关联条目
# 约束: 4. 重复模式且修复后仍有复发 → 升级根因探索非表面修复
