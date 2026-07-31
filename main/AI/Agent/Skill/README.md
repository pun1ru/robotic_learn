# Skill

## 基本信息

- 状态：进行中（Skill 工程化实现完成，白板验收待完成）
- 开始日期：2026-07-31
- 最近更新：2026-07-31
- 一级分支：AI
- 父节点：Agent
- 难度系数：3.3
- 原始来源：`whiteboard_exported_image.pdf`

## 实践目标与验收

编写一个可重复执行的“嵌入式模块审查” Skill，包含输入、步骤、检查项和输出模板；在两个不同模块上运行，人工复核清单覆盖率不低于 90%。

本次先完成了面向 `27_3SE_HERO` 双板固件工程的专用代码修改与验证 Skill。它覆盖代码修改前检查、项目规范加载、范围限定验证、双板同步提醒和安全文本替换，但还没有完成两个模块的完整运行和覆盖率统计。

## 我的问题

- Codex 对 Skill 的目录、`SKILL.md` 和 YAML frontmatter 有什么要求？
- `references/`、`scripts/` 和 `agents/openai.yaml` 应该怎样组织？
- 怎样让 Skill 只在 `27_3SE_HERO` 的嵌入式代码修改任务中触发？
- 怎样在脏工作区中只验证本次修改，不被用户已有改动干扰？

## 我的直觉

> 待我用自己的话补充：为什么这个工作流应该做成 Skill，而不只写进 `AGENTS.md`；哪些步骤适合写成说明，哪些步骤适合用脚本固定下来。

## 手写推导或设计

当前设计采用渐进加载：

```text
name + description
        |
        v
     SKILL.md
        |
        +--> references/editing-rules.md
        +--> references/validation.md
        +--> scripts/preflight.ps1
        +--> scripts/validate_changes.ps1
        `--> scripts/apply_replacements.py
