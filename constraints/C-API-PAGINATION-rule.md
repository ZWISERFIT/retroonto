# C-API-PAGINATION: API分页响应误读禁止

> **来源:** 2026-07-13 daily-research cron误读 `cron list limit=1`
> **严重程度:** 🟡 P2
> **约束类型:** Education — 认知规则

---

## 规则正文

**所有Agent使用OpenClaw API时的分页响应处理规则：**

### 正确解读
```json
{
  "total": 13,
  "limit": 1, 
  "offset": 0,
  "hasMore": true
}
```
- `total` = 实际总数（13个cron作业）
- `limit` = 本次请求的页面大小（仅1条）
- `hasMore = true` = 还有更多未显示

### 禁止行为
❌ 将 `limit` 误解为 `total`
❌ 单靠 `hasMore = false` 判断总数
❌ 使用 limit=1 查询并声称"只有1个"

### 正确做法
✅ 读取 `total` 字段获取真实总数
✅ 需要全量数据时不传limit或用默认
✅ 分页场景用 `offset` 继续请求下一页

## 违反历史
- 2026-07-13 04:22: daily-research cron使用limit=1查询cron list → 报告"cron jobs从13+降到只有1个" → 假阳性

## 版本
v1.0 · 2026-07-13 · Tristan
