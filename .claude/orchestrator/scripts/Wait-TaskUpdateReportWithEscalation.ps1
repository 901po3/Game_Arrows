param(
    [Parameter(Mandatory=$true)]
    [string]$TaskId,
    [int]$TimeoutSeconds = 300,
    [int]$PollSeconds = 2,
    [string]$TeamLeadInboxPath = "",
    [string]$PmInboxPath = "",
    [switch]$EscalateOnTimeout,
    [switch]$EscalateOnParseError
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($TeamLeadInboxPath)) {
    $TeamLeadInboxPath = Join-Path $HOME '.claude/teams/arrow-game/inboxes/team-lead.json'
}
if ([string]::IsNullOrWhiteSpace($PmInboxPath)) {
    $PmInboxPath = Join-Path $HOME '.claude/teams/arrow-game/inboxes/pm.json'
}

function Read-InboxArray([string]$Path) {
    if (-not (Test-Path $Path)) { return @() }
    $raw = Get-Content $Path -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) { return @() }
    $arr = $raw | ConvertFrom-Json
    if ($arr -isnot [System.Array]) { $arr = @($arr) }
    return $arr
}

function Write-InboxArray([string]$Path, [array]$Arr) {
    $parent = Split-Path $Path -Parent
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $Arr | ConvertTo-Json -Depth 16 | Set-Content $Path -Encoding UTF8
}

function Append-InboxMessage([string]$Path, [hashtable]$Message) {
    $arr = Read-InboxArray -Path $Path
    $list = New-Object System.Collections.ArrayList
    foreach ($item in @($arr)) { [void]$list.Add($item) }
    [void]$list.Add([PSCustomObject]$Message)
    Write-InboxArray -Path $Path -Arr @($list)
}

function Send-Escalation([string]$ReasonCode, [string]$ReasonMessage) {
    $payload = [ordered]@{
        type = 'task_monitor_escalation'
        task_id = $TaskId
        reason_code = $ReasonCode
        message = $ReasonMessage
        source = 'monitor'
        requested_action = 'review worker availability and reassign if needed'
    }

    $msg = [ordered]@{
        from = 'orchestrator-monitor'
        summary = "escalation $TaskId"
        text = ($payload | ConvertTo-Json -Depth 8)
        timestamp = [DateTime]::UtcNow.ToString('o')
        read = $false
    }

    Append-InboxMessage -Path $PmInboxPath -Message $msg
    Write-Output "[ESCALATED] PM inbox notified"
}

Write-Output ("[WAIT] task=" + $TaskId)
Write-Output ("[WAIT] inbox=" + $TeamLeadInboxPath)
Write-Output ("[WAIT] timeout=" + $TimeoutSeconds + "s, poll=" + $PollSeconds + "s")

if (-not (Test-Path $TeamLeadInboxPath)) {
    Write-Output "[ERROR] team-lead inbox not found"
    if ($EscalateOnTimeout) {
        Send-Escalation -ReasonCode 'team_lead_inbox_not_found' -ReasonMessage 'team-lead inbox path is missing'
    }
    exit 2
}

$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
$lastSeenCount = -1

while ((Get-Date) -lt $deadline) {
    try {
        $arr = Read-InboxArray -Path $TeamLeadInboxPath

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

            Write-Output "[FOUND] non-orchestrator message exists but no parseable TASK_UPDATE block"
            if ($EscalateOnParseError) {
                Send-Escalation -ReasonCode 'task_update_parse_error' -ReasonMessage 'message exists but TASK_UPDATE block is not parseable'
            }
            exit 3
        }
    }
    catch {
        Write-Output ("[WARN] monitor parse error: " + $_.Exception.Message)
    }

    Start-Sleep -Seconds $PollSeconds
}

Write-Output "[TIMEOUT] no task-related message found"
if ($EscalateOnTimeout) {
    Send-Escalation -ReasonCode 'task_update_timeout' -ReasonMessage ('No task_update report within ' + $TimeoutSeconds + ' seconds')
}
exit 1
