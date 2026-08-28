---
name: agents-md-writer
description: Write, review, or refactor AGENTS.md / CLAUDE.md project instruction files. Use when the user asks to "initialize AGENTS.md", "write project rules", "review my AGENTS.md", "clean up CLAUDE.md", "set up project conventions for the agent", or says 写项目规范 / 初始化 AGENTS.md / 检查 AGENTS.md 是否合规 / 整理项目规范. Ships a section skeleton, writing principles, and a lint script.
license: MIT
compatibility: Lint scripts need bash 3.2+ or zsh (macOS, Linux), or PowerShell 5.1+ (Windows). No external dependencies; jq and git are optional conveniences. The skill itself works without any of them.
---

# AGENTS.md Writer

**Reply in the user's language.** These instructions are in English for token efficiency; that does
not dictate the conversation language. If the user writes in Chinese, answer in Chinese — including
the review findings and the confirmation prompts.

AGENTS.md is a project-level instruction file. Codex, pi, omp, Grok CLI, Kimi Code, OpenClaw,
DeepSeek Harness and others inject it **in full, at the start of every session**.

Two consequences drive everything below:

1. Every line is resident context — **line count is a cost you pay on every single session**.
2. The more instructions you add, the lower the compliance rate for **all** of them, not just the new ones.

So the goal is not coverage. It is **economy**: every line must earn its place.

Scope: AGENTS.md holds **project facts** (how to run, test, commit).
Personal preferences belong in the global agent config, not here.

## Pick a path

| User intent | Path |
|---|---|
| No AGENTS.md yet, create one | **A — Write** |
| File exists, check it for problems | **B — Review** (do not edit) |
| File exists, rewrite / merge / trim | **C — Refactor** |

## Path A — Write

### 1. Probe. Never guess.

Wrong commands and dead paths are the number one defect in these files. Verify before writing.

```bash
ls -A                                   # repo root
jq '.scripts' package.json 2>/dev/null  # npm scripts (no jq? read the file — do not truncate with grep -A)
cat pyproject.toml 2>/dev/null          # Python deps and test config
cat Cargo.toml 2>/dev/null              # Rust
find . -maxdepth 1 \( -name Makefile -o -name '*.mk' -o -name 'dev-*.sh' \)
git log --format=%s -20                 # existing commit style
```

PowerShell equivalents: `Get-ChildItem -Force`, `(Get-Content package.json | ConvertFrom-Json).scripts`.

**Do not use shell globs to probe.** Under zsh, `ls *.mk` with no match aborts the whole command
before `ls` ever runs, and `2>/dev/null` cannot suppress it — the error comes from the shell, not
from `ls`. Use `find`.

- The project README can be wrong. **The filesystem is the source of truth.**
- Verify every path as you write it, then re-verify the whole file at the end.
- If you cannot verify a command, **do not write it**. Mark it as a known gap. Never invent one.

### 2. Follow the skeleton

Sections, ordering, required vs optional: [`references/skeleton.md`](references/skeleton.md).

Blank templates: [`templates/AGENTS.md.template`](templates/AGENTS.md.template) (English),
[`templates/AGENTS.zh.md.template`](templates/AGENTS.zh.md.template) (Chinese).
Delete whole sections that do not apply. Do not leave placeholders behind.

### 3. Run the checks

```bash
./scripts/lint-agents-md.sh AGENTS.md          # macOS / Linux
pwsh -File scripts/lint-agents-md.ps1 AGENTS.md  # Windows
```

