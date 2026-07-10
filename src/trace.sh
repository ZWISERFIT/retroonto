#!/bin/bash
#===============================================================================
# trace.sh — RetroOnto 记录员脚本（P0）
# 捕获 Agent 失败/经验 → 结构化 Archive 条目
#===============================================================================
# 安装: ln -sf /home/agentuser/.openclaw/workspace/tristan/tech_lead/retroonto/scripts/trace.sh /usr/local/bin/retroonto-trace
# 用法:
#   retroonto-trace --error        "简短描述" --detail "详情文件或字符串" [--agent "Tristan"] [--category "infrastructure"]
#   retroonto-trace --success      "简短描述" --detail "详情" [--agent "Tristan"] [--category "infrastructure"]
#   retroonto-trace --from-stdin              # 从管道读取结构化输入
#   retroonto-trace --scan-agent-bus          # 从 Agent-Bus 事件捕获
#===============================================================================

set -euo pipefail

# === 配置 ===
ARCHIVE_BASE="/home/agentuser/.openclaw/workspace/tristan/tech_lead/retroonto/archive"
RETROONTO_DB="${RETROONTO_DB:-/home/agentuser/.openclaw/workspace/tristan/tech_lead/retroonto/retroonto.db}"
AGENT_BUS="/home/agentuser/shared/bus/agent-bus.sh"
NEXT_ID_FILE="${ARCHIVE_BASE}/.next-id"
MAX_RETRIES=3
LOG_FILE="/var/log/zwf-retroonto-trace.log"

# === Logging ===
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"; echo "$*"; }
err() { log "🔴 ERROR: $*"; }

# === 初始化 ===
init_archive_db() {
    mkdir -p "$ARCHIVE_BASE"/{errors/{infrastructure,coordination,cognitive},successes/{infrastructure,coordination,cognitive},patterns,curated,constraints}
    if [ ! -f "$NEXT_ID_FILE" ]; then
        echo "1" > "$NEXT_ID_FILE"
    fi
    # 初始化 RetroOnto SQLite 数据库（如果不存在）
    if [ ! -f "$RETROONTO_DB" ]; then
        local schema="/home/agentuser/.openclaw/workspace/tristan/reports/retroonto-repo/src/schema.sql"
        if [ -f "$schema" ]; then
            sqlite3 "$RETROONTO_DB" < "$schema" 2>/dev/null || {
                log "🟡 SQLite schema 加载失败，跳过（纯文件模式）"
            }
        fi
    fi
}

# === ID 生成 ===
next_id() {
    local prefix="${1:-ERR}"
    local num
    num=$(cat "$NEXT_ID_FILE" 2>/dev/null || echo 1)
    printf "%s-%03d" "$prefix" "$num"
    echo $((num + 1)) > "$NEXT_ID_FILE"
}

# === 写入 Archive 条目 ===
write_archive_entry() {
    local type="$1"          # error | success
    local title="$2"
    local category="$3"      # infrastructure | coordination | cognitive
    local severity="$4"      # 🔴 | 🟡 | 🟢
    local detected_by="$5"
    local agent="$6"
    local detail="$7"        # 可选的详细内容文件路径或文本

    local id_prefix
    [ "$type" = "error" ] && id_prefix="ERR" || id_prefix="SUC"
    local id
    id=$(next_id "$id_prefix")

    local plural; [ "$type" = "success" ] && plural="successes" || plural="errors"
    local target_dir="${ARCHIVE_BASE}/${plural}/${category}"
    local filename="${id}-$(echo "$title" | tr '[:upper:]' '[:lower:]' | tr ' /' '--' | sed 's/[^a-z0-9-]//g' | head -c 60).md"
    local filepath="${target_dir}/${filename}"

    # 生成 frontmatter
    cat > "$filepath" <<FRONTMATTER
---
id: ${id}
type: ${type}
category: ${category}
severity: ${severity}
status: active
created: $(date '+%Y-%m-%d')
source_agent: ${agent}
source_session: ${OPENCLAW_SESSION_ID:-unknown}
detected_by: ${detected_by}
verified_by:
tags: []
---

## 标题
${title}

## 现象
$(echo "$detail" | head -1)

## 记录
_ID: ${id}_ | _创建: $(date '+%Y-%m-%d %H:%M:%S')_ | _Agent: ${agent}_ | _检测: ${detected_by}_

FRONTMATTER

    # 写入详细内容
    if [ -f "$detail" ]; then
        cat "$detail" >> "$filepath"
    elif [ -n "$detail" ] && [ "$detail" != "$(echo "$detail" | head -1)" ]; then
        echo "" >> "$filepath"
        echo "$detail" >> "$filepath"
    fi

    echo "$filepath"
}

# === 写入 RetroOnto DB（最佳努力模式） ===
write_to_db() {
    local id="$1"
    local title="$2"
    local agent="$3"
    local error_type="$4"

    # 如果 DB 不存在/不可写，静默跳过
    if [ ! -f "$RETROONTO_DB" ] || [ ! -w "$(dirname "$RETROONTO_DB")" ]; then
        return 0
    fi

    # SQL 简单写入（纯 ASCII 安全）
    local safe_title=$(echo "$title" | sed 's/[^a-zA-Z0-9_-]/_/g')
    local safe_agent=$(echo "$agent" | sed 's/[^a-zA-Z0-9_-]/_/g')
    local safe_type=$(echo "$error_type" | sed 's/[^a-zA-Z0-9_-]/_/g')
    echo "INSERT INTO decision_traces(event_name,agent,error_type) VALUES('${safe_title}','${safe_agent}','${safe_type}');" | sqlite3 "$RETROONTO_DB" 2>/dev/null || true
    log "✅ DB 记录已写入: ${id} / ${title}"
}

