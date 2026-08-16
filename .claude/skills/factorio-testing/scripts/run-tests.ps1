# Runs a mod's factorio-test suite against the dev install, headless by default, graphics on
# request. Never touches the live mods folder, the play install, or %APPDATA%\Factorio: the
# CLI gets its own data directory, and portal credentials come from the DEV install's
# player-data.json only.

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string] $ModPath,

  # Defaults to the install this repo lives in, same resolution as validate.ps1 -- this script
  # sits one level deeper (scripts/), hence five hops. No fallback to any other install.
  [string] $FactorioPath,

  # The graphics tier: a real window, a real connected player, the gui-tagged specs included.
  # The game is closed automatically when the run finishes unless -KeepOpen.
  [switch] $Graphics,
  [switch] $KeepOpen,

  # Extra mods to enable beside the mod under test. quality hard-requires recycler on 2.1, so
  # the pair travels together; the SA set is the modset every numeric assertion was measured on.
  [string[]] $Mods = @('quality', 'recycler', 'space-age', 'elevated-rails'),

  # Lua patterns forwarded to the CLI to run a subset, e.g. 'planner' or 'eject'.
  [string[]] $Filter = @(),

  [string] $DataDir
)

$ErrorActionPreference = 'Stop'

if (-not $FactorioPath) {
  $selfInstall = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\..\..\..')).Path
  $FactorioPath = @($env:FACTORIO_PATH, $selfInstall) |
    Where-Object { $_ -and (Test-Path -LiteralPath (Join-Path $_ 'bin\x64\factorio.exe')) } |
    Select-Object -First 1
  if (-not $FactorioPath) {
    throw "No dev install found at $selfInstall - pass -FactorioPath or set FACTORIO_PATH."
  }
}
$exe = Join-Path $FactorioPath 'bin\x64\factorio.exe'

$ModPath = (Resolve-Path -LiteralPath $ModPath).Path
$infoPath = Join-Path $ModPath 'info.json'
if (-not (Test-Path -LiteralPath $infoPath)) { throw "No info.json in $ModPath" }
$info = Get-Content -LiteralPath $infoPath -Raw | ConvertFrom-Json
$name = $info.name
$folder = Split-Path -Leaf $ModPath
if ($folder -ne $name -and $folder -ne "$name`_$($info.version)") {
  throw "Folder '$folder' matches neither '$name' nor '$name`_$($info.version)'."
}

$baseVer = (Get-Content -LiteralPath (Join-Path $FactorioPath 'data\base\info.json') -Raw |
  ConvertFrom-Json).version

# Keyed per install: pointing -FactorioPath at the 2.0 install must not flip the mod-list a
# 2.1 run wrote into the same folder, and vice versa.
if (-not $DataDir) { $DataDir = Join-Path $env:LOCALAPPDATA "factorio-testing\$name-$baseVer" }
$modsDir = Join-Path $DataDir 'mods'
New-Item -ItemType Directory -Force -Path $modsDir | Out-Null

# On 2.0 the recycler entity ships inside quality and no `recycler` mod exists -- enabling
# one would send the CLI to the portal for it. Only the DEFAULT set is trimmed; an explicit
# -Mods is the caller's own business.
if (-not $PSBoundParameters.ContainsKey('Mods') -and
    -not (Test-Path -LiteralPath (Join-Path $FactorioPath 'data\recycler'))) {
  $Mods = @($Mods | Where-Object { $_ -ne 'recycler' })
}

