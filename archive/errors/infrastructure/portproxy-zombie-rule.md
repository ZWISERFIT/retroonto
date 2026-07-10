---
id: ERR-001
type: error
category: infrastructure
severity: 🔴
status: active
created: 2026-07-10
source_agent: Tristan
source_session: agent:tristan:main
detected_by: founder
verified_by: Tristan
tags: [portproxy, windows, proxy, netsh, kernel-persistent, pattern-I]
---

## 现象
2026-07-09 创始人Windows电脑全网断连。web3jsq (mihomo v1.19.20) 运行中 + 监听 :7890 + 节点全部 alive，但所有 HTTP CONNECT 请求返回 "Proxy CONNECT aborted" (exit 56)。mihomo traffic API 返回 `{"up":0,"down":0}`——请求从未到达代理进程。

## 根因
`netsh interface portproxy` 中存在僵尸规则：
```
0.0.0.0:7890 → 127.0.0.1:7890
```
Windows IP Helper Service (iphlpsvc, PID 6392 svchost.exe) 通过 HTTP.sys/kernel 级拦截 :7890 的所有 TCP 进站连接 → 透明转发到 :7890 → 应用层无人接收。portproxy 规则是内核持久的：创建进程退出后规则仍存活。

规则创建溯源：2026-07-05 Discord 代理修复时用 `netsh interface portproxy add v4tov4 listenaddress=0.0.0.0 listenport=7890 connectaddress=127.0.0.1 connectport=7890` 暴露 WSL2 代理到 Windows，修复完成后**未删除规则**。

## 修复
```cmd
netsh interface portproxy delete v4tov4 listenport=7890 listenaddress=0.0.0.0
netsh interface portproxy delete v4tov4 listenport=22000 listenaddress=0.0.0.0
```

同步清理 portproxy 规则的 syncthing 端口 22000（同样历史的僵尸规则）。

## 预防
创建 `Tristan-ProxyProtect` 计划任务（每5分钟巡检）：
1. 检测并清理有害 portproxy 规则
2. 三路代理连通性测试
3. 连续2次失败 → 自动禁用系统代理降级直连
4. 代理恢复 → 自动重开系统代理

## 教训
`netsh interface portproxy` 创建的规则是**内核持久**的——即使创建进程退出、创建工具卸载，规则仍然存活。任何临时解决方案中使用 portproxy 必须附带清理逻辑。

## 约束
**铁律3：Windows 代理修复必须先删除 portproxy 冲突规则**
- 任何通过 SSH 操作 Windows 代理/weproxy/web3jsq 时
- 必须执行：删除 `:7890` 和 `:22000` 的 portproxy 规则
- 必须执行：安全网——删除规则后验证代理是否响应；不响应则禁用系统代理
- 必须执行：部署自动保护脚本每5分钟巡检

编写日期 2026-07-09 写入 MEMORY.md + SOUL.md

## 关联
- Pattern I: portproxy劫持代理端口（全军根因模式库）
- MEMORY.md 铁律3
- `/home/agentuser/tmp/proxy-protect.ps1`
