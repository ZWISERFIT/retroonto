#!/bin/bash
#===============================================================================
# constraint-gen.sh — RetroOnto 分析师脚本（P2）
# 扫描 Archive → 模式匹配 → 约束生成
#===============================================================================
# 用法:
#   retroonto-constraint-gen                     # 扫描所有 Archive 条目，生成模式约束
#   retroonto-constraint-gen --since 7           # 只分析 7 天内新增条目
#   retroonto-constraint-gen --match "portproxy"  # 针对特定关键词生成约束
#===============================================================================

set -euo pipefail

# === 配置 ===
RETROONTO_BASE="/home/agentuser/.openclaw/workspace/tristan/tech_lead/retroonto"
ARCHIVE_BASE="${RETROONTO_BASE}/archive"
CONSTRAINTS_DIR="${RETROONTO_BASE}/constraints"
PATTERNS_DIR="${RETROONTO_BASE}/archive/patterns"
AGENT_BUS="/home/agentuser/shared/bus/agent-bus.sh"
LOG_FILE="/var/log/zwf-retroonto-constraint.log"
PATTERN_REGISTRY="${RETROONTO_BASE}/.pattern-registry.json"

# === 模式定义库 ===
# 每行格式: pattern_key|severity|trigger_regex|name|check_desc|constraint_desc
PATTERN_DEFS=(
  "portproxy|🔴|portproxy|portproxy-zombie-cleaning|检查 netsh portproxy 输出|任何涉及 portproxy 的操作必须附带清理逻辑"
  "session-memory|🔴|session.*记忆|session-memory-not-authoritative|声明是否基于 session 记忆|事实性声明前必须查询权威源文件"
  "url-delivery|🟡|URL|founder-url-format-check|URL 格式检查|发送审阅 URL 前需格式+文件+HTTP 三重检查"
  "alert-storm|🟡|告警|alert-storm-suppression|同一根因 24h 告警次数|不可自愈后告警频率降至 ≤1次/24h"
  "external-service|🔴|绑卡|external-service-reachability-test|推荐外部服务前验证可达性|推荐注册/付费服务前必须 curl 验证可达"
)

# === Logging ===
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"; echo "$*"; }
err() { log "🔴 ERROR: $*"; }

# === 初始化 ===
init() {
    mkdir -p "$CONSTRAINTS_DIR" "$PATTERNS_DIR"
    if [ ! -f "$PATTERN_REGISTRY" ]; then
        echo '{"constraints":[]}' > "$PATTERN_REGISTRY"
    fi
}

# === 扫描 Archive 条目 ===
scan_archive_entries() {
    local since_days="${1:-0}"
    local match_term="${2:-}"

    local find_cmd="find \"$ARCHIVE_BASE\" -name \"*.md\" -type f"
    [ "$since_days" -gt 0 ] && find_cmd+=" -mtime -${since_days}"

    eval "$find_cmd" | while IFS= read -r file; do
        [ -f "$file" ] || continue
        grep -q "^---" "$file" || continue
        # 跳过 archived 状态的
        grep -q "^status: archived" "$file" && continue

        local id severity
        id=$(grep "^id: " "$file" | sed 's/^id: //' | tr -d ' ')
        severity=$(grep "^severity: " "$file" | sed 's/^severity: //' | tr -d ' ')
        echo "FILE|${id}|${severity}|${file}"
    done
}

# === 模式匹配（纯 Shell，无 python 依赖）===
match_patterns() {
    local file="$1"
    local content
    content=$(cat "$file" 2>/dev/null) || return 0

    for def in "${PATTERN_DEFS[@]}"; do
        local trigger
        trigger=$(echo "$def" | cut -d'|' -f3)
        echo "$content" | grep -qiE "$trigger" 2>/dev/null || continue
        # 命中 → 输出整行定义
        echo "$def"
        log "  🎯 命中模式 [$(echo "$def" | cut -d'|' -f4)] in $(basename "$file")" >&2
    done
}

# === 生成约束文件 ===
generate_constraint() {
    local archive_file="$1"
    local archive_id="$2"
    local def_line="$3"

    local name severity constraint_desc
    name=$(echo "$def_line" | cut -d'|' -f4)
    severity=$(echo "$def_line" | cut -d'|' -f2)
    constraint_desc=$(echo "$def_line" | cut -d'|' -f6-)

    local safe_name
    safe_name=$(echo "$name" | tr '[:lower:]' '[:upper:]' | sed 's/[^A-Z0-9_-]/_/g' | head -c 30)
    local constraint_id="C-${safe_name}"

    # 规则描述
    local rule_file="${CONSTRAINTS_DIR}/${constraint_id}-rule.md"
    cat > "$rule_file" <<EOF
# ${constraint_id}: ${name}

| 字段 | 值 |
|------|-----|
| **严重程度** | ${severity} |
| **约束** | ${constraint_desc} |
| **来源** | ${archive_file} (${archive_id}) |
| **生成日期** | $(date '+%Y-%m-%d %H:%M:%S') |
EOF

    # 可执行约束脚本
    local exec_file="${CONSTRAINTS_DIR}/${constraint_id}-exec.sh"
    cat > "$exec_file" <<SCRIPT
#!/bin/bash
# ${constraint_id}: ${name}
# 严重程度: ${severity}
# 约束: ${constraint_desc}
# 生成: $(date '+%Y-%m-%d')
set -euo pipefail
echo "🔍 约束检查: ${constraint_id} - ${name}"
echo "   约束: ${constraint_desc}"
echo "   来源: ${archive_id}"
# TODO: 实现具体的检测逻辑
echo "  ⚠️  占位符 — 需根据具体约束实现检测"
exit 0
SCRIPT
    chmod +x "$exec_file"

    log "  ✅ 约束生成: ${constraint_id}"
    echo "$constraint_id"
}

