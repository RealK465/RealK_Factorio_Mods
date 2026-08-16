#requires -Version 5.1
<#
  Verifies that every .ai-support/ folder is indexed and internally consistent.
  See CLAUDE.md -> AI support folders.

  A stale index is worse than none: an agent reads it, believes the folder holds what it says,
  and never opens the file that was added without a row. That failure is silent, so it is
  checked here rather than trusted.

  This checks the SHAPE of the folder and then hands off to check-ai-docs.py, which checks the
  CONTENT of the notes - API citations, game-data file:line citations, freshness front matter
  and every relative path. Run this one; it runs both.

  What is checked here:
    - the folder has an index.md
    - every file in it (and every immediate subfolder) has a row in that index.md
    - the index does not name a file that no longer exists
    - a subfolder of evidence carries its own index.md
    - nothing in the folder is untracked, since these notes travel with the mod

  Not checked: whether a row's description is still TRUE. Nothing can check that.

  Exit 0 = consistent. Exit 1 = at least one problem.
#>

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Push-Location $repo
try {
  $problems = @()
  $checked  = 0

  $folders = @(Get-ChildItem -Directory -Force |
               Where-Object { $_.Name -ne '.git' } |
               ForEach-Object { Join-Path $_.FullName '.ai-support' } |
               Where-Object { Test-Path -LiteralPath $_ })

  foreach ($dir in $folders) {
    $mod   = Split-Path -Leaf (Split-Path -Parent $dir)
    $index = Join-Path $dir 'index.md'
    $checked++

    if (-not (Test-Path -LiteralPath $index)) {
      $problems += "$mod/.ai-support : no index.md - required whenever the folder exists"
      continue
    }

    $text = Get-Content -LiteralPath $index -Raw

    # Every entry at the top level needs a row. Subfolders are named with or without the slash.
    foreach ($e in (Get-ChildItem -LiteralPath $dir -Force | Sort-Object Name)) {
      if ($e.Name -eq 'index.md') { continue }
      if (-not ($text -match [regex]::Escape($e.Name))) {
        $problems += "$mod/.ai-support/$($e.Name) : not listed in index.md - an unindexed file is an incomplete change"
      }
      if ($e.PSIsContainer) {
        $sub = Join-Path $e.FullName 'index.md'
        if (-not (Test-Path -LiteralPath $sub)) {
          $problems += "$mod/.ai-support/$($e.Name)/ : subfolder carries no index.md of its own"
        }
        if (Test-Path -LiteralPath (Join-Path $e.FullName 'README.md')) {
          $problems += "$mod/.ai-support/$($e.Name)/README.md : use index.md - README.md is the player-facing name"
        }
      }
    }

    if (Test-Path -LiteralPath (Join-Path $dir 'README.md')) {
      $problems += "$mod/.ai-support/README.md : use index.md - a mod's README.md becomes the portal description"
    }

    # A row naming a file that is gone points the next session at nothing. Only the first cell
    # of a table row counts as a declaration - a name in prose is a reference, and a name in a
    # bullet list is usually a "add this when there is something to put in it" note.
    foreach ($line in ($text -split "`r?`n" | Where-Object { $_ -match '^\|' })) {
      $cell = ($line -split '\|')[1]
      if ($cell -notmatch '`([A-Za-z0-9._-]+/?)`') { continue }
      $name = $Matches[1]
      if (-not (Test-Path -LiteralPath (Join-Path $dir $name.TrimEnd('/')))) {
        $problems += "$mod/.ai-support/index.md : row names '$name', which does not exist here"
      }
    }

    $untracked = @(git ls-files --others --exclude-standard -- "$mod/.ai-support")
    foreach ($u in $untracked) {
      $problems += "$u : untracked - .ai-support/ is tracked so it travels with the mod"
    }
  }

  if ($problems.Count -eq 0) {
    Write-Host "ai-support consistent - $checked folder(s) checked" -ForegroundColor Green
  }
  else {
    Write-Host "$($problems.Count) problem(s):" -ForegroundColor Red
    foreach ($p in $problems) { Write-Host "  - $p" -ForegroundColor Red }
  }

  # Content checks live in Python - they parse a multi-megabyte runtime-api.json, which is not
  # PowerShell's strength. One command runs both; the worse exit code wins.
  Write-Host ''
  & python (Join-Path $PSScriptRoot 'check-ai-docs.py')
  $docs = $LASTEXITCODE

  if ($problems.Count -eq 0 -and $docs -eq 0) { exit 0 }
  exit 1
}
finally { Pop-Location }
