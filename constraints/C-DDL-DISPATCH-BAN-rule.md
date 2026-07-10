# C-DDL-DISPATCH-BAN: ddl-dispatch-same-action

| 字段 | 值 |
|------|-----|
| **严重程度** | 🔴 |
| **约束** | 创始人带DDL指令必须归档+sessions_send分派同一动作完成，禁止分两段 |
| **来源** | ERR-007 (2026-06-20/06-23 两次DDL执行断链) |
| **生成日期** | 2026-07-10 |

## 规则
1. 归档=分派：创始人带DDL指令 → 归档memory + sessions_send分派 = 同一动作，禁止分两段
2. 制度上报=全军分发：任何Agent上报全军适用的制度改进 → sessions_send全军团 + 标记明日战报
3. 心跳DDL首检：每次心跳第一条 = 扫描今日DDL → 未闭环 → 🔴立即推送
4. DDL cron兜底：收到新DDL → 自动创建DDL前2h预警cron + DDL时刻终检cron

## 关联
- MEMORY.md 🔴🔴 创始人DDL执行铁律
- ERR-007
- ERR-006 (信息断链②:归档≠执行)
