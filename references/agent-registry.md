# Agent registry

Where each agent looks for its instruction file, and what that means for entry points.

**These are external facts that rot.** Re-verify before relying on any row. Evidence level is
recorded per agent so you know how much to trust it.

## Reads AGENTS.md directly

No entry file needed — `AGENTS.md` at the repo root is enough.

| Agent | User level | Project level | Evidence |
|---|---|---|---|
| Codex | `~/.codex/AGENTS.md` | `AGENTS.md` (walk-up) | omp `discovery/codex.ts` |
| pi | `~/.pi/agent/AGENTS.md`, `~/.agents/AGENTS.md` | `.pi/`, `.agents/`, `AGENTS.md` | pi `docs/skills.md` + local install |
| omp | `~/.omp/agent/AGENTS.md` + every path in this table | same | omp `src/discovery/` |
| OpenCode | `~/.config/opencode/AGENTS.md` | `AGENTS.md`, `opencode.json` | omp `discovery/opencode.ts` |
| Grok CLI | `~/.grok/AGENTS.md` | `AGENTS.md` (walk-up), `AGENTS.override.md` | source: `src/utils/instructions.ts` |
| Kimi Code / Kimi CLI | — | `AGENTS.md` | source: `packages/agent-core-v2/src/agent/agentsMdReminder/` |
| OpenClaw | — | `AGENTS.md` (also ships `CLAUDE.md`, `.claude/`, `.agents/`) | repo layout |
| DeepSeek Harness | — | `AGENTS.md`, `.agents/notes/AGENTS.md` | repo layout |
| GitHub Copilot | `~/.copilot/copilot-instructions.md` | `.github/copilot-instructions.md`, `AGENTS.md` | omp `discovery/github.ts` |

## Needs a thin entry file

Same content, different filename. One line pointing at `AGENTS.md`.

| Agent | Reads | Entry file to create |
|---|---|---|
| Claude Code | `CLAUDE.md`, `.claude/` | `CLAUDE.md` containing `@AGENTS.md` |
| Gemini CLI | `~/.gemini/GEMINI.md`, `.gemini/GEMINI.md`, `system.md` | `GEMINI.md`. The `@` import syntax is **unverified** here — use prose: `Project conventions live in ./AGENTS.md. Read it before starting work.` |

## Different format — do not symlink

These use a format that a plain `AGENTS.md` does not satisfy. Adapt the content, or skip them.

| Agent | Reads | Why a symlink breaks |
|---|---|---|
| Cursor | `.cursor/rules/*.mdc`, legacy `.cursorrules` | `.mdc` requires frontmatter (`description`, `globs`, `alwaysApply`). A plain markdown file may be ignored or always-applied unintentionally. |
| Cline | `.clinerules` (file or directory) | No `.md` extension; plain text convention. |
| Windsurf | `~/.codeium/windsurf/memories/global_rules.md`, `.windsurf/rules/*.md` | User-level path is outside the usual `~/.<agent>/` layout, under `~/.codeium/`. |

## No skills mechanism

Gemini CLI loads context files but has no skills directory. To use a skill with it, paste the
`SKILL.md` body into `GEMINI.md`, or reference the file by path in prose.

## Unverified

No authoritative source found for these. **Do not write paths for them.** Ask the user, or detect
by scanning.

- WorkBuddy — only third-party skill collections found, no harness repository
- "Hermes" coding agent — no authoritative repository; the name may refer to something else

## Detection instead of a hardcoded list

New agents appear constantly and every row above can go stale. Prefer detecting what is actually
installed:

1. List `~/.<name>/` directories one level deep. Do not recurse.
2. Inside each, look for known filenames: `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`,
   `copilot-instructions.md`, `global_rules.md`, `*.mdc`, `.clinerules`.
3. For each hit, record whether it is a real file or a symlink, and where it points.
4. Report. Let the user decide what to converge.

Fast whole-disk lookup without recursive scanning:

```bash
mdfind -name 'AGENTS.md'                                    # macOS, Spotlight index
mdfind -onlyin ~/work 'kMDItemFSName == "AGENTS.md"'        # scoped
plocate AGENTS.md                                           # Linux, if the index exists
es.exe AGENTS.md                                            # Windows, Everything CLI
find <dir> -maxdepth 4 -name AGENTS.md                      # fallback, always scope it
```

Never run an unbounded recursive scan over `$HOME`.

## Symlink vs copy

| Level | Symlink? |
|---|---|
| User config (`~/.claude/`, `~/.codex/`, ...) | ✅ Fine. This is how you keep one source of truth across agents. |
| Inside a git repo | ❌ Committed symlinks degrade into plain text files containing a path on Windows and some CI runners. Use a one-line entry file instead. |

A symlink does **not** save memory or tokens. Every agent still reads the full content into context.
The only benefit is that the copies cannot drift apart.
