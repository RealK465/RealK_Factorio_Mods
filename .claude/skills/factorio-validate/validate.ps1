# Validate a mod's data stage headlessly, against an isolated mod directory.
# Never runs against the live mods folder - the game rewrites mod-list.json
# wherever it is pointed, and that file is off-limits in this repo.

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string] $ModPath,

  [string] $FactorioPath = 'C:\Program Files (x86)\Steam\steamapps\common\Factorio',

  # Expansions load from the game install whether or not they are listed, so
  # they only need naming here to turn one OFF for a compatibility check.
  [string[]] $Disable = @(),

  [switch] $KeepDump,

  # Run against a scratch write-data folder instead of %APPDATA%\Factorio, so a
  # running game's .lock does not block the run. Also keeps data-raw-dump.json
  # out of the real user-data folder, so there is nothing to clean up there.
  [switch] $Live
)

$ErrorActionPreference = 'Stop'

$ModPath = (Resolve-Path -LiteralPath $ModPath).Path
$infoPath = Join-Path $ModPath 'info.json'
if (-not (Test-Path -LiteralPath $infoPath)) {
  throw "No info.json in $ModPath"
}

$info = Get-Content -LiteralPath $infoPath -Raw | ConvertFrom-Json
$name = $info.name
$version = $info.version

# Factorio silently skips a folder whose name doesn't match info.json, which
# looks identical to "the mod loaded but did nothing". Catch it here instead.
$folder = Split-Path -Leaf $ModPath
if ($folder -ne $name -and $folder -ne "${name}_${version}") {
  throw "Folder '$folder' matches neither '$name' nor '${name}_${version}' - Factorio would silently not load it."
}

$exe = Join-Path $FactorioPath 'bin\x64\factorio.exe'
if (-not (Test-Path -LiteralPath $exe)) {
  throw "factorio.exe not found at $exe - pass -FactorioPath (see CLAUDE.local.md)."
}

# A standalone (zip) install keeps its write-data in its own folder instead of
# %APPDATA%\Factorio. This script would then read the Steam install's stale log and
# call a failed run a pass, so switch to scratch write-data - which also keeps the
# run from writing anything into that install.
$pathCfg = Join-Path $FactorioPath 'config-path.cfg'
if (-not $Live -and (Test-Path -LiteralPath $pathCfg) -and
    (Get-Content -LiteralPath $pathCfg -Raw) -match 'use-system-read-write-data-directories\s*=\s*false') {
  Write-Host "Standalone install - using a scratch write-data folder."
  $Live = $true
}

$stage = Join-Path $env:TEMP "factorio-validate-$name"
if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
New-Item -ItemType Directory -Path $stage | Out-Null
Copy-Item -LiteralPath $ModPath -Destination (Join-Path $stage $folder) -Recurse

$writeData = $null
if ($Live) {
  $writeData = "$stage-data"
  if (Test-Path -LiteralPath $writeData) { Remove-Item -LiteralPath $writeData -Recurse -Force }
  New-Item -ItemType Directory -Path $writeData | Out-Null
  # The lock lives in the write-data folder, not the mod folder, so moving it is
  # all it takes to validate while Factorio is open.
  $ini = "[path]`nread-data=$FactorioPath\data`nwrite-data=$writeData`n"
  [System.IO.File]::WriteAllText(
    (Join-Path $writeData 'config.ini'), $ini, (New-Object System.Text.UTF8Encoding $false))
}

$entries = @(
  @{ name = 'base'; enabled = $true }
  @{ name = $name;  enabled = $true }
) + @($Disable | ForEach-Object { @{ name = $_; enabled = $false } })

$json = [pscustomobject]@{
  mods = @($entries | ForEach-Object { [pscustomobject]$_ })
} | ConvertTo-Json -Depth 4

# Must be BOM-free: Out-File -Encoding utf8 writes a BOM in PS 5.1, and
# Factorio then rejects the file and silently loads its own defaults instead.
[System.IO.File]::WriteAllText(
  (Join-Path $stage 'mod-list.json'), $json, (New-Object System.Text.UTF8Encoding $false))

Write-Host "Validating $name $version"
if ($Disable.Count) { Write-Host "Disabled: $($Disable -join ', ')" }

# factorio.exe is a GUI-subsystem binary, so the call operator neither waits
# for it nor sets $LASTEXITCODE. Start-Process -Wait -PassThru does both.
$argList = @('--dump-data', '--mod-directory', $stage)
if ($Live) { $argList = @('--config', (Join-Path $writeData 'config.ini')) + $argList }

$proc = Start-Process -FilePath $exe -ArgumentList $argList -Wait -PassThru -NoNewWindow
$code = $proc.ExitCode

# --dump-data and the log both follow write-data, which -Live has relocated.
$userData = $env:APPDATA + '\Factorio'
if ($Live) { $userData = $writeData }
$log = Join-Path $userData 'factorio-current.log'

$dump = Join-Path $userData 'script-output\data-raw-dump.json'
$keptDump = $null
if (Test-Path -LiteralPath $dump) {
  if ($KeepDump) {
    # -Live would delete the dump with its scratch folder, so move it somewhere
    # that survives the cleanup below.
    if ($Live) {
      $keptDump = Join-Path $env:TEMP "data-raw-dump-$name.json"
      Move-Item -LiteralPath $dump -Destination $keptDump -Force
    } else {
      $keptDump = $dump
    }
    Write-Host "Dump kept at $keptDump"
  } else {
    Remove-Item -LiteralPath $dump -Force
  }
}

# Read the log before the scratch folder holding it is removed.
$logText = ''
if (Test-Path -LiteralPath $log) { $logText = Get-Content -LiteralPath $log -Raw }

Remove-Item -LiteralPath $stage -Recurse -Force
if ($Live -and (Test-Path -LiteralPath $writeData)) {
  Remove-Item -LiteralPath $writeData -Recurse -Force
}

if ($code -eq 0) {
  # A silent skip still exits 0, so confirm the mod actually loaded.
  if ($logText -match [regex]::Escape("Checksum of ${name}:")) {
    Write-Host "Data stage loaded clean (exit 0). Runtime behaviour and appearance are still unverified."
  } else {
    Write-Host "Exit 0, but $name never loaded - check the folder name and dependencies."
    $code = 1
  }
} else {
  Write-Host "Data stage FAILED (exit $code):"
  ($logText -split "`n" | Select-String -Pattern 'Error|Failed' | Select-Object -Last 10) |
    ForEach-Object { Write-Host "  $($_.Line.Trim())" }
  if ($logText -match 'Couldn..t create lock file') {
    Write-Host "  ^ that is the running game holding the lock, NOT a mod error. Re-run with -Live."
  }
}
exit $code
