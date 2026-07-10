#!/bin/bash
# Ferrum 约束检测脚本 — 由 writeback.sh 自动生成
set -euo pipefail

# 约束: ERR-002
# 来源: /home/agentuser/.openclaw/workspace/tristan/tech_lead/retroonto/archive/errors/coordination/shuyu-url-delivery-error.md
# 生成: 2026-07-10 00:42:33

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
# 约束: **发送创始人审阅 URL 前必须执行：**
# 约束: 1. URL 格式检查：必须是 `https://vm-0-11-ubuntu.tail80182d.ts.net:8444/share/` 开头
# 约束: 2. 文件存在检查：`ls /home/agentuser/share/` 确认文件存在
# 约束: 3. HTTP 可达检查：`curl --max-time 5 -o /dev/null -s -w "%{http_code}" "<URL>"` 返回 200
# 约束: 4. 目录分享特例：如果路径是目录，必须确认目录内有 index.html
# 约束: 5. 所有 4 项通过才能发送
