# C-PROCESS-VERIFICATION-EMBED: process-verification-embed-in-collaboration

| 字段 | 值 |
|------|-----|
| **严重程度** | 🔴 |
| **约束** | 任何涉及Agent产出的协同链路图必须包含Stella验证节点 |
| **来源** | SUC-002 (Stella诞生史 — Momo培训第一课) |
| **生成日期** | 2026-07-10 |

## 规则
1. 协同链路必须包含Stella验证节点（过程监管）
2. Agent产出→Stella一致性验证→通过→下一环节/退回→重做
3. 验证失败→退回→重新验证→方可通过
4. 每次验证记录写入Stella审计日志

## 任职边界
- Shuyu：结果验收——"做到什么程度"（管理出口）
- Stella：过程监管——"做得对不对"（管理过程）

## 关联
- 宪法v1.5第五条5.3节
- Stella独立审计权（宪法第四条）
- SUC-002
