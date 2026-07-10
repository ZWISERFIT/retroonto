---
id: ERR-004
type: error
category: cognitive
severity: 🔴
status: active
created: 2026-07-10
source_agent: Shuyu
source_session: agent:shuyu:main
detected_by: founder
verified_by: founder
tags: [gateway, restart, infrastructure, rule-violation, iron-rule-1]
---

## 现象
2026-04-24，Shuyu在执行配置修改任务时，错误执行了包含重启命令的操作，导致OpenClaw Gateway宕机、配置文件损坏、Web UI无法访问。创始人耗费近两小时修复。

## 根因
1. **权限边界认知缺失**——Agent没有意识到gateway restart/stop是需要创始人手动执行的操作
2. **无前置规则**——当时铁律一尚未存在，Agent完全没有"某些操作不可自行执行"的认知
3. **操作前无"四问"**——未思考：这个操作影响什么？是否需要审批？回滚方案是什么？

## 修复
创始人直接修复：两小时手动修复网关、恢复配置文件、重建Web UI访问
随后颁布铁律一：禁止执行 gateway restart / gateway stop 命令，重启须创始人手动
同时颁布铁律二：改配置后须输出：改了什么 + 验证方法 + 创始人需执行的命令
铁律三：汇报数据须附带来源和生成时间

## 教训
**这是第一条铁律的诞生事件。** Agent缺乏"危险操作边界"的认知框架。必须：
- 将"危险操作清单"写入所有Agent的固化规则
- 任何涉及基础设施变更的操作必须有"四问自检"（影响？审批？回滚？验证？）
- 涉及Gateway/nginx/systemd/Tailscale的操作全部需要审批

## 约束
**铁律一执行约束：**
1. 任何Agent在任何场景下不得执行：`gateway restart`, `gateway stop`, `openclaw gateway restart/stop`
2. 配置修改前必须执行：回滚方案是否就绪？是否已备份当前配置？
3. 涉及Gateway配置的修改必须写入 `/home/agentuser/shared/changelog/YYYY-MM-DD.md`
4. 修改完成后必须执行验证：Web UI是否可达？企微通道是否正常？

## 关联
- 铁律一（禁止自重启）
- 铁律二（改配置输出）
- 铁律六（先停后改）
- 铁律十七（基础设施变更审批）
- ERR-006: 信息断链四模式（缺"操作验证"环节）
