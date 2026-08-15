# Photograph a mod's entities through Factorio's own renderer.
#
#   .\shoot.ps1 -ModPath ..\..\..\..\..\pure-modules-realk -Entity pure-beacon -Out shots
#   .\shoot.ps1 -ModPath <mod> -SpecJson spec.json -Out shots
#
# Everything the offline compositor in factorio_render/vanilla.py cannot answer:
# render_layer ordering, apply_module_tint against a real module, draw_as_light
# against real darkness, frozen_patch on a real Aquilo surface, and how the
# sprite reads on terrain the map generator actually produced.
#
# Three things this script exists to get right, each found by testing:
#
#  * **A graphics mode can exit 0 having photographed nothing**, so the run is
#    verified by counting PNGs, not by trusting $LASTEXITCODE. (Known cause: a
#    DRM check on Steam builds. SteamAppId=427520 below defuses it and is a
#    no-op on the DRM-free dev installs -- kept as cheap insurance.)
#  * **Scratch write-data.** The .lock, the log and script-output all follow
#    write-data, so relocating it via config.ini keeps the run out of the
#    install's own user-data folder entirely.
#  * **mod-list.json must be BOM-free**, or Factorio silently ignores it and
#    loads its own defaults -- so the mod under test never loads and the run
#    "passes" having shot vanilla.

[CmdletBinding()]
param(
  # Mod folder to photograph. Optional: omit to shoot vanilla entities only.
  [string] $ModPath,

  # Quick form: one entity, three of them in a row, plus a vanilla neighbour.
  [string] $Entity,
  [string] $Compare,
  [int]    $Row = 3,
  [string] $Module,

  # Full form: a JSON file describing groups (see the README section below).
  [string] $SpecJson,

  # Which times of day to shoot, comma separated. 0 is noon; 0.5 is midnight,
  # which is the ONLY way to check a draw_as_light / additive layer -- it
  # renders in the light pass and is simply absent at noon and in any offline
  # composite.
  #
  # A STRING, split below, not [double[]]. Windows PowerShell binds a typed
  # array parameter from `-File` by taking a single value and dropping the
  # rest: `-Daytimes 0,0.5` arrives as one element 0.5, and `-Daytimes 0 0.5`
  # as one element 0. Nothing errors -- the run just quietly shoots one time
  # of day and reports success.
  [string] $Daytimes = '0',

  [string] $Out = 'shots',

  # Defaults to the install this repo lives in -- when the repo is a dev install's
  # mods/ folder the root is six levels above this script. A standalone (DRM-free)
  # install is also what makes this script work with the game open; see the header.
  [string] $FactorioPath,
  [int]    $Ticks = 120,
  [switch] $Keep
)

$ErrorActionPreference = 'Stop'
$daytimeList = @($Daytimes -split ',' | ForEach-Object { [double] $_.Trim() })
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not $FactorioPath) {
  # <install>/mods/.claude/skills/factorio-graphics/scripts/screenshot/ -> <install>
  $selfInstall = (Resolve-Path -LiteralPath (Join-Path $here '..\..\..\..\..\..')).Path
  $FactorioPath = @($env:FACTORIO_PATH, $selfInstall) |
    Where-Object { $_ -and (Test-Path -LiteralPath (Join-Path $_ 'bin\x64\factorio.exe')) } |
    Select-Object -First 1
  # No fallback to a play install on purpose: this script launches a graphics mode
  # and writes screenshots, which is not something to do against someone's game.
  if (-not $FactorioPath) {
    throw "No dev install found at $selfInstall - pass -FactorioPath or set FACTORIO_PATH (see CLAUDE.local.md)."
  }
}
Write-Host "Install: $FactorioPath"

# --- build the spec ------------------------------------------------------
if ($SpecJson) {
  $spec = Get-Content -LiteralPath $SpecJson -Raw | ConvertFrom-Json
} elseif ($Entity) {
  # A lone unit reads differently from a run of them: a utility entity that
  # looks articulated on its own can fuse into an unbroken wall when tiled,
  # and only the row shows it.
  $entities = @()
  for ($i = 0; $i -lt $Row; $i++) {
    $e = @{ name = $Entity; x = ($i * 4) - (($Row - 1) * 2); y = 0 }
    if ($Module) { $e.module = $Module }
    $entities += $e
  }
  if ($Compare) { $entities += @{ name = $Compare; x = (($Row - 1) * 2) + 6; y = 0 } }
  $spec = @{
    surface = 'nauvis'
    groups  = @(
      @{ label = 'row'; center = @(0, 0); radius = 24; zooms = @(1, 2)
         resolution = @(1400, 900); alt_mode = $true; entities = $entities
         daytimes = $daytimeList }
    )
  }
} else {
  throw 'Pass -Entity (quick form) or -SpecJson (full form).'
}

# --- stage ---------------------------------------------------------------
$stage = Join-Path $env:TEMP 'factorio-gfx-probe'
$data = "$stage-data"
foreach ($p in @($stage, $data)) {
  if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force }
  New-Item -ItemType Directory -Path $p | Out-Null
}

