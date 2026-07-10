#!/usr/bin/env bash
# ferrum-gate — RetroOnto constraint execution gateway
# Usage: ./src/ferrum-gate.sh list|check|status
set -euo pipefail

RETROONTO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONSTRAINTS_DIR="${RETROONTO_DIR}/constraints"
DB="${RETROONTO_DIR}/retroonto.db"

mkdir -p "$CONSTRAINTS_DIR"

case "${1:-list}" in
    list)
        echo "📋 Active constraints:"
        if command -v sqlite3 &>/dev/null && [[ -f "$DB" ]]; then
            sqlite3 "$DB" "SELECT id, name, description, severity FROM constraints WHERE status='active';" 2>/dev/null | while IFS='|' read -r id name desc sev; do
                echo "  ${sev:-🟡} ${id}: ${desc}"
            done
        fi
        for f in "${CONSTRAINTS_DIR}"/*-rule.md; do
            [[ -f "$f" ]] || continue
            id=$(basename "$f" | sed 's/-rule.md//')
            desc=$(head -3 "$f" | grep "description:" | sed 's/.*description: *//')
            sev=$(head -3 "$f" | grep "severity:" | sed 's/.*severity: *//')
            echo "  ${sev:-🟡} ${id}: ${desc:-No description}"
        done
        ;;
    check|run)
        PASS=0
        FAIL=0
        for f in "${CONSTRAINTS_DIR}"/*-exec.sh; do
            [[ -f "$f" ]] || continue
            id=$(basename "$f" | sed 's/-exec.sh//')
            rule_file="${CONSTRAINTS_DIR}/${id}-rule.md"
            
            desc=""
            sev="🟡"
            [[ -f "$rule_file" ]] && {
                desc=$(head -5 "$rule_file" | grep "description:" | sed 's/.*description: *//')
                sev=$(head -5 "$rule_file" | grep "severity:" | sed 's/.*severity: *//')
            }
            
            echo "🔍 Constraint check: ${id} - ${desc}"
            if bash "$f" 2>&1; then
                echo "  ✅ ${id}: Passed"
                PASS=$((PASS + 1))
            else
                echo "  ❌ ${id}: FAILED"
                FAIL=$((FAIL + 1))
            fi
        done
        echo "📊 Ferrum: $((PASS + FAIL)) constraints / ${PASS} passed / ${FAIL} violations"
        [[ $FAIL -eq 0 ]]
        ;;
    status)
        echo "✅ Ferrum gate active"
        echo "Constraints dir: ${CONSTRAINTS_DIR}"
        echo "DB: ${DB}"
        ;;
    *)
        echo "Usage: $0 list|check|status"
        exit 1
        ;;
esac