# The CLI shells out to `npx fmtk` with a bare spawn, which on Windows resolves only a real
# .exe -- npm ships none. The scoop shim (node.exe + npx-cli.js) is what makes it callable.
if (-not (Get-Command 'npx.exe' -ErrorAction SilentlyContinue)) {
  $npxCli = 'C:\Program Files\nodejs\node_modules\npm\bin\npx-cli.js'
  if ((Get-Command scoop -ErrorAction SilentlyContinue) -and (Test-Path -LiteralPath $npxCli)) {
    Write-Host 'Creating npx.exe shim (the factorio-test CLI needs a spawnable npx).'
    scoop shim add npx 'C:\Program Files\nodejs\node.exe' "`"$npxCli`"" | Out-Null
  } else {
    throw 'No npx.exe on PATH and no scoop to shim one - the CLI cannot spawn fmtk without it.'
  }
}
if (-not (Get-Command 'factorio-test' -ErrorAction SilentlyContinue)) {
  throw "factorio-test CLI not installed - npm install -g factorio-test-cli"
}

# Pre-seed the framework mod so the CLI never reaches its own download path, whose default
# credential source is %APPDATA%\Factorio - the play install, off-limits in this workspace.
# Version-matched to the install: the newest portal release for THIS game's major.minor,
# because the overall-newest is a 2.1-only build that a 2.0 install refuses to load.
if (-not (Get-ChildItem -LiteralPath $modsDir -Filter 'factorio-test_*.zip' -ErrorAction SilentlyContinue)) {
  $gameMajor = ($baseVer -split '\.')[0..1] -join '.'
  Write-Host "Downloading the factorio-test mod for Factorio $gameMajor (dev-install credentials)."
  $pd = Get-Content -LiteralPath (Join-Path $FactorioPath 'player-data.json') -Raw | ConvertFrom-Json
  if (-not ($pd.'service-username' -and $pd.'service-token')) {
    throw 'This dev install is not logged in to the portal, so factorio-test cannot be fetched.'
  }
  $portal = Invoke-RestMethod -UseBasicParsing -Uri 'https://mods.factorio.com/api/mods/factorio-test'
  $release = $portal.releases | Where-Object { $_.info_json.factorio_version -eq $gameMajor } |
    Sort-Object { [datetime]$_.released_at } | Select-Object -Last 1
  if (-not $release) { throw "No factorio-test release exists for Factorio $gameMajor." }
  $url = 'https://mods.factorio.com' + $release.download_url +
    "?username=$($pd.'service-username')&token=$($pd.'service-token')"
  Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile (Join-Path $modsDir $release.file_name)
}

$cliArgs = @('run', '-p', $ModPath, '--factorio-path', $exe, '-d', $DataDir, '--no-output-file')
foreach ($m in $Mods) { $cliArgs += @('--mods', $m) }

Write-Host "Testing $name against $FactorioPath (base $baseVer)"

if (-not $Graphics) {
  # gui-tagged specs run here too: the CLI's bundled singleplayer save carries a player that
  # stays flagged connected under --benchmark (measured 2.1.14), so even headless runs have a
  # real cursor and gui root. The graphics tier below is the real-client double-check.
  if ($Filter.Count) { $cliArgs += @('--') + $Filter }
  & factorio-test @cliArgs
  exit $LASTEXITCODE
}

# Graphics tier. Two facts drive the shape of everything below, both learned the hard way:
# the CLI's bundled save is a 2.0-era map whose migration dialog blocks a graphics load
# waiting for a click, so a fresh save is created HERE, at the installed version, with this
# exact mod set (the mod's test guard also bakes in freeplay's skip-intro flags at create
# time); and graphics mode is interactive by design -- the CLI never closes the window -- so
# a watcher parses the log for the framework's finish marker and closes the game itself,
# killing only processes launched from this install's path.
$save = Join-Path $DataDir 'gui-save.zip'
Remove-Item -LiteralPath $save -Force -ErrorAction SilentlyContinue
$ini = Join-Path $DataDir 'config.ini'
if (-not (Test-Path -LiteralPath $ini)) {
  # The CLI writes config.ini and the mod-list on its first run; creating the save without
  # them would bake the wrong mod set in and resurrect the migration dialog.
  throw 'Fresh data directory - run the headless tier once first, then -Graphics.'
}
Write-Host 'Creating a current-version save for the graphics run.'
$create = Start-Process -FilePath $exe -ArgumentList @(
  '--create', "`"$save`"", '--mod-directory', "`"$modsDir`"", '-c', "`"$ini`"") `
  -Wait -PassThru -NoNewWindow
if ($create.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $save)) {
  throw "Save creation failed (exit $($create.ExitCode))."
}

$cliArgs += @('--save', $save, '-g', '--output-timeout', '120')
if ($Filter.Count) { $cliArgs += @('--') + $Filter }

$stdout = Join-Path $DataDir 'graphics-run-out.txt'
$stderr = Join-Path $DataDir 'graphics-run-err.txt'
$log = Join-Path $DataDir 'factorio-current.log'
Remove-Item -LiteralPath $log -Force -ErrorAction SilentlyContinue

# Get-Command resolves the npm .ps1 shim, which Start-Process cannot execute; the .cmd
# sibling is the launchable one.
$cliCmd = Join-Path (Split-Path (Get-Command 'factorio-test').Source) 'factorio-test.cmd'
$cli = Start-Process -FilePath $cliCmd -ArgumentList ($cliArgs | ForEach-Object { "`"$_`"" }) `
  -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru -WindowStyle Hidden

$deadline = (Get-Date).AddSeconds(300)
$marker = $null
while ((Get-Date) -lt $deadline -and -not $cli.HasExited) {
  if (Test-Path -LiteralPath $log) {
    $found = Select-String -LiteralPath $log -Pattern 'Test run finished: (\w+)' |
      Select-Object -First 1
    if ($found) { $marker = $found.Matches[0].Groups[1].Value; break }
  }
  Start-Sleep -Seconds 3
}

if (-not $KeepOpen) {
  Start-Sleep -Seconds 2
  Get-Process factorio -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -like "$FactorioPath*" } | Stop-Process -Force
}
if (-not $cli.WaitForExit(30000)) {
  # A CLI that never noticed the game die would hold the log and output files open in the
  # data dir and quietly break the next run's cleanup.
  Stop-Process -Id $cli.Id -Force -ErrorAction SilentlyContinue
}

Get-Content -LiteralPath $stdout -ErrorAction SilentlyContinue |
  Select-String -Pattern 'PASS |FAIL |Tests:' | ForEach-Object { Write-Host $_.Line.Trim() }

# The kill interrupts the CLI's own exit path, so the verdict comes from the framework's
# marker in the log, not from the CLI's exit code.
if ($marker -eq 'passed') {
  Write-Host 'Graphics tier passed.'
  exit 0
}
if (-not $marker) { $marker = 'never appeared' }
Write-Host "Graphics tier did NOT pass (marker: $marker) - see $stdout"
exit 1
