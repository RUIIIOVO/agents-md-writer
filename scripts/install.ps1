#Requires -Version 5.1
<#
.SYNOPSIS
    Link this skill into the agent you are currently running.
.DESCRIPTION
    Mirrors scripts/install.sh. Run from a terminal it asks which agent to use.
    Run by an agent, a pipe or CI it detects the caller, and errors out rather
    than guessing.

    Supported agents:
      claude     Claude Code   ~\.claude\skills\    auto-detected
      codex      Codex         ~\.codex\skills\
      pi         pi            ~\.agents\skills\    auto-detected
      omp        omp           ~\.agents\skills\
      hermes     Hermes        ~\.hermes\skills\        (HERMES_HOME)
      zcode      ZCode         ~\.agents\skills\ - read natively, usually nothing to do
      workbuddy  WorkBuddy     ~\.workbuddy-ai\skills\  (WORKBUDDY_CONFIG_DIR)
      gemini     Gemini CLI    no skills mechanism; appends a block to GEMINI.md

    Windows uses a directory junction by default, which needs no administrator
    rights and no Developer Mode. Use -Symlink or -Copy to override.
.EXAMPLE
    .\scripts\install.ps1                 # detect the caller, link only that one
.EXAMPLE
    .\scripts\install.ps1 -Where          # print agent and path, change nothing
.EXAMPLE
    .\scripts\install.ps1 -Agent claude
.EXAMPLE
    .\scripts\install.ps1 -All -DryRun
#>
[CmdletBinding()]
param(
    [ValidateSet('claude', 'codex', 'pi', 'omp', 'hermes', 'zcode', 'gemini', 'workbuddy')]
    [string]$Agent,
    [switch]$All,
    [switch]$Where,
    [switch]$DryRun,
    [switch]$Symlink,
    [switch]$Copy
)

$ErrorActionPreference = 'Stop'

$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$name = Split-Path $repo -Leaf
if (-not (Test-Path (Join-Path $repo 'SKILL.md'))) {
    Write-Host "error: $repo has no SKILL.md" -ForegroundColor Red
    exit 1
}

$userHome = if ($env:USERPROFILE) { $env:USERPROFILE } else { $HOME }
$allAgents = @('claude', 'codex', 'pi', 'omp', 'hermes', 'zcode', 'gemini', 'workbuddy')

$BeginMark = '<!-- BEGIN agents-md-writer -->'
$EndMark = '<!-- END agents-md-writer -->'

function Get-Label {
    param([string]$Id)
    switch ($Id) {
        'claude' { 'Claude Code' } 'codex' { 'Codex' } 'pi' { 'pi' }
        'omp' { 'omp' } 'hermes' { 'Hermes' } 'zcode' { 'ZCode' }
        'gemini' { 'Gemini CLI' } 'workbuddy' { 'WorkBuddy' } default { $Id }
    }
}

function Get-Marker {
    param([string]$Id)
    switch ($Id) {
        'claude' { "$userHome\.claude" } 'codex' { "$userHome\.codex" }
        'pi' { "$userHome\.pi\agent" } 'omp' { "$userHome\.omp\agent" }
        'hermes' {
            if ($env:HERMES_HOME) { $env:HERMES_HOME.Trim() } else { "$userHome\.hermes" }
        }
        'zcode' { "$userHome\.zcode" }
        'gemini' { "$userHome\.gemini" }
        'workbuddy' {
            if ($env:WORKBUDDY_CONFIG_DIR) { $env:WORKBUDDY_CONFIG_DIR.Trim() }
            else { "$userHome\.workbuddy-ai" }
        }
        default { $null }
    }
}

function Get-SkillsDir {
    param([string]$Id)
    switch ($Id) {
        'claude' { "$userHome\.claude\skills" } 'codex' { "$userHome\.codex\skills" }
        'pi' { "$userHome\.agents\skills" } 'omp' { "$userHome\.agents\skills" }
        'zcode' { "$userHome\.agents\skills" }
        'hermes' { Join-Path (Get-Marker 'hermes') 'skills' }
        'workbuddy' { Join-Path (Get-Marker 'workbuddy') 'skills' }
        default { $null }
    }
}

# Identify the caller from environment variables set by the agent itself.
function Get-Caller {
    if ($env:CLAUDECODE -eq '1') { return 'claude' }
    switch ($env:AI_AGENT) {
        'pi' { return 'pi' }
        'claude' { return 'claude' }
        'claude-code' { return 'claude' }
    }
    if ($env:PI_CODING_AGENT -eq 'true') { return 'pi' }
    return $null
}

