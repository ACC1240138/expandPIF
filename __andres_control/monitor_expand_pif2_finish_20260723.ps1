param(
    [string]$ProjectRoot = 'C:\Users\nDP\Desktop\ACC1240138_private',
    [string]$RunDir = 'C:\Users\nDP\Desktop\ACC1240138_private\__andres_control\manual_paf_pif_draws_20260723_001555',
    [int]$IntervalSeconds = 900
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$ControlDir = Join-Path $ProjectRoot '__andres_control'
$RscriptExe = 'C:\Program Files\R\R-4.4.1\bin\Rscript.exe'
$Validator = Join-Path $ControlDir 'validate_paf_draw_regeneration.R'
$ProgressPath = Join-Path $RunDir 'expand_pif2_progress.json'
$ResultPath = Join-Path $RunDir 'expand_pif2_result.json'
$ExpandPifResultPath = Join-Path $RunDir 'expand_pif_result.json'
$MonitorLog = Join-Path $RunDir 'monitor_15min.log'
$StatePath = Join-Path $RunDir 'monitor_state.json'
$RunId = Split-Path -Leaf $RunDir

function Get-IsoTimestamp {
    return (Get-Date).ToString('o')
}

function Write-Log {
    param([string]$Message)
    Add-Content -LiteralPath $MonitorLog -Encoding utf8 -Value ("[{0}] {1}" -f (Get-IsoTimestamp), $Message)
}

function Write-State {
    param([hashtable]$State)
    $temporary = "$StatePath.tmp"
    $State | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $temporary -Encoding utf8
    Move-Item -LiteralPath $temporary -Destination $StatePath -Force
}

function Get-RunEpoch {
    param([string]$StartedAt)
    return ([DateTimeOffset]::Parse($StartedAt)).ToUnixTimeSeconds().ToString()
}

function Invoke-Validation {
    param(
        [string]$Stage,
        [string]$StartedAt,
        [string]$StdoutPath,
        [string]$StderrPath
    )
    $env:PIF_RUN_STARTED_EPOCH = Get-RunEpoch -StartedAt $StartedAt
    $env:PIF_ARTIFACT_STAMP = ([DateTimeOffset]::Parse($StartedAt)).ToString('yyyyMMdd')
    Write-Log "START validation $Stage with PIF_RUN_STARTED_EPOCH=$env:PIF_RUN_STARTED_EPOCH PIF_ARTIFACT_STAMP=$env:PIF_ARTIFACT_STAMP"
    Push-Location -LiteralPath $ControlDir
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & $RscriptExe $Validator $Stage 1> $StdoutPath 2> $StderrPath
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
        Pop-Location
    }
    if ($exitCode -ne 0) {
        throw "Validation failed for $Stage with exit code $exitCode. See $StderrPath"
    }
    Write-Log "PASS validation $Stage"
}

function Copy-RunLogsForCommit {
    $targets = @(
        @{ source = (Join-Path $RunDir 'monitor_15min.log'); dest = (Join-Path $ControlDir "paf_draw_regeneration_${RunId}_monitor.log") },
        @{ source = (Join-Path $RunDir 'expand_pif_chunk_timings.jsonl'); dest = (Join-Path $ControlDir "paf_draw_regeneration_${RunId}_expand_pif_chunk_timings.jsonl") },
        @{ source = (Join-Path $RunDir 'expand_pif2_chunk_timings.jsonl'); dest = (Join-Path $ControlDir "paf_draw_regeneration_${RunId}_expand_pif2_chunk_timings.jsonl") },
        @{ source = (Join-Path $RunDir 'expand_pif_validate.stdout.log'); dest = (Join-Path $ControlDir "paf_draw_regeneration_${RunId}_validate_expand_pif.stdout.log") },
        @{ source = (Join-Path $RunDir 'expand_pif_validate.stderr.log'); dest = (Join-Path $ControlDir "paf_draw_regeneration_${RunId}_validate_expand_pif.stderr.log") },
        @{ source = (Join-Path $RunDir 'expand_pif2_validate.stdout.log'); dest = (Join-Path $ControlDir "paf_draw_regeneration_${RunId}_validate_expand_pif2.stdout.log") },
        @{ source = (Join-Path $RunDir 'expand_pif2_validate.stderr.log'); dest = (Join-Path $ControlDir "paf_draw_regeneration_${RunId}_validate_expand_pif2.stderr.log") }
    )
    foreach ($target in $targets) {
        if (Test-Path -LiteralPath $target.source) {
            Copy-Item -LiteralPath $target.source -Destination $target.dest -Force
        }
    }
}

