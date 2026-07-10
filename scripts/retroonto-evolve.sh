#!/bin/bash
#===============================================================================
# retroonto-evolve.sh — RetroOnto 自动进化守护进程
#===============================================================================
# 职责: 在 cron 上自动运行，检测新 Archive 条目 → 生成约束 → 写回知识环
# 部署: 由 cron 每 2h 触发，或由 Agent 在修复错误后显式调用
# 自省: 记录自身运行状态，避免重复处理
#===============================================================================
set -euo pipefail

RETROONTO_BASE="/home/agentuser/.openclaw/workspace/tristan/tech_lead/retroonto"
SCRIPTS_DIR="${RETROONTO_BASE}/scripts"
ARCHIVE_BASE="${RETROONTO_BASE}/archive"
STATE_FILE="${RETROONTO_BASE}/.evolve-state.json"
LOG_DIR="${RETROONTO_BASE}/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/retroonto-evolve.log"
LOCK_FILE="/tmp/retroonto-evolve.lock"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"; echo "$*" >&2; }
err() { log "🔴 ERROR: $*"; }

# === 防止并发 ===
if [ -f "$LOCK_FILE" ]; then
    lock_age=$(( $(date +%s) - $(stat -c %Y "$LOCK_FILE" 2>/dev/null || echo 0) ))
    if [ "$lock_age" -lt 300 ]; then
        log "🟡 已有实例运行中 (${lock_age}s ago)，跳过"
        exit 0
    fi
    log "🟡 锁过期 (${lock_age}s)，覆盖"
fi
touch "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

# === 初始化状态文件 ===
init_state() {
    if [ ! -f "$STATE_FILE" ]; then
        cat > "$STATE_FILE" <<'JSON'
{
  "last_scan_ts": null,
  "last_constraint_gen_ts": null,
  "last_writeback_ts": null,
  "processed_archives": [],
  "total_traces_created": 0,
  "total_constraints_generated": 0,
  "total_writebacks_done": 0,
  "evolve_cycle": 0,
  "status": "initialized"
}
JSON
        log "✅ 状态文件初始化"
    fi
}

# === 读取状态 ===
get_state() {
    local key="$1"
    if command -v jq &>/dev/null && [ -f "$STATE_FILE" ]; then
        jq -r ".${key} // \"\"" "$STATE_FILE" 2>/dev/null || echo ""
    else
        echo ""
    fi
}

# === 更新状态 ===
set_state() {
    local key="$1"
    local value="$2"
    if command -v jq &>/dev/null && [ -f "$STATE_FILE" ]; then
        local tmp
        tmp=$(mktemp)
        # 判断 value 是数字还是 JSON 对象/数组
        if echo "$value" | jq -e . >/dev/null 2>&1; then
            # 有效的 JSON（数组或对象），直接嵌入
            jq ".${key} = ${value}" "$STATE_FILE" > "$tmp"
        elif echo "$value" | grep -qE '^[0-9]+$'; then
            jq ".${key} = ${value}" "$STATE_FILE" > "$tmp"
        else
            jq ".${key} = \"${value}\"" "$STATE_FILE" > "$tmp"
        fi
        mv "$tmp" "$STATE_FILE"
    fi
}

# === 阶段1: 检测新 Archive 条目 ===
detect_new_archives() {
    local last_scan
    last_scan=$(get_state "last_scan_ts")
    local new_count=0
    local new_ids=()

    log "🔍 扫描新 Archive 条目..."

    # 获取已处理列表
    local processed_json
    processed_json=$(jq -r '.processed_archives[]' "$STATE_FILE" 2>/dev/null || echo "")

    while IFS= read -r file; do
        [ -f "$file" ] || continue
        grep -q "^---" "$file" 2>/dev/null || continue

        local id
        id=$(grep "^id: " "$file" 2>/dev/null | sed 's/^id: //' | tr -d ' ')
        [ -z "$id" ] && continue

        # 检查是否已处理
        if echo "$processed_json" | grep -qF "\"$id\""; then
            continue
        fi

        # 检查是否在 last_scan 之后创建
        if [ -n "$last_scan" ] && [ "$last_scan" != "null" ] && [ "$last_scan" != "" ]; then
            local file_mtime
            file_mtime=$(stat -c %Y "$file" 2>/dev/null || echo 0)
            if [ "$file_mtime" -le "$last_scan" ] 2>/dev/null; then
                continue
            fi
        fi

        new_ids+=("$id")
        new_count=$((new_count + 1))
        log "  🆕 新条目: $id — $(basename "$file")"
    done < <(find "$ARCHIVE_BASE" -name "*.md" -type f)

    set_state "last_scan_ts" "$(date +%s)"

    if [ "$new_count" -eq 0 ]; then
        log "  ✅ 无新条目"
        echo "0"
        return 0
    fi

    # 合并已处理列表
    local ids_json
    ids_json=$(printf '%s\n' "${new_ids[@]}" | jq -R -s 'split("\n") | map(select(length > 0))')
    
    # 与已有列表合并
    local merged
    merged=$(jq -n --argjson existing "$(jq '.processed_archives' "$STATE_FILE" 2>/dev/null || echo '[]')" --argjson new "$ids_json" '$existing + $new | unique')
    set_state "processed_archives" "$merged"
    set_state "total_traces_created" "$(($(get_state "total_traces_created" || echo 0) + new_count))"

    echo "$new_count"
}

