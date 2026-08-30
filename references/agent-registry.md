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
| Hermes | `~/.hermes/config.yaml` | `AGENTS.md` | repo layout (NousResearch/hermes-agent) |

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

## Skills directories

Where a skill package is installed, as opposed to where the instruction file is read from.

| Agent | Skills directory | Evidence |
|---|---|---|
| Claude Code | `~/.claude/skills/`, `.claude/skills/` | pi `docs/skills.md`, local install |
| Codex | `~/.codex/skills/`, `.codex/skills/` | omp `discovery/codex.ts` |
| pi, omp | `~/.agents/skills/`, `~/.pi/agent/skills/`, `.agents/skills/` | pi `docs/skills.md` |
| GitHub Copilot | `.github/skills/` | omp `discovery/github.ts` |
| Hermes | `~/.hermes/skills/`, `$HERMES_HOME/skills/` | source, see below |
| ZCode | `~/.agents/skills/`, `~/.zcode/skills/`, `.agents/skills/`, `.zcode/skills/` | app source, see below |
| WorkBuddy | `~/.workbuddy-ai/skills/` | app source, see below |

**Hermes** (`hermes_cli`, `tools/skills_tool.py`):

```python
def get_hermes_home() -> Path:
    val = (os.environ.get("HERMES_HOME") or "").strip()
    return Path(val).resolve() if val else (Path.home() / ".hermes").resolve()

SKILLS_DIR = HERMES_HOME / "skills"   # "All skills live in ~/.hermes/skills/"
```

**ZCode** resolves four roots, two of them shared with pi and omp:

```js
function f1(){ return yn(ly(), ".agents", "skills") }   // getUserAgentsSkillRoot
function Tp(){ return yn(ly(), ".zcode", "skills") }    // getUserZcodeSkillRoot
function $Ke(e){ return yn(e, ".agents", "skills") }    // getWorkspaceAgentsSkillRoot
function d1(e){ return yn(e, ".zcode", "skills") }      // getWorkspaceZcodeSkillRoot
// ly = resolveUserHomeDir = $HOME || $USERPROFILE
```

Since ZCode reads `~/.agents/skills/` natively, a skill already installed there needs no link.

**WorkBuddy** (Tencent) resolves its skills directory in three steps:

```js
getDefaultConfigDirname() // product.json → dataFolderName: ".workbuddy-ai"
getWorkbuddyConfigDir()   // $WORKBUDDY_CONFIG_DIR || path.join(homedir(), <above>)
getWorkbuddySkillsDir()   // path.join(configDir, "skills")
```

So `~/.workbuddy-ai/skills/`, overridable with `WORKBUDDY_CONFIG_DIR`. Bundled skills under
`WorkBuddy AI.app/.../builtin-plugins/*/skills/*/SKILL.md` use standard `name` + `description`
frontmatter.

Beware `~/.workbuddy` — it exists too, but only holds `binaries/` and `logs/`. A third-party
registry lists it as the config directory; that is wrong for skills purposes.

Hermes, ZCode and WorkBuddy are desktop applications rather than CLIs, so there is no environment
variable to detect the caller from. Pass `--agent` explicitly.

They also create their config directory only on **first launch**. Detecting an installed agent by
config directory alone misses one that has been installed but never run, so check the application
bundle too (`/Applications/ZCode.app`, `/Applications/WorkBuddy AI.app`, `/Applications/Hermes.app`).

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
