---
id: ERR-002
type: error
category: coordination
severity: 🟡
status: active
created: 2026-07-10
source_agent: Tristan
source_session: agent:tristan:main
detected_by: founder
verified_by: Shuyu
tags: [url-format, founder-review, canvas-path, coordination]
---

## 现象
Shuyu 在交付创始人审阅链接时，多次使用 `__openclaw__/canvas/` 路径或裸文件系统路径（如 `/home/agentuser/...`），而非标准审阅 URL 格式。创始人点击后要么需要 Web UI 登录，要么弹出文件下载。

统计：3次同类错误/9天内（2026-06-25 ~ 2026-07-04）

## 根因
1. **来源缺失**——创始人审阅 URL 标准格式（2026-07-01 创始人终端确认）未写入任何 Agent 的 SOUL.md 或固化规则
2. **空转规则**——治理执行架构交叉验证报告（2026-07-05）确认：78条提取规则中 46条（59%）处于空转状态——原则已写但没翻译成"条件→动作"
3. **无执行前自检**——发送 URL 前没有自检步骤确认 URL 是否为 `:8444/share/` 格式

## 修复
1. 2026-07-01 创始人确认标准格式：`https://vm-0-11-ubuntu.tail80182d.ts.net:8444/share/<文件名>`
2. 增加 HTML+交互审阅框要求（铁律二十一）
3. 目录分享必须带 index.html（避免 autoindex 下载弹窗）

## 教训
**原则→条件→动作 翻译链断裂。** 仅仅写下一份"知识"不构成"规则"。必须：
- 知识：写入 permanent-knowledge
- 规则：写入 SOUL.md 执行前自检
- 条件：每次发送 URL 前触发
- 动作：验证 URL 格式 + nginx 可达性

## 约束
**发送创始人审阅 URL 前必须执行：**
1. URL 格式检查：必须是 `https://vm-0-11-ubuntu.tail80182d.ts.net:8444/share/` 开头
2. 文件存在检查：`ls /home/agentuser/share/` 确认文件存在
3. HTTP 可达检查：`curl --max-time 5 -o /dev/null -s -w "%{http_code}" "<URL>"` 返回 200
4. 目录分享特例：如果路径是目录，必须确认目录内有 index.html
5. 所有 4 项通过才能发送

## 关联
- 铁律二十一：创始人审阅URL必须为HTML+交互审阅框
- 治理执行架构交叉验证报告（2026-07-05）
- `SHARED_CAPABILITIES.md` 对外交付标准