# Desktop apps only create their config directory on first launch, so an
# installed-but-never-run app has to be recognised by its bundle as well.
function Test-AgentInstalled {
    param([string]$Id)
    $m = Get-Marker $Id
    if ($m -and (Test-Path -LiteralPath $m -PathType Container)) { return $true }
    $bundles = switch ($Id) {
        'hermes' { @('/Applications/Hermes.app') }
        'zcode' { @('/Applications/ZCode.app') }
        'workbuddy' { @('/Applications/WorkBuddy AI.app', "$userHome\.workbuddy") }
        default { @() }
    }
    foreach ($b in $bundles) { if (Test-Path -LiteralPath $b) { return $true } }
    return $false
}

function Get-InstalledAgents { $allAgents | Where-Object { Test-AgentInstalled $_ } }

function Write-Row {
    param([string]$Id, [string]$Status, [ConsoleColor]$Color, [string]$Detail)
    Write-Host ("  {0,-14} " -f (Get-Label $Id)) -NoNewline -ForegroundColor White
    Write-Host $Status -NoNewline -ForegroundColor $Color
    if ($Detail) { Write-Host " $Detail" -ForegroundColor DarkGray } else { Write-Host '' }
}

function Install-Link {
    param([string]$Id)
    $skills = Get-SkillsDir $Id
    $target = Join-Path $skills $name

    if ($skills -eq "$userHome\.agents\skills" -and $repo -eq $target) {
        Write-Row $Id 'reads this location natively' Green $repo
        return $true
    }

    $existing = Get-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue
    if ($existing -and $existing.LinkType) {
        $current = if ($existing.LinkTarget) { $existing.LinkTarget } else { $existing.Target | Select-Object -First 1 }
        $resolved = if ($current) { (Resolve-Path -LiteralPath $current -ErrorAction SilentlyContinue).Path } else { $null }
        if ($resolved -eq $repo) {
            Write-Row $Id 'already linked' Green $target
            return $true
        }
        Write-Row $Id 'replace' Yellow $target
    } elseif ($existing) {
        Write-Row $Id 'blocked' Red "$target exists and is not a link - move it aside"
        return $false
    } else {
        Write-Row $Id 'link' Cyan $target
    }

    if ($DryRun) { return $true }
    New-Item -ItemType Directory -Force -Path $skills | Out-Null
    if ($existing) { Remove-Item -LiteralPath $target -Force -Recurse }
    if ($Copy) {
        Copy-Item -LiteralPath $repo -Destination $target -Recurse -Force
    } elseif ($Symlink) {
        New-Item -ItemType SymbolicLink -Path $target -Target $repo | Out-Null
    } else {
        New-Item -ItemType Junction -Path $target -Target $repo | Out-Null
    }
    return $true
}

# Gemini has no skills mechanism. Append a marked block to GEMINI.md instead, so
# it can be detected and removed cleanly. Nothing outside the block is touched.
function Install-GeminiReference {
    $f = "$userHome\.gemini\GEMINI.md"

    # GEMINI.md is frequently a link into a shared config file. Appending would
    # write through it and mutate that file instead. Refuse and let the user decide.
    $item = Get-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue
    if ($item -and $item.LinkType) {
        $t = if ($item.LinkTarget) { $item.LinkTarget } else { $item.Target | Select-Object -First 1 }
        Write-Row 'gemini' 'blocked' Red "$f is a link -> $t"
        Write-Host "  Appending would modify that file. Add this line there yourself if you want it:" -ForegroundColor DarkGray
        Write-Host "  Read $repo\SKILL.md before writing or reviewing AGENTS.md / CLAUDE.md files." -ForegroundColor DarkGray
        return $false
    }

    if ((Test-Path -LiteralPath $f) -and ((Get-Content -LiteralPath $f -Raw) -like "*$BeginMark*")) {
        Write-Row 'gemini' 'already referenced' Green $f
        return $true
    }
    Write-Row 'gemini' 'append reference block' Cyan "$f (no skills mechanism)"
    if ($DryRun) { return $true }
    New-Item -ItemType Directory -Force -Path "$userHome\.gemini" | Out-Null
    $block = @()
    if ((Test-Path -LiteralPath $f) -and (Get-Item -LiteralPath $f).Length -gt 0) { $block += '' }
    $block += $BeginMark
    $block += "Read $repo\SKILL.md before writing or reviewing AGENTS.md / CLAUDE.md files."
    $block += $EndMark
    Add-Content -LiteralPath $f -Value ($block -join "`n")
    return $true
}

