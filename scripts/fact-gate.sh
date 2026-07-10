#!/bin/bash
#===============================================================================
# fact-gate.sh — 写入前事实门禁
# 提案: Shuyu 2026-07-10 | 实现: Zeus 2026-07-10 22:18 创始人确认令
# 职责: 扫描产出文件的 claimed references → 验证文件是否存在 → 阻断虚假引用
# 集成: writeback.sh 写入前 + retroonto-evolve.sh 管线 + 手动调用
#===============================================================================
# 用法:
#   fact-gate.sh <产出文件>          检查单个文件的引用
#   fact-gate.sh --stdin             从标准输入读取（Agent产出管道）
#   fact-gate.sh --archive <entry>   检查Archive条目的references字段
#===============================================================================
set -euo pipefail

RETROONTO_BASE="/home/agentuser/.openclaw/workspace/tristan/tech_lead/retroonto"
LOG_DIR="${RETROONTO_BASE}/logs"
mkdir -p "$LOG_DIR"
GATE_LOG="${LOG_DIR}/fact-gate.log"
AGENT_BUS="/home/agentuser/shared/bus/agent-bus.sh"
WORKSPACE="/home/agentuser/.openclaw/workspace/data/ZWISERFIT"
SHARED="/home/agentuser/shared"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$GATE_LOG"; echo "$*" >&2; }

# === 文件存在性检查 ===
file_exists() {
    local path="$1"
    
    # 绝对路径
    if [ -e "$path" ]; then
        return 0
    fi
    
    # 去掉可能的 shared/ 前缀，拼到SHARED
    local stripped
    stripped=$(echo "$path" | sed 's|^shared/||')
    if [ -e "${SHARED}/${stripped}" ]; then
        return 0
    fi
    
    # 去掉可能的 data/ZWISERFIT/ 前缀，拼到WORKSPACE
    stripped=$(echo "$path" | sed 's|^data/ZWISERFIT/||')
    if [ -e "${WORKSPACE}/${stripped}" ]; then
        return 0
    fi
    
    # 相对于workspace（完整路径）
    if [ -e "${WORKSPACE}/${path}" ]; then
        return 0
    fi
    
    return 1
}

# === 从YAML frontmatter提取references ===
extract_references_yaml() {
    local file="$1"
    local in_frontmatter=0
    local in_references=0
    local refs=""
    
    while IFS= read -r line; do
        # 检测YAML frontmatter边界
        if [ "$line" = "---" ]; then
            if [ "$in_frontmatter" -eq 0 ]; then
                in_frontmatter=1
                continue
            else
                break  # frontmatter结束
            fi
        fi
        
        [ "$in_frontmatter" -eq 0 ] && continue
        
        # references段
        if echo "$line" | grep -q "^references:"; then
            in_references=1
            continue
        fi
        
        # references的子项: "  - path: xxx"
        if [ "$in_references" -eq 1 ] && echo "$line" | grep -qE "^\s+- path:"; then
            local p
            p=$(echo "$line" | sed 's/.*path:\s*//' | tr -d '"' | tr -d "'" | xargs)
            refs="${refs}${p}"$'\n'
        fi
        
        # 遇到非缩进行=退出references段
        if [ "$in_references" -eq 1 ] && echo "$line" | grep -qE "^[a-z]"; then
            in_references=0
        fi
    done < "$file"
    
    echo "$refs"
}

# === 从全文提取声称的引用（兜底：无YAML references时用） ===
extract_references_fallback() {
    local content
    content=$(cat "$1" 2>/dev/null || echo "")
    
    # 模式: "来源: path" / "Source: path" / "[ref: path]" / "引用: path"
    echo "$content" | grep -oP '(?:来源|Source|引用|锚点|[Rr]ef)[：:]\s*\K[^\s]+(?:/[^\s]+)*\.(?:md|json|sh|txt|yaml|yml|toml)' 2>/dev/null || true
    echo "$content" | grep -oP '\[ref:\s*\K[^\]]+' 2>/dev/null || true
}