function Stage-And-Commit {
    Copy-RunLogsForCommit
    $messagePath = Join-Path $RunDir 'commit_message_paf_pif_draws_20260723.txt'
    $messageLines = @(
        ([string]::Concat('actualizaci', [char]0x00F3, 'n PAF (recogida draws) (tambien PUC AAFs y PIFs)')),
        '',
        '- Regenera expand_pif y valida AAF main + Table 5/PUC con artefactos 20260723.',
        '- Guarda draws sincronizados AAF WHO/Adam y AAF Table 5/PUC fuera de los resumenes compactos.',
        '- Regenera expand_pif2 usando los artefactos AAF frescos producidos por expand_pif.',
        '- Guarda resultados, auditorias y draws sincronizados PIF main + Table 5/PUC.',
        '- Conserva tiempos por chunk, logs de validacion y scripts de runner/monitor/validador.',
        '- Versiona outputs mediante whitelist puntual de .gitignore; sin git add -f.',
        '- Mantiene separadas las incertidumbres AAF y PIF: PIF se recalcula desde insumos primitivos, no desde AAF colapsada.'
    )
    $messageLines | Set-Content -LiteralPath $messagePath -Encoding utf8
    # Stage the whole worktree through the repository whitelist. This keeps new,
    # modified, and deleted outputs together without bypassing .gitignore.
    & git -C $ProjectRoot add -A -- .
    if ($LASTEXITCODE -ne 0) {
        throw 'git add -A failed.'
    }
    $staged = @(& git -C $ProjectRoot diff --cached --name-only)
    if ($LASTEXITCODE -ne 0 -or $staged.Count -eq 0) {
        throw 'No files were staged for commit.'
    }
    Write-Log "Staged all worktree changes: $($staged.Count) files."
    $checkTargets = @(
        & git -C $ProjectRoot diff --cached --name-only --diff-filter=ACMRT |
            Where-Object { $_ -notlike '*.html' }
    )
    if ($LASTEXITCODE -ne 0) {
        throw 'git diff --cached --name-only failed.'
    }
    if ($checkTargets.Count -gt 0) {
        & git -C $ProjectRoot diff --cached --check -- $checkTargets
        if ($LASTEXITCODE -ne 0) {
            throw 'git diff --cached --check failed for non-HTML staged files.'
        }
    }
    & git -C $ProjectRoot commit -F $messagePath
    if ($LASTEXITCODE -ne 0) {
        throw 'git commit failed.'
    }
    return (& git -C $ProjectRoot rev-parse HEAD).Trim()
}

Write-Log "Monitor started. IntervalSeconds=$IntervalSeconds RunDir=$RunDir"

while ($true) {
    try {
        if (Test-Path -LiteralPath $ResultPath) {
            $result = Get-Content -LiteralPath $ResultPath -Raw | ConvertFrom-Json
            Write-Log "Runner result detected: status=$($result.status); completed=$($result.code_cells_completed)/$($result.code_cells_total); final_label=$($result.final_label)"
            if ($result.status -ne 'completed') {
                throw "expand_pif2 runner ended with status $($result.status)"
            }
            if ($result.final_label -ne 'pif2-session-info') {
                throw "expand_pif2 ended at unexpected final label $($result.final_label)"
            }
            $expandPifResult = Get-Content -LiteralPath $ExpandPifResultPath -Raw | ConvertFrom-Json
            Invoke-Validation -Stage 'expand_pif' `
                -StartedAt $expandPifResult.started_at `
                -StdoutPath (Join-Path $RunDir 'expand_pif_validate.stdout.log') `
                -StderrPath (Join-Path $RunDir 'expand_pif_validate.stderr.log')
            Invoke-Validation -Stage 'expand_pif2' `
                -StartedAt $result.started_at `
                -StdoutPath (Join-Path $RunDir 'expand_pif2_validate.stdout.log') `
                -StderrPath (Join-Path $RunDir 'expand_pif2_validate.stderr.log')
            $commit = Stage-And-Commit
            Write-Log "DONE commit=$commit"
            Write-State @{
                status = 'completed'
                commit = $commit
                completed_at = Get-IsoTimestamp
                run_dir = $RunDir
            }
            exit 0
        }
        if (Test-Path -LiteralPath $ProgressPath) {
            $progress = Get-Content -LiteralPath $ProgressPath -Raw | ConvertFrom-Json
            Write-Log "RUNNING completed=$($progress.code_cells_completed)/$($progress.code_cells_total); active=$($progress.active_label); updated=$($progress.updated_at)"
            Write-State @{
                status = 'running'
                completed = "$($progress.code_cells_completed)/$($progress.code_cells_total)"
                active_label = $progress.active_label
                updated_at = $progress.updated_at
                monitor_updated_at = Get-IsoTimestamp
            }
        } else {
            Write-Log "Progress file not found yet: $ProgressPath"
        }
    } catch {
        Write-Log "FAILED $($_.Exception.Message)"
        Write-State @{
            status = 'failed'
            error = $_.Exception.Message
            failed_at = Get-IsoTimestamp
            run_dir = $RunDir
        }
        exit 1
    }
    Start-Sleep -Seconds $IntervalSeconds
}
