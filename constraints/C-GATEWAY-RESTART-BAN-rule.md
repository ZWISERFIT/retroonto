# C-GATEWAY-RESTART-BAN: gateway-restart-fatal-ban

| 字段 | 值 |
|------|-----|
| **严重程度** | 🔴 |
| **Gate类型** | 执行前拦截 |
| **约束** | 任何Agent在任何场景下不得自行执行 gateway restart/stop 命令 |
| **来源** | ERR-004 (2026-04-24 网关宕机事件) |
| **生成日期** | 2026-07-10 |

## 禁止命令列表
- `gateway restart`
- `gateway stop`
- `openclaw gateway restart`
- `openclaw gateway stop`
- 任何包含`gateway`相关重启/停止的操作

## 正确做法
- Gateway相关操作必须由创始人手动执行
- 如需操作→输出命令给创始人→创始人执行
- 其他基础设施变更→先写changelog→再执行→后验证

## 关联
- 铁律一（禁止自重启）
- 铁律二（改配置输出）
- 铁律六（先停后改）
- 铁律十七（基础设施变更审批）
- ERR-004
