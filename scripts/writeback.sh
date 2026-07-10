#!/bin/bash
#===============================================================================
# writeback.sh — RetroOnto 守门人脚本（P1）
# 约束写回知识环 → permanent-knowledge + SOUL.md
#===============================================================================
# 用法:
#   retroonto-writeback                         # 处理所有待写回约束
#   retroonto-writeback --id ERR-001            # 处理指定条目
#   retroonto-writeback --constraint "C-001"    # 处理指定约束
#   retroonto-writeback --force                  # 强制写回（跳过验证）
#===============================================================================

set -euo pipefail

# === 配置 ===
RETROONTO_BASE="/home/agentuser/.openclaw/workspace/tristan/tech_lead/retroonto"
ARCHIVE_BASE="${RETROONTO_BASE}/archive"
CONSTRAINTS_DIR="${RETROONTO_BASE}/constraints"
PERMANENT_KNOWLEDGE="/home/agentuser/shared/permanent-knowledge"
AGENT_BUS="/home/agentuser/shared/bus/agent-bus.sh"
LOG_FILE="/var/log/zwf-retroonto-writeback.log"
REGISTRY_FILE="${RETROONTO_BASE}/.writeback-registry.json"

# === Logging ===
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"; echo "$*"; }
err() { log "🔴 ERROR: $*"; }

# === 初始化 ===
init() {
    mkdir -p "$PERMANENT_KNOWLEDGE"
    # 初始化注册表
    if [ ! -f "$REGISTRY_FILE" ]; then
        echo '{"writebacks":[]}' > "$REGISTRY_FILE"
    fi
}

# === 提取 Archive 条目中的约束 ===
extract_constraints() {
    local archive_file="$1"
    local constraints=""

    # 从 ## 约束 段落提取 → 从 ## 到下一个 ## 或文件尾
    local in_constraint_section=0
    while IFS= read -r line; do
        if echo "$line" | grep -q "^## 约束"; then
            in_constraint_section=1
            continue
        fi
        if echo "$line" | grep -q "^## "; then
            [ "$in_constraint_section" = "1" ] && in_constraint_section=0
            continue
        fi
        if [ "$in_constraint_section" = "1" ] && [ -n "$line" ]; then
            constraints="${constraints}${line}"$'\n'
        fi
    done < "$archive_file"

    echo "$constraints"
}

# === 检查是否已写回 ===
is_already_written() {
    local archive_id="$1"
    if command -v jq &>/dev/null && [ -f "$REGISTRY_FILE" ]; then
        jq -e ".writebacks[] | select(.archive_id == \"${archive_id}\")" "$REGISTRY_FILE" >/dev/null 2>&1
        return $?
    fi
    # 回退：检查 permanent-knowledge 中是否存在同名文件
    local target="${PERMANENT_KNOWLEDGE}/${archive_id}-*.md"
    ls $target 2>/dev/null | head -1 | grep -q .
    return $?
}

# === 写入 permanent-knowledge ===
write_to_permanent_knowledge() {
    local archive_file="$1"
    local archive_id="$2"
    local constraints="$3"

    local target="${PERMANENT_KNOWLEDGE}/${archive_id}-$(basename "$archive_file" .md).md"

    # 提取 frontmatter 和关键内容
    local title severity category detected_by
    title=$(grep "^## 标题" -A1 "$archive_file" | tail -1)
    severity=$(grep "^severity: " "$archive_file" | sed 's/^severity: //')
    category=$(grep "^category: " "$archive_file" | sed 's/^category: //')
    detected_by=$(grep "^detected_by: " "$archive_file" | sed 's/^detected_by: //')

    cat > "$target" <<EOF
# ${archive_id}: ${title}

> **来源：** RetroOnto Archive | **分类：** ${category} | **严重程度：** ${severity}
> **检测者：** ${detected_by} | **写回日期：** $(date '+%Y-%m-%d')
> **原始条目：** ${archive_file}

## 约束规则

${constraints:-（无明确约束规则）}

## 关联

EOF

    # 添加关联信息
    if grep -q "^## 关联" "$archive_file"; then
        sed -n '/^## 关联/,$ p' "$archive_file" | tail -n +2 >> "$target"
    fi

    echo "$target"
}