Copy-Item -LiteralPath (Join-Path $here 'probe') -Destination (Join-Path $stage 'gfx-probe') -Recurse
# Hand-rolling a PowerShell -> Lua serialiser does not survive contact with
# PowerShell unrolling single-element arrays: a one-group spec came out as the
# group itself, and the probe iterated its fields. ConvertTo-Json plus the
# engine's own helpers.json_to_table has neither problem -- and the probe
# normalises anything that still arrives as a bare object.
$specJsonText = $spec | ConvertTo-Json -Depth 12 -Compress
[System.IO.File]::WriteAllText(
  (Join-Path $stage 'gfx-probe\spec.lua'),
  "-- generated by shoot.ps1`nreturn [==[" + $specJsonText + "]==]`n",
  (New-Object System.Text.UTF8Encoding $false))

$mods = @(@{ name = 'base'; enabled = $true }, @{ name = 'gfx-probe'; enabled = $true })
if ($ModPath) {
  $ModPath = (Resolve-Path -LiteralPath $ModPath).Path
  $info = Get-Content -LiteralPath (Join-Path $ModPath 'info.json') -Raw | ConvertFrom-Json
  $folder = Split-Path -Leaf $ModPath
  if ($folder -ne $info.name -and $folder -ne "$($info.name)_$($info.version)") {
    throw "Folder '$folder' matches neither '$($info.name)' nor '$($info.name)_$($info.version)' - Factorio would silently skip it."
  }
  Copy-Item -LiteralPath $ModPath -Destination (Join-Path $stage $folder) -Recurse
  $mods += @{ name = $info.name; enabled = $true }
}

$json = [pscustomobject]@{ mods = @($mods | ForEach-Object { [pscustomobject]$_ }) } |
  ConvertTo-Json -Depth 4
[System.IO.File]::WriteAllText((Join-Path $stage 'mod-list.json'), $json,
  (New-Object System.Text.UTF8Encoding $false))

$ini = "[path]`nread-data=$FactorioPath\data`nwrite-data=$data`n"
[System.IO.File]::WriteAllText((Join-Path $data 'config.ini'), $ini,
  (New-Object System.Text.UTF8Encoding $false))

$exe = Join-Path $FactorioPath 'bin\x64\factorio.exe'
if (-not (Test-Path -LiteralPath $exe)) { throw "factorio.exe not found at $exe" }
$cfg = Join-Path $data 'config.ini'
$save = Join-Path $data 'probe.zip'

# --- create the save, then photograph it ---------------------------------
Write-Host 'Creating probe save...'
$p = Start-Process -FilePath $exe -Wait -PassThru -NoNewWindow -ArgumentList @(
  '--config', $cfg, '--mod-directory', $stage, '--create', $save, '--map-gen-seed', '1')
if ($p.ExitCode -ne 0) { throw "--create failed ($($p.ExitCode))" }

Write-Host 'Rendering...'
$old = $env:SteamAppId
$env:SteamAppId = '427520'
try {
  $p = Start-Process -FilePath $exe -Wait -PassThru -NoNewWindow -ArgumentList @(
    '--config', $cfg, '--mod-directory', $stage,
    '--benchmark-graphics', $save, '--benchmark-ticks', "$Ticks")
} finally {
  if ($null -eq $old) { Remove-Item Env:SteamAppId -ErrorAction SilentlyContinue }
  else { $env:SteamAppId = $old }
}

# --- collect -------------------------------------------------------------
$so = Join-Path $data 'script-output'
if (-not (Test-Path -LiteralPath $Out)) { New-Item -ItemType Directory -Path $Out | Out-Null }
$shots = @()
if (Test-Path -LiteralPath $so) {
  $shots = @(Get-ChildItem -LiteralPath $so -Filter *.png -Recurse)
  $shots | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $Out -Force }
  $probeLog = Join-Path $so 'gfx-probe.log'
  if (Test-Path -LiteralPath $probeLog) {
    Write-Host '--- probe log ---'
    Get-Content -LiteralPath $probeLog | ForEach-Object { Write-Host "  $_" }
  }
}

$gameLog = Join-Path $data 'factorio-current.log'
if (Test-Path -LiteralPath $gameLog) {
  $text = Get-Content -LiteralPath $gameLog -Raw
  if ($text -match 'Steam requires game restart') {
    Write-Host 'Steam refused the graphics mode - SteamAppId did not take effect.'
  }
}

if (-not $Keep) {
  Remove-Item -LiteralPath $stage -Recurse -Force
  Remove-Item -LiteralPath $data -Recurse -Force
}

# Exit code is not evidence here: the Steam refusal above exits 0 having shot
# nothing at all. Count the pictures instead.
if ($shots.Count -eq 0) {
  Write-Host 'No screenshots produced.'
  exit 1
}
Write-Host "$($shots.Count) screenshot(s) in $Out"
