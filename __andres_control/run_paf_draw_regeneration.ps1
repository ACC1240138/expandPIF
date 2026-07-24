param(
    [Parameter(Mandatory = $true)]
    [string]$RunDirectory,
    [Parameter(Mandatory = $true)]
    [string]$RunId
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$ProjectRoot = 'C:\Users\nDP\Desktop\ACC1240138_private'
$ControlDir = Join-Path $ProjectRoot '__andres_control'
$PythonExe = 'C:\ProgramData\anaconda3\python.exe'
$RscriptExe = 'C:\Program Files\R\R-4.4.1\bin\Rscript.exe'
$Runner = Join-Path $ControlDir 'run_notebook_logged.py'
$Validator = Join-Path $ControlDir 'validate_paf_draw_regeneration.R'
$EventsPath = Join-Path $RunDirectory 'chunk_timings.jsonl'
$ProgressPath = Join-Path $RunDirectory 'progress.json'
$PipelineStatePath = Join-Path $RunDirectory 'pipeline_state.json'
$WorkLogPath = Join-Path $RunDirectory 'worklog.log'
$FailedPath = Join-Path $RunDirectory 'FAILED.json'
$DonePath = Join-Path $RunDirectory 'DONE.json'

New-Item -ItemType Directory -Path $RunDirectory -Force | Out-Null

function Get-IsoTimestamp {
    return (Get-Date).ToString('o')
}

function Write-WorkLog {
    param([string]$Message)
    $line = '[{0}] {1}' -f (Get-IsoTimestamp), $Message
    Add-Content -LiteralPath $WorkLogPath -Value $line -Encoding utf8
}

function Write-AtomicJson {
    param(
        [string]$Path,
        [hashtable]$Payload
    )
    $temporary = "$Path.tmp"
    $Payload | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $temporary -Encoding utf8
    Move-Item -LiteralPath $temporary -Destination $Path -Force
}

function Get-MemorySnapshot {
    $operatingSystem = Get-CimInstance Win32_OperatingSystem
    return @{
        total_visible_gb = [math]::Round($operatingSystem.TotalVisibleMemorySize / 1MB, 3)
        free_physical_gb = [math]::Round($operatingSystem.FreePhysicalMemory / 1MB, 3)
        used_physical_gb = [math]::Round(
            ($operatingSystem.TotalVisibleMemorySize - $operatingSystem.FreePhysicalMemory) / 1MB,
            3
        )
    }
}

function Get-DescendantProcesses {
    param([int]$RootProcessId)
    $allProcesses = @(Get-CimInstance Win32_Process)
    $knownIds = [System.Collections.Generic.HashSet[int]]::new()
    [void]$knownIds.Add($RootProcessId)
    $changed = $true
    while ($changed) {
        $changed = $false
        foreach ($process in $allProcesses) {
            if ($knownIds.Contains([int]$process.ParentProcessId) -and
                -not $knownIds.Contains([int]$process.ProcessId)) {
                [void]$knownIds.Add([int]$process.ProcessId)
                $changed = $true
            }
        }
    }
    return @($allProcesses | Where-Object {
        $_.ProcessId -ne $RootProcessId -and $knownIds.Contains([int]$_.ProcessId)
    })
}

function Clear-RunnerDescendants {
    param([int]$RootProcessId)
    Start-Sleep -Seconds 5
    $descendants = @(Get-DescendantProcesses -RootProcessId $RootProcessId)
    $rProcesses = @($descendants | Where-Object { $_.Name -match '^(R|Rscript)\.exe$' })
    foreach ($process in $rProcesses) {
        Write-WorkLog (
            'Stopping a lingering runner-owned R descendant: PID={0}; parent={1}; command={2}' -f
            $process.ProcessId, $process.ParentProcessId, $process.CommandLine
        )
        Stop-Process -Id $process.ProcessId -Force -ErrorAction SilentlyContinue
    }
    $remaining = @(Get-DescendantProcesses -RootProcessId $RootProcessId | Where-Object {
        $_.Name -match '^(R|Rscript)\.exe$'
    })
    if ($remaining.Count -gt 0) {
        throw "Runner-owned R descendants remain after cleanup: $($remaining.ProcessId -join ', ')"
    }
}

function Invoke-ExternalStage {
    param(
        [string]$Stage,
        [string]$Executable,
        [string[]]$Arguments,
        [string]$WorkingDirectory
    )
    $stdoutPath = Join-Path $RunDirectory "$Stage.stdout.log"
    $stderrPath = Join-Path $RunDirectory "$Stage.stderr.log"
    Write-WorkLog "START $Stage | free RAM: $((Get-MemorySnapshot).free_physical_gb) GB"
    Write-AtomicJson -Path $PipelineStatePath -Payload @{
        run_id = $RunId
        status = 'running'
        stage = $Stage
        updated_at = Get-IsoTimestamp
        memory = Get-MemorySnapshot
    }
    $process = Start-Process -FilePath $Executable -ArgumentList $Arguments `
        -WorkingDirectory $WorkingDirectory -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
    Write-WorkLog "$Stage process PID=$($process.Id)"
    Wait-Process -Id $process.Id
    $process.Refresh()
    Clear-RunnerDescendants -RootProcessId $process.Id
    if ($process.ExitCode -ne 0) {
        throw "$Stage failed with exit code $($process.ExitCode). See $stderrPath"
    }
    Write-WorkLog "PASS $Stage | free RAM: $((Get-MemorySnapshot).free_physical_gb) GB"
}

function Invoke-NotebookStage {
    param(
        [string]$Stage,
        [string]$NotebookName,
        [string]$ExpectedFinalLabel
    )
    $resultPath = Join-Path $RunDirectory "$Stage.result.json"
    $arguments = @(
        $Runner,
        '--notebook', (Join-Path $ControlDir $NotebookName),
        '--cwd', $ControlDir,
        '--kernel', 'ir44',
        '--events', $EventsPath,
        '--progress', $ProgressPath,
        '--result', $resultPath,
        '--run-id', $RunId
    )
    Invoke-ExternalStage -Stage $Stage -Executable $PythonExe `
        -Arguments $arguments -WorkingDirectory $ControlDir
    $result = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
    if ($result.status -ne 'completed') {
        throw "$Stage runner result is not completed."
    }
    if ($result.code_cells_completed -ne $result.code_cells_total) {
        throw "$Stage did not complete every non-empty code cell."
    }
    if ($result.final_label -ne $ExpectedFinalLabel) {
        throw (
            "$Stage ended at unexpected code label '$($result.final_label)'; " +
            "expected '$ExpectedFinalLabel'."
        )
    }
}

function Assert-FreshYpll {
    $stamp = Get-Date -Format 'yyyyMMdd'
    $path = Join-Path $ProjectRoot "Mortalidad\Matrices\YPLL_$stamp.rds"
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Fresh YPLL artifact not found: $path"
    }
    $info = Get-Item -LiteralPath $path
    if ($info.Length -le 0 -or $info.LastWriteTime -lt $script:RunStartedAt) {
        throw "YPLL artifact is empty or predates this run: $path"
    }
    Write-WorkLog "PASS fresh YPLL artifact: $path ($($info.Length) bytes)"
}

