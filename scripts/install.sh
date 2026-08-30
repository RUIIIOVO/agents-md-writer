#!/usr/bin/env bash
# install.sh — link this skill into the agent you are currently running.
#
#   ./scripts/install.sh              detect the calling agent, link only that one
#   ./scripts/install.sh --where      print "agent:" and "path:" and exit (no changes)
#   ./scripts/install.sh --agent NAME one specific agent (see the list below)
#   ./scripts/install.sh --all        link every agent found on this machine
#   ./scripts/install.sh --dry-run    print what would happen, change nothing
#
# Supported agents:
#   claude     Claude Code   ~/.claude/skills/    auto-detected
#   codex      Codex         ~/.codex/skills/
#   pi         pi            ~/.agents/skills/    auto-detected
#   omp        omp           ~/.agents/skills/
#   hermes     Hermes        ~/.hermes/skills/        ($HERMES_HOME)
#   zcode      ZCode         ~/.agents/skills/ — read natively, usually nothing to do
#   workbuddy  WorkBuddy     ~/.workbuddy-ai/skills/  ($WORKBUDDY_CONFIG_DIR)
#   gemini     Gemini CLI    no skills mechanism; appends a block to GEMINI.md
#
# Run from a terminal it asks which agent to use. Run by an agent, a pipe or CI
# it detects the caller, and errors out rather than guessing. Safe to re-run.
#
# Exit: 0 ok, 1 error, 2 usage error

set -eu

# zsh does not word-split unquoted parameters, so `for a in $ALL_AGENTS` would
# see one long string and find no agents at all. Only matters when the script is
# invoked as `zsh install.sh`; the shebang path is unaffected.
if [ -n "${ZSH_VERSION:-}" ]; then setopt SH_WORD_SPLIT; fi

MODE=auto
DRY=0
WANT=

while [ $# -gt 0 ]; do
  case $1 in
    --where)   MODE=where ;;
    --all)     MODE=all ;;
    --dry-run) DRY=1 ;;
    --agent)   shift; [ $# -gt 0 ] || { echo "--agent needs a value" >&2; exit 2; }; MODE=explicit; WANT=$1 ;;
    --agent=*) MODE=explicit; WANT=${1#--agent=} ;;
    # Print the header block in full. A hardcoded line range silently truncates
    # the agent list every time the comment grows.
    -h|--help) awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

RED=''; YLW=''; GRN=''; CYN=''; DIM=''; BLD=''; RST=''
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  RED=$'\033[31m'; YLW=$'\033[33m'; GRN=$'\033[32m'; CYN=$'\033[36m'
  DIM=$'\033[2m'; BLD=$'\033[1m'; RST=$'\033[0m'
fi

# Resolve the repo from this script's own location, never from $PWD.
SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd -P)
REPO=$(cd -- "$SCRIPT_DIR/.." && pwd -P)
NAME=$(basename "$REPO")

[ -f "$REPO/SKILL.md" ] || { printf '%serror%s: %s has no SKILL.md\n' "$RED" "$RST" "$REPO" >&2; exit 1; }

ALL_AGENTS='claude codex pi omp hermes zcode gemini workbuddy'

label_of() {
  case $1 in
    claude) echo 'Claude Code' ;; codex) echo 'Codex' ;; pi) echo 'pi' ;;
    omp) echo 'omp' ;; hermes) echo 'Hermes' ;; zcode) echo 'ZCode' ;;
    gemini) echo 'Gemini CLI' ;; workbuddy) echo 'WorkBuddy' ;; *) echo "$1" ;;
  esac
}

hermes_home() { echo "${HERMES_HOME:-$HOME/.hermes}"; }
workbuddy_home() { echo "${WORKBUDDY_CONFIG_DIR:-$HOME/.workbuddy-ai}"; }

# Desktop apps only create their config directory on first launch, so an
# installed-but-never-run app has to be recognised by its bundle as well.
is_installed() {
  case $1 in
    claude) [ -d "$HOME/.claude" ] ;;
    codex) [ -d "$HOME/.codex" ] ;;
    pi) [ -d "$HOME/.pi/agent" ] || [ -d "$HOME/.agents" ] ;;
    omp) [ -d "$HOME/.omp/agent" ] ;;
    gemini) [ -d "$HOME/.gemini" ] ;;
    hermes) [ -d "$(hermes_home)" ] || [ -d '/Applications/Hermes.app' ] ;;
    zcode) [ -d "$HOME/.zcode" ] || [ -d '/Applications/ZCode.app' ] ;;
    workbuddy)
      [ -d "$(workbuddy_home)" ] || [ -d "$HOME/.workbuddy" ] ||
        [ -d '/Applications/WorkBuddy AI.app' ] ;;
    *) return 1 ;;
  esac
}

