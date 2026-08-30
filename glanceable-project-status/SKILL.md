---
name: glanceable-project-status
description: Convert authorized Git, Gate, State, Artifact, Agent, Node, test, and log information into concise, evidence-linked project status reports. Use when the user asks for project progress, blockers, handoff state, next steps, or a human-readable explanation of machine project state. Do not use as a state writer, workflow executor, or generic literature summarizer.
---

# Glanceable Project Status

把项目真实状态转换为读者可以快速定位、判断和继续行动的说明。保持项目事实和专业术语，不把机器标签机械翻译成低信息量白话。

## 核心边界

- 只在当前任务授权和项目声明的范围内读取；默认只读。
- 先识别项目自己的状态所有者和规则，不用通用惯例覆盖项目事实。
- 分开表达产物存在、技术验证、领域或业务接受以及整体完成。
- Agent 结束、Gate PASS、Node 前进或 Artifact 存在都不能单独证明项目完成。
- 来源冲突、时间过旧或范围未核验时，明确写成未知或覆盖缺口。
- 不修改状态、运行工作流、批准结果或扫描未授权位置。
- 输出遵循最小披露；默认使用项目相对路径，不展示与判断无关的姓名、用户名、邮箱、账号标识、用户目录前缀、主机地址或其他私人信息。
- 不复述令牌、密钥、口令、会话凭据或疑似敏感值；只说明敏感信息存在及其对任务的影响。

## 选择执行路径

### 读取真实项目

用户要求检查当前项目或给出项目路径时，先读 [source-discovery.md](references/source-discovery.md)。建立来源覆盖清单后再写状态报告。

如果缺少真实项目路径或项目声明的外部状态位置不可读，报告 `NOT_TESTED` 或 `PARTIAL`，不得猜测完整状态。

### 转换已提供的状态快照

用户已经给出边界清楚的状态事实时，可以不做项目发现；把这些事实视为本次声明范围，并明确未独立核验的部分。

输入含 Gate、State、Artifact、Agent、Node、日志、检查结果或来源冲突时，读 [transformation-rules.md](references/transformation-rules.md)。

## 读者与语言

需要按专业度、阅读目的、时间或证据需求调整，或输出中文报告时，读 [reader-contract.md](references/reader-contract.md)。

只使用当前问题上的领域熟悉度、阅读目的、时间预算和证据需求。不要用年龄、学历、职业、人格或隐蔽行为建立读者画像。适配可以改变解释和展开程度，不得改变事实、风险和证据强度。

## 生成报告

正式状态报告必须读：

- [symbol-system.md](references/symbol-system.md)：固定符号、状态判定和顺序。
- [output-contract.md](references/output-contract.md)：总览、密度、证据和省略规则。

执行顺序：

1. 确认授权范围、来源覆盖和用户要作出的判断。
2. 建立最小事实集，区分当前、历史、候选、推论和未知。
3. 把机器对象转换成对项目步骤、质量和下一动作的实际影响；先说用户获得了什么，再说内部如何实现。
4. 先判断语义，再选择固定符号。
5. 保留领域术语；默认不假定读者熟悉项目内部文件、Gate、Agent 或 Node，必要时增加一句语境桥接。
6. 按“一句话总览 → 用户可理解的状态成果 → 问题或阻塞 → 下一步 → 实现与证据依据”输出。
7. 检查是否存在状态升级、符号漂移、被隐藏的阻塞或无证据结论。

需要确定性结构检查时运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/lint-status-report.ps1 -Path <report.md>
```

结构检查通过只证明格式不变量通过，不证明项目事实、来源覆盖或用户理解已经验收。

## 迁移边界

文献汇报只作为共享表达原则的迁移测试。普通文献总结、论文写作或科研审查不应因本 Skill 自动改用项目状态模板。