function Stage-CommitScope {
    $committedLog = Join-Path $ControlDir "paf_draw_regeneration_${RunId}_worklog.log"
    $committedTimings = Join-Path $ControlDir "paf_draw_regeneration_${RunId}_chunk_timings.jsonl"
    Copy-Item -LiteralPath $WorkLogPath -Destination $committedLog -Force
    Copy-Item -LiteralPath $EventsPath -Destination $committedTimings -Force

    $pathspecs = @(
        '.gitignore',
        '.gitattributes',
        '__andres_control/aaf_unified.R',
        '__andres_control/expand_pif.ipynb',
        '__andres_control/expand_pif2.ipynb',
        '__andres_control/run_notebook_logged.py',
        '__andres_control/run_paf_draw_regeneration.ps1',
        '__andres_control/validate_paf_draw_regeneration.R',
        '__andres_control/test_ypll_death_base.R',
        '__andres_control/build_ypll.R',
        '__andres_control/ypll_icd_defs.R',
        '__andres_control/aaf_engine_inputs_bundle_*.rds',
        '__andres_control/aaf_nested_by_disease_*.rds',
        '__andres_control/aaf_synchronised_draws_*.rds',
        '__andres_control/aaf_table5_result_*.rds',
        '__andres_control/Mortality Estimates WHO 2024.xlsx',
        '__andres_control/Mortality Estimates WHO 2024_*.xlsx',
        '__andres_control/ine_proyecciones_2012_2024.xlsx',
        '__andres_control/tabla_aaf_who2024_sexo_causa_ano.md',
        '__andres_control/tabla_aaf_who2024_sexo_causa_ano.csv',
        '__andres_control/Figure 1.png',
        '__andres_control/Figure 2.png',
        '__andres_control/Figure 3.png',
        '__andres_control/Figure 4.png',
        '__andres_control/Figure 4_not_pancreas_stomach.png',
        '__andres_control/Figure 5.png',
        '__andres_control/Figure 5_not_panc_stomach.png',
        '__andres_control/pif2_pif_results_full_*.rds',
        '__andres_control/pif2_pif_audit_full_*.rds',
        '__andres_control/pif2_pif_synchronised_draws_full_*.rds',
        '__andres_control/pif2_injuries_fulltest_results_*.rds',
        '__andres_control/pif2_injuries_fulltest_checks_*.rds',
        '__andres_control/pif2_pif_results_table5_full_*.rds',
        '__andres_control/pif2_pif_audit_table5_full_*.rds',
        '__andres_control/pif2_pif_synchronised_draws_table5_full_*.rds',
        'Mortalidad/Matrices/YPLL_*.rds',
        'ACC1240138-Potentially-Avoidable-Injury-Mortality-in-Chile--bc6359e/PIF addiction/data_binge_sensitivity.rds',
        "__andres_control/$(Split-Path -Leaf $committedLog)",
        "__andres_control/$(Split-Path -Leaf $committedTimings)"
    )
    foreach ($pathspec in $pathspecs) {
        # Force is required because this repository uses a defensive ignore-all
        # policy and several newly generated audit artifacts are intentionally
        # absent from the static .gitignore whitelist.
        & git -C $ProjectRoot add -f -A -- $pathspec
        if ($LASTEXITCODE -ne 0) {
            throw "git add failed for pathspec: $pathspec"
        }
    }
    $staged = @(& git -C $ProjectRoot diff --cached --name-only)
    if ($LASTEXITCODE -ne 0 -or $staged.Count -eq 0) {
        throw 'No files were staged for the requested commit.'
    }
    $forbidden = @($staged | Where-Object {
        $_ -match 'expand_pif3|figures_expand_pif3|tables_expand_pif3|codex_handoff'
    })
    if ($forbidden.Count -gt 0) {
        throw "Unrelated pre-existing PIF3/handoff changes entered the commit: $($forbidden -join ', ')"
    }
    & git -C $ProjectRoot diff --cached --check
    if ($LASTEXITCODE -ne 0) {
        throw 'git diff --cached --check failed.'
    }
    Write-WorkLog "Staged files: $($staged -join '; ')"
}

