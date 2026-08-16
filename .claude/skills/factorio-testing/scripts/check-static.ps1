# The static tier: luacheck (undefined globals, unused locals) plus emmylua_check (field-level
# API misuse against fmtk-generated type definitions). Run from anywhere; paths are resolved
# from this script's own location. Exit 0 means both checkers are clean of errors -- emmylua
# warnings are printed but do not fail the run.

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string] $ModPath,

  # Rebuild the type definitions from the install's machine-readable docs. Needed once, and
  # again whenever the dev install's game version moves.
  [switch] $RegenerateTypedefs
)

$ErrorActionPreference = 'Stop'

$skillRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $skillRoot '..\..\..')).Path
$installRoot = (Resolve-Path -LiteralPath (Join-Path $repoRoot '..')).Path
$ModPath = (Resolve-Path -LiteralPath $ModPath).Path

if (-not (Get-Command luacheck -ErrorAction SilentlyContinue)) {
  throw 'luacheck not on PATH - scoop install luacheck'
}

$emmy = Join-Path $skillRoot 'tools\emmylua_check.exe'
if (-not (Test-Path -LiteralPath $emmy)) {
  # Pinned release; the binary lives git-ignored under the skill.
  Write-Host 'Downloading emmylua_check 0.25.1.'
  New-Item -ItemType Directory -Force -Path (Join-Path $skillRoot 'tools') | Out-Null
  $zip = Join-Path $env:TEMP 'emmylua_check.zip'
  Invoke-WebRequest -UseBasicParsing -OutFile $zip -Uri `
    'https://github.com/EmmyLuaLs/emmylua-analyzer-rust/releases/download/0.25.1/emmylua_check-win32-x64.zip'
  Expand-Archive -LiteralPath $zip -DestinationPath (Join-Path $skillRoot 'tools') -Force
  Remove-Item -LiteralPath $zip -Force
}

$typedefs = Join-Path $skillRoot 'typedefs'
if ($RegenerateTypedefs -or -not (Test-Path -LiteralPath (Join-Path $typedefs 'factorio\library'))) {
  Write-Host 'Generating type definitions from the installed doc-html.'
  fmtk docs -d (Join-Path $installRoot 'doc-html\runtime-api.json') `
    -p (Join-Path $installRoot 'doc-html\prototype-api.json') $typedefs
  if ($LASTEXITCODE -ne 0) { throw 'fmtk docs failed - check the doc-html paths.' }
}

Write-Host "-- luacheck --"
Push-Location $repoRoot
# Both tools write progress to stderr; under 'Stop' plus an output redirection that would
# become a terminating NativeCommandError with the real exit code lost, so relax around the
# native calls and judge them by $LASTEXITCODE alone.
$ErrorActionPreference = 'Continue'
try {
  luacheck $ModPath --codes -q
  $luacheckExit = $LASTEXITCODE

  Write-Host "-- emmylua_check --"
  # The config must be passed explicitly: discovery looks in the WORKSPACE argument, and the
  # workspace here is the mod while the config lives at the repo root.
  & $emmy -c (Join-Path $repoRoot '.emmyrc.json') $ModPath
  $emmyExit = $LASTEXITCODE
} finally {
  Pop-Location
  $ErrorActionPreference = 'Stop'
}

# emmylua_check exits non-zero on errors only; warnings print and pass. luacheck exits
# non-zero on any finding, which is the strictness we want from it.
if ($luacheckExit -ne 0) { Write-Host 'luacheck found problems.'; exit 1 }
if ($emmyExit -ne 0) { Write-Host 'emmylua_check found errors.'; exit 1 }
Write-Host 'Static tier clean.'
exit 0
