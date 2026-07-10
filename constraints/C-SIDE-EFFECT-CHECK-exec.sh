#!/bin/bash
# C-SIDE-EFFECT-CHECK: 基础设施操作副作用预估约束 (IMPLEMENTED 2026-07-10)
# 严重程度: 🔴 P0
# 约束类型: Gate — 操作前检查
# 约束: 基础设施操作前必须列出完整影响面清单
# 来源: RetroOnto模式挖掘 · ERR-004/ERR-008/ERR-009
# 生成: 2026-07-10
set -euo pipefail

RETROONTO_BASE="/home/agentuser/.openclaw/workspace/tristan/tech_lead/retroonto"
AGENT_BUS="/home/agentuser/shared/bus/agent-bus.sh"
CHANGELOG_DIR="/home/agentuser/.openclaw/workspace/tristan/tech_lead/infra-change-log"
ALERT_LOG="${RETROONTO_BASE}/logs/c-side-effect-check.log"
mkdir -p "$(dirname "$ALERT_LOG")"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$ALERT_LOG" >&2; }

echo "🔍 约束检查: C-SIDE-EFFECT-CHECK - 基础设施操作副作用预估"
echo "   约束: 基础设施操作前必须列出完整影响面清单"
echo "   来源: ERR-004 gateway-restart-crash / ERR-008 three-miskill / ERR-009 portproxy"
echo ""

# === 触发操作列表 ===
TRIGGER_OPS=(
  "systemctl restart"
  "systemctl stop"
  "net stop"
  "net start"
  "iptables.*-[ADIL]"
  "netsh.*portproxy.*add"
  "netsh.*portproxy.*delete"
  "docker restart"
  "gateway restart"
  "gateway stop"
  "sudo.*reboot"
  "sudo.*shutdown"
)

# === 检查1: 扫描近期操作日志中的基础设施变更 ===
echo "  [1/4] 扫描近期操作日志中的基础设施变更..."
VIOLATION=0
HITS=""

for log_file in /home/agentuser/.openclaw/workspace/tristan/memory/2026-07-*.md; do
    [ -f "$log_file" ] || continue
    for op in "${TRIGGER_OPS[@]}"; do
        while IFS= read -r line; do
            [ -z "$line" ] && continue
            HITS="${HITS}${log_file}:${line}"$'\n'
            log "  🟡 检测到基础设施操作: $(basename "$log_file") — $line"
        done < <(grep -iE "$op" "$log_file" 2>/dev/null || true)
    done
done

if [ -z "$HITS" ]; then
    echo "    ✅ 无近期基础设施操作记录"
else
    echo "    ⚠️  发现基础设施操作记录（见上方）"
fi