$script:RunStartedAt = Get-Date
$env:PIF_RUN_STARTED_EPOCH = [DateTimeOffset]::Now.ToUnixTimeSeconds().ToString()

try {
    $preStaged = @(& git -C $ProjectRoot diff --cached --name-only)
    if ($preStaged.Count -gt 0) {
        throw "Refusing to mix pre-staged changes into the automated commit: $($preStaged -join ', ')"
    }
    Write-WorkLog "Pipeline started. RunId=$RunId"
    Write-WorkLog "Initial memory: $((Get-MemorySnapshot) | ConvertTo-Json -Compress)"

    Invoke-NotebookStage -Stage 'expand_pif' -NotebookName 'expand_pif.ipynb' `
        -ExpectedFinalLabel 'table5-ihd-is-aaf-step4-dgs-formatting'
    Invoke-ExternalStage -Stage 'validate_expand_pif' -Executable $RscriptExe `
        -Arguments @($Validator, 'expand_pif') -WorkingDirectory $ControlDir
    Invoke-ExternalStage -Stage 'test_ypll_death_base' -Executable $RscriptExe `
        -Arguments @((Join-Path $ControlDir 'test_ypll_death_base.R')) -WorkingDirectory $ProjectRoot
    Invoke-ExternalStage -Stage 'build_ypll' -Executable $RscriptExe `
        -Arguments @((Join-Path $ControlDir 'build_ypll.R')) -WorkingDirectory $ProjectRoot
    Assert-FreshYpll

    Write-WorkLog 'RAM boundary reached: expand_pif kernel is gone; starting expand_pif2 in a new process.'
    Invoke-NotebookStage -Stage 'expand_pif2' -NotebookName 'expand_pif2.ipynb' `
        -ExpectedFinalLabel 'pif2-session-info'
    Invoke-ExternalStage -Stage 'validate_expand_pif2' -Executable $RscriptExe `
        -Arguments @($Validator, 'expand_pif2') -WorkingDirectory $ControlDir

    Stage-CommitScope
    $commitMessage = [string]::Concat(
        'actualizaci',
        [char]0x00F3,
        'n PAF (recogida draws) (tambien PUC AAFs y PIFs)'
    )
    & git -C $ProjectRoot commit -m $commitMessage
    if ($LASTEXITCODE -ne 0) {
        throw 'git commit failed.'
    }
    $commit = (& git -C $ProjectRoot rev-parse HEAD).Trim()
    $done = @{
        run_id = $RunId
        status = 'completed'
        started_at = $script:RunStartedAt.ToString('o')
        ended_at = Get-IsoTimestamp
        commit = $commit
        commit_message = $commitMessage
        timings = $EventsPath
        worklog = $WorkLogPath
        memory = Get-MemorySnapshot
    }
    Write-AtomicJson -Path $DonePath -Payload $done
    Write-AtomicJson -Path $PipelineStatePath -Payload $done
    Write-WorkLog "DONE commit=$commit"
    exit 0
}
catch {
    $failure = @{
        run_id = $RunId
        status = 'failed'
        started_at = $script:RunStartedAt.ToString('o')
        failed_at = Get-IsoTimestamp
        error = $_.Exception.Message
        script_stack = $_.ScriptStackTrace
        progress = $ProgressPath
        timings = $EventsPath
        worklog = $WorkLogPath
        memory = Get-MemorySnapshot
    }
    Write-AtomicJson -Path $FailedPath -Payload $failure
    Write-AtomicJson -Path $PipelineStatePath -Payload $failure
    Write-WorkLog "FAILED $($_.Exception.Message)"
    exit 1
}
