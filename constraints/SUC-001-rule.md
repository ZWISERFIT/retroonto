---
id: SUC-001
type: success
category: infrastructure
severity: 🟢
status: active
created: 2026-07-10
source_agent: Tristan
source_session: agent:tristan:main
detected_by: agent
verified_by: Shuyu
tags: [syncthing, systemd, watchdog, self-healing]
---

## 标题
Syncthing 系统自愈闭环（Pattern F→G→H 根因修复链）

## 现象
Syncthing 服务周期性崩溃（Pattern F: systemd 重启死亡螺旋 → Pattern G: KillSignal=SIGKILL 破坏性重启 → Pattern H: QUIC UDP 端口泄漏）。每个模式被识别、诊断、修复，形成完整的根因修复链。

## 成功原因
1. **分级诊断**：不满足于表面修复（加 KillSignal=SIGKILL），继续深挖根因
2. **完整修复链**：override.conf 逐步优化（KillMode=mixed → 移除 KillSignal → 增加 ExecStopPre 端口清理）
3. **文档同步**：每个修复都写入 MEMORY.md + TOOLS.md + 全军根因模式库

## 成果
- 服务 uptime 从每2h崩溃 → 连续运行24h+稳定
- 0 人工介入的自愈闭环
- 根因模式库新增3个模式（F/G/H），供全军参考

## 可复用的模式
1. Lock contention → KillMode=mixed
2. 优雅退出被破坏 → 不要用 SIGKILL 覆盖默认 SIGTERM
3. UDP 端口泄漏 → ExecStartPre 前置清理

## 约束
**Syncthing自愈模式重用约束：**
1. 任何systemd服务出现周期性崩溃时，执行分级诊断：L1-锁和KillSignal → L2-端口争用和双重服务 → L3-根本root cause
2. 不要满足于表面修复——加KillSignal=SIGKILL不是修复，是掩盖
3. 每次修复必须：文档同步至MEMORY.md + 全军根因模式库 + 关联条目
4. 重复模式且修复后仍有复发 → 升级根因探索非表面修复

## 关联
- Pattern F / G / H（全军根因模式库）
- TOOLS.md systemd 用户服务 cgroup 陷阱
