$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path $PSScriptRoot '..\remove-worktree.ps1'
$tasksPath = Join-Path $PSScriptRoot '..\tasks.json'
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) "boorusama-remove-worktree-$([guid]::NewGuid())"

function Invoke-Git {
    param(
        [Parameter(Mandatory)][string] $WorkingDirectory,
        [Parameter(ValueFromRemainingArguments)][string[]] $Arguments
    )

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & git -C $WorkingDirectory @Arguments 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($exitCode -ne 0) {
        throw "git $($Arguments -join ' ') failed:`n$($output -join "`n")"
    }
    return $output
}

function Assert-True {
    param([bool] $Condition, [string] $Message)
    if (-not $Condition) { throw $Message }
}

try {
    $tasks = Get-Content -Raw $tasksPath | ConvertFrom-Json
    $removeTask = $tasks.tasks | Where-Object label -eq 'Worktrees: Remove'
    Assert-True ($null -ne $removeTask) 'The workspace should expose a worktree removal task.'

    New-Item -ItemType Directory -Path $testRoot | Out-Null
    Invoke-Git $testRoot init | Out-Null
    Invoke-Git $testRoot config user.email tests@example.com | Out-Null
    Invoke-Git $testRoot config user.name 'Worktree Tests' | Out-Null
    Set-Content -LiteralPath (Join-Path $testRoot 'README.md') -Value 'test repository'
    Invoke-Git $testRoot add README.md | Out-Null
    Invoke-Git $testRoot commit -m initial | Out-Null

    $worktreePath = Join-Path $testRoot '.worktrees\remove-me'
    Invoke-Git $testRoot worktree add --relative-paths $worktreePath -b feature/remove-me | Out-Null

    $dockerLog = Join-Path $testRoot 'docker.log'
    $fakeDocker = Join-Path $testRoot 'fake-docker.ps1'
    Set-Content -LiteralPath $fakeDocker -Value @'
param([Parameter(ValueFromRemainingArguments)][string[]] $DockerArguments)
$commandLine = $DockerArguments -join ' '
if ($DockerArguments[0] -eq 'ps') {
    Write-Output 'container-1'
    Write-Output 'container-2'
    exit 0
}
if ($DockerArguments[0] -eq 'inspect') {
    @(
        @{
            Id = 'container-1'
            Config = @{ Labels = @{ 'devcontainer.local_folder' = $env:FAKE_DOCKER_WORKTREE } }
            Mounts = @(
                @{ Type = 'volume'; Name = 'boorusama-private-dart-tool'; Destination = '/workspace/Boorusama/.worktrees/remove-me/.dart_tool' },
                @{ Type = 'volume'; Name = 'boorusama-private-build'; Destination = '/workspace/Boorusama/.worktrees/remove-me/build' },
                @{ Type = 'volume'; Name = 'boorusama-private-android-gradle'; Destination = '/workspace/Boorusama/.worktrees/remove-me/android/.gradle' },
                @{ Type = 'volume'; Name = 'boorusama-pub-cache'; Destination = '/root/.pub-cache' }
            )
        },
        @{
            Id = 'container-2'
            Config = @{ Labels = @{ 'devcontainer.local_folder' = 'C:\unrelated\worktree' } }
            Mounts = @()
        }
    ) | ConvertTo-Json -Depth 6
    exit 0
}
Add-Content -LiteralPath $env:FAKE_DOCKER_LOG -Value $commandLine
exit 0
'@
    $env:FAKE_DOCKER_WORKTREE = $worktreePath
    $env:FAKE_DOCKER_LOG = $dockerLog

    $copiedScriptDirectory = Join-Path $testRoot '.vscode'
    New-Item -ItemType Directory -Path $copiedScriptDirectory | Out-Null
    $copiedScript = Join-Path $copiedScriptDirectory 'remove-worktree.ps1'
    Copy-Item -LiteralPath $scriptPath -Destination $copiedScript
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $copiedScript -WorktreeName remove-me -SkipConfirmation -DockerCommand $fakeDocker
    if ($LASTEXITCODE -ne 0) { throw 'The removal action failed.' }

    Assert-True (-not (Test-Path -LiteralPath $worktreePath)) 'The linked worktree should be removed.'
    Assert-True ([bool](Invoke-Git $testRoot show-ref --verify refs/heads/feature/remove-me)) 'The branch should remain.'
    $dockerCommands = Get-Content -Raw $dockerLog
    Assert-True ($dockerCommands -match 'rm -f container-1') 'The matching dev container should be removed.'
    Assert-True ($dockerCommands -notmatch 'rm -f.*container-2') 'An unrelated dev container should remain.'
    Assert-True ($dockerCommands -match 'volume rm.*boorusama-private-dart-tool') 'The private Dart volume should be removed.'
    Assert-True ($dockerCommands -match 'boorusama-private-build') 'The private build volume should be removed.'
    Assert-True ($dockerCommands -match 'boorusama-private-android-gradle') 'The private Android Gradle volume should be removed.'
    Assert-True ($dockerCommands -notmatch 'boorusama-pub-cache') 'Shared dependency volumes should remain.'

    Write-Host 'All worktree removal tests passed.'
}
finally {
    Remove-Item Env:FAKE_DOCKER_WORKTREE -ErrorAction SilentlyContinue
    Remove-Item Env:FAKE_DOCKER_LOG -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}