```

- `description` 负责触发边界，限定双板嵌入式 C/C++、Keil、FreeRTOS、CAN、驱动、控制模块和 QP 状态机。
- `SKILL.md` 负责编排读取项目记忆、修改、验证和最终汇报流程。
- `references/` 保存项目专用规则和按风险选择的验证清单。
- `scripts/` 固定容易遗漏或需要确定性的检查与文本替换步骤。
- Skill 安装在目标仓库的 `.agents/skills/code-designer/`，只服务该工程。

## 实现与实验记录

### 条件与参数

- 目标工程：`C:\Users\liaoz\Desktop\rm\code\27_3SE_HERO`
- Skill 目录：`C:\Users\liaoz\Desktop\rm\code\27_3SE_HERO\.agents\skills\code-designer`
- 工程范围：`hero_down`、`hero_up`、Keil MDK-ARM、FreeRTOS、CAN/FDCAN、控制模块和 QP 状态机
- 测试环境：Windows PowerShell、Python 3.14、Git 工作区存在用户已有修改

### 过程

1. 建立 `SKILL.md`、`agents/openai.yaml`、两个参考文档和三个脚本。
2. 将 Skill 从学习笔记目录安装到目标工程的 `.agents/skills/code-designer/`。
3. 将过宽的触发描述收窄到该双板固件的嵌入式代码修改任务，并排除无关仓库和普通文档编辑。
4. 修正 `preflight.ps1` 与目标工程 `MEMORY.md`、`memory/*.md` 的对应关系。
5. 为 `validate_changes.ps1` 增加必需的 `-Paths` 参数，只检查本次任务明确传入的相对路径。
6. 补充已暂存、未暂存和未跟踪的新 C 文件检测，提醒同步 Keil 工程和编译数据库。
7. 将 `apply_replacements.py --check` 从仅输出匹配成功改为显示 unified diff。
8. 运行格式校验、脚本语法检查、预检和单路径验证。

本次执行的只读验证：

```powershell
python -X utf8 "<skill-creator>/scripts/quick_validate.py" "<skill-dir>"
powershell -ExecutionPolicy Bypass -File "<skill-dir>/scripts/preflight.ps1" -ProjectRoot "<project-root>"
& "<skill-dir>/scripts/validate_changes.ps1" `
    -ProjectRoot "<project-root>" `
    -Paths @("hero_up/PrivateApplications/ADRC/adrc.c")
python -X utf8 "<skill-dir>/scripts/apply_replacements.py" --help
```

## 结果与验收

| 验收项 | 目标值 | 实际值 | 是否通过 | 证据位置 |
|---|---:|---:|---|---|
| Skill 目录可被项目发现 | 位于 `.agents/skills/` | 已安装到目标工程 | 是 | `27_3SE_HERO/.agents/skills/code-designer/` |
| `SKILL.md` 格式 | 官方校验通过 | `Skill is valid!` | 是 | `code-designer/SKILL.md` |
| 触发范围 | 仅目标工程嵌入式修改 | 已限定双板固件并排除无关任务 | 是 | `SKILL.md` 的 `description` |
| 预检脚本 | 在目标工程通过 | 必需记忆文件和 Git 状态检查通过 | 是 | `scripts/preflight.ps1` |
| 范围限定验证 | 不受无关已有改动影响 | 单独验证 `adrc.c` 通过 | 是 | `scripts/validate_changes.ps1` |
| 文本替换预览 | 修改前显示差异 | 已输出 unified diff | 是 | `scripts/apply_replacements.py` |
| 输入、步骤和检查项 | 明确定义 | 已包含 | 是 | `SKILL.md`、`references/`、`scripts/` |
| 固定输出模板 | 明确定义 | 只有最终汇报要求，尚无固定模板 | 否 | 待补充 |
| 在两个不同模块上完整运行 | 2 个模块 | 0 个完整运行记录；当前只有单文件验证脚本测试 | 否 | 待实验 |
| 人工复核清单覆盖率 | 不低于 90% | 尚未统计 | 否 | 待实验 |

结论：Skill 的格式、安装、触发和辅助脚本已经达到可使用状态；白板目标仍缺输出模板、两个模块的完整运行记录和覆盖率数据，因此暂不标记为全部完成。

## 错误与修正

| 现象 | 原因 | 修正 | 如何避免再次发生 |
|---|---|---|---|
| Codex 未发现 Skill | 最初放在普通学习目录 | 移到目标仓库 `.agents/skills/` | 创建后用 `/skills` 或 `$` 检查发现结果 |
| 普通代码编辑也可能触发 | `description` 只写“编辑主项目” | 增加工程技术范围和排除条件 | 在 description 中同时写“做什么、何时使用、何时不用” |
| 预检在学习仓库失败 | 脚本要求目标固件工程专用 memory 文件 | 在真实目标工程中安装和运行 | 专用 Skill 的脚本必须在目标工程验证 |
| 无关已有修改导致验证失败 | 对整个工作区执行 `git diff --check` | 增加 `-Paths`，只检查本次路径 | 验证命令显式传入任务范围 |
| 已暂存的新 C 文件可能漏报 | 只扫描未跟踪文件 | 合并未暂存、已暂存和未跟踪新增文件 | 分别覆盖 Git index 和 worktree 状态 |
| `--check` 无法看到替换内容 | 只输出 `CHECK OK` | 输出 unified diff | 预览命令必须展示将发生的具体变化 |
| Windows 校验器读取中文失败 | Python 默认使用 GBK | 使用 `python -X utf8` | 中文 Skill 校验时显式启用 UTF-8 |

## 资料来源

- OpenAI, [Build skills](https://learn.chatgpt.com/docs/build-skills)：Skill 结构、发现位置、触发和渐进加载。
- OpenAI, [Build plugin skills](https://developers.openai.com/plugins/build/skills)：`SKILL.md`、资源目录和测试方法。
- [Agent Skills specification](https://agentskills.io/specification)：通用 Skill 格式规范。
- `27_3SE_HERO/AGENTS.md`、`MEMORY.md` 和 `memory/*.md`：目标工程规则、架构与验证要求。

## 下一步

- [ ] 在 Skill 中加入固定输出模板，至少包含范围、发现、风险、验证结果和未验证项。
- [ ] 使用 Skill 完整审查两个不同模块，保存输入、过程和原始输出。
- [ ] 按人工清单逐项复核两次输出，计算覆盖率并达到不低于 90%。
- [ ] 用自己的话补充“我的直觉”，说明 Skill、`AGENTS.md` 和脚本各自负责什么。
