# agents-md-writer

**An agent skill for writing `AGENTS.md` files that are short, verifiable, and actually followed.**

[![CI](https://github.com/RUIIIOVO/agents-md-writer/actions/workflows/ci.yml/badge.svg)](https://github.com/RUIIIOVO/agents-md-writer/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Agent Skills](https://img.shields.io/badge/Agent%20Skills-spec%20compliant-6f42c1)](https://agentskills.io/specification)

Works with **Claude Code, Codex, pi, omp, Hermes, ZCode, WorkBuddy, Grok CLI, Kimi Code, OpenClaw,
DeepSeek Harness** and anything else that loads
[Agent Skills](https://agentskills.io/specification).

[中文说明](README.zh-CN.md)

---

## Quick start

Paste this to whichever agent you are already talking to:

> Install the skill from https://github.com/RUIIIOVO/agents-md-writer

Or run it yourself — two commands:

```bash
git clone https://github.com/RUIIIOVO/agents-md-writer.git ~/.agents/skills/agents-md-writer
~/.agents/skills/agents-md-writer/scripts/install.sh
```

The first puts the skill in one shared location. The second links it into the agent you are
running right now; nothing else is touched. Add `--all` for every agent on the machine.

<details>
<summary>Windows</summary>

```powershell
git clone https://github.com/RUIIIOVO/agents-md-writer.git "$env:USERPROFILE\.agents\skills\agents-md-writer"
& "$env:USERPROFILE\.agents\skills\agents-md-writer\scripts\install.ps1"
```

`install.ps1` creates a directory junction, so no administrator rights and no Developer Mode are
needed. Add `-Symlink` for a real symbolic link, `-Copy` to copy the files instead.

</details>

How the installer picks its target: run it yourself from a terminal and it lists the agents on the
machine and asks; called by an agent, a pipe, or CI, it detects the caller and never prompts.
Re-running is safe.

### Use it on one project

Nothing to run after that. Open your agent in the project directory and just say:

```
you> write an AGENTS.md for this project
```

The agent picks up the skill, probes the repo, writes only what it verified, and lints its own
output.

### Take stock of the whole machine

Again, one sentence to your agent:

```
you> check every AGENTS.md on my machine
```

Read-only. Files are located through the filesystem index, not a recursive scan of your home
directory. You get a table of every file with its path, line count and problem count. Nothing is
touched until you name the ones to fix. By hand:

```bash
mdfind -0 -name 'AGENTS.md' | xargs -0 ./scripts/lint-agents-md.sh   # macOS
```

---

## The problem

Ask an agent to "write an AGENTS.md for this project" and you usually get back:

- Commands that were never run — `npm test` in a repo with no test script
- Paths that do not exist, copied from the README instead of the filesystem
- `/Users/alice/dev/project` hardcoded into the setup section
- 300 lines of "write clean, maintainable code", which is unverifiable and therefore free to ignore

That last one is the expensive part. AGENTS.md is injected **in full at the start of every session**,
and the more instructions you pile in, the lower the compliance rate for all of them, not just
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

One copy lives in `~/.agents/skills/`; each agent gets a link pointing at it. `git pull` once and
every linked agent is up to date — no copies to drift apart.

```bash
./scripts/install.sh                # the agent calling right now, or ask if run from a terminal
./scripts/install.sh --all          # every agent on this machine
./scripts/install.sh --agent codex  # one specific agent
./scripts/install.sh --dry-run      # show the plan, change nothing
./scripts/install.sh --where        # print "agent:" and "path:", then exit
```

`--where` is for agents: two parseable lines, zero side effects.

| Agent | Skills directory | Auto-detected |
|---|---|---|
| Claude Code | `~/.claude/skills/` | yes, via `CLAUDECODE` |
| pi | `~/.agents/skills/` (read natively) | yes, via `AI_AGENT` |
| omp | `~/.agents/skills/` (read natively) | `--agent omp` |
| Codex | `~/.codex/skills/` | `--agent codex` |
| ZCode | `~/.agents/skills/` (read natively) | `--agent zcode` |
| Hermes | `~/.hermes/skills/` | `--agent hermes` |
| WorkBuddy | `~/.workbuddy-ai/skills/` | `--agent workbuddy` |
| Gemini CLI | no skills mechanism | `--agent gemini`, see below |

The clone location is not fixed — keep the repo wherever you like and let `~/.agents/skills/` be a
link to it. The installer resolves the repo from its own location.

**Gemini CLI** has no skills mechanism, so `--agent gemini` appends a marked block to
`~/.gemini/GEMINI.md` pointing at `SKILL.md`. Nothing outside the markers is touched; delete the
block to uninstall. This only *asks* the model to read the file — there is no progressive
disclosure, so it is less reliable than a real skill. If your `GEMINI.md` is a symlink into a shared
config, the installer refuses and prints the line for you to add yourself.

Verify by asking your agent: *"what skills do you have?"*

## Usage

Any of these will make your agent reach for the skill — no command to memorise:

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
scripts/install.sh                identify the calling agent and link the skill
scripts/install.ps1               same, using Windows directory junctions
scripts/lint-agents-md.sh         mechanical checks — bash 3.2+ / zsh
scripts/lint-agents-md.ps1        same checks — PowerShell 5.1+
examples/before.md                a typical AI-generated AGENTS.md, with the usual defects
examples/after.md                 the same project, done properly
```

## The lint

Five of the twelve checklist rows are mechanical, so they are a script:

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
running it on `examples/after.md` will warn about `src/` and friends, which is expected for a
standalone sample. Point it at `AGENTS.md`, not at `SKILL.md` (skills legitimately have frontmatter).

## Why these rules

The skeleton comes from the section statistics of three real projects in the
[agents.md](https://agents.md) showcase — apache/airflow (522 lines), openai/codex (322),
temporalio/sdk-java (59). Instruction verifiability and rule consistency come from Anthropic's
[memory documentation](https://docs.claude.com/en/docs/claude-code/memory). The instruction-budget
argument comes from HumanLayer's
[*Writing a Good CLAUDE.md*](https://www.humanlayer.dev/blog/writing-a-good-claude-md): frontier
models reliably follow roughly 150–200 instructions, and adding more degrades compliance across all
of them.

Full citations and the reasoning behind the required/optional split: [`references/skeleton.md`](references/skeleton.md).

**This skill is opinionated.** Two of its positions go beyond anything in the official docs:

- **No fixed line limit.** The showcase files run to 522 lines; the official guidance says keep it
  short. Neither is a rule you can apply mechanically. The test used here is "can you delete a line
  without losing information", and when a root file grows past ~200 lines the first move is to push
  content down into subdirectory files, not to compress the prose.
- **Required sections differ from the sample statistics.** Testing and code style are demoted to
  optional because they collapse into filler in projects that have neither. The reasoning is
  documented.

Disagreement is welcome — open an issue.

## Compatibility

`AGENTS.md` is now the de facto standard. OpenClaw (388k★) and DeepSeek Harness (201k★) both ship
one; Grok CLI reads `~/.grok/AGENTS.md` and walks up from the working directory; Kimi Code carries a
dedicated `agentsMdReminder` module.

Where the skill itself installs is in [Install](#install). What matters more is where the
`AGENTS.md` it writes will actually be read:

- **Read `AGENTS.md` directly** — Codex, pi, omp, OpenCode, Grok CLI, Kimi Code / Kimi CLI,
  OpenClaw, DeepSeek Harness, Hermes, GitHub Copilot
- **Need a one-line entry file** — Claude Code (`CLAUDE.md`), Gemini CLI (`GEMINI.md`)
- **Incompatible format, never symlink** — Cursor (`.mdc` with frontmatter), Cline (`.clinerules`),
  Windsurf (`global_rules.md`)

Full matrix with per-agent evidence: [`references/agent-registry.md`](references/agent-registry.md).

Lint scripts: bash 3.2+ (the macOS system bash), zsh, or PowerShell 5.1+. No external dependencies.
Windows behaviour is verified in CI on `windows-latest` under both `pwsh` and Windows PowerShell 5.1.

## Contributing

Issues and PRs welcome. If you change a lint rule, update both scripts — CI asserts that
`examples/before.md` exits `1` and `examples/after.md` exits `0` on Linux, macOS, and Windows.

## License

[MIT](LICENSE) © liaokongrui