# === 广播事件 ===
broadcast() {
    local id="$1"
    local title="$2"
    local status="$3"

    if [ -x "$AGENT_BUS" ]; then
        bash "$AGENT_BUS" publish "progress" "Tristan" "$status" \
            "Archive:${id}" \
            "RetroOnto 记录: ${title}" \
            "all" 2>/dev/null || true
    fi
}

# === 从 Agent-Bus 事件扫描捕获 ===
scan_agent_bus() {
    local events_dir="/home/agentuser/.openclaw/workspace/data/ZWISERFIT/.event"
    local count=0

    for event_file in "$events_dir"/alarm-*.json "$events_dir"/*-alarm-*.json; do
        [ -f "$event_file" ] || continue
        # 只处理 24h 内新事件
        local file_time
        file_time=$(stat -c %Y "$event_file" 2>/dev/null || echo 0)
        local now
        now=$(date +%s)
        local age=$(( (now - file_time) / 3600 ))
        [ "$age" -gt 24 ] && continue

        # 记录已被 trace 处理过
        local traced_marker="${event_file}.traced"
        [ -f "$traced_marker" ] && continue

        log "🟡 发现未捕获事件: $(basename "$event_file")"
        # 这里可扩展为解析 JSON → Archive 条目
        touch "$traced_marker"
        count=$((count + 1))
    done

    log "📊 Agent-Bus 扫描: ${count} 新事件"
}

# === 主流程 ===
main() {
    init_archive_db

    local type=""
    local title=""
    local category="infrastructure"
    local severity="🟡"
    local detected_by="agent"
    local agent="Tristan"
    local detail=""
    local mode="manual"

    # 解析参数
    while [ $# -gt 0 ]; do
        case "$1" in
            --error) type="error"; title="$2"; shift 2 ;;
            --success) type="success"; title="$2"; shift 2 ;;
            --detail) detail="$2"; shift 2 ;;
            --agent) agent="$2"; shift 2 ;;
            --category) category="$2"; shift 2 ;;
            --severity) severity="$2"; shift 2 ;;
            --detected-by) detected_by="$2"; shift 2 ;;
            --from-stdin) mode="stdin"; shift ;;
            --scan-agent-bus) mode="scan"; shift ;;
            --help|-h)
                echo "用法: retroonto-trace [选项]"
                echo "  --error \"标题\"     记录错误"
                echo "  --success \"标题\"   记录成功"
                echo "  --detail \"内容\"    详细内容或文件路径"
                echo "  --agent NAME       Agent 名称 (默认: Tristan)"
                echo "  --category CAT     分类 (infrastructure|coordination|cognitive)"
                echo "  --severity LVL     严重程度 (🔴|🟡|🟢)"
                echo "  --detected-by SRC  检测来源 (agent|founder|stella)"
                echo "  --from-stdin       从管道读取结构化 JSON 输入"
                echo "  --scan-agent-bus   扫描 Agent-Bus 事件"
                exit 0
                ;;
            *) err "未知参数: $1"; exit 1 ;;
        esac
    done

    if [ "$mode" = "scan" ]; then
        scan_agent_bus
        return 0
    fi

    if [ "$mode" = "stdin" ]; then
        # 从标准输入读取 JSON
        if ! command -v jq &>/dev/null; then
            err "stdin 模式需要 jq"
            exit 1
        fi
        local input
        input=$(cat)
        type=$(echo "$input" | jq -r '.type // "error"')
        title=$(echo "$input" | jq -r '.title // ""')
        category=$(echo "$input" | jq -r '.category // "infrastructure"')
        severity=$(echo "$input" | jq -r '.severity // "🟡"')
        detected_by=$(echo "$input" | jq -r '.detected_by // "agent"')
        agent=$(echo "$input" | jq -r '.agent // "Tristan"')
        detail=$(echo "$input" | jq -r '.detail // ""')
    fi

    if [ -z "$type" ] || [ -z "$title" ]; then
        err "必须指定 --error 或 --success + 标题"
        exit 1
    fi

    # 写入 Archive
    local attempts=0
    local filepath=""
    while [ $attempts -lt $MAX_RETRIES ]; do
        attempts=$((attempts + 1))
        filepath=$(write_archive_entry "$type" "$title" "$category" "$severity" "$detected_by" "$agent" "$detail" 2>/dev/null) && break
        err "写入失败 (尝试 ${attempts}/${MAX_RETRIES})"
        sleep 1
    done

    if [ -z "$filepath" ] || [ ! -f "$filepath" ]; then
        err "写入 Archive 失败，已达最大重试次数"
        exit 1
    fi

    log "✅ Archive 条目已创建: $filepath"

    # 提取 ID
    local id
    id=$(grep "^id: " "$filepath" | sed 's/^id: //' | tr -d ' ')

    # 写入 RetroOnto DB
    write_to_db "$id" "$title" "$agent" "${type}_${category}"

    # 广播
    broadcast "$id" "$title" "🟢"

    # 事件驱动进化：trace后立即触发约束生成+写回（异步·不等cron）
    local retroonto_base
    retroonto_base="$(dirname "$(dirname "$ARCHIVE_BASE")")"
    local evolve_script="${retroonto_base}/scripts/retroonto-evolve.sh"
    if [ -x "$evolve_script" ]; then
        log "🔄 触发自动进化: ${id}"
        bash "$evolve_script" --immediate 2>/dev/null &
    fi

    echo "$filepath"
}

main "$@"
