# C-SIDE-EFFECT-CHECK: 基础设施操作副作用预估约束

> **来源:** RetroOnto模式挖掘 · 跨3个错误聚类
> **严重程度:** 🔴 P0
> **约束类型:** Gate — 操作前检查

---

## 规则正文

**凡涉及以下基础设施操作，执行前必须列出完整影响面清单：**

### 触发操作
| 操作 | 常见副作用 |
|:---|:---|
| `systemctl restart` / 服务重启 | 依赖服务级联停止 |
| `net stop/start` (Windows) | Tailscale等依赖服务 |
| `iptables` / `netsh` 变更 | 网络连通性中断 |
| Gateway重启 | WebUI短暂不可达 |
| `docker restart` | 容器链中断 |

### 影响面清单（必须逐项回答）
1. 该服务有哪些**下游依赖**？
2. 重启期间**谁会受影响**？
3. **恢复时间**预估？
4. **验证方法**是什么？
5. **回滚方案**？

### 违反时
- 立即停止操作
- 写入 ERR-xxx
- Stella标记审计

## 覆盖的错误
- ERR-004: gateway-restart-crash (重启→宕机)
- ERR-008: three-miskill-webui-outage (三误杀→WebUI 9h断联)
- ERR-009: portproxy-false-fix (iphlpsvc重启→Tailscale断联)

## 版本
v1.0 · 2026-07-10 · RetroOnto自动模式挖掘
