[CmdletBinding()]
param(
    [string] $RepositoryRoot,
    [string] $WorktreeName,
    [switch] $SkipConfirmation,
    [string] $DockerCommand = 'docker'
)

$ErrorActionPreference = 'Stop'

function Invoke-NativeCommand {
    param(
        [Parameter(Mandatory)][string] $Command,
        [Parameter(Mandatory)][string[]] $Arguments
    )

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & $Command @Arguments 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($exitCode -ne 0) {
        throw "$Command $($Arguments -join ' ') failed:`n$($output -join "`n")"
    }
    return $output
}

function Invoke-Git {
    param([Parameter(ValueFromRemainingArguments)][string[]] $Arguments)
    return Invoke-NativeCommand git (@('-C', $RepositoryRoot) + $Arguments)
}

function Invoke-Docker {
    param([Parameter(ValueFromRemainingArguments)][string[]] $Arguments)
    return Invoke-NativeCommand $DockerCommand $Arguments
}

function Invoke-WithShortWorktreePath {
    param(
        [Parameter(Mandatory)][scriptblock] $Action
    )

    $driveName = $null
    foreach ($candidate in @('B', 'Z', 'Y', 'X', 'W')) {
        $candidateName = $candidate + ':'
        $query = @(& subst $candidateName 2>$null)
        if (($LASTEXITCODE -ne 0 -or $query.Count -eq 0) -and -not (Test-Path -LiteralPath ($candidateName + '\'))) {
            $driveName = $candidateName
            break
        }
    }
    if ($null -eq $driveName) {
        throw 'No temporary drive letter is available for short-path worktree cleanup.'
    }

    & subst $driveName $worktreesRoot
    if ($LASTEXITCODE -ne 0) {
        throw "Could not map $driveName to $worktreesRoot."
    }
    try {
        & $Action ($driveName + '\' + $WorktreeName)
    }
    finally {
        & subst $driveName /d
    }
}

function Remove-GeneratedWorktreeDirectories {
    param(
        [Parameter(Mandatory)][string] $ShortTarget
    )

    foreach ($relativePath in @('.dart_tool', 'build', 'android\.gradle')) {
        $path = Join-Path $ShortTarget $relativePath
        if (Test-Path -LiteralPath $path) {
            Remove-Item -LiteralPath $path -Recurse -Force
        }
    }
}

if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    $checkoutRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $commonDirectory = Invoke-NativeCommand git @('-C', $checkoutRoot, 'rev-parse', '--path-format=absolute', '--git-common-dir')
    $RepositoryRoot = Split-Path ($commonDirectory | Select-Object -First 1) -Parent
}
$RepositoryRoot = [System.IO.Path]::GetFullPath($RepositoryRoot)
$worktreesRoot = [System.IO.Path]::GetFullPath((Join-Path $RepositoryRoot '.worktrees'))

$registeredWorktrees = @()
$currentPath = $null
foreach ($line in @(Invoke-Git worktree list --porcelain)) {
    if ($line -like 'worktree *') {
        $currentPath = [System.IO.Path]::GetFullPath($line.Substring(9))
        if ($currentPath.StartsWith("$worktreesRoot$([System.IO.Path]::DirectorySeparatorChar)", [System.StringComparison]::OrdinalIgnoreCase)) {
            $registeredWorktrees += [pscustomobject]@{
                Name = Split-Path $currentPath -Leaf
                Path = $currentPath
            }
        }
    }
}

if ([string]::IsNullOrWhiteSpace($WorktreeName)) {
    if ($registeredWorktrees.Count -eq 0) {
        throw 'No removable worktrees are registered under .worktrees/.'
    }
    Write-Host 'Choose a worktree to remove:'
    for ($index = 0; $index -lt $registeredWorktrees.Count; $index++) {
        Write-Host "  $($index + 1). $($registeredWorktrees[$index].Name)"
    }
    $selection = Read-Host 'Worktree number'
    $selectionNumber = 0
    if (-not [int]::TryParse($selection, [ref] $selectionNumber) -or
        $selectionNumber -lt 1 -or $selectionNumber -gt $registeredWorktrees.Count) {
        throw "'$selection' is not a valid worktree number."
    }
    $WorktreeName = $registeredWorktrees[$selectionNumber - 1].Name
}

$target = $registeredWorktrees | Where-Object Name -eq $WorktreeName | Select-Object -First 1
if ($null -eq $target) {
    throw "'$WorktreeName' is not a registered worktree under '$worktreesRoot'."
}

$changes = @(Invoke-Git -C $target.Path status --porcelain)
if ($changes.Count -gt 0) {
    throw "Worktree '$WorktreeName' has modified or untracked files. Commit or discard them before removal."
}

$containerIds = @(Invoke-Docker ps -aq --filter 'label=devcontainer.local_folder')
$matchingContainers = @()
$privateVolumes = @()
if ($containerIds.Count -gt 0) {
    $inspectionJson = @(Invoke-Docker inspect @containerIds)
    $containerData = ConvertFrom-Json ($inspectionJson -join "`n")
    $targetContainerRoot = "/workspace/Boorusama/.worktrees/$WorktreeName"
    $privateDestinations = @(
        "$targetContainerRoot/.dart_tool",
        "$targetContainerRoot/build",
        "$targetContainerRoot/android/.gradle"
    )
    foreach ($container in $containerData) {
        $localFolder = $container.Config.Labels.'devcontainer.local_folder'
        if ($localFolder -and [System.IO.Path]::GetFullPath($localFolder) -ieq $target.Path) {
            $matchingContainers += $container.Id
            foreach ($mount in $container.Mounts) {
                if ($mount.Type -eq 'volume' -and $mount.Destination -in $privateDestinations) {
                    if ($mount.Name -notlike 'boorusama-*') {
                        throw "Refusing to remove unexpected volume '$($mount.Name)'."
                    }
                    $privateVolumes += $mount.Name
                }
            }
        }
    }
}
$matchingContainers = @($matchingContainers | Sort-Object -Unique)
$privateVolumes = @($privateVolumes | Sort-Object -Unique)

Write-Host "Worktree: $($target.Path)"
Write-Host "Containers: $(if ($matchingContainers.Count) { $matchingContainers -join ', ' } else { '<none found>' })"
Write-Host "Private volumes: $(if ($privateVolumes.Count) { $privateVolumes -join ', ' } else { '<none found>' })"
if ($matchingContainers.Count -eq 0) {
    Write-Warning 'No matching dev container exists, so orphaned private volumes cannot be identified safely.'
}

if (-not $SkipConfirmation) {
    $confirmation = Read-Host "Type '$WorktreeName' to remove this worktree and its private Docker resources"
    if ($confirmation -cne $WorktreeName) {
        throw 'Removal cancelled.'
    }
}

if ($matchingContainers.Count -gt 0) {
    Invoke-Docker rm -f @matchingContainers | Out-Null
}
if ($privateVolumes.Count -gt 0) {
    Invoke-Docker volume rm @privateVolumes | Out-Null
}

$removalError = $null
try {
    Invoke-WithShortWorktreePath {
        param($shortTarget)
        Remove-GeneratedWorktreeDirectories $shortTarget
        Invoke-Git worktree remove -- $shortTarget | Out-Null
    }
}
catch {
    $removalError = $_
    if (Test-Path -LiteralPath $target.Path) {
        Write-Warning 'Git removed or failed to remove the worktree registration, but the directory remains. Removing the remaining files through a short path.'
        Invoke-WithShortWorktreePath {
            param($shortTarget)
            if (Test-Path -LiteralPath $shortTarget) {
                Remove-Item -LiteralPath $shortTarget -Recurse -Force
            }
        }
    }
    if ($null -ne $removalError -and (Test-Path -LiteralPath $target.Path)) {
        throw $removalError
    }
    Invoke-Git worktree prune | Out-Null
}

Write-Host "Removed worktree '$WorktreeName'. Its branch was retained."
