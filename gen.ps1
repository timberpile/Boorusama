$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$env:BOORUSAMA_ROOT = $root
$GeneratorArguments = @($args)

function Write-GenError([string] $Message) {
    [Console]::Error.WriteLine("[gen] ERROR: $Message")
}

function Resolve-NativeCommand([string] $Command, [string] $Hint) {
    if ([System.IO.Path]::IsPathRooted($Command)) {
        $resolved = $Command
    }
    elseif ($Command.Contains('\') -or $Command.Contains('/')) {
        $resolved = Join-Path $root $Command
    }
    else {
        $resolved = $Command
    }

    if (-not (Get-Command $resolved -ErrorAction SilentlyContinue)) {
        throw "$Command not found. $Hint"
    }

    return $resolved
}

try {
    $useFvm = if ($env:BOORUSAMA_USE_FVM) {
        $env:BOORUSAMA_USE_FVM.ToLowerInvariant()
    }
    else {
        'auto'
    }

    if ($useFvm -notin @('auto', 'true', 'false')) {
        throw "Invalid BOORUSAMA_USE_FVM=$useFvm. Use auto, true, or false."
    }

    $fvmAvailable = [bool](Get-Command 'fvm' -ErrorAction SilentlyContinue)
    $useResolvedFvm = $useFvm -eq 'true' -or (
        $useFvm -eq 'auto' -and
        (Test-Path -LiteralPath (Join-Path $root '.fvmrc')) -and
        $fvmAvailable
    )

    if ($useFvm -eq 'true' -and -not $fvmAvailable) {
        throw 'fvm not found. Install fvm or set BOORUSAMA_USE_FVM=false to use system Flutter/Dart.'
    }

    if ($useFvm -eq 'auto' -and (Test-Path -LiteralPath (Join-Path $root '.fvmrc')) -and -not $fvmAvailable) {
        Write-Host '[gen] .fvmrc found, but fvm is not in PATH; using system Flutter/Dart.'
        $env:BOORUSAMA_USE_FVM = 'false'
    }

    if ($env:BOORUSAMA_DART) {
        $dartCommand = @(Resolve-NativeCommand $env:BOORUSAMA_DART 'Check BOORUSAMA_DART.')
        $env:BOORUSAMA_USE_FVM = 'false'
    }
    elseif ($useResolvedFvm) {
        $dartCommand = @('fvm', 'dart')
    }
    else {
        $dartCommand = @(Resolve-NativeCommand 'dart' 'Install Dart or set BOORUSAMA_DART.')
    }

    $cliArguments = @('run', 'bin/boorusama.dart')
    if ($GeneratorArguments.Count -gt 0 -and $GeneratorArguments[0] -in @('i18n', 'booru')) {
        $cliArguments += $GeneratorArguments[0]
        $cliArguments += 'gen'
        if ($GeneratorArguments.Count -gt 1) {
            $cliArguments += $GeneratorArguments[1..($GeneratorArguments.Count - 1)]
        }
    }
    else {
        $cliArguments += 'gen'
        $cliArguments += $GeneratorArguments
    }

    Push-Location (Join-Path $root 'packages\boorusama_cli')
    try {
        if ($dartCommand.Count -gt 1) {
            & $dartCommand[0] $dartCommand[1] @cliArguments
        }
        else {
            & $dartCommand[0] @cliArguments
        }
        exit $LASTEXITCODE
    }
    finally {
        Pop-Location
    }
}
catch {
    Write-GenError $_.Exception.Message
    exit 1
}
