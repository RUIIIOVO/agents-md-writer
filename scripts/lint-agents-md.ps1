#Requires -Version 5.1
<#
.SYNOPSIS
    Mechanical checks for AGENTS.md / CLAUDE.md.
.DESCRIPTION
    Covers checklist rows 1-5 from SKILL.md. Rows 6-12 need a human or an agent.
    Behaviour matches scripts/lint-agents-md.sh.
.PARAMETER Path
    Files to check. Defaults to ./AGENTS.md
.EXAMPLE
    pwsh -File scripts/lint-agents-md.ps1 AGENTS.md
.OUTPUTS
    Exit 0 = no errors (warnings allowed), 1 = at least one error, 2 = usage error
#>
[CmdletBinding()]
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Path)

$script:Errors = 0
$script:Warnings = 0

function Write-Err {
    param([string]$File, [object]$Line, [string]$Message)
    Write-Host "${File}:${Line} " -NoNewline -ForegroundColor DarkGray
    Write-Host 'ERROR' -NoNewline -ForegroundColor Red
    Write-Host "   $Message"
    $script:Errors++
}

function Write-Warn {
    param([string]$File, [object]$Line, [string]$Message)
    Write-Host "${File}:${Line} " -NoNewline -ForegroundColor DarkGray
    Write-Host 'WARN' -NoNewline -ForegroundColor Yellow
    Write-Host "    $Message"
    $script:Warnings++
}

# Is this backticked token a filesystem path worth checking?
function Test-PathToken {
    param([string]$Token)
    if ($Token -match '\s') { return $false }              # a command, not a path
    if ($Token -match '^https?:|://') { return $false }    # URL
    if ($Token.StartsWith('-')) { return $false }          # CLI flag
    if ($Token -match '[*?]') { return $false }            # glob
    if ($Token -match '[<>$|&;]') { return $false }        # placeholder or shell syntax
    if ($Token -eq '/') { return $false }
    return $Token.Contains('/')
}

function Invoke-Lint {
    param([string]$File)

    if (-not (Test-Path -LiteralPath $File -PathType Leaf)) {
        Write-Err $File 0 'file not found'
        return
    }
    $dir = Split-Path -Parent (Resolve-Path -LiteralPath $File)
    $lines = Get-Content -LiteralPath $File

    # 2. YAML frontmatter
    if ($lines.Count -gt 0 -and $lines[0] -eq '---') {
        Write-Err $File 1 'YAML frontmatter: AGENTS.md has no frontmatter spec; it is injected verbatim as noise'
    }

    # 1. hardcoded developer-machine paths
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $l = $lines[$i]
        if ($l -match '<') { continue }
        if ($l -match '(/Users/[A-Za-z0-9._-]+/|/home/[A-Za-z0-9._-]+/|(^|[^A-Za-z0-9])[A-Za-z]:\\)') {
            Write-Err $File ($i + 1) 'hardcoded machine path -> use a repo-relative path, or state which machine and OS it applies to'
        }
    }

    # 3. hand-written dates
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '(19|20)\d{2}-\d{2}-\d{2}') {
            Write-Warn $File ($i + 1) 'hand-written date -> git log is the authority; this rots into a second source of truth'
        }
    }

    # 4. backticked paths that do not resolve
    $seen = @{}
    for ($i = 0; $i -lt $lines.Count; $i++) {
        foreach ($m in [regex]::Matches($lines[$i], '`([^`]+)`')) {
            $tok = $m.Groups[1].Value
            if ($seen.ContainsKey($tok)) { continue }
            $seen[$tok] = $true
            if (-not (Test-PathToken $tok)) { continue }
            $p = $tok.TrimEnd('.', ',', ':', ';')
            if ($p.StartsWith('./')) { $p = $p.Substring(2) }
            if (-not $p) { continue }
            $rel = Join-Path $dir $p
            if (-not (Test-Path -LiteralPath $rel) -and -not (Test-Path -LiteralPath $p)) {
                Write-Warn $File ($i + 1) "path does not resolve: $tok"
            }
        }
    }

    # 5. length
    if ($lines.Count -gt 200) {
        Write-Warn $File $lines.Count "$($lines.Count) lines -> push module-local rules down into subdirectory AGENTS.md files"
    } else {
        Write-Host "${File}: $($lines.Count) lines" -ForegroundColor DarkGray
    }
}

if (-not $Path -or $Path.Count -eq 0) {
    if (Test-Path -LiteralPath 'AGENTS.md' -PathType Leaf) {
        $Path = @('AGENTS.md')
    } else {
        Write-Host 'usage: lint-agents-md.ps1 [FILE ...]'
        exit 2
    }
}

foreach ($f in $Path) { Invoke-Lint $f }

Write-Host ''
if ($script:Errors -gt 0) {
    Write-Host "$($script:Errors) error(s)" -NoNewline -ForegroundColor Red
    Write-Host ", $($script:Warnings) warning(s). Checklist rows 6-12 still need manual review."
    exit 1
}
Write-Host 'Mechanical checks passed' -NoNewline -ForegroundColor Green
Write-Host " - $($script:Warnings) warning(s). Checklist rows 6-12 still need manual review."
exit 0
