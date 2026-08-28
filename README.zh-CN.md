# agents-md-writer

**一个 agent skill，用来写出简短、可验证、真正会被遵守的 `AGENTS.md`。**

[![CI](https://github.com/RUIIIOVO/agents-md-writer/actions/workflows/ci.yml/badge.svg)](https://github.com/RUIIIOVO/agents-md-writer/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Agent Skills](https://img.shields.io/badge/Agent%20Skills-spec%20compliant-6f42c1)](https://agentskills.io/specification)

支持 **Claude Code、Codex、pi、omp、Grok CLI、Kimi Code、OpenClaw、DeepSeek Harness**，
以及任何加载 [Agent Skills](https://agentskills.io/specification) 的工具。

[English](README.md)

---

## 快速开始

```bash
git clone https://github.com/RUIIIOVO/agents-md-writer.git
ln -s "$PWD/agents-md-writer" ~/.claude/skills/agents-md-writer   # 或 ~/.codex/skills、~/.agents/skills
```

然后在任意仓库里直接说：

```
给这个项目写一份 AGENTS.md
```

skill 会先探测仓库、只写验证过的内容，最后自己跑一遍检查。检查已有文件：

```bash
./scripts/lint-agents-md.sh AGENTS.md
```

> skill 正文是英文（省 token），但**回复会跟随你的语言**。用中文提问就得到中文回答。

---

## 要解决的问题

让 agent「给这个项目写个 AGENTS.md」，通常会得到：

- 从没跑过的命令 —— 在没有 test script 的仓库里写「跑 `npm test`」
- 不存在的路径 —— 抄 README 而不是看文件系统
- `/Users/alice/dev/project` 这种写死开发机的绝对路径
- 三百行「编写清晰、可维护的高质量代码」—— 无法验证，因此可以随便忽略

最后一条代价最大。AGENTS.md 在**每次会话开始时被全量注入**，塞的指令越多，**所有**指令的遵循率
一起下降，不只是新加的那条。臃肿的 AGENTS.md 不只是浪费 token，它会稀释掉你真正在意的规则。

这个 skill 强制 agent 先探测仓库、只写验证过的内容、再检查自己的产出。

## 改造前后

左边是典型的 AI 生成结果，右边是同一个项目写对的样子
（完整文件：[examples/before.md](examples/before.md) / [examples/after.md](examples/after.md)）。

<table>
<tr><th>before</th><th>after</th></tr>
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

根据你怎么说，自动选择：

| 你说 | skill 做什么 |
|---|---|
| 「给这个仓库写个 AGENTS.md」 | 先探测仓库（绝不猜命令），按章节骨架写，最后跑 lint |
| 「检查一下我的 AGENTS.md」 | **只读不改**。给结论 + `位置 → 问题 → 建议` 清单，不会擅自重写 |
| 「这个 CLAUDE.md 四百行，整理一下」 | 先备份，把每段分类（保留 / 上提全局 / 下沉子目录 / 移到 skill / 删除），给你过目后再动手 |

## 安装

| Agent | 命令 |
|---|---|
| **Claude Code** | `ln -s "$PWD/agents-md-writer" ~/.claude/skills/agents-md-writer` |
| **Codex** | `ln -s "$PWD/agents-md-writer" ~/.codex/skills/agents-md-writer` |
| **pi** | `ln -s "$PWD/agents-md-writer" ~/.agents/skills/agents-md-writer` |
| **omp** | 同 pi —— omp 会扫描 `.agents/`、`.claude/`、`.codex/` 和 `.github/skills/` |
| **项目级** | `ln -s ../../agents-md-writer .claude/skills/agents-md-writer` |

Windows 上没有软链权限就直接复制目录。

> `~/.agents/skills/` 覆盖面最广 —— pi 和 omp 直接读，Claude Code / Codex 把自己的目录软链过去即可。

**Gemini CLI 没有 skills 机制。** 把 `SKILL.md` 内容贴进 `GEMINI.md`，
或者在里面写一句：`写项目规范前先读 ./agents-md-writer/SKILL.md`。

装完问一句「你现在有哪些 skill」就能确认。

## 目录结构

```
SKILL.md                          skill 本体 —— 三条路径、写作原则、12 项自检
references/skeleton.md            章节骨架：必备 vs 按需、分层、出处
references/agent-registry.md      各 agent 的路径矩阵、格式差异、探测优于硬编码
templates/AGENTS.md.template      空模板（英文）
templates/AGENTS.zh.md.template   空模板（中文）
scripts/lint-agents-md.sh         机械检查 —— bash 3.2+ / zsh
scripts/lint-agents-md.ps1        同样的检查 —— PowerShell 5.1+
examples/before.md                典型的 AI 生成结果，毛病齐全
examples/after.md                 同一个项目写对的样子
```

## lint

12 项自检里有 5 项是纯机械的，所以做成了脚本而不是一段建议：

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

路径是相对于被检查文件所在目录解析的，所以要在真实仓库里跑。直接检查 `examples/after.md`
会对 `src/` 之类报警告，这对一个独立样本文件来说是正确行为。另外别拿它检查 `SKILL.md` ——
skill 文件本来就该有 frontmatter。

## 这些规则的依据

章节骨架来自 [agents.md](https://agents.md) 官方 showcase 三个真实项目的章节统计 ——
apache/airflow（522 行）、openai/codex（322 行）、temporalio/sdk-java（59 行）。
指令可验证性与规则一致性来自 Anthropic 的
[memory 文档](https://docs.claude.com/en/docs/claude-code/memory)。
指令预算 —— 前沿模型可靠遵循约 150–200 条指令，超出后**所有**指令的遵循率一起下降 ——
来自 HumanLayer 的 [《Writing a Good CLAUDE.md》](https://www.humanlayer.dev/blog/writing-a-good-claude-md)。

完整引用与「必备 / 按需」划分的推理过程见 [`references/skeleton.md`](references/skeleton.md)。

**这个 skill 是有立场的。** 有两条主张超出了官方文档：

- **不设固定行数上限。** showcase 里的文件有 522 行，官方建议又说越短越好，两者都不能机械套用。
  这里用的判断标准是「能不能删掉一行而不损失信息」；根文件超过约 200 行时，第一反应应该是把内容
  下沉到子目录文件，而不是压缩措辞。
- **必备章节与样本统计不一致。** 测试和编码规范被降为按需，因为在没有测试框架、没有格式化工具的
  项目里它们会变成套话。理由写在文档里，而不是直接断言。

不同意欢迎开 issue。

## 兼容性

`AGENTS.md` 已经是事实标准：OpenClaw（388k★）和 DeepSeek Harness（201k★）仓库里都有；
Grok CLI 读 `~/.grok/AGENTS.md` 并从工作目录向上查找；Kimi Code 专门有一个 `agentsMdReminder`
模块。写好一份，整套工具链都受益。

**skill 装在哪：**

| Agent | Skills | 读取位置 |
|---|---|---|
| Claude Code | ✅ | `~/.claude/skills/`、`.claude/skills/` |
| Codex | ✅ | `~/.codex/skills/`、`.codex/skills/` |
| pi | ✅ | `~/.pi/agent/skills/`、`~/.agents/skills/`、`.pi/skills/`、`.agents/skills/` |
| omp | ✅ | 上述全部，外加 `.github/skills/` 和 Claude Code 插件缓存 |
| GitHub Copilot | ✅ | `.github/skills/` |
| Gemini CLI | ❌ | 无 skills 机制 —— 见[安装](#安装)的降级方案 |

**写出来的 AGENTS.md 谁会读：** Codex、pi、omp、OpenCode、Grok CLI、Kimi Code / Kimi CLI、
OpenClaw、DeepSeek Harness、Copilot 都直接读 `AGENTS.md`；Claude Code 和 Gemini CLI 需要一个
一行的入口文件；Cursor、Cline、Windsurf 格式不兼容，**不能软链**。
完整矩阵及证据等级见 [`references/agent-registry.md`](references/agent-registry.md)。

lint 脚本需要 bash 3.2+（macOS 自带版本）、zsh 或 PowerShell 5.1+，无外部依赖。
Windows 行为由 CI 在 `windows-latest` 上用 `pwsh` 和 Windows PowerShell 5.1 双重验证。

## 贡献

欢迎 issue 和 PR。改动 lint 规则时两个脚本都要改 —— CI 会在 Linux、macOS、Windows 上断言
`examples/before.md` 退出码为 `1`、`examples/after.md` 为 `0`。

## 许可

[MIT](LICENSE) © liaokongrui