The lint covers the mechanical checks. Run the rest by hand — see [Checklist](#checklist).

### 4. Add entry points for other agents

See [Entry points](#entry-points).

## Path B — Review

**Read only. Do not edit.**

1. Read the file, walk the [Checklist](#checklist) top to bottom.
2. Verify three things for real:
   - **Commands** — run the read-only ones. For anything with side effects, check it is at least
     declared (e.g. present in `jq '.scripts' package.json`).
   - **Paths** — `test -e` each one.
   - **Conflicts** — against the global config and any other AGENTS.md in the repo.
3. Report: one-line verdict (fine / needs fixes / rewrite), then a list of
   `location → problem → suggested fix`.

Do not rewrite the file. The user asked for a diagnosis.

## Path C — Refactor

1. `cp AGENTS.md AGENTS.md.bak` and tell the user where the backup is.
2. Classify every existing block and show the table before touching anything:

   | Destination | What goes there |
   |---|---|
   | Keep in project | Project facts: layout, commands, boundaries, conventions |
   | Promote to global | Personal preferences: language, output style, local machine setup |
   | Push down to subdirectory | Rules that only concern one module |
   | Move to a skill | Multi-step procedures, low-frequency specialist knowledge |
   | Delete | Stale content, meta-rules, hand-written dates, one-off requests |

3. Get confirmation, then edit.
4. Re-run the checklist.

## Writing principles

| Principle | Why |
|---|---|
| Make every instruction **verifiable** | "Run `npm test`" is executable. "Test your changes" is not. |
| Never let two rules contradict | On conflict the model picks one at random. Behaviour becomes unpredictable. |
| Keep it as short as it can be | See the two consequences at the top. When it grows, **push down** before you trim wording. |
| No YAML frontmatter | AGENTS.md has no frontmatter spec. Loaders inject it as plain markdown, so it lands in context verbatim as noise. |
| No hand-written dates or version stamps | `git log` is the authority. A hand-typed date rots into a second source of truth. |
| No meta-rules ("this file only describes how to...") | Written for the human maintainer. Does not change agent behaviour. Pure budget. |
| Multi-step procedures, module-local content | Move to a skill or a subdirectory AGENTS.md. Keep them out of the root file. |
| Pointers to external docs go **last** | The top of the file is for the hardest constraints. |

### Length

**No hard line limit.** The test is: can you delete a line without losing information?

Rough scale: an ordinary repo needs about 100 lines. If a monorepo root file passes ~200 lines,
that is a signal to push content down into subdirectory files, not to compress the prose.

For calibration, the `agents.md` showcase includes files of 522 and 322 lines. Those are examples of
module-local content piling up in the root file — a caution, not a target.

### Verifiable instructions

| ✗ | ✓ |
|---|---|
| Follow the project code style | Run `cargo fmt && cargo clippy -- -D warnings` before committing |
| Mind test coverage | New logic needs a case in `tests/`; run `pytest tests/ -x` |
| Do not touch core modules | `src/kernel/` is read-only. Propose a plan and wait for approval before changing it. |
| Use appropriate log levels | Use `logger.debug` for diagnostics. `print` is forbidden. |

### Global vs project

Ask whether the rule **still holds in a different repo**. Yes → global. No → project.

| Rule | Belongs to | Why |
|---|---|---|
| "Always answer in Chinese" | Global | Holds anywhere. It is a personal preference. |
| "Match the existing commit style in `git log`" | Global | The method is universal. |
| "Commits here use `feat(scope): ...`" | Project | It is a fact about this repo. |
| "Never read `.env`" | Global | Universal safety floor. |
| "`config/secrets.yml` is ops-owned, do not edit" | Project | Names a specific file in this repo. |

## Entry points

Keep **one source of truth plus thin entry files** — never maintain parallel copies.

| Situation | Action |
|---|---|
| Codex, pi, omp, OpenCode, Grok CLI, Kimi Code, OpenClaw, DeepSeek Harness, Copilot | Nothing to do. They read `AGENTS.md` directly. |
| Claude Code | Create `CLAUDE.md` containing one line: `@AGENTS.md` |
| Gemini CLI | Create `GEMINI.md` with prose pointing at `AGENTS.md` |
| Cursor, Cline, Windsurf | **Different formats — do not symlink.** See the registry. |

Per-agent paths, evidence levels, format caveats, and how to detect installed agents instead of
hardcoding a list: [`references/agent-registry.md`](references/agent-registry.md).

- **Do not use symlinks for project-level entry files.** Committed symlinks degrade into plain text
  files containing a path on Windows and some CI runners. Symlinks are fine for user-level config
  (`~/.claude/`, `~/.codex/`).
- Check `.gitignore` does not already exclude `CLAUDE.md` or `GEMINI.md`.
- If the user only runs one agent, create only that one entry file.

## Checklist

Rows 1–5 are covered by `scripts/lint-agents-md.sh` / `.ps1`. Run the rest by hand.

| # | Check | How | Auto |
|---|---|---|---|
| 1 | No hardcoded developer-machine paths | `/Users/<name>/`, `/home/<name>/`, `C:\...`. Machine-bound paths (remote hosts, external tool installs) must state which machine and OS. | ✅ |
| 2 | No YAML frontmatter | First line is not `---` | ✅ |
| 3 | No hand-written dates | No `YYYY-MM-DD` in body text | ✅ |
| 4 | Referenced paths exist | Every backticked path resolves on disk | ✅ |
| 5 | Length is justified | Report line count; flag root files over ~200 lines for push-down | ✅ |
| 6 | Commands actually run | Execute read-only ones. Declared-only for the rest. Mark unverifiable ones as known gaps. | |
| 7 | Cross-platform commands are complete | If the project is developed on multiple OSes, give portable commands or list them per platform and label which is which. | |
| 8 | Referenced tools exist | "Run ESLint" requires an ESLint config in the repo. Otherwise label it a known gap. | |
| 9 | No contradictions | Look for "always X" next to "never X" | |
| 10 | Review items are verifiable | The review section lists **verification actions**, not "do not do X" (that belongs in Boundaries). Items needing a human — visual diffs, real-device runs — must be marked "human verifies this; AI must not claim it is done". | |
| 11 | Subdirectory files do not repeat the parent | Diff against the root file; keep only the differences. | |
| 12 | Entry files exist | See [Entry points](#entry-points), or confirm they are gitignored. | |

## Content that belongs elsewhere

- **Runtime prompts or deployment artifacts placed at the repo root as AGENTS.md.** The agent will
  read them as constraints on working *in* this repo. They are not.
- **One-off requests, temporary plans, single-iteration goals.** These go in `docs/` or an issue.
