$ErrorActionPreference = 'Stop'

$adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
if (-not (Test-Path -LiteralPath $adb)) {
    throw "ADB was not found at $adb. Set up Android SDK platform-tools first."
}

& $adb kill-server
& $adb -a start-server

Write-Warning 'ADB is listening on all host interfaces on TCP port 5037. Keep the Windows firewall enabled and stop ADB when it is not needed.'
& $adb devices -l
