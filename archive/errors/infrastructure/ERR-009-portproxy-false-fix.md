---
id: ERR-009
type: error
category: infrastructure
severity: 🔴
status: active
created: 2026-07-10
source_agent: Tristan
source_session: agent:tristan:main
detected_by: founder
verified_by:
tags: []
---

## 标题
portproxy-false-fix

## 现象
/tmp/portproxy-false-fix-detail.md

## 记录
_ID: ERR-002_ | _创建: 2026-07-10 14:27:38_ | _Agent: Tristan_ | _检测: founder_

## 完整时间线

### 2026-07-05（源头）
Discord代理修复时创建了 portproxy 规则：
```powershell
netsh interface portproxy add v4tov4 listenaddress=0.0.0.0 listenport=7890 connectaddress=127.0.0.1 connectport=7890
```
**修复完成后未删除规则。** 规则是内核持久的（iphlpsvc svchost.exe），不受创建进程生命周期影响。

### 2026-07-09（第一次"修复"—假修复）
检测到Pattern I后执行：
```powershell
# ✅ 删除规则（实际执行了）
netsh interface portproxy delete v4tov4 listenport=7890 listenaddress=0.0.0.0

# ✅ 部署安全网（实际执行了）
schtasks /create /tn "Tristan-ProxyProtect" /tr "powershell -File ...\proxy-protect.ps1" /sc minute /mo 5
```

**❌ 未做什么（三重失效）：**
1. **未验证删除结果** — 没有运行 `netsh interface portproxy show v4tov4` 确认规则真的消失
2. **未测试保护脚本** — proxy-protect.ps1 中的 portproxy 检测正则 `^\s+0\.0\.0\.0\s+7890` 有 bug：`netsh` 输出中 IP 地址从第 1 列开始无前导空白，正则的 `^\s+` 永远匹配不上 → 清理逻辑从未执行
3. **未跟踪创始人反馈** — 创始人次日反馈"问题还在"，我以为已修复所以没有复查

### 2026-07-10（Stella/Shuyu调度修复）
Stella监督+创始人执行恢复：
- Windows设置→关闭系统代理→国内访问立即恢复
- 删除 portproxy 规则→根治

## 三重失效链
| 环节 | 失效 | 违反原则 |
|:----|:-----|:--------|
| 临时规则清理 | 7/5创建规则→7/9才试图删除→实际未验证 | 铁律3：操作后必须验证 |
| 保护脚本质量 | 正则错误导致保护逻辑零执行 | 基因③："已完成"检验 |
| 创始人反馈跟踪 | 收到反馈但未升级为P0-pending | 基因⑤：公开自批判 |

## 约束
1. **README-BACK验证（C004）：** 任何网络/防火墙/代理操作声明"已完成"前，自动执行 `show/check/list` read-back 验证
2. **脚本干跑测试：** 保护脚本必须通过实际输出测试，不能仅靠语法检查
3. **创始人反馈升级协议：** "问题还在"反馈→自动升级P0→Agent-Bus广播→不能仅靠Agent自履约
