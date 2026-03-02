param(
    [Parameter(Mandatory=$true)]
    [string]$TaskId,
    [int]$TimeoutSeconds = 300,
    [int]$PollSeconds = 2,
    [string]$TeamLeadInboxPath = ""
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($TeamLeadInboxPath)) {
    $TeamLeadInboxPath = Join-Path $HOME '.claude/teams/arrow-game/inboxes/team-lead.json'
}

Write-Output ("[WAIT] task=" + $TaskId)
Write-Output ("[WAIT] inbox=" + $TeamLeadInboxPath)
Write-Output ("[WAIT] timeout=" + $TimeoutSeconds + "s, poll=" + $PollSeconds + "s")

if (-not (Test-Path $TeamLeadInboxPath)) {
    Write-Output "[ERROR] team-lead inbox not found"
    exit 2
}

$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
$lastSeenCount = -1

while ((Get-Date) -lt $deadline) {
    try {
        $raw = Get-Content $TeamLeadInboxPath -Raw
        if ([string]::IsNullOrWhiteSpace($raw)) {
            Start-Sleep -Seconds $PollSeconds
            continue
        }

        $arr = $raw | ConvertFrom-Json
        if ($arr -isnot [System.Array]) { $arr = @($arr) }

        if ($arr.Count -ne $lastSeenCount) {
            Write-Output ("[WAIT] inbox_count=" + $arr.Count)
            $lastSeenCount = $arr.Count
        }

        $taskIdPattern = [regex]::Escape($TaskId)
        $matched = $arr | Where-Object {
            [string]$from = [string]$_.from
            if ($from -eq 'orchestrator') { return $false }

            ([string]$_.summary -match $taskIdPattern) -or
            ([string]$_.text -match ('"task_id"\s*:\s*"' + $taskIdPattern + '"')) -or
            ([string]$_.text -match $taskIdPattern)
        } | Select-Object -Last 1

        if ($matched) {
            Write-Output "[FOUND] task-related message detected"
            Write-Output ("[FOUND] from=" + [string]$matched.from)
            Write-Output ("[FOUND] summary=" + [string]$matched.summary)

            $text = [string]$matched.text
            $blockMatch = [regex]::Match($text, '(?s)TASK_UPDATE_BEGIN\s*(?<json>\{.*?\})\s*TASK_UPDATE_END')
            if ($blockMatch.Success) {
                $payload = $null
                try { $payload = $blockMatch.Groups['json'].Value | ConvertFrom-Json } catch { $payload = $null }
                if ($payload) {
                    Write-Output ("[FOUND] type=" + [string]$payload.type)
                    Write-Output ("[FOUND] task_id=" + [string]$payload.task_id)
                    Write-Output ("[FOUND] stage=" + [string]$payload.stage)
                    Write-Output ("[FOUND] outcome=" + [string]$payload.outcome)
                    Write-Output ("[FOUND] summary_line=" + [string]$payload.summary)
                    exit 0
                }
            }

            Write-Output "[FOUND] non-orchestrator message exists but no parseable TASK_UPDATE block, continue waiting"
        }
    }
    catch {
        Write-Output ("[WARN] monitor parse error: " + $_.Exception.Message)
    }

    Start-Sleep -Seconds $PollSeconds
}

Write-Output "[TIMEOUT] no task-related message found"
exit 1
