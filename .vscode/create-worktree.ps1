[CmdletBinding()]
param(
    [string] $RepositoryRoot,
    [string] $WorktreeName,
    [string] $BranchName,
    [switch] $ChooseBranch,
    [switch] $NoOpen,
    [switch] $SkipInitialize
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    $RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}

function Invoke-Git {
    param(
        [Parameter(ValueFromRemainingArguments)]
        [string[]] $Arguments
    )

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & git -C $RepositoryRoot @Arguments 2>&1
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

function Test-GitReference {
    param([Parameter(Mandatory)][string] $Reference)

    & git -C $RepositoryRoot show-ref --verify --quiet $Reference
    return $LASTEXITCODE -eq 0
}

function Get-NextWorktreeName {
    $registeredPaths = @(
        Invoke-Git worktree list --porcelain |
            Where-Object { $_ -like 'worktree *' } |
            ForEach-Object { [System.IO.Path]::GetFullPath($_.Substring(9)) }
    )

    for ($index = 1; ; $index++) {
        $candidate = "w$index"
        $candidatePath = [System.IO.Path]::GetFullPath(
            (Join-Path $RepositoryRoot ".worktrees\$candidate")
        )

        if (Test-Path -LiteralPath $candidatePath) {
            continue
        }
        if ($registeredPaths -contains $candidatePath) {
            continue
        }

        return $candidate
    }
}

function Select-GitBranch {
    $branches = @(
        Invoke-Git for-each-ref '--format=%(refname:short)' refs/heads refs/remotes |
            Where-Object { $_ -and $_ -notmatch '/HEAD$' } |
            Sort-Object -Unique
    )
    if ($branches.Count -eq 0) {
        throw 'No existing branches are available.'
    }

    Write-Host 'Choose a branch:'
    for ($index = 0; $index -lt $branches.Count; $index++) {
        Write-Host "  $($index + 1). $($branches[$index])"
    }

    $selection = Read-Host 'Branch number'
    $selectionNumber = 0
    if (-not [int]::TryParse($selection, [ref] $selectionNumber) -or
        $selectionNumber -lt 1 -or $selectionNumber -gt $branches.Count) {
        throw "'$selection' is not a valid branch number."
    }

    return $branches[$selectionNumber - 1] -replace '^origin/', ''
}

function Get-ToolCommand {
    param(
        [Parameter(Mandatory)]
        [string] $Tool
    )

    $fvm = Get-Command fvm -ErrorAction SilentlyContinue
    if ($fvm) {
        return @($fvm.Source, $Tool)
    }

    $systemTool = Get-Command $Tool -ErrorAction Stop
    return @($systemTool.Source)
}

function Invoke-ToolCommand {
    param(
        [Parameter(Mandatory)]
        [string[]] $Command,

        [Parameter(Mandatory)]
        [string[]] $Arguments,

        [Parameter(Mandatory)]
        [string] $WorkingDirectory
    )

    Push-Location $WorkingDirectory
    try {
        $commandArguments = @()
        if ($Command.Count -gt 1) {
            $commandArguments += $Command[1..($Command.Count - 1)]
        }
        $commandArguments += $Arguments
        & $Command[0] @commandArguments
        if ($LASTEXITCODE -ne 0) {
            throw "$($Command -join ' ') $($Arguments -join ' ') failed with exit code $LASTEXITCODE."
        }
    }
    finally {
        Pop-Location
    }
}

function Initialize-Worktree {
    param(
        [Parameter(Mandatory)]
        [string] $Target
    )

    $generatedFiles = @(
        (Join-Path $Target 'packages\i18n\lib\src\gen\strings.g.dart'),
        (Join-Path $Target 'lib\boorus\registry.g.dart')
    )
    if (($generatedFiles | Where-Object { -not (Test-Path -LiteralPath $_) }).Count -eq 0) {
        Write-Host "Worktree '$Target' is already initialized."
        return
    }

    Write-Host "Initializing worktree '$Target'..."
    $previousUseFvm = $env:BOORUSAMA_USE_FVM
    $previousRoot = $env:BOORUSAMA_ROOT
    try {
        $flutter = Get-ToolCommand 'flutter'
        $dart = Get-ToolCommand 'dart'
        $env:BOORUSAMA_USE_FVM = if ($flutter.Count -gt 1) { 'true' } else { 'false' }
        $env:BOORUSAMA_ROOT = $Target

        Invoke-ToolCommand $flutter @('pub', 'get') $Target
        Invoke-ToolCommand $dart @('pub', 'get') (Join-Path $Target 'packages\boorusama_cli')
        Invoke-ToolCommand $dart @('run', 'bin/boorusama.dart', 'gen') (Join-Path $Target 'packages\boorusama_cli')
        Write-Host "Worktree '$Target' initialized."
    }
    finally {
        if ($null -eq $previousUseFvm) {
            Remove-Item Env:BOORUSAMA_USE_FVM -ErrorAction SilentlyContinue
        }
        else {
            $env:BOORUSAMA_USE_FVM = $previousUseFvm
        }
        if ($null -eq $previousRoot) {
            Remove-Item Env:BOORUSAMA_ROOT -ErrorAction SilentlyContinue
        }
        else {
            $env:BOORUSAMA_ROOT = $previousRoot
        }
    }
}

if (-not (Test-Path -LiteralPath (Join-Path $RepositoryRoot '.git'))) {
    throw "'$RepositoryRoot' is not a Git checkout."
}

if ([string]::IsNullOrWhiteSpace($WorktreeName)) {
    $WorktreeName = Get-NextWorktreeName
    Write-Host "No worktree name supplied; using '$WorktreeName'."
}
$WorktreeName = $WorktreeName.Trim()
if ($WorktreeName -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$' -or $WorktreeName -in '.', '..') {
    throw 'The worktree name may contain only letters, numbers, dots, underscores, and hyphens.'
}

if ($ChooseBranch) {
    $BranchName = Select-GitBranch
}
elseif ([string]::IsNullOrWhiteSpace($BranchName)) {
    $BranchName = $env:BOORUSAMA_WORKTREE_BRANCH
}
if ([string]::IsNullOrWhiteSpace($BranchName)) {
    $BranchName = $WorktreeName
}
$BranchName = $BranchName.Trim()
& git -C $RepositoryRoot check-ref-format --branch $BranchName 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "'$BranchName' is not a valid branch name."
}

