$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path $PSScriptRoot '..\create-worktree.ps1'
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) "boorusama-worktree-action-$([guid]::NewGuid())"

function Invoke-Git {
    param(
        [Parameter(Mandatory)]
        [string] $WorkingDirectory,

        [Parameter(ValueFromRemainingArguments)]
        [string[]] $Arguments
    )

    $output = & git -C $WorkingDirectory @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed:`n$($output -join "`n")"
    }

    return $output
}

function Assert-Equal {
    param(
        [Parameter(Mandatory)]
        [string] $Expected,

        [Parameter(Mandatory)]
        [string] $Actual,

        [Parameter(Mandatory)]
        [string] $Message
    )

    if ($Expected -ne $Actual) {
        throw "$Message Expected '$Expected', got '$Actual'."
    }
}

function Assert-True {
    param(
        [Parameter(Mandatory)]
        [bool] $Condition,

        [Parameter(Mandatory)]
        [string] $Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

try {
    $tasks = Get-Content -Raw (Join-Path $PSScriptRoot '..\tasks.json') | ConvertFrom-Json
    $createTask = $tasks.tasks | Where-Object label -eq 'Worktrees: Create or Open'
    Assert-Equal 'process' $createTask.type 'The task should bypass shell command reconstruction.'
    Assert-Equal '${workspaceFolder}/.vscode/create-worktree.ps1' $createTask.args[4] 'The script path should survive VS Code task substitution on Windows.'
    Assert-Equal '${input:branchName}' $createTask.options.env.BOORUSAMA_WORKTREE_BRANCH 'The optional branch should be passed through the environment.'
    Assert-True (-not ($createTask.args -contains '-WorktreeName')) 'The create task should let the script choose a short default name.'

    $chooseTask = $tasks.tasks | Where-Object label -eq 'Worktrees: Choose Existing Branch'
    Assert-True (-not ($chooseTask.args -contains '-WorktreeName')) 'The branch-selection task should let the script choose a short default name.'

    New-Item -ItemType Directory -Path $testRoot | Out-Null
    Invoke-Git $testRoot init | Out-Null
    Invoke-Git $testRoot config user.email tests@example.com | Out-Null
    Invoke-Git $testRoot config user.name 'Worktree Tests' | Out-Null
    Set-Content -LiteralPath (Join-Path $testRoot 'README.md') -Value 'test repository'
    Invoke-Git $testRoot add README.md | Out-Null
    Invoke-Git $testRoot commit -m initial | Out-Null

    $copiedScriptDirectory = Join-Path $testRoot '.vscode'
    New-Item -ItemType Directory -Path $copiedScriptDirectory | Out-Null
    $copiedScript = Join-Path $copiedScriptDirectory 'create-worktree.ps1'
    Copy-Item -LiteralPath $scriptPath -Destination $copiedScript
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $copiedScript -WorktreeName 'default-root' -BranchName 'feature/default-root' -NoOpen -SkipInitialize
    if ($LASTEXITCODE -ne 0) {
        throw 'Resolving the repository from the script location failed.'
    }
    $defaultRootWorktree = Join-Path $testRoot '.worktrees\default-root'
    Assert-Equal 'feature/default-root' (Invoke-Git $defaultRootWorktree branch --show-current) 'The workspace invocation should resolve its repository root.'

    & $scriptPath -RepositoryRoot $testRoot -BranchName 'feature/short-default' -NoOpen -SkipInitialize
    if ($LASTEXITCODE -ne 0) {
        throw 'Creating a worktree with an automatic name failed.'
    }
    $shortDefaultWorktree = Join-Path $testRoot '.worktrees\w1'
    Assert-Equal 'feature/short-default' (Invoke-Git $shortDefaultWorktree branch --show-current) 'A missing worktree name should use the first short name.'

    & $scriptPath -RepositoryRoot $testRoot -BranchName 'feature/short-default-2' -NoOpen -SkipInitialize
    if ($LASTEXITCODE -ne 0) {
        throw 'Creating a second worktree with an automatic name failed.'
    }
    $secondShortDefaultWorktree = Join-Path $testRoot '.worktrees\w2'
    Assert-Equal 'feature/short-default-2' (Invoke-Git $secondShortDefaultWorktree branch --show-current) 'An occupied short name should advance to the next available name.'

    & $scriptPath -RepositoryRoot $testRoot -WorktreeName 'new-feature' -BranchName 'feature/new-feature' -NoOpen -SkipInitialize
    if ($LASTEXITCODE -ne 0) {
        throw 'Creating a new worktree failed.'
    }
    $newWorktree = Join-Path $testRoot '.worktrees\new-feature'
    Assert-Equal 'feature/new-feature' (Invoke-Git $newWorktree branch --show-current) 'A missing branch should be created.'

    Remove-Item -LiteralPath $newWorktree -Recurse -Force
    Invoke-Git $testRoot worktree prune | Out-Null
    & $scriptPath -RepositoryRoot $testRoot -WorktreeName 'existing-feature' -BranchName 'feature/new-feature' -NoOpen -SkipInitialize
    if ($LASTEXITCODE -ne 0) {
        throw 'Checking out an existing branch failed.'
    }
    $existingWorktree = Join-Path $testRoot '.worktrees\existing-feature'
    Assert-Equal 'feature/new-feature' (Invoke-Git $existingWorktree branch --show-current) 'An existing local branch should be reused.'

    & $scriptPath -RepositoryRoot $testRoot -WorktreeName 'existing-feature' -BranchName 'feature/new-feature' -NoOpen -SkipInitialize
    if ($LASTEXITCODE -ne 0) {
        throw 'Reopening an existing matching worktree failed.'
    }

    Write-Host 'All worktree action tests passed.'
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}
