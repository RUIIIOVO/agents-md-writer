# agents-md-writer

**一个 agent skill，用来写出简短、可验证、真正会被遵守的 `AGENTS.md`。**

[![CI](https://github.com/RUIIIOVO/agents-md-writer/actions/workflows/ci.yml/badge.svg)](https://github.com/RUIIIOVO/agents-md-writer/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Agent Skills](https://img.shields.io/badge/Agent%20Skills-spec%20compliant-6f42c1)](https://agentskills.io/specification)

支持 **Claude Code、Codex、pi、omp、Hermes、ZCode、WorkBuddy、Grok CLI、Kimi Code、OpenClaw、
DeepSeek Harness**，以及任何加载 [Agent Skills](https://agentskills.io/specification) 的工具。

[English](README.md)

---

## 快速开始

直接把这句贴给你正在用的那个 agent：

> 安装这个 skill：https://github.com/RUIIIOVO/agents-md-writer

或者自己跑，两条命令：

```bash
git clone https://github.com/RUIIIOVO/agents-md-writer.git ~/.agents/skills/agents-md-writer
~/.agents/skills/agents-md-writer/scripts/install.sh
```

第一条把 skill 放到共享位置，第二条只链到你当前在用的这个 agent，其他的不动。加 `--all` 则全部链上。

<details>
<summary>Windows</summary>

```powershell
git clone https://github.com/RUIIIOVO/agents-md-writer.git "$env:USERPROFILE\.agents\skills\agents-md-writer"
& "$env:USERPROFILE\.agents\skills\agents-md-writer\scripts\install.ps1"
```

`install.ps1` 建的是目录联接（junction），不需要管理员权限，也不需要开发者模式。加
`-Symlink` 改建真符号链接，加 `-Copy` 改为直接复制文件。

</details>

安装脚本怎么知道要装到哪个 agent：你在终端里手动跑，它把本机的 agent 列出来问你选；
由 agent、管道或 CI 调用，它自己认出调用者，不弹提示。重复跑不会出错。

### 在单个项目中使用

装完之后不需要再跑任何命令。在项目目录里打开 agent，直接跟它说：

```
你> 给这个项目写一份 AGENTS.md
```

agent 会自动调用这个 skill，先探测仓库、只写验证过的内容，最后自己跑一遍检查。

### 盘点整台机器

同样是跟 agent 说一句话：

```
你> 检查一下我电脑上所有的 AGENTS.md
```

只读。通过文件系统索引定位，不递归扫描你的 home 目录。你会拿到一张表：每个文件的路径、行数、
问题数量。你不点名要改哪个，它一个字都不动。手动版本：

```bash
mdfind -0 -name 'AGENTS.md' | xargs -0 ./scripts/lint-agents-md.sh   # macOS
```

> skill 正文是英文（省 token），但回复会跟随你的语言。用中文提问就得到中文回答。

---

## 要解决的问题

让 agent「给这个项目写个 AGENTS.md」，通常会得到：

- 从没跑过的命令：在没有 test script 的仓库里写「跑 `npm test`」
- 不存在的路径：抄 README 而不是看文件系统
- `/Users/alice/dev/project` 这种写死开发机的绝对路径
- 三百行「编写清晰、可维护的高质量代码」：无法验证，因此可以随便忽略

最后一条代价最大。AGENTS.md 在**每次会话开始时被全量注入**，塞的指令越多，所有指令的遵循率
一起下降，不只是新加的那条。臃肿的 AGENTS.md 不只是浪费 token，它会稀释掉你真正在意的规则。

这个 skill 强制 agent 先探测仓库、只写验证过的内容、再检查自己的产出。

## 改造前后

左边是典型的 AI 生成结果，右边是同一个项目写对的样子。

<table>
<tr><th><a href="examples/before.md">examples/before.md</a></th><th><a href="examples/after.md">examples/after.md</a></th></tr>
<tr valign="top"><td>

```md
## Setup

The project lives in
/Users/alice/dev/acme-api. Clone it
and run the setup script. You will
need Node and a database.

Start the dev server with the usual
command. Tests can be run with the
test runner.

## Review Checklist

- [ ] Code is well written
- [ ] Do not commit secrets
- [ ] Tests pass
- [ ] The UI looks correct
```

</td><td>

```md
## Environment & commands

Prerequisites: Node 20+, pnpm 9+,
Docker (for Postgres).

- **Install**: `pnpm install`
- **Dev server**: `pnpm dev` (port 3000)
- **Reset database**: `pnpm db:reset`

## Review checklist

- [ ] `pnpm typecheck` passes
- [ ] `pnpm lint` passes, zero warnings
- [ ] The changed endpoint was actually
      called — compiling is not verification

**A human verifies these. AI must not
claim they are done**: staging smoke
test, dashboard visuals.
```

</td></tr>
</table>

```console
$ ./scripts/lint-agents-md.sh examples/before.md
examples/before.md:1  ERROR   YAML frontmatter: AGENTS.md has no frontmatter spec; it is injected verbatim as noise
examples/before.md:30 ERROR   hardcoded machine path -> use a repo-relative path, or state which machine and OS it applies to
examples/before.md:3  WARN    hand-written date -> git log is the authority; this rots into a second source of truth

2 error(s), 1 warning(s). Checklist rows 6-12 still need manual review.
```

## 三条路径

看你怎么说，自动走其中一条：

| 你说 | skill 做什么 |
|---|---|
| 「给这个仓库写个 AGENTS.md」 | 先探测仓库（绝不猜命令），按章节骨架写，最后跑 lint |
| 「检查一下我的 AGENTS.md」 | **只读不改**。给结论 + `位置 → 问题 → 建议` 清单，不会擅自重写 |
| 「这个 CLAUDE.md 四百行，整理一下」 | 先备份，把每段分类（保留 / 上提全局 / 下沉子目录 / 移到 skill / 删除），给你过目后再动手 |

## 安装

实体只一份，放在 `~/.agents/skills/`，各 agent 各链一条过去。`git pull` 一次，所有链上的 agent 都是新的，
不会分裂成几份副本。

```bash
./scripts/install.sh                # 当前调用它的 agent；在终端里跑则问你装哪个
./scripts/install.sh --all          # 本机所有 agent
./scripts/install.sh --agent codex  # 指定一个
./scripts/install.sh --dry-run      # 只看计划，不改东西
./scripts/install.sh --where        # 输出 agent 和路径两行就退
```

`--where` 是给 AI 用的：两行可解析，不碰任何文件。

| Agent | skills 目录 | 能否自动识别 |
|---|---|---|
| Claude Code | `~/.claude/skills/` | 能，看 `CLAUDECODE` |
| pi | `~/.agents/skills/`（原生读取） | 能，看 `AI_AGENT` |
| omp | `~/.agents/skills/`（原生读取） | 用 `--agent omp` |
| Codex | `~/.codex/skills/` | 用 `--agent codex` |
| ZCode | `~/.agents/skills/`（原生读取） | 用 `--agent zcode` |
| Hermes | `~/.hermes/skills/` | 用 `--agent hermes` |
| WorkBuddy | `~/.workbuddy-ai/skills/` | 用 `--agent workbuddy` |
| Gemini CLI | 无 skills 机制 | 用 `--agent gemini`，见下 |

clone 到哪里都行。仓库放在你自己的工作区，让 `~/.agents/skills/` 反过来指向它，一样能用。
脚本从自身位置找仓库根，不看 `$PWD`。

**Gemini CLI** 没有 skills 机制，`--agent gemini` 会向 `~/.gemini/GEMINI.md` 追加一个带标记的引用块，
指向 `SKILL.md`。标记外的内容一字不改，删掉这个块就算卸载。但它只是叫模型去读那个文件，
没有 progressive disclosure，没真正的 skill 机制可靠。如果你的 `GEMINI.md` 是指向共享配置的软链，
脚本会拒绝写入，把要加的那行打印出来让你自己放。

装完问一句「你现在有哪些 skill」就能确认。

## 怎么用

下面这几种说法都能让 agent 调到这个 skill，不用记命令：

```
初始化一下这个项目的 AGENTS.md
检查一下我的 AGENTS.md
这个 CLAUDE.md 四百行了，整理一下
给 agent 配一份项目规范
```

如果你的 agent 支持显式调用：`/skill:agents-md-writer`

## 目录结构

```
SKILL.md                          skill 本体 —— 三条路径、写作原则、12 项自检
references/skeleton.md            章节骨架：必备 vs 按需、分层、出处
references/agent-registry.md      各 agent 的路径矩阵、格式差异、探测优于硬编码
templates/AGENTS.md.template      空模板（英文）
templates/AGENTS.zh.md.template   空模板（中文）
scripts/install.sh                识别调用者并建立链接
scripts/install.ps1               同上，Windows 用目录联接
scripts/lint-agents-md.sh         机械检查 —— bash 3.2+ / zsh
scripts/lint-agents-md.ps1        同样的检查 —— PowerShell 5.1+
examples/before.md                典型的 AI 生成结果，常见毛病都齐
examples/after.md                 同一个项目写对的样子
```

## lint

12 项自检里有 5 项是纯机械的，所以做成了脚本：

| 检查项 | 级别 |
|---|---|
| 存在 YAML frontmatter | error |
| 写死开发机路径（`/Users/x/`、`/home/x/`、`C:\`） | error |
| 手填日期（`YYYY-MM-DD`） | warning |
| 反引号里的路径不存在 | warning |
| 行数超过 200 | warning |

```bash
./scripts/lint-agents-md.sh                     # 默认检查 ./AGENTS.md
./scripts/lint-agents-md.sh AGENTS.md docs/sub/AGENTS.md
pwsh -File scripts/lint-agents-md.ps1 AGENTS.md # Windows
```

退出码 `0` 表示无 error，`1` 表示至少一个 error。`NO_COLOR=1` 关闭彩色。

lint 按被检查文件所在的目录解析路径，所以要在真实仓库里跑。直接检查 `examples/after.md`
会对 `src/` 之类报警告，独立样本文件本来就该这样。另外别拿它检查 `SKILL.md`，
skill 文件本来就该有 frontmatter。

## 这些规则的依据

章节骨架来自 [agents.md](https://agents.md) 官方 showcase 三个真实项目的章节统计：
apache/airflow（522 行）、openai/codex（322 行）、temporalio/sdk-java（59 行）。
指令可验证性与规则一致性来自 Anthropic 的
[memory 文档](https://docs.claude.com/en/docs/claude-code/memory)。
指令预算的说法来自 HumanLayer 的
[《Writing a Good CLAUDE.md》](https://www.humanlayer.dev/blog/writing-a-good-claude-md)：
前沿模型可靠遵循约 150–200 条指令，超出后所有指令的遵循率一起下降。

完整引用与「必备 / 按需」划分的推理过程见 [`references/skeleton.md`](references/skeleton.md)。

**这个 skill 是有立场的。** 有两条主张超出了官方文档：

- **不设固定行数上限。** showcase 里的文件有 522 行，官方建议又说越短越好，两者都不能机械套用。
  这里用的判断标准是「能不能删掉一行而不损失信息」；根文件超过约 200 行时，第一反应应该是把内容
  下沉到子目录文件，而不是压缩措辞。
- **必备章节与样本统计不一致。** 测试和编码规范被降为按需，因为在没有测试框架、没有格式化工具的
  项目里它们会变成套话。理由写在文档里。

不同意欢迎开 issue。

## 兼容性

`AGENTS.md` 已经是事实标准：OpenClaw（388k★）和 DeepSeek Harness（201k★）仓库里都有；
Grok CLI 读 `~/.grok/AGENTS.md` 并从工作目录向上查找；Kimi Code 专门有一个 `agentsMdReminder`
模块。

skill 自己装在哪看[安装](#安装)。更要紧的是它写出来的 `AGENTS.md` 谁会读：

- **直接读 `AGENTS.md`** —— Codex、pi、omp、OpenCode、Grok CLI、Kimi Code / Kimi CLI、
  OpenClaw、DeepSeek Harness、Hermes、GitHub Copilot
- **需要一行入口文件** —— Claude Code（`CLAUDE.md`）、Gemini CLI（`GEMINI.md`）
- **格式不兼容，切勿软链** —— Cursor（`.mdc` 带 frontmatter）、Cline（`.clinerules`）、
  Windsurf（`global_rules.md`）

逐个 agent 的完整矩阵和证据见 [`references/agent-registry.md`](references/agent-registry.md)。

lint 脚本需要 bash 3.2+（macOS 自带版本）、zsh 或 PowerShell 5.1+，无外部依赖。
Windows 行为由 CI 在 `windows-latest` 上用 `pwsh` 和 Windows PowerShell 5.1 双重验证。

## 贡献

欢迎 issue 和 PR。改动 lint 规则时两个脚本都要改。CI 会在 Linux、macOS、Windows 上断言
`examples/before.md` 退出码为 `1`、`examples/after.md` 为 `0`。

## 许可

[MIT](LICENSE) © liaokongrui