# Where the skill has to be visible for that agent. pi and omp both read
# ~/.agents/skills, so that is the shared home and needs no link of its own.
# Empty means "no known skills directory" — see references/agent-registry.md.
skills_of() {
  case $1 in
    claude) echo "$HOME/.claude/skills" ;; codex) echo "$HOME/.codex/skills" ;;
    pi|omp|zcode) echo "$HOME/.agents/skills" ;;
    hermes) echo "$(hermes_home)/skills" ;;
    workbuddy) echo "$(workbuddy_home)/skills" ;;
    *) echo '' ;;
  esac
}

# Identify the caller from environment variables set by the agent itself.
detect_caller() {
  [ "${CLAUDECODE:-}" = '1' ] && { echo claude; return; }
  case ${AI_AGENT:-} in pi) echo pi; return ;; claude|claude-code) echo claude; return ;; esac
  [ "${PI_CODING_AGENT:-}" = 'true' ] && { echo pi; return; }
  echo ''
}

installed_agents() {
  out=''
  for a in $ALL_AGENTS; do is_installed "$a" && out="$out$a "; done
  echo "$out"
}

say() { printf '  %s%-14s%s %s\n' "$BLD" "$(label_of "$1")" "$RST" "$2"; }

link_one() {
  agent=$1
  skills=$(skills_of "$agent")
  target="$skills/$NAME"

  # The shared home needs no link: pi and omp read it directly.
  if [ "$skills" = "$HOME/.agents/skills" ] && [ "$REPO" = "$target" ]; then
    say "$agent" "${GRN}reads this location natively${RST} ${DIM}$REPO${RST}"
    return 0
  fi

  if [ -L "$target" ]; then
    current=$(cd -- "$(dirname -- "$target")" && cd -- "$(readlink "$target")" 2>/dev/null && pwd -P || echo '')
    if [ "$current" = "$REPO" ]; then
      say "$agent" "${GRN}already linked${RST} ${DIM}$target${RST}"
      return 0
    fi
    say "$agent" "${YLW}replace${RST} $target ${DIM}(was -> $current)${RST}"
  elif [ -e "$target" ]; then
    say "$agent" "${RED}blocked${RST} $target exists and is not a link ${DIM}— move it aside${RST}"
    return 1
  else
    say "$agent" "${CYN}link${RST} $target"
  fi

  [ "$DRY" -eq 1 ] && return 0
  mkdir -p "$skills"
  rm -f "$target"
  ln -s "$REPO" "$target"
}

# Gemini has no skills mechanism. Append a marked block to GEMINI.md instead,
# so it can be detected and removed cleanly. Never touches anything outside it.
BEGIN_MARK='<!-- BEGIN agents-md-writer -->'
END_MARK='<!-- END agents-md-writer -->'

link_gemini() {
  f="$HOME/.gemini/GEMINI.md"

  # GEMINI.md is frequently a symlink into a shared config file. Appending would
  # write through it and mutate that file instead. Refuse and let the user decide.
  if [ -L "$f" ]; then
    real=$(cd -- "$(dirname -- "$f")" && cd -- "$(dirname -- "$(readlink "$f")")" 2>/dev/null && pwd -P)/$(basename -- "$(readlink "$f")")
    say gemini "${RED}blocked${RST} $f is a symlink"
    printf '  %s-> %s%s\n' "$DIM" "$real" "$RST"
    printf '  %sAppending would modify that file. Add this line there yourself if you want it:%s\n' "$DIM" "$RST"
    printf '  %sRead %s/SKILL.md before writing or reviewing AGENTS.md / CLAUDE.md files.%s\n' "$DIM" "$REPO" "$RST"
    return 1
  fi

  if [ -f "$f" ] && grep -qF "$BEGIN_MARK" "$f" 2>/dev/null; then
    say gemini "${GRN}already referenced${RST} ${DIM}$f${RST}"
    return 0
  fi
  say gemini "${CYN}append reference block${RST} $f ${DIM}(no skills mechanism)${RST}"
  [ "$DRY" -eq 1 ] && return 0
  mkdir -p "$HOME/.gemini"
  {
    [ -s "$f" ] && printf '\n'
    printf '%s\n' "$BEGIN_MARK"
    printf 'Read %s/SKILL.md before writing or reviewing AGENTS.md / CLAUDE.md files.\n' "$REPO"
    printf '%s\n' "$END_MARK"
  } >> "$f"
}

# Supported but absent from this machine. Listed so the menu is not mistaken
# for the full set of agents this skill supports.
uninstalled_agents() {
  for a in $ALL_AGENTS; do
    if ! is_installed "$a"; then printf '%s ' "$a"; fi
  done
}