# === 阶段2: 自动生成约束 ===
auto_constraint_gen() {
    local new_count="$1"
    if [ "$new_count" -eq 0 ]; then
        log "⏭️  跳过约束生成（无新条目）"
        echo "0"
        return 0
    fi

    log "📐 自动约束生成 (处理最近 ${new_count} 个新条目)..."
    local result
    # constraint-gen.sh 的 log 也输出到 stdout，取最后一行 JSON
    result=$(bash "${SCRIPTS_DIR}/constraint-gen.sh" --since 1 2>/dev/null | tail -1)

    local generated
    generated=$(echo "$result" | jq -r '.generated // 0' 2>/dev/null || echo "0")
    generated=$((generated + 0))

    set_state "last_constraint_gen_ts" "$(date +%s)"
    set_state "total_constraints_generated" "$(($(get_state "total_constraints_generated") + generated))"

    log "  ✅ 生成 ${generated} 个新约束"
    echo "$generated"
}

# === 阶段3: 自动写回知识环 ===
auto_writeback() {
    local generated="$1"
    if [ "$generated" -eq 0 ]; then
        log "⏭️  跳过写回（无新约束）"
        echo "0"
        return 0
    fi

    log "💾 自动写回知识环..."
    local result
    result=$(bash "${SCRIPTS_DIR}/writeback.sh" 2>&1 | grep "写回完成" | grep -oP '\d+(?= 成功)') || true
    local written="${result:-0}"

    set_state "last_writeback_ts" "$(date +%s)"
    set_state "total_writebacks_done" "$(($(get_state "total_writebacks_done") + written))"

    log "  ✅ 写回完成: ${written} 条目"
    echo "$written"
}

# === 阶段4: Ferrum 门禁自检 ===
gate_self_check() {
    log "🛡️  Ferrum 门禁自检..."
    local result
    result=$(bash "${SCRIPTS_DIR}/ferrum-gate.sh" 2>&1 | tail -1)
    log "  ${result}"
}

# === 进化循环报告 ===
evolve_report() {
    local new_archives="$1"
    local new_constraints="$2"
    local new_writebacks="$3"

    local cycle
    cycle=$(get_state "evolve_cycle")
    local total_traces total_constraints total_writebacks
    total_traces=$(get_state "total_traces_created")
    total_constraints=$(get_state "total_constraints_generated")
    total_writebacks=$(get_state "total_writebacks_done")

    log ""
    log "═══════════════════════════════════════════════"
    log "  ♻️  RetroOnto 自动进化 · #${cycle}"
    log "───────────────────────────────────────────────"
    log "  新 trace:     ${new_archives}"
    log "  新 constraint: ${new_constraints}"
    log "  新 writeback:  ${new_writebacks}"
    log "───────────────────────────────────────────────"
    log "  累计 trace:      ${total_traces}"
    log "  累计 constraint:  ${total_constraints}"
    log "  累计 writeback:   ${total_writebacks}"
    log "═══════════════════════════════════════════════"
}

# === 主循环 ===
main() {
    local mode="auto"

    while [ $# -gt 0 ]; do
        case "$1" in
            --force|--immediate) mode="force"; shift ;;
            --report) mode="report"; shift ;;
            --help|-h)
                echo "用法: retroonto-evolve [选项]"
                echo "  (无参数)  自动检测 → 约束生成 → 写回"
                echo "  --force   强制处理所有未处理条目"
                echo "  --report  仅输出当前状态"
                exit 0
                ;;
            *) shift ;;
        esac
    done

    init_state

    if [ "$mode" = "report" ]; then
        log "📊 RetroOnto 进化状态"
        log "  总 traces:     $(get_state 'total_traces_created')"
        log "  总 constraints: $(get_state 'total_constraints_generated')"
        log "  总 writebacks:  $(get_state 'total_writebacks_done')"
        log "  进化周期:       $(get_state 'evolve_cycle')"
        log "  状态:           $(get_state 'status')"
        exit 0
    fi

    log "♻️  RetroOnto 自动进化 · 启动"

    local new_archives=0
    local new_constraints=0
    local new_writebacks=0

    # 阶段1: 检测
    new_archives=$(detect_new_archives || echo "0")

    # 阶段2: 约束生成
    new_constraints=$(auto_constraint_gen "$new_archives" || echo "0")

    # 阶段3: 写回
    if [ "$new_constraints" -gt 0 ]; then
        new_writebacks=$(auto_writeback "$new_constraints" || echo "0")
    fi

    # 阶段4: Gate自检
    if [ "$new_constraints" -gt 0 ]; then
        gate_self_check
    fi

    # 更新周期计数
    local current_cycle
    current_cycle=$(get_state "evolve_cycle")
    set_state "evolve_cycle" "$((current_cycle + 1))"
    set_state "status" "evolving"

    if [ "$new_constraints" -gt 0 ] || [ "$new_writebacks" -gt 0 ]; then
        set_state "status" "active_growth"
    fi

    evolve_report "$new_archives" "$new_constraints" "$new_writebacks"

    # 返回码: 有实质性进化 → 0; 无变化 → 0 (都是正常)
    log "✅ 进化循环完成"
}

main "$@"
