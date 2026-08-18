$ErrorActionPreference = 'Stop'

$adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
if (-not (Test-Path -LiteralPath $adb)) {
    throw "ADB was not found at $adb."
}

& $adb kill-server
Write-Host 'The network-accessible ADB server has stopped.'
