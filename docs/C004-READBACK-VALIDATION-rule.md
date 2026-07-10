# C004-READBACK-VALIDATION: 网络操作Read-Back验证

| 字段 | 值 |
|------|-----|
| **严重程度** | 🔴 |
| **Gate类型** | 执行前拦截（Pre-execution Gate） |
| **约束** | 任何宣称"已修复/已部署/已删除/已配置"的网络/防火墙/代理操作声明，在标记为「已完成」前必须执行read-back验证（show/check/list） |
| **来源** | ERR-002 portproxy-false-fix |
| **生成日期** | 2026-07-10 |

## 触发条件

任何Agent操作声明或日志记录包含以下模式时触发：

- `已修复 (fixed/resolved)` + `netsh|portproxy|firewall|iptables|代理|proxy`
- `已部署 (deployed)` + `防火墙|代理|隧道|tunnel|port`
- `已删除 (deleted/removed)` + `规则|rule|portproxy|转发`
- `已配置 (configured)` + `路由|route|转发|forward|proxy`

## Gate动作

```yaml
pre_check:
  - type: readback_verify
    description: "执行读回验证确认变更生效"
    required_commands:
      - "netsh interface portproxy show v4tov4"
      - "netsh advfirewall show currentprofile"
      - "iptables -L -n"  # Linux防火墙
    pass_condition: "输出不包含预期删除的规则条目，或规则符合预期配置"

on_pass:
  action: "允许标记为已完成"
  validators: ["self", "peer"]
  logging: "✅ read-back验证通过：{{command_output}}"

on_fail:
  action: "拒绝「已完成」标记，退回Agent重新执行"
  severity: "🟡"
  escalation: "连续2次read-back失败→升级🟠stella协同"
  logging: "🔴 read-back验证失败：{{failure_reason}}"
  retry: "退回Agent，要求重新执行修复操作并重新验证"
```

## 验证流程

```
Agent声明："已修复" + 网络操作
        │
        ▼
  C004 Gate触发
        │
        ▼
  执行 read-back 命令（show/check/list）
        │
    ┌───┴───┐
    │       │
    ▼       ▼
  通过    失败
    │       │
    ▼       ▼
 允许  退回Agent
 完成  重新执行
    │       │
    ▼       ▼
  记录✅  重试计数
           │
        ≥2次失败
           │
           ▼
        Stella协同
```

## 关联规则
- 铁律3：Windows代理修复必须先删除portproxy冲突规则
- 铁律3.1：网络操作后必须执行read-back验证
- C-PORTPROXY-ZOMBIE-CLEANING
