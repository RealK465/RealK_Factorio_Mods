param(
  [Parameter(Mandatory = $true)] [string] $Out,
  [string] $FactorioPath = $env:FACTORIO_PATH
)
# Builds Assembly Planner's portal showcase in a windowed dev client and copies the screenshots
# to -Out. The mod is staged from the repo into a scratch folder with showcase.lua added; nothing
# in the repo or the install is written. Closes only the process it started, never any other
# Factorio. Needs a real display: with the screen off Windows offers only a virtual one, and the
# client dies before loading mods (factorio-testing skill, the graphics tier).
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
# assets/assembly-planner/showcase -> the repo root, which is a dev install's mods folder.
$repo = (Resolve-Path -LiteralPath (Join-Path $here '..\..\..')).Path
if (-not $FactorioPath) { $FactorioPath = Split-Path -Parent $repo }
$exe = Join-Path $FactorioPath 'bin\x64\factorio.exe'
if (-not (Test-Path -LiteralPath $exe)) { throw "No factorio.exe under $FactorioPath; pass -FactorioPath." }

$root = Join-Path $env:TEMP 'apl-show'
if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
$mods = Join-Path $root 'mods'
$data = Join-Path $root 'data'
New-Item -ItemType Directory -Force -Path $mods, $data | Out-Null

$mod = Join-Path $mods 'assembly-planner'
robocopy (Join-Path $repo 'assembly-planner') $mod /E /XD images .ai-support tests /NFL /NDL /NJH /NJS /NP | Out-Null
# robocopy's codes below 8 all mean success.
if ($LASTEXITCODE -ge 8) { throw "robocopy failed ($LASTEXITCODE)" }
Copy-Item -LiteralPath (Join-Path $here 'showcase.lua') -Destination (Join-Path $mod 'showcase.lua')
# Freeplay's intro and crash site would hold the first join waiting for a click.
$control = Join-Path $mod 'control.lua'
$text = [System.IO.File]::ReadAllText($control)
$init = 'script.on_init(state.init)'
if (-not $text.Contains($init)) { throw "control.lua no longer has '$init'; update the patch here." }
$skip = 'script.on_init(function() state.init() if remote.interfaces["freeplay"] then ' +
  'remote.call("freeplay", "set_skip_intro", true) remote.call("freeplay", "set_disable_crashsite", true) end end)'
$text = $text.Replace($init, $skip) + "`nrequire(`"showcase`")`n"
[System.IO.File]::WriteAllText($control, $text, (New-Object System.Text.UTF8Encoding $false))

$list = @(@{ name = 'base'; enabled = $true }, @{ name = 'assembly-planner'; enabled = $true })
foreach ($m in @('space-age', 'quality', 'elevated-rails', 'recycler')) { $list += @{ name = $m; enabled = $true } }
[System.IO.File]::WriteAllText((Join-Path $mods 'mod-list.json'), (@{ mods = $list } | ConvertTo-Json -Depth 4),
  (New-Object System.Text.UTF8Encoding $false))

$ini = "[path]`r`nread-data=$FactorioPath\data`r`nwrite-data=$data`r`n[graphics]`r`nfull-screen=false`r`n" +
  "window-size=1920x1080`r`n[interface]`r`nshow-tips-and-tricks-notifications=false`r`n[sound]`r`nmaster-volume=0`r`n"
$cfg = Join-Path $data 'config.ini'
[System.IO.File]::WriteAllText($cfg, $ini, (New-Object System.Text.UTF8Encoding $false))

$save = Join-Path $data 'show.zip'
$p = Start-Process -FilePath $exe -Wait -PassThru -NoNewWindow -ArgumentList @(
  '--config', "`"$cfg`"", '--mod-directory', "`"$mods`"", '--create', "`"$save`"", '--map-gen-seed', '42')
if ($p.ExitCode -ne 0) { throw "--create failed ($($p.ExitCode))" }

$client = Start-Process -FilePath $exe -PassThru -ArgumentList @(
  '--config', "`"$cfg`"", '--mod-directory', "`"$mods`"", '--load-game', "`"$save`"")
$shots = Join-Path $data 'script-output\apl-shots'
$marker = Join-Path $shots 'done.txt'
$deadline = (Get-Date).AddMinutes(5)
while (-not (Test-Path -LiteralPath $marker) -and (Get-Date) -lt $deadline -and -not $client.HasExited) {
  Start-Sleep -Seconds 2
}
$finished = Test-Path -LiteralPath $marker
if (-not $client.HasExited) { Stop-Process -Id $client.Id -Force }

New-Item -ItemType Directory -Force -Path $Out | Out-Null
if (Test-Path -LiteralPath $shots) {
  Get-ChildItem -LiteralPath $shots -File -Filter *.jpg | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $Out -Force }
  Get-Content -LiteralPath (Join-Path $shots 'log.txt') -ErrorAction SilentlyContinue
}
Select-String -LiteralPath (Join-Path $data 'factorio-current.log') -Pattern 'Error|error' -ErrorAction SilentlyContinue |
  Select-Object -First 10 | ForEach-Object { $_.Line }
"finished: $finished"
exit $(if ($finished) { 0 } else { 1 })
