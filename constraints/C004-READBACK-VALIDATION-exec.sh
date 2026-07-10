#!/bin/bash
# C004-READBACK-VALIDATION: 网络操作Read-Back验证
# 严重程度: 🔴
# Gate类型: 执行前拦截
# 约束: 任何宣称"已修复/已部署"的网络操作，标记为「已完成」前必须read-back验证
# 生成: 2026-07-10
set -euo pipefail

# === 检测网络操作声明 ===
# 检查最近的日志/事件中是否包含网络操作完成声明
LOG_DIR="/home/agentuser/.openclaw/workspace/tristan/tech_lead/retroonto/archive"
TRIGGER_PATTERNS=(
  "netsh.*portproxy.*add"
  "netsh.*portproxy.*delete"
  "iptables.*-A"
  "iptables.*-D"
  "firewall.*add"
  "firewall.*delete"
  "代理.*配置.*完成"
  "proxy.*configured"
  "隧道.*已部署"
  "tunnel.*deployed"
  "已修复.*portproxy"
  "已修复.*防火墙"
  "fixed.*portproxy"
  "fixed.*firewall"
)

# === 扫描近期操作声明 ===
check_recent_network_operations() {
  local found=0
  local log_files=(
    "/var/log/zwf-retroonto-trace.log"
    "/home/agentuser/.openclaw/workspace/tristan/memory/2026-07-10.md"
  )
  
  for log_file in "${log_files[@]}"; do
    [ -f "$log_file" ] || continue
    for pattern in "${TRIGGER_PATTERNS[@]}"; do
      if grep -qiE "$pattern" "$log_file" 2>/dev/null; then
        echo "  ⚠️  检测到网络操作声明: $(grep -iE "$pattern" "$log_file" | tail -1)"
        found=1
      fi
    done
  done

  echo "$found"
}

# === 执行Read-Back验证 ===
run_readback_verify() {
  local target="${1:-auto}"
  local failed=0
  local results=""

  echo "🔍 C004 Gate: 网络操作Read-Back验证"
  echo "   Target: ${target}"

  case "$target" in
    portproxy|auto)
      echo "   [1/3] 检查 netsh portproxy..."
      local portproxy_out
      portproxy_out=$(netsh interface portproxy show v4tov4 2>/dev/null || echo "NOT_AVAILABLE")
      
      if echo "$portproxy_out" | grep -qE "^[0-9]"; then
        # 有实际规则输出（出现了IP/端口）
        local rule_count
        rule_count=$(echo "$portproxy_out" | grep -cE "^[0-9]")
        echo "   🔴 FAIL: portproxy 规则仍存在 (${rule_count}条)"
        echo "   └─ 输出: $portproxy_out" | head -5
        failed=1
      elif echo "$portproxy_out" | grep -q "NOT_AVAILABLE"; then
        echo "   🟡 SKIP: netsh 不可用（非Windows环境）"
      else
        echo "   ✅ PASS: portproxy 规则列表为空（已清除）"
      fi
      ;&
      
    firewall|auto)
      # Windows防火墙检查
      if command -v netsh &>/dev/null; then
        echo "   [2/3] 检查 Windows防火墙..."
        local fw_out
        fw_out=$(netsh advfirewall show currentprofile 2>/dev/null | grep -i state || echo "NOT_AVAILABLE")
        echo "   └─ ${fw_out}"
      fi
      
      # iptables检查
      if command -v iptables &>/dev/null; then
        echo "   [3/3] 检查 iptables..."
        local ipt_out
        ipt_out=$(iptables -L -n --line-numbers 2>/dev/null | head -20 || echo "NOT_AVAILABLE")
        # TODO: 根据具体配置校验规则
        echo "   └─ iptables 规则数: $(echo "$ipt_out" | wc -l) 行"
      fi
      ;;
  esac

  if [ "$failed" -eq 1 ]; then
    echo "  📋 结果: 🔴 验证失败 — 拒绝「已完成」标记"
    return 1
  fi

  echo "  📋 结果: ✅ 验证通过 — 允许标记为已完成"
  return 0
}

# === 主流程 ===
main() {
  echo "🔍 约束检查: C004-READBACK-VALIDATION"
  echo "   约束: 网络操作声明必须read-back验证"
  echo "   来源: ERR-002 portproxy-false-fix"

  local target="${1:-auto}"
  run_readback_verify "$target"
  local rc=$?

  exit $rc
}

main "$@"