# Supported but absent from this machine. Listed so the menu is not mistaken
# for the full set of agents this skill supports.
function Get-UninstalledAgents {
    $allAgents | Where-Object { -not (Test-AgentInstalled $_) }
}

function Install-One {
    param([string]$Id)
    if ($Id -eq 'gemini') { return Install-GeminiReference }
    return Install-Link $Id
}

# A human at a terminal can be asked. Anything else (agent, pipe, CI) cannot.
function Select-AgentInteractively {
    $found = @(Get-InstalledAgents)
    if ($found.Count -eq 0) { return $null }
    Write-Host 'Which agent? ' -NoNewline
    Write-Host '(you are in a terminal, so I can ask)' -ForegroundColor DarkGray
    Write-Host ''
    for ($i = 0; $i -lt $found.Count; $i++) {
        Write-Host "  $($i + 1)" -NoNewline -ForegroundColor Cyan
        Write-Host ") $(Get-Label $found[$i])"
    }
    Write-Host '  a' -NoNewline -ForegroundColor Cyan
    Write-Host ') all of them'
    $missing = @(Get-UninstalledAgents)
    if ($missing.Count -gt 0) {
        $names = ($missing | ForEach-Object { Get-Label $_ }) -join ', '
        Write-Host ''
        Write-Host "also supported, not installed here: $names" -ForegroundColor DarkGray
    }
    Write-Host ''
    $reply = (Read-Host "Choice [1-$($found.Count)/a]").Trim()
    if ($reply -eq 'a' -or $reply -eq 'all') { return '--all' }
    $n = 0
    if ([int]::TryParse($reply, [ref]$n) -and $n -ge 1 -and $n -le $found.Count) { return $found[$n - 1] }
    return $null
}

# --- where -------------------------------------------------------------------
if ($Where) {
    $caller = Get-Caller
    if (-not $caller) {
        Write-Host "agent: unknown`npath:  unknown"
        Write-Host "hint: pass -Agent with one of: $($allAgents -join ', ')" -ForegroundColor DarkGray
        exit 1
    }
    Write-Host "agent: $caller"
    Write-Host "path:  $(Join-Path (Get-SkillsDir $caller) $name)"
    exit 0
}

Write-Host 'skill   ' -NoNewline -ForegroundColor White
Write-Host $repo
if ($DryRun) { Write-Host 'dry run - nothing will be written' -ForegroundColor DarkGray }
Write-Host ''

$ok = $true
if ($Agent) {
    $ok = Install-One $Agent
} elseif ($All) {
    $found = @(Get-InstalledAgents)
    if ($found.Count -eq 0) {
        Write-Host 'no agents found under $HOME' -ForegroundColor Yellow
        exit 1
    }
    foreach ($a in $found) { if (-not (Install-One $a)) { $ok = $false } }
} else {
    $caller = Get-Caller
    $interactive = [Environment]::UserInteractive -and -not [Console]::IsInputRedirected
    if (-not $caller -and $interactive) {
        $picked = Select-AgentInteractively
        if (-not $picked) {
            Write-Host ''
            Write-Host 'cancelled' -ForegroundColor Yellow
            exit 1
        }
        Write-Host ''
        if ($picked -eq '--all') {
            foreach ($a in Get-InstalledAgents) { if (-not (Install-One $a)) { $ok = $false } }
        } else {
            $ok = Install-One $picked
        }
    } elseif (-not $caller) {
        Write-Host 'error: cannot identify the calling agent.' -ForegroundColor Red
        Write-Host ''
        Write-Host "Re-run with -Agent NAME, where NAME is one of: $($allAgents -join ', ')"
        Write-Host 'Or use -All to link every agent found here:'
        foreach ($a in Get-InstalledAgents) { Write-Host "  $(Get-Label $a)" -ForegroundColor DarkGray }
        $missing = @(Get-UninstalledAgents)
        if ($missing.Count -gt 0) {
            $names = ($missing | ForEach-Object { Get-Label $_ }) -join ', '
            Write-Host "Also supported, not installed here: $names" -ForegroundColor DarkGray
        }
        exit 1
    } else {
        $ok = Install-One $caller
    }
}

Write-Host ''
if (-not $ok) {
    Write-Host 'Blocked.' -NoNewline -ForegroundColor Red
    Write-Host ' Move the listed paths aside and re-run.'
    exit 1
}
if ($DryRun) {
    Write-Host 'Dry run complete. Re-run without -DryRun to apply.'
} else {
    Write-Host 'Done.' -NoNewline -ForegroundColor Green
    Write-Host ' Ask your agent: "what skills do you have?"'
}
exit 0
