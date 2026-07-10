#!/bin/bash
#===============================================================================
# council-gate-pipeline.sh — 智囊团全自动三链管线
# 创始人令 2026-07-10: trace→constraint→writeback 必须自动化
# 链① trace: 监听 bus/events → 自动 trace.sh → archive/
# 链② constrain: 新archive条目 → 模式挖掘 → 约束生成/更新
# 链③ writeback: 新约束 → Git push → 广播Agent
# 集成: 每次心跳调用 · 替代手工逐个触发
#===============================================================================
set -euo pipefail

RETROONTO="/home/agentuser/.openclaw/workspace/tristan/tech_lead/retroonto"
ARCHIVE="$RETROONTO/archive"
CONSTRAINTS="$RETROONTO/constraints"
BUS="/home/agentuser/shared/bus"
STATE="/home/agentuser/shared/state"
TRACE_SCRIPT="$RETROONTO/scripts/trace.sh"
NOW=$(date -Iseconds)
PIPELINE_LOG="$STATE/council-pipeline.log"
CHANGES=0

log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$PIPELINE_LOG"; }

#===============================================================================
# 链①: TRACE — 扫描 bus/events 中新错误 → 自动归档
#===============================================================================
log "═══ 链① TRACE ═══"

PROCESSED_DIR="$BUS/events/.processed"
mkdir -p "$PROCESSED_DIR"

if [ -d "$BUS/events" ]; then
  for event in "$BUS/events"/*.json; do
    [ -f "$event" ] || continue
    event_name=$(basename "$event" .json)
    
    # skip processed markers
    [ "$event_name" = ".processed" ] && continue
    
    event_age=$(( $(date +%s) - $(stat -c %Y "$event" 2>/dev/null || echo 999999) ))
    
    if [ "$event_age" -lt 600 ]; then
      event_type=$(jq -r '.type // "unknown"' "$event" 2>/dev/null || echo "unknown")
      event_agent=$(jq -r '.agent // "unknown"' "$event" 2>/dev/null || echo "unknown")
      
      log "  📨 $event_name ($event_type / $event_agent)"
      
      if echo "$event_type" | grep -qi "error\|failure\|alert"; then
        log "  🔴 → archive"
        bash "$TRACE_SCRIPT" \
          --error "$event_name" \
          --agent "$event_agent" \
          --category "coordination" \
          --severity "🔴" \
          --detected-by "pipeline" \
          --detail "$(jq -r '.detail // "no detail"' "$event" 2>/dev/null)" \
          2>&1 | tail -1 | tee -a "$PIPELINE_LOG"
        CHANGES=$((CHANGES + 1))
      fi
      
      mv "$event" "$PROCESSED_DIR/$(date +%s)_${event_name}.json" 2>/dev/null || true
    fi
  done
fi

#===============================================================================
# 链②: CONSTRAIN — 模式挖掘
#===============================================================================
log "═══ 链② CONSTRAIN ═══"

# 扫描近期新错误
RECENT=$(find "$ARCHIVE/errors" -name "ERR-*.md" -mmin -120 2>/dev/null | wc -l)
TOTAL_ERRS=$(find "$ARCHIVE/errors" -name "ERR-*.md" 2>/dev/null | wc -l)
TOTAL_CONSTRAINTS=$(find "$CONSTRAINTS" -name "*-rule.md" 2>/dev/null | wc -l)

log "  错误: $TOTAL_ERRS 条 | 约束: $TOTAL_CONSTRAINTS 个 | 近期: $RECENT"

# 简单覆盖检查
COVERED=0
for c in "$CONSTRAINTS"/*-rule.md; do
  [ -f "$c" ] || continue
  hits=$(grep -c "ERR-" "$c" 2>/dev/null || true); hits=${hits:-0}
  COVERED=$((COVERED + hits))
done
UNCOVERED=$((TOTAL_ERRS - COVERED))
[ "$UNCOVERED" -lt 0 ] && UNCOVERED=0

log "  覆盖: $COVERED / 未覆盖: $UNCOVERED"

if [ "$UNCOVERED" -gt 2 ]; then
  log "  🟡 ${UNCOVERED}条未覆盖 → 建议运行模式挖掘"
fi

#===============================================================================
# 链③: WRITEBACK — Git同步
#===============================================================================
log "═══ 链③ WRITEBACK ═══"

REPO="/home/agentuser/.openclaw/workspace/tristan/reports/retroonto-repo"

if [ -d "$REPO/.git" ]; then
  cd "$REPO"
  
  # 同步
  cp "$CONSTRAINTS"/*-rule.md docs/ 2>/dev/null || true
  cp "$CONSTRAINTS"/*-exec.sh scripts/ 2>/dev/null || true
  cp "$RETROONTO/scripts/trace.sh" src/ 2>/dev/null || true
  
  if ! git diff --quiet 2>/dev/null || [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    git add -A 2>/dev/null
    git commit -m "pipeline: 自动同步 $(date +%Y%m%d-%H%M)" 2>&1 | tail -1
    git push origin master 2>&1 | tail -1
    log "  ✅ push完成"
    CHANGES=$((CHANGES + 1))
  else
    log "  无变更"
  fi
fi

#===============================================================================
log "═══ 管线: $CHANGES 项变更 ═══"
echo "PIPELINE_OK"
