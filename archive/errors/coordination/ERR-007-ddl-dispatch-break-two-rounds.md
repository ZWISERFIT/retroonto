---
id: ERR-007
type: error
category: coordination
severity: 🔴
status: active
created: 2026-07-10
source_agent: Shuyu
source_session: agent:shuyu:main
detected_by: founder
verified_by: founder
tags: [ddl, dispatch, coordination, founder-correction, pattern, cron-check]
---

## 现象
两次同模式DDL执行断链：

### 第1次（2026-06-20）
创始人DDL 08:00（Momo防幻觉方案Tristan+Stella商讨）。Shuyu在06-19归档了方案但**未向Tristan/Stella下达分派指令**，DDL逾期近2h后才补发。根因：认知环节（知道要做什么）→执行环节（实际分派）中间断链。

### 第2次（2026-06-23 13:50）
Baron上报全军制度改进建议（任务依赖管理协议）→ Shuyu确认「纳入明日战报」→ **未立即全军分派** → 13:50创始人追问才执行。
根因：「纳入战报」≠「立即分发」——与06-20「归档≠分派」完全同构。战报是汇总通道，实时指令走sessions_send。

## 根因
1. **归档=分派断链**——"我知道要做什么"和"我告诉相关Agent去做"之间没有自动连接
2. **战报≠指令通道**——错误地认为战报记录即分发完成
3. **无DDL前自检**——没有机制确保DDL前自动检查任务是否已分派

## 修复
1. 铁律：归档=分派——创始人带DDL指令 → 归档memory + sessions_send分派 = 同一动作完成
2. 铁律：制度上报=全军分发——任何Agent上报全军适用的制度改进→ sessions_send全军团 + 标记明日战报
3. 心跳DDL首检：每次心跳第一条 = 扫描今日DDL/制度变更
4. DDL cron兜底：每收到新DDL → 自动创建DDL前2h预警cron + DDL时刻终检cron

## 教训
**从"知道"到"做到"之间有一个必须自动化的转换动作。** 仅仅在头脑中记录"需要分派"是不够的——必须有立即触发的执行机制。战报是汇总通道，不是指令通道。

## 约束
**DDL执行铁律约束：**
1. 每次收到创始人带DDL的指令：归档memory + sessions_send分派 = 同一动作，禁止分两段
2. 每次Agent上报全军制度改进：sessions_send全军团 + 标记明日战报 = 同一动作，禁止拆分
3. 每次心跳第一条：扫描今日是否有创始人DDL/制度变更 → 未闭环 → 🔴立即推送
4. 每收到新DDL：自动创建DDL前2h预警cron + DDL时刻终检cron

## 关联
- MEMORY.md 🔴🔴 创始人DDL执行铁律
- 创始人口令："我需要你解决问题，不是提出问题。"
- ERR-006: 信息断链四模式（②归档≠执行）
