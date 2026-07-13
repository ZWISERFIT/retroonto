# C-FERRUM-LITE-GATE: Isolated cron session轻量预检

> **来源:** Shuyu建议 (2026-07-13 04:30) · 心跳诊断aftermath
> **严重程度:** 🟡 P2
> **约束类型:** Process — cron session启动前置检查

---

## 规则正文

**所有isolated cron session在启动时，prompt中应包含以下命令调用：**

```bash
bash /path/to/ferrum-lite-check.sh
```

该检查覆盖：
1. **API分页认知（C-API-PAGINATION）：** 读取 `total` 不读 `limit`
2. **URL格式（C-FOUNDER-URL-FORMAT-CHECK）：** 对外交付URL正确性
3. **State Drift快速扫描：** 关键state文件存在性

### 违反时
isolated session产生因分页/URL格式导致的假阳性告警 → Stella标记审计

## 覆盖的记录
- 2026-07-13 04:22: daily-research cron误读cron list分页

## 版本
v1.0 · 2026-07-13 · Shuyu/Tristan
