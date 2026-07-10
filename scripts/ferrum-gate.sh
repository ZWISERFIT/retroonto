#!/bin/bash
#===============================================================================
# ferrum-gate.sh — Ferrum 约束执行网关
# 在 Agent 产出前扫描 constraints/ 目录 → 执行匹配检测
# 集成到 preflight-alert-check.sh 或作为独立 cron
#===============================================================================
# 用法:
#   ferrum-gate                              # 执行所有约束检测
#   ferrum-gate --check "发送"                # 根据关键词执行匹配约束
#   ferrum-gate --list                        # 列出所有约束
#===============================================================================

set -euo pipefail

RETROONTO_BASE="/home/agentuser/.openclaw/workspace/tristan/tech_lead/retroonto"
CONSTRAINTS_DIR="${RETROONTO_BASE}/constraints"
LOG_FILE="/var/log/zwf-ferrum-gate.log"
AGENT_BUS="/home/agentuser/shared/bus/agent-bus.sh"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"; echo "$*"; }
err() { log "🔴 ERROR: $*"; }

# 执行所有约束检测
run_all_checks() {
    local passed=0 failed=0 total=0

    for exec_script in "$CONSTRAINTS_DIR"/*-exec.sh; do
        [ -f "$exec_script" ] || continue
        # 跳过 writeback.sh 生成的 raw 脚本（非 C- 前缀的）
        basename "$exec_script" | grep -q "^C-" || continue

        total=$((total + 1))
        local constraint_name
        constraint_name=$(basename "$exec_script" .sh)

        if bash "$exec_script" 2>/dev/null; then
            log "  ✅ ${constraint_name}: 通过"
            passed=$((passed + 1))
        else
            log "  🔴 ${constraint_name}: 违反"
            failed=$((failed + 1))
        fi
    done

    log "📊 Ferrum: ${total} 约束 / ${passed} 通过 / ${failed} 违反"
    return $failed
}

# 列出所有约束
list_constraints() {
    echo "📋 Ferrum 约束清单"
    echo "=================="
    for rule_file in "$CONSTRAINTS_DIR"/*-rule.md; do
        [ -f "$rule_file" ] || continue
        basename "$rule_file" .md | grep -q "^C-" || continue
        local severity constraint
        severity=$(grep "严重程度" "$rule_file" | sed 's/.*|//' | tr -d ' ')
        constraint=$(grep "约束" "$rule_file" | head -1 | sed 's/.*|//' | tr -d ' ')
        echo "  $(basename "$rule_file" .md) [${severity}]: ${constraint}"
    done
}

main() {
    local mode="run"

    while [ $# -gt 0 ]; do
        case "$1" in
            --list) mode="list"; shift ;;
            --check) mode="check"; shift ;;
            --help) echo "用法: ferrum-gate [--list|--check]"; exit 0 ;;
            *) shift ;;
        esac
    done

    case "$mode" in
        run) run_all_checks ;;
        list) list_constraints ;;
        check)
            log "🟡 关键词过滤模式（待实现）"
            run_all_checks
            ;;
    esac
}

main "$@"