# === 阻断并告警 ===
block_and_alert() {
    local file="$1"
    local missing_ref="$2"
    local reason="$3"
    
    log "🔴 BLOCK: $(basename "$file") — 引用不存在: ${missing_ref}"
    log "   原因: ${reason}"
    
    # Agent-Bus告警
    if [ -x "$AGENT_BUS" ]; then
        bash "$AGENT_BUS" publish "alarm" "Zeus" "🔴" \
            "FactGate:${missing_ref}" \
            "事实门禁阻断: $(basename "$file") 声称引用 ${missing_ref} 但文件不存在" \
            "Shuyu" 2>/dev/null || true
    fi
    
    return 1
}

# === 主检查 ===
check_file() {
    local target="$1"
    local failed=0
    local checked=0
    
    if [ ! -f "$target" ]; then
        log "🔴 目标文件不存在: $target"
        return 1
    fi
    
    log "🔍 Fact Gate 检查: $(basename "$target")"
    
    # 优先从YAML references提取
    local refs
    refs=$(extract_references_yaml "$target")
    
    if [ -n "$refs" ]; then
        log "   📋 从YAML references提取到引用"
        while IFS= read -r path; do
            [ -z "$path" ] && continue
            checked=$((checked + 1))
            
            if file_exists "$path"; then
                log "   ✅ ${path}"
            else
                log "   🔴 ${path} — 文件不存在"
                block_and_alert "$target" "$path" "文件不存在"
                failed=$((failed + 1))
            fi
        done <<< "$refs"
    else
        # 兜底：全文提取
        log "   📋 无YAML references·使用全文兜底提取"
        while IFS= read -r path; do
            [ -z "$path" ] && continue
            checked=$((checked + 1))
            
            if file_exists "$path"; then
                log "   ✅ ${path} (fallback)"
            else
                log "   🔴 ${path} — 文件不存在 (fallback)"
                block_and_alert "$target" "$path" "文件不存在(fallback)"
                failed=$((failed + 1))
            fi
        done < <(extract_references_fallback "$target")
    fi
    
    if [ "$failed" -gt 0 ]; then
        log "🛑 阻断: ${failed}/${checked} 引用不存在"
        return 1
    fi
    
    log "✅ 通过: ${checked}/${checked} 引用验证"
    return 0
}

# === 主入口 ===
main() {
    local target=""
    local mode="file"
    
    while [ $# -gt 0 ]; do
        case "$1" in
            --stdin) mode="stdin"; shift ;;
            --archive) mode="archive"; target="$2"; shift 2 ;;
            --help|-h)
                echo "用法: fact-gate.sh [选项] <文件>"
                echo "  <文件>        检查产出文件的引用"
                echo "  --stdin       从标准输入读取"
                echo "  --archive ID  检查Archive条目(如 ERR-001)"
                echo ""
                echo "引用格式(YAML frontmatter):"
                echo "  references:"
                echo "    - path: data/ZWISERFIT/xxx.md"
                echo "    - path: shared/state/xxx.json"
                exit 0
                ;;
            -*) shift ;;
            *) target="$1"; shift ;;
        esac
    done
    
    if [ "$mode" = "stdin" ]; then
        local tmp
        tmp=$(mktemp)
        cat > "$tmp"
        target="$tmp"
        trap 'rm -f "$tmp"' EXIT
    fi
    
    if [ "$mode" = "archive" ]; then
        target=$(find "${RETROONTO_BASE}/archive" -name "${target}-*.md" -type f | head -1)
        if [ -z "$target" ]; then
            log "🔴 Archive条目未找到: $target"
            exit 1
        fi
    fi
    
    if [ -z "$target" ]; then
        log "🔴 需要指定文件或 --stdin"
        exit 1
    fi
    
    check_file "$target"
}

main "$@"
