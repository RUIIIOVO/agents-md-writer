#!/usr/bin/env bash
# lint-agents-md.sh — mechanical checks for AGENTS.md / CLAUDE.md
#
# Usage:  ./lint-agents-md.sh [FILE ...]        (defaults to ./AGENTS.md)
# Exit:   0 = no errors (warnings allowed), 1 = at least one error, 2 = usage error
#
# Covers checklist rows 1-5 from SKILL.md. Rows 6-12 need a human or an agent.

set -u

RED=''; YLW=''; GRN=''; DIM=''; RST=''
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  RED=$'\033[31m'; YLW=$'\033[33m'; GRN=$'\033[32m'; DIM=$'\033[2m'; RST=$'\033[0m'
fi

errors=0
warnings=0

err()  { printf '%s%s:%s%s %sERROR%s   %s\n' "$DIM" "$1" "$2" "$RST" "$RED" "$RST" "$3"; errors=$((errors+1)); }
warn() { printf '%s%s:%s%s %sWARN%s    %s\n' "$DIM" "$1" "$2" "$RST" "$YLW" "$RST" "$3"; warnings=$((warnings+1)); }

# Is this backticked token a filesystem path worth checking?
is_path_token() {
  case $1 in
    *[[:space:]]*) return 1 ;;   # a command, not a path
    http*|*://*)   return 1 ;;   # URL
    -*)            return 1 ;;   # CLI flag
    *'*'*|*'?'*)   return 1 ;;   # glob
    *'<'*|*'>'*)   return 1 ;;   # <placeholder>
    *'$'*|*'|'*|*'&'*|*';'*) return 1 ;;
    /)             return 1 ;;
    */*)           return 0 ;;   # contains a separator -> treat as path
    *)             return 1 ;;
  esac
}

lint_file() {
  local file=$1 dir line num rest tok p lines seen
  dir=$(dirname "$file")

  if [ ! -f "$file" ]; then
    err "$file" 0 "file not found"
    return
  fi

  # 2. YAML frontmatter
  if [ "$(head -n 1 "$file")" = "---" ]; then
    err "$file" 1 "YAML frontmatter: AGENTS.md has no frontmatter spec; it is injected verbatim as noise"
  fi

  # 1. hardcoded developer-machine paths
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    num=${line%%:*}
    err "$file" "$num" "hardcoded machine path -> use a repo-relative path, or state which machine and OS it applies to"
  done < <(grep -nE '(/Users/[A-Za-z0-9._-]+/|/home/[A-Za-z0-9._-]+/|(^|[^A-Za-z0-9])[A-Za-z]:\\)' "$file" | grep -v '<' || true)

  # 3. hand-written dates
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    num=${line%%:*}
    warn "$file" "$num" "hand-written date -> git log is the authority; this rots into a second source of truth"
  done < <(grep -nE '(19|20)[0-9]{2}-[0-9]{2}-[0-9]{2}' "$file" || true)

  # 4. backticked paths that do not resolve (in file order, first occurrence only)
  seen=' '
  while IFS= read -r line; do
    num=${line%%:*}
    rest=${line#*:}
    while IFS= read -r tok; do
      [ -n "$tok" ] || continue
      case $seen in *" $tok "*) continue ;; esac
      seen="$seen$tok "
      is_path_token "$tok" || continue
      p=${tok%[.,:;]}
      p=${p#./}
      [ -n "$p" ] || continue
      if [ ! -e "$dir/$p" ] && [ ! -e "$p" ]; then
        warn "$file" "$num" "path does not resolve: $tok"
      fi
    done < <(printf '%s\n' "$rest" | grep -oE '`[^`]+`' | tr -d '`')
  done < <(grep -n '`' "$file" || true)

  # 5. length
  lines=$(wc -l < "$file" | tr -d ' ')
  if [ "$lines" -gt 200 ]; then
    warn "$file" "$lines" "$lines lines -> push module-local rules down into subdirectory AGENTS.md files"
  else
    printf '%s%s: %s lines%s\n' "$DIM" "$file" "$lines" "$RST"
  fi
}

if [ $# -eq 0 ]; then
  if [ -f AGENTS.md ]; then set -- AGENTS.md; else
    printf 'usage: %s [FILE ...]\n' "${0##*/}" >&2; exit 2
  fi
fi

for f in "$@"; do lint_file "$f"; done

printf '\n'
if [ "$errors" -gt 0 ]; then
  printf '%s%d error(s)%s, %d warning(s). Checklist rows 6-12 still need manual review.\n' "$RED" "$errors" "$RST" "$warnings"
  exit 1
fi
printf '%sMechanical checks passed%s — %d warning(s). Checklist rows 6-12 still need manual review.\n' "$GRN" "$RST" "$warnings"
exit 0