$worktreePath = Join-Path $RepositoryRoot ".worktrees\$WorktreeName"
$resolvedTarget = [System.IO.Path]::GetFullPath($worktreePath)
$registeredWorktrees = @(Invoke-Git worktree list --porcelain)
$currentPath = $null
$currentBranch = $null
$matchingBranchPath = $null
foreach ($line in $registeredWorktrees) {
    if ($line -like 'worktree *') {
        $currentPath = $line.Substring(9)
        $currentBranch = $null
    }
    elseif ($line -like 'branch refs/heads/*') {
        $currentBranch = $line.Substring(18)
        if ($currentBranch -eq $BranchName) {
            $matchingBranchPath = $currentPath
        }
    }
    elseif ($line -eq '' -and $currentPath) {
        if ([System.IO.Path]::GetFullPath($currentPath) -eq $resolvedTarget) {
            if ($currentBranch -ne $BranchName) {
                throw "The worktree '$WorktreeName' already uses branch '$currentBranch'."
            }
            $matchingBranchPath = $currentPath
        }
        $currentPath = $null
    }
}

if ($matchingBranchPath) {
    if ([System.IO.Path]::GetFullPath($matchingBranchPath) -ne $resolvedTarget) {
        throw "Branch '$BranchName' is already checked out at '$matchingBranchPath'."
    }
    Write-Host "Opening existing worktree '$resolvedTarget'."
}
else {
    if (Test-Path -LiteralPath $resolvedTarget) {
        throw "'$resolvedTarget' exists but is not a registered worktree."
    }

    Invoke-Git config worktree.useRelativePaths true | Out-Null
    if (Test-GitReference "refs/heads/$BranchName") {
        Invoke-Git worktree add --relative-paths $resolvedTarget $BranchName | Out-Null
    }
    elseif (Test-GitReference "refs/remotes/origin/$BranchName") {
        Invoke-Git worktree add --relative-paths $resolvedTarget -b $BranchName "origin/$BranchName" | Out-Null
    }
    else {
        Invoke-Git worktree add --relative-paths $resolvedTarget -b $BranchName | Out-Null
    }
    Write-Host "Created worktree '$resolvedTarget' on branch '$BranchName'."
}

if (-not $SkipInitialize) {
    Initialize-Worktree $resolvedTarget
}

if (-not $NoOpen) {
    if (Get-Command code -ErrorAction SilentlyContinue) {
        & code -n $resolvedTarget
    }
    else {
        Write-Warning "The 'code' command is unavailable. Open '$resolvedTarget' manually."
    }
}