# === 注册约束 ===
register_constraint() {
    local constraint_id="$1"
    local archive_id="$2"

    if command -v jq &>/dev/null; then
        local entry
        entry=$(jq -n \
            --arg id "$constraint_id" \
            --arg archive "$archive_id" \
            --arg date "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            '{constraint_id: $id, archive_id: $archive, generated_at: $date}')
        local tmp
        tmp=$(mktemp)
        jq ".constraints += [$entry]" "$PATTERN_REGISTRY" > "$tmp"
        mv "$tmp" "$PATTERN_REGISTRY"
    fi
}

# === 去重检查 ===
is_duplicate() {
    local archive_id="$1"
    local pattern_name="$2"
    if command -v jq &>/dev/null && [ -f "$PATTERN_REGISTRY" ]; then
        jq -e ".constraints[] | select(.archive_id == \"${archive_id}\")" "$PATTERN_REGISTRY" >/dev/null 2>&1
        return $?
    fi
    return 1
}

# === 广播 ===
broadcast() {
    local constraint_id="$1"
    local msg="$2"
    [ -x "$AGENT_BUS" ] && bash "$AGENT_BUS" publish "progress" "Tristan" "🟢" \
        "Constraint:${constraint_id}" "${msg}" "all" 2>/dev/null || true
}

# === 生成模式抽象文件 ===
generate_pattern_abstraction() {
    local key="$1"
    local pattern_file="${PATTERNS_DIR}/pattern-${key}.md"
    [ -f "$pattern_file" ] && return 0

    cat > "$pattern_file" <<EOF
---
pattern: "${key}"
created: $(date '+%Y-%m-%d')
source: constraint-gen.sh
---

# 模式: ${key}

自动生成于 $(date '+%Y-%m-%d %H:%M:%S')

## 状态
- [ ] 已生成约束
- [ ] 已写回知识环
- [ ] 已集成 Ferrum
EOF
    log "  📐 模式抽象: ${key}"
}

# === 主流程 ===
main() {
    init

    local since_days=0
    local match_term=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --since) since_days="$2"; shift 2 ;;
            --match) match_term="$2"; shift 2 ;;
            --help|-h)
                echo "用法: retroonto-constraint-gen [选项]"
                echo "  (无参数)     扫描所有 Archive 条目并生成约束"
                echo "  --since N    只分析 N 天内新增条目"
                echo "  --match TERM 针对特定关键词生成约束"
                exit 0 ;;
            *) err "未知参数: $1"; exit 1 ;;
        esac
    done

    log "📊 开始 Archive 模式扫描... (${since_days}d | ${match_term:-全部})"

    local total=0 matched=0 generated=0

    # 使用进程替换而非管道，保持变量作用域
    local tmpfile
    tmpfile=$(mktemp)

    scan_archive_entries "$since_days" "$match_term" > "$tmpfile" 2>/dev/null || true

    while IFS='|' read -r marker id severity file; do
        [ "$marker" != "FILE" ] && continue
        total=$((total + 1))
        log "  分析: ${id} ($(basename "$file"))"

        # 关键词过滤
        if [ -n "$match_term" ]; then
            grep -qi "$match_term" "$file" 2>/dev/null || continue
        fi

        # 模式匹配
        local matches
        matches=$(match_patterns "$file") || true
        [ -z "$matches" ] && continue

        matched=$((matched + 1))

        while IFS= read -r def_line; do
            [ -z "$def_line" ] && continue
            local pattern_name
            pattern_name=$(echo "$def_line" | cut -d'|' -f4)

            if is_duplicate "$id" "$pattern_name"; then
                log "  🟡 约束已存在，跳过: ${pattern_name}" >&2
                continue
            fi

            local cid
            cid=$(generate_constraint "$file" "$id" "$def_line") || continue

            generated=$((generated + 1))
            register_constraint "$cid" "$id"
            broadcast "$cid" "新约束: ${pattern_name} (来源: ${id})"
            generate_pattern_abstraction "$pattern_name"
        done < <(echo "$matches")
    done < "$tmpfile"

    rm -f "$tmpfile"

    log "📊 扫描完成: ${total} 条目 / ${matched} 命中 / ${generated} 新约束"

    if [ "$generated" -gt 0 ]; then
        log "📐 触发 writeback.sh 推入知识环..."
        bash "${RETROONTO_BASE}/scripts/writeback.sh" 2>/dev/null || true
    fi

    echo "{\"scanned\":${total},\"matched\":${matched},\"generated\":${generated}}"
}

main "$@"