labels_of() {
  out=''
  for a in "$@"; do
    if [ -n "$out" ]; then out="$out, "; fi
    out="$out$(label_of "$a")"
  done
  printf '%s' "$out"
}

install_one() {
  case $1 in
    gemini) link_gemini ;;
    *) link_one "$1" ;;
  esac
}

# A human at a terminal can be asked. Anything else (agent, pipe, CI) cannot.
choose_interactively() {
  found=$(installed_agents)
  [ -n "$found" ] || return 1
  printf 'Which agent? %s(you are in a terminal, so I can ask)%s\n\n' "$DIM" "$RST" >&2
  i=0
  for a in $found; do i=$((i+1)); printf '  %s%d%s) %s\n' "$CYN" "$i" "$RST" "$(label_of "$a")" >&2; done
  printf '  %sa%s) all of them\n' "$CYN" "$RST" >&2
  missing=$(uninstalled_agents)
  [ -n "$missing" ] && printf '\n%salso supported, not installed here: %s%s\n' \
    "$DIM" "$(labels_of $missing)" "$RST" >&2
  printf '\nChoice [1-%d/a]: ' "$i" >&2
  read -r reply || return 1
  reply=${reply%"$(printf '\r')"}   # ptys and Git Bash hand back a trailing CR
  case $reply in
    a|A|all) echo '--all'; return 0 ;;
    ''|*[!0-9]*) return 1 ;;
  esac
  [ "$reply" -ge 1 ] 2>/dev/null && [ "$reply" -le "$i" ] || return 1
  i=0
  for a in $found; do i=$((i+1)); [ "$i" -eq "$reply" ] && { echo "$a"; return 0; }; done
  return 1
}

# --- where -------------------------------------------------------------------
if [ "$MODE" = where ]; then
  caller=$(detect_caller)
  if [ -z "$caller" ]; then
    printf 'agent: unknown\npath:  unknown\n'
    printf '%shint: pass --agent with one of: %s%s\n' "$DIM" "$ALL_AGENTS" "$RST" >&2
    exit 1
  fi
  printf 'agent: %s\n' "$caller"
  printf 'path:  %s/%s\n' "$(skills_of "$caller")" "$NAME"
  exit 0
fi

printf '%sskill%s   %s\n' "$BLD" "$RST" "$REPO"
[ "$DRY" -eq 1 ] && printf '%sdry run — nothing will be written%s\n' "$DIM" "$RST"
printf '\n'

rc=0
case $MODE in
  explicit)
    case " $ALL_AGENTS " in
      *" $WANT "*) ;;
      *) printf '%serror%s: unknown agent "%s". Valid: %s\n' "$RED" "$RST" "$WANT" "$ALL_AGENTS" >&2; exit 2 ;;
    esac
    install_one "$WANT" || rc=1
    ;;
  all)
    found=$(installed_agents)
    [ -n "$found" ] || { printf '%sno agents found under $HOME%s\n' "$YLW" "$RST"; exit 1; }
    for a in $found; do install_one "$a" || rc=1; done
    ;;
  auto)
    caller=$(detect_caller)
    if [ -z "$caller" ] && [ -t 0 ] && [ -t 1 ]; then
      picked=$(choose_interactively) || {
        printf '\n%scancelled%s\n' "$YLW" "$RST" >&2; exit 1; }
      printf '\n'
      if [ "$picked" = '--all' ]; then
        for a in $(installed_agents); do install_one "$a" || rc=1; done
      else
        install_one "$picked" || rc=1
      fi
    elif [ -z "$caller" ]; then
      printf '%serror%s: cannot identify the calling agent.\n\n' "$RED" "$RST" >&2
      printf 'Re-run with --agent NAME, where NAME is one of: %s\n' "$ALL_AGENTS" >&2
      printf 'Or use --all to link every agent found here:%s\n' "$DIM" >&2
      for a in $(installed_agents); do printf '  %s\n' "$(label_of "$a")" >&2; done
      missing=$(uninstalled_agents)
      if [ -n "$missing" ]; then
        printf 'Also supported, not installed here: %s\n' "$(labels_of $missing)" >&2
      fi
      printf '%s' "$RST" >&2
      exit 1
    else
      install_one "$caller" || rc=1
    fi
    ;;
esac

printf '\n'
if [ "$rc" -ne 0 ]; then
  printf '%sBlocked.%s Move the listed paths aside and re-run.\n' "$RED" "$RST"
  exit 1
fi
if [ "$DRY" -eq 1 ]; then
  printf 'Dry run complete. Re-run without --dry-run to apply.\n'
else
  printf '%sDone.%s Ask your agent: "what skills do you have?"\n' "$GRN" "$RST"
fi