# === 检查2: 操作前是否写了变更日志 ===
echo "  [2/4] 检查操作前是否已写 infra-change-log..."
CHANGE_LOG_MISSING=0
if [ -n "$HITS" ]; then
    if [ -d "$CHANGELOG_DIR" ]; then
        echo "    ✅ infra-change-log 目录存在: $CHANGELOG_DIR"
        local_logs=$(ls "$CHANGELOG_DIR"/*.md 2>/dev/null | wc -l)
        echo "    已有 ${local_logs} 个变更日志文件"
        # 检查最近是否有变更日志（24h内）
        recent=$(find "$CHANGELOG_DIR" -name "*.md" -mtime -1 2>/dev/null | wc -l)
        if [ "$recent" -gt 0 ]; then
            echo "    ✅ 24h内有 ${recent} 个变更日志（操作可能已记录影响面）"
        else
            echo "    🟡 24h内无变更日志 — 操作可能未评估副作用"
            CHANGE_LOG_MISSING=1
        fi
    else
        echo "    🟡 infra-change-log 目录不存在"
        CHANGE_LOG_MISSING=1
    fi
else
    echo "    ⏭️  无操作记录，跳过"
fi

# === 检查3: 验证影响面清单完整性 ===
echo "  [3/4] 验证影响面清单完整性..."
IMPACT_ASSESSED=1
if [ "$CHANGE_LOG_MISSING" -eq 1 ]; then
    IMPACT_ASSESSED=0
    echo "    🔴 影响面清单未生成 — 缺少变更日志"
    VIOLATION=1
elif [ -n "$HITS" ]; then
    # 检查最近的变更日志是否包含五要素
    latest_log=$(find "$CHANGELOG_DIR" -name "*.md" -mtime -1 2>/dev/null | sort -r | head -1)
    if [ -n "$latest_log" ]; then
        MISSING_ELEMENTS=""
        grep -qi "下游依赖\|downstream\|依赖" "$latest_log" 2>/dev/null || MISSING_ELEMENTS="${MISSING_ELEMENTS} 下游依赖"
        grep -qi "影响\|受影响" "$latest_log" 2>/dev/null || MISSING_ELEMENTS="${MISSING_ELEMENTS} 影响范围"
        grep -qi "恢复\|回滚\|rollback" "$latest_log" 2>/dev/null || MISSING_ELEMENTS="${MISSING_ELEMENTS} 恢复/回滚方案"
        grep -qi "验证\|verify\|check" "$latest_log" 2>/dev/null || MISSING_ELEMENTS="${MISSING_ELEMENTS} 验证方法"

        if [ -n "$MISSING_ELEMENTS" ]; then
            echo "    🟡 影响面清单不完整: 缺少${MISSING_ELEMENTS}"
            IMPACT_ASSESSED=0
        else
            echo "    ✅ 影响面清单完整"
        fi
    fi
else
    echo "    ✅ 无需检查（无操作记录）"
fi

# === 检查4: 是否有三级副作用（级联效应） ===
echo "  [4/4] 级联效应检查..."
CASCADE_RISK=0
if [ -n "$HITS" ]; then
    # 检查操作是否涉及共享基础设施
    if echo "$HITS" | grep -qiE "gateway|tailscale|syncthing|docker"; then
        echo "    🟡 操作涉及共享基础设施组件 — 有级联风险"
        CASCADE_RISK=1
    fi
    # 检查是否有正在运行的关键进程
    for critical_pid in $(pgrep -x "openclaw\|syncthing\|tailscaled" 2>/dev/null); do
        echo "    🟡 关键进程运行中 — 重启会导致服务中断"
        CASCADE_RISK=1
    done
fi

if [ "$CASCADE_RISK" -eq 0 ]; then
    echo "    ✅ 无极联效应风险"
fi

echo ""
echo "  📋 结果:"
echo "  ┌──────────────────────────────────────┐"
if [ "$VIOLATION" -gt 0 ]; then
    echo "  │      🔴 约束违反检测到!               │"
    echo "  │      基础设施操作前未做副作用评估       │"
    echo "  └──────────────────────────────────────┘"
    echo ""
    echo "  🔧 建议修复: 操作前写入 infra-change-log，回答五要素："
    echo "     1. 有哪些下游依赖？"
    echo "     2. 重启期间谁受影响？"
    echo "     3. 恢复时间预估？"
    echo "     4. 验证方法？"
    echo "     5. 回滚方案？"

    # Agent-Bus告警
    if [ -x "$AGENT_BUS" ]; then
        bash "$AGENT_BUS" publish "alarm" "Tristan" "🔴" \
            "C-SIDE-EFFECT-CHECK:操作前未评估副作用" \
            "影响面清单缺失: change_log=${CHANGE_LOG_MISSING} impact_assessed=${IMPACT_ASSESSED} cascade=${CASCADE_RISK}" \
            "Shuyu" 2>/dev/null || true
    fi

    exit 1
fi

echo "  │      ✅ 约束检查通过                   │"
echo "  └──────────────────────────────────────┘"
exit 0
