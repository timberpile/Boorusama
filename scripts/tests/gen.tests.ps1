$ErrorActionPreference = 'Stop'

function Assert-Equal($Expected, $Actual, $Message) {
    if ($Expected -ne $Actual) {
        throw "$Message Expected '$Expected', got '$Actual'."
    }
}

$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("boorusama-gen-test-" + [guid]::NewGuid())
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

try {
    $cliDir = Join-Path $testRoot 'packages\boorusama_cli'
    New-Item -ItemType Directory -Path $cliDir -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $repoRoot 'gen.ps1') -Destination (Join-Path $testRoot 'gen.ps1')
    Set-Content -LiteralPath (Join-Path $testRoot '.fvmrc') -Value '{}'

    $logPath = Join-Path $testRoot 'dart-invocation.txt'
    $fakeDart = Join-Path $testRoot 'fake-dart.cmd'
    Set-Content -LiteralPath $fakeDart -Value @"
@echo off
echo cwd=%CD%>"$logPath"
echo root=%BOORUSAMA_ROOT%>>"$logPath"
echo use_fvm=%BOORUSAMA_USE_FVM%>>"$logPath"
echo args=%*>>"$logPath"
if not "%FAKE_DART_EXIT%"=="" exit /b %FAKE_DART_EXIT%
"@

    $previousDart = $env:BOORUSAMA_DART
    $env:BOORUSAMA_DART = $fakeDart
    try {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $testRoot 'gen.ps1') i18n --verbose
    }
    finally {
        $env:BOORUSAMA_DART = $previousDart
    }
    Assert-Equal 0 $LASTEXITCODE 'The wrapper should return the Dart command exit code.'

    $lines = Get-Content -LiteralPath $logPath
    Assert-Equal "cwd=$cliDir" $lines[0] 'The CLI should run from its package directory.'
    Assert-Equal "root=$testRoot" $lines[1] 'The wrapper should expose the repository root.'
    Assert-Equal 'use_fvm=false' $lines[2] 'A custom native Dart command should disable FVM.'
    Assert-Equal 'args=run bin/boorusama.dart i18n gen --verbose' $lines[3] 'The wrapper should preserve gen.sh scope and argument ordering.'

    $env:BOORUSAMA_DART = $fakeDart
    $env:FAKE_DART_EXIT = '7'
    try {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $testRoot 'gen.ps1') booru
        Assert-Equal 7 $LASTEXITCODE 'The wrapper should propagate a failed generator exit code.'
    }
    finally {
        $env:BOORUSAMA_DART = $previousDart
        Remove-Item Env:FAKE_DART_EXIT -ErrorAction SilentlyContinue
    }
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}
