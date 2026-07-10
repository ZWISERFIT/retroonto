# C-STATE-DRIFT: 禁止计数器·强制执行地面真相查询

> **来源:** ERR-003 · STATE-DRIFT四犯 (a16z/Reddit/Agent活跃度/MCP授权)
> **生成:** constraint-gen + 手动补充 (2026-07-10)
> **严重程度:** 🔴 P0
> **约束类型:** Gate — 断言前强制验证

---

## 规则正文

**任何Agent在对外报告中断言外部系统状态时，必须满足以下条件之一，否则该断言不得通过Gate发布：**

### ✅ 允许的断言形式
- `🟢 MCP正常 (实测 15:22 errcode=0)` — 带实测时间戳+证据
- `🔴 GitHub不可达 (实测 15:30 HTTP 503)` — 带实测时间戳+错误码
- ❌ `🔴 MCP授权过期D23` — 禁止计数器格式
- ❌ `🟡 Agent活跃度62h` — 禁止内部计数器

### 🔴 触发条件（4个已验证场景）
| 场景 | 地面真相来源 | 验证方式 |
|:---|:---|:---|
| 外部API状态（MCP/GitHub/GHCR/Discord） | 实时API调用 | curl/wecom_mcp/docker login |
| 文件系统状态（tracker/凭据/config） | 磁盘文件 | grep/cat/find |
| Agent活跃度 | 文件mtime + Bus事件 | agent-activity-tracker.sh (实时扫描) |
| 凭据/密钥存在性 | credentials/目录 | 文件存在检查 |

### 🚫 禁止模式
- `D+N` 计数器格式（MCP授权D23 / Discord断联D2 → 应改为"实测 15:22 正常/异常"）
- `Xh` 内部计数器格式（Agent活跃62h → 应改为"文件mtime: 2h前"）
- 未经验证的"已确认"/"已收到"/"已授权"声明

## 执行机制

每次心跳第一条检查：运行 `C-STATE-DRIFT-exec.sh`，扫描当日所有报告中是否包含禁止模式。
命中禁止模式 → 🟡 标记 → 替换为实测值 → 推Shuyu纠正。

## 版本

v1.0 · 2026-07-10 · 创始人纠正后立即生成
