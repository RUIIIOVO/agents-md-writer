# agents-md-writer

**An agent skill for writing `AGENTS.md` files that are short, verifiable, and actually followed.**

[![CI](https://github.com/RUIIIOVO/agents-md-writer/actions/workflows/ci.yml/badge.svg)](https://github.com/RUIIIOVO/agents-md-writer/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Agent Skills](https://img.shields.io/badge/Agent%20Skills-spec%20compliant-6f42c1)](https://agentskills.io/specification)

Works with **Claude Code, Codex, pi, omp, Grok CLI, Kimi Code, OpenClaw, DeepSeek Harness** and
anything else that loads [Agent Skills](https://agentskills.io/specification).

[中文说明](README.zh-CN.md)

---

## Quick start

```bash
git clone https://github.com/RUIIIOVO/agents-md-writer.git
ln -s "$PWD/agents-md-writer" ~/.claude/skills/agents-md-writer   # or ~/.codex/skills, ~/.agents/skills
```

Then, in any repo:

```
you> write an AGENTS.md for this project
```

The agent probes the repo, writes only what it verified, and lints its own output. To check an
existing file instead:

```bash
./scripts/lint-agents-md.sh AGENTS.md
```

---

## The problem

Ask an agent to "write an AGENTS.md for this project" and you usually get back:

- Commands that were never run — `npm test` in a repo with no test script
- Paths that do not exist, copied from the README instead of the filesystem
- `/Users/alice/dev/project` hardcoded into the setup section
- 300 lines of "write clean, maintainable code", which is unverifiable and therefore free to ignore

That last one is the expensive part. AGENTS.md is injected **in full at the start of every session**,
and the more instructions you pile in, the lower the compliance rate for *all* of them — not just
the new ones. A padded AGENTS.md does not just waste tokens; it dilutes the rules you actually care about.

This skill makes the agent probe the repo first, write only what it verified, and check its own output.

## Before / after

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

## What it does

Three paths, picked automatically from what you ask for:

| You say | The skill |
|---|---|
| "write an AGENTS.md for this repo" | Probes the repo (never guesses commands), follows a section skeleton, runs the lint |
| "review my AGENTS.md" | **Read-only.** Verdict + `location → problem → fix` list. Does not rewrite your file |
| "clean up this AGENTS.md" | Backs up, classifies every block (keep / promote to global / push down / move to a skill / delete), shows you the table, then edits |

## Install

| Agent | Install |
|---|---|
| **Claude Code** | `ln -s "$PWD/agents-md-writer" ~/.claude/skills/agents-md-writer` |
| **Codex** | `ln -s "$PWD/agents-md-writer" ~/.codex/skills/agents-md-writer` |
| **pi** | `ln -s "$PWD/agents-md-writer" ~/.agents/skills/agents-md-writer` |
| **omp** | Same as pi — omp scans `.agents/`, `.claude/`, `.codex/` and `.github/skills/` |
| **Per-project** | `ln -s ../../agents-md-writer .claude/skills/agents-md-writer` (or `.agents/skills/`, `.codex/skills/`, `.github/skills/`) |

Windows without symlink privileges: copy the directory instead of linking.

> `~/.agents/skills/` is the widest net — pi and omp read it directly, and Claude Code / Codex
> pick it up if you symlink their directories to it.

**Gemini CLI has no skills mechanism.** Paste the contents of `SKILL.md` into your `GEMINI.md`,
or keep it as a file and add: `Read ./agents-md-writer/SKILL.md before writing project rules.`

Verify the install by asking your agent: *"what skills do you have?"*

## Usage

Trigger it in plain language:

```
初始化一下这个项目的 AGENTS.md
review my AGENTS.md
this CLAUDE.md is 400 lines, clean it up
set up project conventions for the agent
```

Or invoke it explicitly, if your agent supports it: `/skill:agents-md-writer`

## What's inside

```
SKILL.md                          the skill itself — three paths, principles, 12-row checklist
references/skeleton.md            section skeleton: required vs optional, layering, sources
references/agent-registry.md      per-agent paths, format caveats, detection over hardcoding
templates/AGENTS.md.template      blank template (English)
templates/AGENTS.zh.md.template   blank template (Chinese)
scripts/lint-agents-md.sh         mechanical checks — bash 3.2+ / zsh
scripts/lint-agents-md.ps1        same checks — PowerShell 5.1+
examples/before.md                a typical AI-generated AGENTS.md, with the usual defects
examples/after.md                 the same project, done properly
```

## The lint

Five of the twelve checklist rows are mechanical, so they are a script rather than a paragraph of advice:

| Check | Level |
|---|---|
| YAML frontmatter present | error |
| Hardcoded machine paths (`/Users/x/`, `/home/x/`, `C:\`) | error |
| Hand-written dates (`YYYY-MM-DD`) | warning |
| Backticked paths that do not resolve | warning |
| Line count over 200 | warning |

```bash
./scripts/lint-agents-md.sh                     # defaults to ./AGENTS.md
./scripts/lint-agents-md.sh AGENTS.md docs/sub/AGENTS.md
pwsh -File scripts/lint-agents-md.ps1 AGENTS.md # Windows
```

Exit code `0` = no errors, `1` = at least one error. `NO_COLOR=1` disables colour.

Paths are resolved relative to the linted file's directory, so run it against a real repo —
running it on `examples/after.md` will warn about `src/` and friends, which is correct behaviour
for a standalone sample. Point it at `AGENTS.md`, not at `SKILL.md` (skills legitimately have frontmatter).

## Why these rules

The skeleton comes from the section statistics of three real projects in the
[agents.md](https://agents.md) showcase — apache/airflow (522 lines), openai/codex (322),
temporalio/sdk-java (59). Instruction verifiability and rule consistency come from Anthropic's
[memory documentation](https://docs.claude.com/en/docs/claude-code/memory). The instruction-budget
argument — frontier models reliably follow roughly 150–200 instructions, and adding more degrades
compliance across *all* of them — comes from HumanLayer's
[*Writing a Good CLAUDE.md*](https://www.humanlayer.dev/blog/writing-a-good-claude-md).

Full citations and the reasoning behind the required/optional split: [`references/skeleton.md`](references/skeleton.md).

**This skill is opinionated.** Two of its positions go beyond anything in the official docs:

- **No fixed line limit.** The showcase files run to 522 lines; the official guidance says keep it
  short. Neither is a rule you can apply mechanically. The test used here is "can you delete a line
  without losing information", and when a root file grows past ~200 lines the first move is to push
  content down into subdirectory files, not to compress the prose.
- **Required sections differ from the sample statistics.** Testing and code style are demoted to
  optional because they collapse into filler in projects that have neither. Reasoning is documented
  rather than asserted.

Disagreement is welcome — open an issue.

## Compatibility

`AGENTS.md` is now the de facto standard. OpenClaw (388k★) and DeepSeek Harness (201k★) both ship
one; Grok CLI reads `~/.grok/AGENTS.md` and walks up from the working directory; Kimi Code carries a
dedicated `agentsMdReminder` module. Writing a good one pays off across the whole fleet.

**Where the skill installs:**

| Agent | Skills | Reads from |
|---|---|---|
| Claude Code | ✅ | `~/.claude/skills/`, `.claude/skills/` |
| Codex | ✅ | `~/.codex/skills/`, `.codex/skills/` |
| pi | ✅ | `~/.pi/agent/skills/`, `~/.agents/skills/`, `.pi/skills/`, `.agents/skills/` |
| omp | ✅ | all of the above, plus `.github/skills/` and Claude Code plugin caches |
| GitHub Copilot | ✅ | `.github/skills/` |
| Gemini CLI | ❌ | no skills mechanism — see [Install](#install) for the fallback |

**Where the AGENTS.md it writes will be read:** Codex, pi, omp, OpenCode, Grok CLI, Kimi Code /
Kimi CLI, OpenClaw, DeepSeek Harness and Copilot read `AGENTS.md` directly. Claude Code and Gemini
CLI need a one-line entry file. Cursor, Cline and Windsurf use incompatible formats and must not be
symlinked. Full matrix with evidence levels: [`references/agent-registry.md`](references/agent-registry.md).

Lint scripts: bash 3.2+ (the macOS system bash), zsh, or PowerShell 5.1+. No external dependencies.
Windows behaviour is verified in CI on `windows-latest` under both `pwsh` and Windows PowerShell 5.1.

## Contributing

Issues and PRs welcome. If you change a lint rule, update both scripts — CI asserts that
`examples/before.md` exits `1` and `examples/after.md` exits `0` on Linux, macOS, and Windows.

## License

[MIT](LICENSE) © liaokongrui
