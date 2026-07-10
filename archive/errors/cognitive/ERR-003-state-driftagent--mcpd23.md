---
id: ERR-003
type: error
category: cognitive
severity: 🔴
status: active
created: 2026-07-10
source_agent: Shuyu
source_session: unknown
detected_by: founder
verified_by:
tags: []
---

## 标题
STATE-DRIFT四犯:Agent内部状态与地面真相解耦-第四次复发-MCP授权D23假阳性

## 现象
/tmp/err-state-drift.json

## 记录
_ID: ERR-003_ | _创建: 2026-07-10 15:30:04_ | _Agent: Shuyu_ | _检测: founder_

{
  "event_name": "STATE_DRIFT_PATTERN_4X",
  "agent": "Shuyu",
  "error_type": "internal_state_drift",
  "context": "Agent维护内部计数器/记忆作为状态来源，而非查询磁盘文件或调用实时API验证。同一模式出现4次：(1)a16z状态错误-未grep tracker (2)Reddit凭据-3次确认未写盘 (3)Agent活跃度-计数器与文件mtime矛盾 (4)MCP授权-D23计数器从未实测。创始人已纠正4次，写入永久记录3次，仍复发。",
  "decision_made": "用RetroOnto将'记录错误'升级为'可执行约束'——即生成一个自动验证脚本，在每次心跳/报告前强制执行地面真相查询，而非依赖Agent记忆。",
  "root_cause": "Agent的LLM推理层维护了与磁盘/API地面真相脱节的内部状态。每次纠正后Agent'记住'了正确结论但未改变查询行为。行为层面：Agent默认相信自己的上下文记忆 > 外部查询的成本。",
  "correction": "创建可执行约束C-STATE-DRIFT：任何涉及外部系统状态的断言前，必须先执行对应的verify脚本（grep tracker文件/curl API/call MCP tool），并在断言中附带验证时间戳。违反时Gate拒绝通过。",
  "rule_added": "C-STATE-DRIFT: 状态断言=实测+时间戳，禁止计数器，心跳首检强制执行",
  "learning_compound": 4,
  "trace_json": {
    "pattern_family": "memory_over_ground_truth",
    "occurrences": [
      {"id": 1, "date": "2026-07-05", "system": "a16z/高瓴/Multicoin", "error": "未grep capital-funnel-tracker.md即断言状态", "fix": "资本核查前先grep tracker"},
      {"id": 2, "date": "2026-06-29", "system": "Reddit凭据", "error": "3次确认未写入磁盘→compaction后丢失", "fix": "铁律十九·随收随写"},
      {"id": 3, "date": "2026-06-29", "system": "Agent活跃度", "error": "内部计数器(62h/60h/83h)与文件mtime矛盾", "fix": "废除计数器·改用文件mtime+Bus事件实时扫描"},
      {"id": 4, "date": "2026-07-10", "system": "企微MCP授权", "error": "D23计数器递增·从未实测MCP调用", "fix": "心跳实测wecom_mcp call get_userlist"}
    ],
    "root_mechanism": "LLM推理层状态与磁盘/API地面真相解耦。Agent倾向于相信上下文记忆(低成本) > 外部验证(高成本)。纠正仅修复了'结论'未修复'行为'。",
    "meta_lesson": "写入记录≠防止复发。需要将约束嵌入执行管道(Gate)而非依赖Agent记忆。"
  }
}

## 约束

```yaml
constraint: C-STATE-DRIFT
type: gate_check
enforcement: p0_block
exec_script: constraints/C-STATE-DRIFT-exec.sh
trigger: heartbeat_1st | report_precompile | external_assert
description: 禁止计数器格式的断言，强制执行地面真相实时查询
compound_value: 4  # 第4次复发 → 最高复利等级
```
