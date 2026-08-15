#requires -Version 5.1
<#
  Verifies that every root folder's scope declarations agree with each other.
  See CLAUDE.md -> Folder classes.

  The class is inferred from evidence rather than declared in a fourth list — the presence of a
  deny rule IS the machine-readable marker, and an editable folder declares itself by carrying
  its own CLAUDE.md:

    tracked                       -> Deliverable
    ignored + deny rules          -> Frozen vendor / Reference  (hands-off)
    ignored + no deny rules       -> Local mod / Patched vendor (editable, must self-declare)

  Only folders at THIS repo's root are checked. Anything kept elsewhere on disk is invisible
  here, so if it matters it has to be written down in CLAUDE.local.md, where nothing verifies it.

  Exit 0 = consistent. Exit 1 = at least one problem.
#>

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Push-Location $repo
try {
  $deny = @((Get-Content '.claude/settings.json' -Raw | ConvertFrom-Json).permissions.deny)
  $localMd = ''
  if (Test-Path 'CLAUDE.local.md') { $localMd = Get-Content 'CLAUDE.local.md' -Raw }

  $problems = @()
  $rows     = @()

  foreach ($d in (Get-ChildItem -Directory -Force | Where-Object { $_.Name -ne '.git' } | Sort-Object Name)) {
    $n = $d.Name

    git check-ignore -q -- $n
    $ignored = ($LASTEXITCODE -eq 0)
    $tracked = (@(git ls-files -- $n).Count -gt 0)

    $hasEdit  = $deny -contains "Edit($n/**)"
    $hasWrite = $deny -contains "Write($n/**)"
    $inLocal  = $localMd -match [regex]::Escape($n)
    $ownMd    = Test-Path (Join-Path $n 'CLAUDE.md')
    $isMod    = Test-Path (Join-Path $n 'info.json')

    if     ($tracked)              { $class = 'Deliverable' }
    elseif ($hasEdit -or $hasWrite){ $class = 'Frozen/Reference' }
    elseif ($ignored)              { $class = 'Local/Patched' }
    else                           { $class = 'UNDECLARED' }

    # R1 every root folder is either tracked or ignored
    if (-not $tracked -and -not $ignored) {
      $problems += "$n : neither tracked nor git-ignored - one stray 'git add -A' from being committed"
    }
    # R2 a hands-off folder must not be tracked
    if (($hasEdit -or $hasWrite) -and $tracked) {
      $problems += "$n : has deny rules but is tracked - a deliverable cannot be hands-off"
    }
    # R3 anything ignored has to be findable in the local inventory
    if ($ignored -and -not $inLocal) {
      $problems += "$n : git-ignored but not mentioned in CLAUDE.local.md - invisible to the next session"
    }
    # R4 Edit and Write are separate tools; one without the other is a half-open door
    if ($hasEdit -ne $hasWrite) {
      $problems += "$n : deny rules incomplete (Edit=$hasEdit Write=$hasWrite) - needs both"
    }
    # R5 an editable untracked folder must declare itself, or it reads as hands-off
    if ($ignored -and -not $hasEdit -and -not $hasWrite -and -not $ownMd) {
      $problems += "$n : editable but carries no CLAUDE.md saying so - will be mistaken for a frozen vendor"
    }
    # R6 a tracked mod should carry its own context
    if ($tracked -and $isMod -and -not $ownMd) {
      $problems += "$n : tracked mod with no CLAUDE.md of its own"
    }

    $rows += [pscustomobject]@{
      Folder = $n; Class = $class; Tracked = $tracked; Ignored = $ignored
      Deny = $(if ($hasEdit -and $hasWrite) { 'E+W' } elseif ($hasEdit -or $hasWrite) { 'PARTIAL' } else { '-' })
      InLocalMd = $inLocal; OwnMd = $ownMd
    }
  }

  $rows | Format-Table -AutoSize

  if ($problems.Count -eq 0) {
    Write-Host "folder scope consistent - $($rows.Count) folders checked" -ForegroundColor Green
    exit 0
  }
  Write-Host "$($problems.Count) problem(s):" -ForegroundColor Red
  foreach ($p in $problems) { Write-Host "  - $p" -ForegroundColor Red }
  exit 1
}
finally { Pop-Location }
