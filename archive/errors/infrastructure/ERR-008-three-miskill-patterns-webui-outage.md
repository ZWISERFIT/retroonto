---
id: ERR-008
type: error
category: infrastructure
severity: 🔴
status: active
created: 2026-07-10
source_agent: Shuyu
source_session: agent:shuyu:main
detected_by: Stella
verified_by: founder
tags: [watchdog, auto-recover, pipeline, miskill, pattern, stella-audit]
---

## 现象
2026-06-28 Web UI 9小时断联期间，出现三起误杀反模式：

| 误杀事件 | 操作 | 触发 | 结果 |
|:--------|:----|:----|:----|
| **① watchdog杀进程** | watchdog检测到"异常"→kill→重启 | 误判RSS增长为泄漏 | 正常运行进程被终止，引起4-6h运行状态丢失 |
| **② auto-recover盲目恢复** | 自动恢复脚本"修复"→产生新问题 | 配置误判 | 修复本身成为新故障 |
| **③ Pipeline修复干扰** | 修复操作影响Pipeline正常流程 | 操作冲突 | Pipeline短暂中断 |

## 根因
1. **Watchdog阈值太敏感**——进程刚启动RSS冲高≠内存泄漏，但没有上下文判断
2. **没有"先诊断3次再行动"的铁律**——类似Stella的"3轮自批判→3轮交叉验证→再行动"机制缺失
3. **操作前没有回滚方案**——每次kill/restart前没有考虑"如果这个坏了怎样回到上一步"
4. **无操作前通知机制**——修复操作前没有通知可能受影响的其他Agent

## 修复
Stella审计报告建议（2026-06-29 00:30）：
1. Watchdog增加"3次连续异常再行动"的冷静期
2. Auto-recover每次触发前自动备份当前配置 + 通知Shuyu
3. 全Agent增加"暴力操作禁令"：任何kill/restart/stop操作前必须发Bus通知
4. nginx/openclaw.json git管理强制执行

## 教训
**自动化修复工具如果缺乏上下文判断和冷静期，本身就是故障源。** watchdog/auto-recover的误杀率必须通过：冷静期 + 通知机制 + 回滚方案 三管齐下控制。核心原则：没有回滚方案的修复=制造新故障。

## 约束
**自动化操作三管齐下约束：**
1. Watchdog冷静期：任何检测到"异常"必须连续3次（至少间隔30秒）确认后才触发操作
2. Auto-recover预检查：每次触发前自动备份当前配置至 `/etc/nginx/backups/`，并通过Agent-Bus通知Shuyu
3. 暴力操作禁令：任何kill/restart/stop操作前必须发Agent-Bus通知 → 等待15秒确认 → 执行
4. 每次基础设施变更前：写入changelog + 备份旧配置 + 写回滚方案

## 关联
- Stella审计: webui-outage-audit-20260628.md·第四章
- ERR-004: 网关宕机（同样的"操作前无思考"模式）
- 铁律十七：基础设施变更审批
- 铁律十八：创始人办公设施保障