# === 注册写回 ===
register_writeback() {
    local archive_id="$1"
    local constraint_file="$2"
    local target_file="$3"

    if command -v jq &>/dev/null; then
        local entry
        entry=$(jq -n \
            --arg id "$archive_id" \
            --arg constraint "$constraint_file" \
            --arg target "$target_file" \
            --arg date "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            '{archive_id: $id, constraint_file: $constraint, target_file: $target, written_at: $date}')
        local tmp
        tmp=$(mktemp)
        jq ".writebacks += [$entry]" "$REGISTRY_FILE" > "$tmp"
        mv "$tmp" "$REGISTRY_FILE"
    fi
}

# === 写入约束到 constraints/ 目录（Ferrum 集成）===
write_ferrum_constraint() {
    local archive_file="$1"
    local archive_id="$2"

    local exec_script="${CONSTRAINTS_DIR}/${archive_id}-exec.sh"
    local rule_file="${CONSTRAINTS_DIR}/${archive_id}-rule.md"

    # 复制规则描述
    cp "$archive_file" "$rule_file"

    # 生成可执行检测脚本（如果约束段可转换）
    local constraints
    constraints=$(extract_constraints "$archive_file")
    if [ -n "$constraints" ]; then
        cat > "$exec_script" <<'SCRIPT'
#!/bin/bash
# Ferrum 约束检测脚本 — 由 writeback.sh 自动生成
set -euo pipefail

SCRIPT
        echo "# 约束: ${archive_id}" >> "$exec_script"
        echo "# 来源: ${archive_file}" >> "$exec_script"
        echo "# 生成: $(date '+%Y-%m-%d %H:%M:%S')" >> "$exec_script"
        cat >> "$exec_script" <<SCRIPT

check_violation() {
    local rule_name="\$1"
    local check_cmd="\$2"
    local fix_cmd="\${3:-}"

    echo "🟡 检查: \$rule_name"
    if eval "\$check_cmd" 2>/dev/null; then
        echo "  ✅ 通过"
        return 0
    else
        echo "  🔴 违反: \$rule_name"
        if [ -n "\$fix_cmd" ]; then
            echo "  🔧 自动修复: \$fix_cmd"
            eval "\$fix_cmd" 2>/dev/null || true
        fi
        return 1
    fi
}

# === 约束检查点 ===
SCRIPT

        # 将约束文本转换为检查点（简化版）
        echo "$constraints" | while IFS= read -r line; do
            [ -z "$line" ] && continue
            echo "# 约束: $line" >> "$exec_script"
        done

        chmod +x "$exec_script"
        log "  Ferrum 约束脚本: $exec_script"
    fi

    echo "$rule_file"
}

# === 广播 ===
broadcast() {
    local archive_id="$1"
    local target="$2"

    if [ -x "$AGENT_BUS" ]; then
        bash "$AGENT_BUS" publish "progress" "Tristan" "🟢" \
            "Writeback:${archive_id}" \
            "约束写回知识环: ${target}" \
            "all" 2>/dev/null || true
    fi
}

# === 处理单个 Archive 条目 ===
process_entry() {
    local archive_file="$1"
    local force="${2:-false}"

    local id
    id=$(grep "^id: " "$archive_file" | sed 's/^id: //' | tr -d ' ')

    if [ -z "$id" ]; then
        err "无法提取 ID，跳过: $archive_file"
        return 1
    fi

    # 跳过已写回的（除非 force）
    if [ "$force" != "true" ] && is_already_written "$id"; then
        log "  🟡 跳过（已写回）: ${id}"
        return 0
    fi

    log "  🔄 处理: ${id} — $(basename "$archive_file")"

    # 提取约束
    local constraints
    constraints=$(extract_constraints "$archive_file")
    if [ -z "$constraints" ]; then
        log "  🟡 无约束段，跳过写回: ${id}"
        return 0
    fi

    # 🔴 Fact Gate: 写入前事实门禁
    local fact_gate="${RETROONTO_BASE}/scripts/fact-gate.sh"
    if [ -x "$fact_gate" ]; then
        if ! bash "$fact_gate" "$archive_file" 2>/dev/null; then
            log "  🛑 Fact Gate 阻断: ${id} — 引用文件不存在·写入中止"
            return 1
        fi
        log "  ✅ Fact Gate 通过: ${id}"
    fi

    # 写回 permanent-knowledge
    local target
    target=$(write_to_permanent_knowledge "$archive_file" "$id" "$constraints")
    log "  ✅ 已写回知识环: $target"

    # 写入 Ferrum 约束
    local rule_file
    rule_file=$(write_ferrum_constraint "$archive_file" "$id")
    log "  ✅ Ferrum 约束: $rule_file"

    # 注册
    register_writeback "$id" "$rule_file" "$target"

    # 广播
    broadcast "$id" "$target"

    return 0
}

# === 扫描 Archive 中所有需写回条目 ===
scan_and_writeback() {
    local force="${1:-false}"
    local count=0
    local failed=0

    log "📋 扫描 Archive 待写回条目..."

    while IFS= read -r archive_file; do
        [ -f "$archive_file" ] || continue
        # 只处理带 frontmatter 的
        grep -q "^---" "$archive_file" || continue
        # 跳过非 active 状态
        local status
        status=$(grep "^status: " "$archive_file" | sed 's/^status: //')
        [ "$status" = "archived" ] && continue

        if process_entry "$archive_file" "$force"; then
            count=$((count + 1))
        else
            failed=$((failed + 1))
        fi
    done < <(find "$ARCHIVE_BASE" -name "*.md" -type f)

    log "📊 写回完成: ${count} 成功 / ${failed} 失败"
    return $failed
}

# === 主流程 ===
main() {
    init

    local mode="scan"
    local target_id=""
    local target_constraint=""
    local force=false

    while [ $# -gt 0 ]; do
        case "$1" in
            --id) mode="id"; target_id="$2"; shift 2 ;;
            --constraint) mode="constraint"; target_constraint="$2"; shift 2 ;;
            --force) force=true; shift ;;
            --help|-h)
                echo "用法: retroonto-writeback [选项]"
                echo "  (无参数)     扫描所有 Archive 条目并写回"
                echo "  --id ID      写回指定 ID 的条目 (如 ERR-001)"
                echo "  --force      强制写回（跳过已写回检查）"
                exit 0
                ;;
            *) err "未知参数: $1"; exit 1 ;;
        esac
    done

    case "$mode" in
        scan)
            scan_and_writeback "$force"
            ;;
        id)
            local file
            file=$(find "$ARCHIVE_BASE" -name "${target_id}-*.md" -type f | head -1)
            if [ -z "$file" ]; then
                err "未找到 Archive 条目: ${target_id}"
                exit 1
            fi
            process_entry "$file" "$force"
            ;;
        constraint)
            err "按约束 ID 处理暂未实现: ${target_constraint}"
            exit 1
            ;;
    esac
}

main "$@"
