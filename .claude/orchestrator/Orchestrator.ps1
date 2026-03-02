param(
    [switch]$Once,
    [string]$ConfigPath = ".claude/orchestrator/config.json"
)

$ErrorActionPreference = "Stop"
$script:WorkspaceRoot = (Get-Location).Path

function Resolve-TokenPath {
    param([string]$PathValue)

    if ([string]::IsNullOrWhiteSpace($PathValue)) { return $PathValue }

    $resolved = $PathValue -replace "\$\{HOME\}", $HOME
    $resolved = [Environment]::ExpandEnvironmentVariables($resolved)

    if ([System.IO.Path]::IsPathRooted($resolved)) { return $resolved }
    return (Join-Path $script:WorkspaceRoot $resolved)
}

function ConvertTo-HashtableDeep {
    param($InputObject)

    if ($null -eq $InputObject) {
        return $null
    }

    if ($InputObject -is [hashtable]) {
        $result = @{}
        foreach ($key in $InputObject.Keys) {
            $result[$key] = ConvertTo-HashtableDeep -InputObject $InputObject[$key]
        }
        return $result
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        $result = @{}
        foreach ($key in $InputObject.Keys) {
            $result[$key] = ConvertTo-HashtableDeep -InputObject $InputObject[$key]
        }
        return $result
    }

    if ($InputObject -is [System.Array]) {
        $result = @()
        foreach ($item in $InputObject) {
            $result += ,(ConvertTo-HashtableDeep -InputObject $item)
        }
        return $result
    }

    if ($InputObject -is [pscustomobject]) {
        $result = @{}
        foreach ($prop in $InputObject.PSObject.Properties) {
            $result[$prop.Name] = ConvertTo-HashtableDeep -InputObject $prop.Value
        }
        return $result
    }

    return $InputObject
}

function Read-JsonFile {
    param([string]$Path, $Default)
    if (-not (Test-Path $Path)) { return $Default }

    try {
        $raw = Get-Content $Path -Raw
        if ([string]::IsNullOrWhiteSpace($raw)) { return $Default }

        return ($raw | ConvertFrom-Json)
    }
    catch {
        return $Default
    }
}

function Write-JsonFile {
    param([string]$Path, $Data, [int]$Depth = 12)

    $parent = Split-Path $Path -Parent
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }

    $json = $Data | ConvertTo-Json -Depth $Depth
    Set-Content -Path $Path -Value $json -Encoding UTF8
}

function Write-OrchestratorLog {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR")]
        [string]$Level = "INFO"
    )

    $line = "[$([DateTime]::UtcNow.ToString("o"))][$Level] $Message"
    Write-Host $line

    $logParent = Split-Path $script:Config.logFileResolved -Parent
    if (-not (Test-Path $logParent)) { New-Item -ItemType Directory -Path $logParent -Force | Out-Null }
    Add-Content -Path $script:Config.logFileResolved -Value $line
}

function Normalize-Role {
    param([string]$Raw)

    if ([string]::IsNullOrWhiteSpace($Raw)) { return "" }

    $value = $Raw.Trim().ToLowerInvariant()
    if ($value -match "planner") { return "planner" }
    if ($value -match "programmer|developer|dev") { return "programmer" }
    if ($value -match "code-reviewer|code reviewer|reviewer") { return "codeReviewer" }
    if ($value -match "plan-reviewer|plan reviewer") { return "planReviewer" }
    if ($value -match "^pm$") { return "pm" }
    if ($value -match "resource") { return "resource" }

    return $value
}

function Normalize-Priority {
    param([string]$Raw)

    if ([string]::IsNullOrWhiteSpace($Raw)) { return "medium" }

    $v = $Raw.Trim().ToLowerInvariant()
    if ($v -match "high") { return "high" }
    if ($v -match "low") { return "low" }
    if ($v -match "medium") { return "medium" }

    return "medium"
}

function Get-PriorityRank {
    param([string]$Priority)

    $v = Normalize-Priority -Raw $Priority
    if ($v -eq "high") { return 1 }
    if ($v -eq "medium") { return 2 }
    if ($v -eq "low") { return 3 }
    return 9
}

function Ensure-TaskDefaults {
    param([hashtable]$Task)

    if (-not $Task.ContainsKey("taskId")) { $Task.taskId = [guid]::NewGuid().ToString("N") }
    if (-not $Task.ContainsKey("title")) { $Task.title = $Task.taskId }
    if (-not $Task.ContainsKey("source")) { $Task.source = "orchestrator" }
    if (-not $Task.ContainsKey("status")) { $Task.status = "NEW" }
    if (-not $Task.ContainsKey("kind")) { $Task.kind = "implementation" }
    if (-not $Task.ContainsKey("assignee")) { $Task.assignee = "" }
    if (-not $Task.ContainsKey("priority")) { $Task.priority = "medium" }
    if (-not $Task.ContainsKey("attempt")) { $Task.attempt = 0 }
    if (-not $Task.ContainsKey("branch")) { $Task.branch = "" }
    if (-not $Task.ContainsKey("currentOwner")) { $Task.currentOwner = "" }
    if (-not $Task.ContainsKey("awaitingValidReport")) { $Task.awaitingValidReport = $false }
    if (-not $Task.ContainsKey("createdAt")) { $Task.createdAt = [DateTime]::UtcNow.ToString("o") }
    if (-not $Task.ContainsKey("updatedAt")) { $Task.updatedAt = [DateTime]::UtcNow.ToString("o") }
    if (-not $Task.ContainsKey("history")) { $Task.history = @() }
}

function Add-History {
    param([hashtable]$Task, [string]$From, [string]$To, [string]$Reason, [string]$Actor)

    if (-not $Task.history) { $Task.history = @() }
    $Task.history += [ordered]@{
        timestamp = [DateTime]::UtcNow.ToString("o")
        from = $From
        to = $To
        reason = $Reason
        actor = $Actor
    }
}

function Set-TaskStatus {
    param([hashtable]$Task, [string]$To, [string]$Reason, [string]$Actor)

    $from = [string]$Task.status
    if ($from -eq $To) { return }

    $Task.status = $To
    $Task.updatedAt = [DateTime]::UtcNow.ToString("o")
    Add-History -Task $Task -From $from -To $To -Reason $Reason -Actor $Actor
}

function Get-TaskFilePath {
    param([string]$TaskId)

    $safe = ($TaskId -replace "[^A-Za-z0-9_-]", "_")
    return (Join-Path $script:Config.tasksDirResolved "$safe.json")
}

function Load-TaskMap {
    $map = @{}

    if (-not (Test-Path $script:Config.tasksDirResolved)) {
        New-Item -ItemType Directory -Path $script:Config.tasksDirResolved -Force | Out-Null
        return $map
    }

    $files = Get-ChildItem -Path $script:Config.tasksDirResolved -Filter *.json -File -ErrorAction SilentlyContinue
    foreach ($file in $files) {
        $obj = Read-JsonFile -Path $file.FullName -Default $null
        if ($null -eq $obj) { continue }

        $task = @{}
        foreach ($p in $obj.PSObject.Properties) { $task[$p.Name] = $p.Value }
        Ensure-TaskDefaults -Task $task
        $map[$task.taskId] = $task
    }

    return $map
}

function Save-TaskMap {
    param([hashtable]$TaskMap)

    foreach ($taskId in $TaskMap.Keys) {
        $task = $TaskMap[$taskId]
        Ensure-TaskDefaults -Task $task
        Write-JsonFile -Path (Get-TaskFilePath -TaskId $taskId) -Data $task
    }
}

function Parse-TodoTasks {
    $items = @()
    $todoPath = $script:Config.todoFileResolved
    if (-not (Test-Path $todoPath)) { return $items }

    $lines = Get-Content $todoPath
    foreach ($line in $lines) {
        if ($line -notmatch "^\s*-\s*\[(?<mark>.?)\]\s+(?<body>.+)$") { continue }

        $mark = $Matches.mark
        $body = $Matches.body.Trim()
        if ($body -match "^\*\(.*\)\*$") { continue }

        $title = $body
        $meta = ""
        if ($body -match "^(?<title>.+?)\s*\((?<meta>[^)]*)\)\s*$") {
            $title = $Matches.title.Trim()
            $meta = $Matches.meta.Trim()
        }

        $taskId = ""
        if ($title -match "^\[(?<id>[^\]]+)\]\s*(?<plain>.+)$") {
            $taskId = $Matches.id.Trim()
            $title = $Matches.plain.Trim()
        }
        if ([string]::IsNullOrWhiteSpace($taskId)) {
            $taskId = [Math]::Abs($title.GetHashCode()).ToString()
        }

        $assignee = ""
        if ($meta -match "planner|programmer|developer|dev|pm|reviewer|resource") {
            $assignee = Normalize-Role -Raw $Matches[0]
        }

        $priority = "medium"
        if ($meta -match "high|medium|low") {
            $priority = Normalize-Priority -Raw $Matches[0]
        }

        $items += [ordered]@{
            taskId = $taskId
            title = $title
            assignee = $assignee
            priority = $priority
            mark = $mark
        }
    }

    return $items
}

function Sync-TodoToTaskMap {
    param([hashtable]$TaskMap)

    $todoTasks = Parse-TodoTasks
    foreach ($todo in $todoTasks) {
        if (-not $TaskMap.ContainsKey($todo.taskId)) {
            $kind = if ($todo.assignee -eq "planner") { "planning" } else { "implementation" }
            $task = [ordered]@{
                taskId = $todo.taskId
                title = $todo.title
                source = "TODO"
                status = "NEW"
                kind = $kind
                assignee = $todo.assignee
                priority = $todo.priority
                attempt = 0
                branch = ""
                currentOwner = ""
                createdAt = [DateTime]::UtcNow.ToString("o")
                updatedAt = [DateTime]::UtcNow.ToString("o")
                history = @()
            }

            if ($todo.mark -eq "~") { $task.status = "IN_DEV" }

            $TaskMap[$todo.taskId] = $task
            Write-OrchestratorLog "Imported TODO task $($todo.taskId)"
        }
        else {
            $task = $TaskMap[$todo.taskId]
            $task.title = $todo.title
            if (-not [string]::IsNullOrWhiteSpace($todo.assignee)) { $task.assignee = $todo.assignee }
            $task.priority = $todo.priority
            $task.updatedAt = [DateTime]::UtcNow.ToString("o")
        }
    }
}

function Load-State {
    $default = [ordered]@{
        processedMessages = @()
        agents = [ordered]@{}
    }

    $obj = Read-JsonFile -Path $script:Config.stateFileResolved -Default $default
    if ($null -eq $obj) { return $default }

    $state = ConvertTo-HashtableDeep -InputObject $obj
    if (-not $state.ContainsKey("processedMessages")) { $state.processedMessages = @() }
    if (-not $state.ContainsKey("agents")) {
        $state.agents = @{}
    }
    elseif ($state.agents -isnot [hashtable]) { $state.agents = ConvertTo-HashtableDeep -InputObject $state.agents }
    return $state
}

function Save-State {
    param([hashtable]$State)
    Write-JsonFile -Path $script:Config.stateFileResolved -Data $State
}

function Ensure-ValidationState {
    param([hashtable]$State)

    if (-not $State.ContainsKey("taskUpdateFailures")) {
        $State.taskUpdateFailures = @{}
    }
    elseif ($State.taskUpdateFailures -isnot [hashtable]) { $State.taskUpdateFailures = ConvertTo-HashtableDeep -InputObject $State.taskUpdateFailures }
}

function Get-TaskUpdateFailureKey {
    param(
        [string]$Agent,
        [string]$TaskId
    )

    $safeTaskId = if ([string]::IsNullOrWhiteSpace($TaskId)) { "unknown" } else { $TaskId }
    return "$Agent|$safeTaskId"
}

function Get-ProcessingFailureTaskId {
    return "__processing__"
}

function Register-TaskUpdateValidationFailure {
    param(
        [hashtable]$State,
        [string]$Agent,
        [string]$TaskId
    )

    Ensure-ValidationState -State $State
    $key = Get-TaskUpdateFailureKey -Agent $Agent -TaskId $TaskId
    $count = 0
    if ($State.taskUpdateFailures.ContainsKey($key)) {
        $count = [int]$State.taskUpdateFailures[$key]
    }

    $count += 1
    $State.taskUpdateFailures[$key] = $count

    $softLimit = 1
    if ($script:Config.runtime -and $script:Config.runtime.taskUpdateSoftFailLimit) {
        $softLimit = [int]$script:Config.runtime.taskUpdateSoftFailLimit
    }

    $severity = if ($count -le $softLimit) { "soft" } else { "hard" }
    return [ordered]@{ count = $count; severity = $severity }
}

function Clear-TaskUpdateValidationFailure {
    param(
        [hashtable]$State,
        [string]$Agent,
        [string]$TaskId
    )

    Ensure-ValidationState -State $State
    $key = Get-TaskUpdateFailureKey -Agent $Agent -TaskId $TaskId
    if ($State.taskUpdateFailures.ContainsKey($key)) {
        $State.taskUpdateFailures.Remove($key) | Out-Null
    }
}

function Load-TeamRegistry {
    $registry = @{
        teamLead = [string]$script:Config.inboxes.teamLead
        roles = @{
            planner = @()
            programmer = @()
            pm = @()
            codeReviewer = @()
        }
    }

    $teamConfigPath = Join-Path $script:Config.teamRootResolved "config.json"
    if (-not (Test-Path $teamConfigPath)) {
        return $registry
    }

    $teamConfig = Read-JsonFile -Path $teamConfigPath -Default $null
    if ($null -eq $teamConfig -or -not $teamConfig.members) {
        return $registry
    }

    $leadAgentId = ""
    if ($teamConfig.leadAgentId) {
        $leadAgentId = [string]$teamConfig.leadAgentId
    }

    foreach ($member in $teamConfig.members) {
        $name = ""
        if ($member.name) {
            $name = [string]$member.name
        }
        if ([string]::IsNullOrWhiteSpace($name)) {
            continue
        }

        if ($member.agentId -and [string]$member.agentId -eq $leadAgentId) {
            $registry.teamLead = $name
        }

        $candidates = @()
        if ($member.agentType) { $candidates += [string]$member.agentType }
        if ($member.prompt) { $candidates += [string]$member.prompt }
        $candidates += $name

        $role = ""
        foreach ($candidate in $candidates) {
            $normalized = Normalize-Role -Raw $candidate
            if ($normalized -in @("planner", "programmer", "pm", "codeReviewer")) {
                $role = $normalized
                break
            }
        }

        if (-not [string]::IsNullOrWhiteSpace($role)) {
            $registry.roles[$role] += $name
        }
    }

    foreach ($roleKey in @("planner", "programmer", "pm", "codeReviewer")) {
        $registry.roles[$roleKey] = @($registry.roles[$roleKey] | Select-Object -Unique)
    }

    if ($registry.roles.planner.Count -eq 0 -and $script:Config.inboxes.planner) {
        $registry.roles.planner = @([string]$script:Config.inboxes.planner)
    }
    if ($registry.roles.programmer.Count -eq 0 -and $script:Config.inboxes.programmer) {
        $registry.roles.programmer = @([string]$script:Config.inboxes.programmer)
    }
    if ($registry.roles.pm.Count -eq 0 -and $script:Config.inboxes.pm) {
        $registry.roles.pm = @([string]$script:Config.inboxes.pm)
    }
    if ($registry.roles.codeReviewer.Count -eq 0 -and $script:Config.inboxes.codeReviewer) {
        $registry.roles.codeReviewer = @([string]$script:Config.inboxes.codeReviewer)
    }

    return $registry
}

function Ensure-StateRoutingData {
    param([hashtable]$State)

    if (-not $State.ContainsKey("roleCursor")) {
        $State.roleCursor = @{}
    }
    elseif ($State.roleCursor -isnot [hashtable]) { $State.roleCursor = ConvertTo-HashtableDeep -InputObject $State.roleCursor }
}

function Ensure-RegistryAgents {
    param(
        [hashtable]$State,
        [hashtable]$Registry
    )

    foreach ($roleKey in $Registry.roles.Keys) {
        foreach ($agentName in $Registry.roles[$roleKey]) {
            Ensure-AgentState -State $State -Agent $agentName
        }
    }
}

function Select-AgentForRole {
    param(
        [hashtable]$State,
        [hashtable]$Registry,
        [string]$Role
    )

    if (-not $Registry.roles.ContainsKey($Role)) {
        return $null
    }

    $allMembers = @($Registry.roles[$Role])
    if ($allMembers.Count -eq 0) {
        return $null
    }

    $idleMembers = @()
    foreach ($member in $allMembers) {
        if (Agent-IsIdle -State $State -Agent $member) {
            $idleMembers += $member
        }
    }

    if ($idleMembers.Count -eq 0) {
        return $null
    }

    Ensure-StateRoutingData -State $State
    $cursor = 0
    if ($State.roleCursor.ContainsKey($Role)) {
        $cursor = [int]$State.roleCursor[$Role]
    }

    $selectedIndex = $cursor % $idleMembers.Count
    $selected = $idleMembers[$selectedIndex]
    $State.roleCursor[$Role] = ($selectedIndex + 1) % $idleMembers.Count

    return $selected
}

function Get-TeamLeadInboxName {
    param([hashtable]$Registry)

    if ($Registry -and $Registry.teamLead -and -not [string]::IsNullOrWhiteSpace([string]$Registry.teamLead)) {
        return [string]$Registry.teamLead
    }

    return [string]$script:Config.inboxes.teamLead
}

function Ensure-AgentState {
    param([hashtable]$State, [string]$Agent)

    if ($State.agents -isnot [hashtable]) {
        $State.agents = ConvertTo-HashtableDeep -InputObject $State.agents
    }

    if (-not $State.agents.ContainsKey($Agent)) {
        $State.agents[$Agent] = [ordered]@{
            idle = $true
            lastSeen = ""
            lastEvent = ""
        }
    }
}

function Get-InboxPath {
    param([string]$InboxName)
    return (Join-Path $script:Config.teamRootResolved "inboxes/$InboxName.json")
}

function Read-InboxMessages {
    param([string]$InboxPath)

    if (-not (Test-Path $InboxPath)) { return @() }

    try {
        $raw = Get-Content $InboxPath -Raw
        if ([string]::IsNullOrWhiteSpace($raw)) { return @() }

        $items = $raw | ConvertFrom-Json
        if ($items -is [System.Array]) { return $items }
        return @($items)
    }
    catch {
        Write-OrchestratorLog "Invalid inbox JSON skipped: $InboxPath" "WARN"
        return @()
    }
}

function Write-InboxMessages {
    param([string]$InboxPath, [array]$Messages)

    $parent = Split-Path $InboxPath -Parent
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }

    $json = $Messages | ConvertTo-Json -Depth 16
    Set-Content -Path $InboxPath -Value $json -Encoding UTF8
}

function Append-InboxMessage {
    param([string]$InboxName, [hashtable]$Message)

    $path = Get-InboxPath -InboxName $InboxName
    $existing = Read-InboxMessages -InboxPath $path
    $list = New-Object System.Collections.ArrayList
    foreach ($item in @($existing)) {
        [void]$list.Add($item)
    }

    [void]$list.Add([PSCustomObject]$Message)
    Write-InboxMessages -InboxPath $path -Messages @($list)
}

function Get-MessageKey {
    param($Message)

    $from = [string]$Message.from
    $timestamp = [string]$Message.timestamp
    $summary = [string]$Message.summary
    $text = [string]$Message.text
    if ($text.Length -gt 120) { $text = $text.Substring(0, 120) }

    return "$from|$timestamp|$summary|$text"
}

function Try-ParseJsonText {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $null
    }

    try {
        return ($Text | ConvertFrom-Json)
    }
    catch {
        return $null
    }
}

function Get-TaskUpdateBlockJson {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $null
    }

    $pattern = '(?s)TASK_UPDATE_BEGIN\s*(?<json>\{.*?\})\s*TASK_UPDATE_END'
    $match = [regex]::Match($Text, $pattern)
    if (-not $match.Success) {
        return $null
    }

    return $match.Groups["json"].Value
}

function Has-TaskUpdateMarkers {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $false
    }

    return ($Text -match "TASK_UPDATE_BEGIN" -and $Text -match "TASK_UPDATE_END")
}

function Get-TaskIdFromText {
    param([string]$Text)

    $taskId = ""
    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $taskId
    }

    $matchTaskId = [regex]::Match($Text, '"task_id"\s*:\s*"(?<id>[^"]+)"')
    if ($matchTaskId.Success) {
        $taskId = [string]$matchTaskId.Groups["id"].Value
    }

    return $taskId
}

function Ensure-TaskBranch {
    param([hashtable]$Task)

    if (-not [string]::IsNullOrWhiteSpace($Task.branch)) { return }

    $role = if ([string]::IsNullOrWhiteSpace($Task.assignee)) { "task" } else { $Task.assignee }
    $slug = ($Task.taskId -replace "[^A-Za-z0-9_-]", "-").ToLowerInvariant()
    $Task.branch = "feature/$role-$slug"
}

function Try-HandoffCommit {
    param([hashtable]$Task, [string]$From, [string]$To)

    if (-not $script:Config.git.autoCommitOnHandoff) { return }

    $repo = Resolve-TokenPath -PathValue $script:Config.git.repositoryPath
    if (-not (Test-Path $repo)) { return }

    $inside = (& git -C $repo rev-parse --is-inside-work-tree 2>$null)
    if ($inside -ne "true") { return }

    Ensure-TaskBranch -Task $Task

    $current = (& git -C $repo rev-parse --abbrev-ref HEAD 2>$null).Trim()
    if ($script:Config.git.autoCheckoutTaskBranch -and $current -ne $Task.branch) {
        & git -C $repo checkout $Task.branch 2>$null | Out-Null
        $current = (& git -C $repo rev-parse --abbrev-ref HEAD 2>$null).Trim()
    }

    if ($current -ne $Task.branch) {
        Write-OrchestratorLog "Skip handoff commit for $($Task.taskId): branch mismatch '$current' vs '$($Task.branch)'" "WARN"
        return
    }

    $changes = & git -C $repo status --porcelain
    if (-not $changes) { return }

    & git -C $repo add -A | Out-Null

    $msg = [string]$script:Config.git.commitMessageTemplate
    $msg = $msg.Replace("{from}", $From).Replace("{to}", $To).Replace("{taskId}", $Task.taskId)

    & git -C $repo commit -m $msg | Out-Null
    Write-OrchestratorLog "Created handoff commit: $msg"
}

function Handle-TaskUpdate {
    param([hashtable]$TaskMap, [hashtable]$Update)

    $taskId = [string]$Update.task_id
    if ([string]::IsNullOrWhiteSpace($taskId)) { return }

    if (-not $TaskMap.ContainsKey($taskId)) {
        $TaskMap[$taskId] = [ordered]@{
            taskId = $taskId
            title = [string]$Update.title
            source = "inbox"
            status = "NEW"
            kind = "implementation"
            assignee = "programmer"
            priority = "medium"
            attempt = 0
            branch = ""
            currentOwner = ""
            createdAt = [DateTime]::UtcNow.ToString("o")
            updatedAt = [DateTime]::UtcNow.ToString("o")
            history = @()
        }
    }

    $task = $TaskMap[$taskId]
    Ensure-TaskDefaults -Task $task

    $stage = [string]$Update.stage
    $outcome = [string]$Update.outcome
    $summary = [string]$Update.summary
    $actor = [string]$Update.actor
    if ([string]::IsNullOrWhiteSpace($actor)) { $actor = "agent" }

    switch ($stage) {
        "PLANNING" {
            if ($outcome -eq "done") {
                Set-TaskStatus -Task $task -To "PM_REVIEW" -Reason "Planner finished: $summary" -Actor $actor
            }
        }
        "PM_REVIEW" {
            if ($outcome -eq "approved") {
                if ($task.kind -eq "planning") {
                    Set-TaskStatus -Task $task -To "DONE" -Reason "PM approved planning task" -Actor $actor
                } else {
                    Set-TaskStatus -Task $task -To "READY_FOR_DEV" -Reason "PM approved development" -Actor $actor
                }
            }
            elseif ($outcome -eq "rejected") {
                $task.attempt = [int]$task.attempt + 1
                Set-TaskStatus -Task $task -To "PLANNING" -Reason "PM requested rework: $summary" -Actor $actor
            }
        }
        "IN_DEV" {
            if ($outcome -eq "done") {
                Set-TaskStatus -Task $task -To "CODE_REVIEW" -Reason "Developer finished" -Actor $actor
            }
            elseif ($outcome -eq "blocked") {
                Set-TaskStatus -Task $task -To "BLOCKED" -Reason "Developer blocked: $summary" -Actor $actor
            }
        }
        "CODE_REVIEW" {
            if ($outcome -eq "approved") {
                Set-TaskStatus -Task $task -To "MERGE_READY" -Reason "Code review passed" -Actor $actor
            }
            elseif ($outcome -eq "rejected") {
                $task.attempt = [int]$task.attempt + 1
                Set-TaskStatus -Task $task -To "REWORK" -Reason "Code review rejected: $summary" -Actor $actor
            }
        }
        "MERGE_READY" {
            if ($outcome -eq "approved" -or $outcome -eq "done") {
                Set-TaskStatus -Task $task -To "DONE" -Reason "Merge approved" -Actor $actor
            }
        }
    }

    if ($Update.assignee) { $task.assignee = Normalize-Role -Raw ([string]$Update.assignee) }
    if ($Update.priority) { $task.priority = Normalize-Priority -Raw ([string]$Update.priority) }

    $task.updatedAt = [DateTime]::UtcNow.ToString("o")
}

function Agent-IsIdle {
    param([hashtable]$State, [string]$Agent)

    Ensure-AgentState -State $State -Agent $Agent
    if (-not $script:Config.runtime.requireIdleAgent) { return $true }
    return [bool]$State.agents[$Agent].idle
}

function Dispatch-Task {
    param(
        [hashtable]$Task,
        [string]$AgentRole,
        [string]$Reason,
        [hashtable]$State,
        [hashtable]$Registry
    )

    $agentName = Select-AgentForRole -State $State -Registry $Registry -Role $AgentRole
    if ([string]::IsNullOrWhiteSpace($agentName)) {
        Write-OrchestratorLog "No idle member for role: $AgentRole" "WARN"
        return $false
    }

    Ensure-TaskBranch -Task $Task

    $contract = Get-TaskUpdateContract
    $schema = New-TaskUpdateSchema -TaskId $Task.taskId -Contract $contract

    $payload = [ordered]@{
        type = "task_instruction"
        task_id = $Task.taskId
        title = $Task.title
        stage = $Task.status
        status = $Task.status
        branch = $Task.branch
        priority = $Task.priority
        reason = $Reason
        required_response = [ordered]@{
            target = "team-lead inbox"
            format = "JSON"
            wrapper = $contract.wrapper
            schema = $schema
        }
    }

    $msg = [ordered]@{
        from = "orchestrator"
        text = ($payload | ConvertTo-Json -Depth 8)
        summary = "[$($Task.taskId)] $($Task.title)"
        timestamp = [DateTime]::UtcNow.ToString("o")
        read = $false
    }

    Append-InboxMessage -InboxName $agentName -Message $msg
    Append-InboxMessage -InboxName (Get-TeamLeadInboxName -Registry $Registry) -Message ([ordered]@{
        from = "orchestrator"
        text = "dispatch: $($Task.taskId) -> $agentName ($AgentRole, $Reason)"
        summary = "dispatch $($Task.taskId)"
        timestamp = [DateTime]::UtcNow.ToString("o")
        read = $false
    })

    $from = if ([string]::IsNullOrWhiteSpace($Task.currentOwner)) { "orchestrator" } else { $Task.currentOwner }
    $Task.currentOwner = $agentName
    $Task.updatedAt = [DateTime]::UtcNow.ToString("o")

    Ensure-AgentState -State $State -Agent $agentName
    $State.agents[$agentName].idle = $false
    $State.agents[$agentName].lastSeen = [DateTime]::UtcNow.ToString("o")
    $State.agents[$agentName].lastEvent = "dispatched"

    Try-HandoffCommit -Task $Task -From $from -To $agentName
    Write-OrchestratorLog "Dispatched $($Task.taskId) to $agentName ($AgentRole)"

    return $true
}

function Send-ValidationFeedback {
    param(
        [string]$AgentName,
        [string]$ErrorCode,
        [string]$ErrorMessage,
        [string]$Severity,
        [int]$FailureCount,
        [hashtable]$Registry
    )

    if ([string]::IsNullOrWhiteSpace($AgentName)) {
        return
    }

    $contract = Get-TaskUpdateContract
    $payload = [ordered]@{
        type = "task_update_error"
        code = $ErrorCode
        message = $ErrorMessage
        severity = $Severity
        failure_count = $FailureCount
        required_schema = (New-TaskUpdateSchema -TaskId "<task-id>" -Contract $contract)
        required_wrapper = $contract.wrapper
    }

    Append-InboxMessage -InboxName $AgentName -Message ([ordered]@{
        from = "orchestrator"
        text = ($payload | ConvertTo-Json -Depth 8)
        summary = "task_update rejected: $ErrorCode"
        timestamp = [DateTime]::UtcNow.ToString("o")
        read = $false
    })

    Append-InboxMessage -InboxName (Get-TeamLeadInboxName -Registry $Registry) -Message ([ordered]@{
        from = "orchestrator"
        text = "task_update rejected from ${AgentName}: $ErrorCode - $ErrorMessage"
        summary = "task_update invalid"
        timestamp = [DateTime]::UtcNow.ToString("o")
        read = $false
    })
}

function Get-TaskUpdateContract {
    return [ordered]@{
        wrapper = [ordered]@{
            begin = "TASK_UPDATE_BEGIN"
            end = "TASK_UPDATE_END"
        }
        allowedStages = @("PLANNING", "PM_REVIEW", "IN_DEV", "CODE_REVIEW", "MERGE_READY")
        allowedOutcomesByStage = [ordered]@{
            "PLANNING" = @("done", "blocked")
            "PM_REVIEW" = @("approved", "rejected")
            "IN_DEV" = @("done", "blocked")
            "CODE_REVIEW" = @("approved", "rejected")
            "MERGE_READY" = @("approved", "done")
        }
        expectedStatusByStage = [ordered]@{
            "PLANNING" = "PLANNING"
            "PM_REVIEW" = "PM_REVIEW"
            "IN_DEV" = "IN_DEV"
            "CODE_REVIEW" = "CODE_REVIEW"
            "MERGE_READY" = "MERGE_READY"
        }
        outcomeHint = "approved|rejected|done|blocked"
    }
}

function New-TaskUpdateSchema {
    param([string]$TaskId = "<task-id>", $Contract = $null)

    if ($null -eq $Contract) {
        $Contract = Get-TaskUpdateContract
    }

    $stagesHint = ($Contract.allowedStages -join "|")
    return [ordered]@{
        type = "task_update"
        task_id = $TaskId
        stage = $stagesHint
        outcome = [string]$Contract.outcomeHint
        summary = "one-line summary"
        notes = "optional"
    }
}

function Get-ExpectedStatusForStage {
    param([string]$Stage)

    $contract = Get-TaskUpdateContract
    if ($contract.expectedStatusByStage.Contains($Stage)) {
        return [string]$contract.expectedStatusByStage[$Stage]
    }
    return ""
}

function Test-TaskUpdateSchema {
    param(
        [hashtable]$Update,
        [hashtable]$TaskMap
    )

    $required = @("type", "task_id", "stage", "outcome", "summary")
    foreach ($field in $required) {
        if (-not $Update.ContainsKey($field) -or [string]::IsNullOrWhiteSpace([string]$Update[$field])) {
            return @{ isValid = $false; code = "missing_field"; message = "Missing required field: $field" }
        }
    }

    if ([string]$Update.type -ne "task_update") {
        return @{ isValid = $false; code = "invalid_type"; message = "type must be task_update" }
    }

    $contract = Get-TaskUpdateContract

    $stage = [string]$Update.stage
    if ($stage -notin $contract.allowedStages) {
        return @{ isValid = $false; code = "invalid_stage"; message = "Unsupported stage: $stage" }
    }

    $outcome = [string]$Update.outcome
    if ($outcome -notin $contract.allowedOutcomesByStage[$stage]) {
        return @{ isValid = $false; code = "invalid_outcome"; message = "Outcome $outcome is not allowed for stage $stage" }
    }

    $taskId = [string]$Update.task_id
    if (-not $TaskMap.ContainsKey($taskId)) {
        return @{ isValid = $false; code = "unknown_task"; message = "Task not found: $taskId" }
    }

    $task = $TaskMap[$taskId]
    Ensure-TaskDefaults -Task $task
    $expectedStatus = Get-ExpectedStatusForStage -Stage $stage
    if ($task.status -ne $expectedStatus) {
        return @{ isValid = $false; code = "invalid_transition"; message = "Task $taskId is in $($task.status), expected $expectedStatus" }
    }

    return @{ isValid = $true; code = "ok"; message = "ok" }
}

function Try-AutoInjectTaskId {
    param(
        [hashtable]$Update,
        [hashtable]$TaskMap,
        [string]$AgentName
    )

    if (-not $script:Config.runtime.autoInjectTaskId) {
        return [ordered]@{ injected = $false; reason = "disabled"; taskId = "" }
    }

    if ($Update.ContainsKey("task_id") -and -not [string]::IsNullOrWhiteSpace([string]$Update.task_id)) {
        return [ordered]@{ injected = $false; reason = "already_set"; taskId = [string]$Update.task_id }
    }

    $stage = ""
    if ($Update.ContainsKey("stage")) {
        $stage = [string]$Update.stage
    }

    $expectedStatus = Get-ExpectedStatusForStage -Stage $stage
    if ([string]::IsNullOrWhiteSpace($expectedStatus)) {
        return [ordered]@{ injected = $false; reason = "unknown_stage"; taskId = "" }
    }

    $primary = @()
    $secondary = @()
    foreach ($task in $TaskMap.Values) {
        Ensure-TaskDefaults -Task $task
        if ($task.currentOwner -ne $AgentName) {
            continue
        }

        if ($task.status -ne $expectedStatus) {
            continue
        }

        if ($task.awaitingValidReport) {
            $primary += $task
        }
        else {
            $secondary += $task
        }
    }

    $candidate = $null
    if ($primary.Count -eq 1) {
        $candidate = $primary[0]
    }
    elseif ($primary.Count -eq 0 -and $secondary.Count -eq 1) {
        $candidate = $secondary[0]
    }
    else {
        return [ordered]@{ injected = $false; reason = "ambiguous_or_missing_candidate"; taskId = "" }
    }

    $Update.task_id = [string]$candidate.taskId
    if (-not $Update.ContainsKey("notes") -or [string]::IsNullOrWhiteSpace([string]$Update.notes)) {
        $Update.notes = "auto_injected_task_id"
    }

    return [ordered]@{ injected = $true; reason = "single_candidate"; taskId = [string]$candidate.taskId }
}

function Process-TeamLeadInbox {
    param(
        [hashtable]$State,
        [hashtable]$TaskMap,
        [hashtable]$Registry
    )

    $inboxPath = Get-InboxPath -InboxName (Get-TeamLeadInboxName -Registry $Registry)
    $messages = Read-InboxMessages -InboxPath $inboxPath

    $processed = @{}
    foreach ($k in $State.processedMessages) { $processed[[string]$k] = $true }

    foreach ($m in $messages) {
        $key = Get-MessageKey -Message $m
        if ($processed.ContainsKey($key)) { continue }

        try {
            $from = [string]$m.from
            $timestamp = [string]$m.timestamp
            $text = [string]$m.text
            $payload = Try-ParseJsonText -Text $text
            $updateTaskId = ""

            Ensure-AgentState -State $State -Agent $from
            $State.agents[$from].lastSeen = $timestamp

            if ($payload -and $payload.type -eq "idle_notification") {
                $State.agents[$from].idle = $true
                $State.agents[$from].lastEvent = "idle"
            }
            else {
                $taskUpdatePayload = $null
                $taskUpdateRawJson = $null
                $hasTaskUpdateMarkers = Has-TaskUpdateMarkers -Text $text

                if ($payload -and $payload.type -eq "task_update") {
                    $taskUpdatePayload = $payload
                }
                else {
                    $taskUpdateRawJson = Get-TaskUpdateBlockJson -Text $text
                    if ($taskUpdateRawJson) {
                        $taskUpdatePayload = Try-ParseJsonText -Text $taskUpdateRawJson
                    }
                }

                if ($taskUpdatePayload) {
                    $State.agents[$from].idle = $true
                    $State.agents[$from].lastEvent = "task_update"

                    $update = ConvertTo-HashtableDeep -InputObject $taskUpdatePayload
                    if (-not $update.ContainsKey("actor")) { $update.actor = $from }

                    $injection = Try-AutoInjectTaskId -Update $update -TaskMap $TaskMap -AgentName $from
                    if ($injection.injected) {
                        Write-OrchestratorLog "Auto-injected task_id for $from at stage '$([string]$update.stage)': $([string]$injection.taskId)"
                    }

                    if ($update.ContainsKey("task_id")) { $updateTaskId = [string]$update.task_id }

                    $validation = Test-TaskUpdateSchema -Update $update -TaskMap $TaskMap
                    if (-not $validation.isValid) {
                        $failure = Register-TaskUpdateValidationFailure -State $State -Agent $from -TaskId $updateTaskId
                        Send-ValidationFeedback -AgentName $from -ErrorCode ([string]$validation.code) -ErrorMessage ([string]$validation.message) -Severity ([string]$failure.severity) -FailureCount ([int]$failure.count) -Registry $Registry
                        Write-OrchestratorLog "Rejected task_update from ${from}: $($validation.code) - $($validation.message) [severity=$($failure.severity), count=$($failure.count)]" "WARN"

                        if ($TaskMap.ContainsKey($updateTaskId)) {
                            $task = $TaskMap[$updateTaskId]
                            Ensure-TaskDefaults -Task $task
                            $task.awaitingValidReport = $true
                            $task.updatedAt = [DateTime]::UtcNow.ToString("o")
                        }

                        if ($failure.severity -eq "hard") {
                            $State.agents[$from].idle = $false
                            $State.agents[$from].lastEvent = "task_update_hard_invalid"
                        }
                    }
                    else {
                        if ($TaskMap.ContainsKey($updateTaskId)) {
                            $task = $TaskMap[$updateTaskId]
                            Ensure-TaskDefaults -Task $task
                            $task.awaitingValidReport = $false
                        }

                        Clear-TaskUpdateValidationFailure -State $State -Agent $from -TaskId $updateTaskId
                        Handle-TaskUpdate -TaskMap $TaskMap -Update $update
                    }
                }
                elseif ($taskUpdateRawJson -or $hasTaskUpdateMarkers) {
                    $taskIdFromText = Get-TaskIdFromText -Text $text

                    $failure = Register-TaskUpdateValidationFailure -State $State -Agent $from -TaskId $taskIdFromText
                    Send-ValidationFeedback -AgentName $from -ErrorCode "invalid_json_block" -ErrorMessage "Could not parse JSON inside TASK_UPDATE markers" -Severity ([string]$failure.severity) -FailureCount ([int]$failure.count) -Registry $Registry
                    Write-OrchestratorLog "Rejected task_update from ${from}: invalid_json_block [severity=$($failure.severity), count=$($failure.count)]" "WARN"

                    if ($TaskMap.ContainsKey($taskIdFromText)) {
                        $task = $TaskMap[$taskIdFromText]
                        Ensure-TaskDefaults -Task $task
                        $task.awaitingValidReport = $true
                        $task.updatedAt = [DateTime]::UtcNow.ToString("o")
                    }

                    if ($failure.severity -eq "hard") {
                        $State.agents[$from].idle = $false
                        $State.agents[$from].lastEvent = "task_update_hard_invalid"
                    }
                    else {
                        $State.agents[$from].idle = $true
                        $State.agents[$from].lastEvent = "task_update_soft_invalid"
                    }
                }
                else {
                    $State.agents[$from].idle = $false
                    $State.agents[$from].lastEvent = "message"
                }
            }

            Clear-TaskUpdateValidationFailure -State $State -Agent $from -TaskId (Get-ProcessingFailureTaskId)
        }
        catch {
            $fromSafe = [string]$m.from
            if ([string]::IsNullOrWhiteSpace($fromSafe)) {
                $fromSafe = "unknown-agent"
            }

            Write-OrchestratorLog "Failed to process inbox message from ${fromSafe}: $($_.Exception.Message)" "WARN"
            Ensure-AgentState -State $State -Agent $fromSafe
            $processingFailure = Register-TaskUpdateValidationFailure -State $State -Agent $fromSafe -TaskId (Get-ProcessingFailureTaskId)

            if ($processingFailure.severity -eq "hard") {
                $State.agents[$fromSafe].idle = $false
                $State.agents[$fromSafe].lastEvent = "task_update_processing_error_hard"
            }
            else {
                $State.agents[$fromSafe].idle = $true
                $State.agents[$fromSafe].lastEvent = "task_update_processing_error_soft"
            }

            Send-ValidationFeedback -AgentName $fromSafe -ErrorCode "processing_error" -ErrorMessage "Message processing failed. Please resend with valid TASK_UPDATE contract." -Severity ([string]$processingFailure.severity) -FailureCount ([int]$processingFailure.count) -Registry $Registry
        }

        $processed[$key] = $true
    }

    $keys = @($processed.Keys)
    if ($keys.Count -gt [int]$script:Config.runtime.maxProcessedMessages) {
        $keys = $keys | Select-Object -Last ([int]$script:Config.runtime.maxProcessedMessages)
    }

    $State.processedMessages = $keys
}

function Try-DispatchByState {
    param(
        [hashtable]$Task,
        [hashtable]$State,
        [hashtable]$Registry
    )

    if ($Task.awaitingValidReport) {
        return $false
    }

    if ($Task.status -eq "NEW") {
        if ($Task.assignee -eq "planner") {
            Set-TaskStatus -Task $Task -To "PLANNING" -Reason "New planning task" -Actor "orchestrator"
        }
        elseif ($Task.assignee -eq "programmer") {
            Set-TaskStatus -Task $Task -To "READY_FOR_DEV" -Reason "New development task" -Actor "orchestrator"
        }
        else {
            Set-TaskStatus -Task $Task -To "PM_REVIEW" -Reason "Needs PM triage" -Actor "orchestrator"
        }
    }

    if ($Task.status -eq "PLANNING") {
        return (Dispatch-Task -Task $Task -AgentRole "planner" -Reason "Create or revise plan" -State $State -Registry $Registry)
    }
    elseif ($Task.status -eq "PM_REVIEW") {
        return (Dispatch-Task -Task $Task -AgentRole "pm" -Reason "Review and assign" -State $State -Registry $Registry)
    }
    elseif ($Task.status -eq "READY_FOR_DEV") {
        $dispatched = Dispatch-Task -Task $Task -AgentRole "programmer" -Reason "Implement task" -State $State -Registry $Registry
        if ($dispatched) {
            Set-TaskStatus -Task $Task -To "IN_DEV" -Reason "Assigned to developer" -Actor "orchestrator"
            return $true
        }
    }
    elseif ($Task.status -eq "REWORK") {
        $dispatched = Dispatch-Task -Task $Task -AgentRole "programmer" -Reason "Address review feedback" -State $State -Registry $Registry
        if ($dispatched) {
            Set-TaskStatus -Task $Task -To "IN_DEV" -Reason "Assigned for rework" -Actor "orchestrator"
            return $true
        }
    }
    elseif ($Task.status -eq "CODE_REVIEW") {
        return (Dispatch-Task -Task $Task -AgentRole "codeReviewer" -Reason "Review code changes" -State $State -Registry $Registry)
    }
    elseif ($Task.status -eq "MERGE_READY") {
        return (Dispatch-Task -Task $Task -AgentRole "pm" -Reason "Prepare PR and request final approval" -State $State -Registry $Registry)
    }

    return $false
}

function Invoke-OrchestratorTick {
    $taskMap = Load-TaskMap
    $state = Load-State
    $registry = Load-TeamRegistry
    Ensure-ValidationState -State $state
    Ensure-RegistryAgents -State $state -Registry $registry

    Sync-TodoToTaskMap -TaskMap $taskMap
    Process-TeamLeadInbox -State $state -TaskMap $taskMap -Registry $registry

    $orderedTaskIds = @(
        $taskMap.Keys | Sort-Object `
            @{ Expression = { Get-PriorityRank -Priority $taskMap[$_].priority } }, `
            @{ Expression = { $taskMap[$_].updatedAt } }
    )

    foreach ($taskId in $orderedTaskIds) {
        $task = $taskMap[$taskId]
        Try-DispatchByState -Task $task -State $state -Registry $registry | Out-Null
    }

    Save-TaskMap -TaskMap $taskMap
    Save-State -State $state

    Write-OrchestratorLog "Tick complete. tasks=$($taskMap.Keys.Count), processedMessages=$($state.processedMessages.Count)"
}

function Initialize-Config {
    $resolvedConfigPath = Resolve-TokenPath -PathValue $ConfigPath
    $obj = Read-JsonFile -Path $resolvedConfigPath -Default $null
    if ($null -eq $obj) { throw "Config not found: $resolvedConfigPath" }

    $cfg = ConvertTo-HashtableDeep -InputObject $obj

    $cfg.teamRootResolved = Resolve-TokenPath -PathValue $cfg.teamRoot
    $cfg.todoFileResolved = Resolve-TokenPath -PathValue $cfg.todoFile
    $cfg.tasksDirResolved = Resolve-TokenPath -PathValue $cfg.tasksDir
    $cfg.stateFileResolved = Resolve-TokenPath -PathValue $cfg.stateFile
    $cfg.logFileResolved = Resolve-TokenPath -PathValue $cfg.logFile

    if (-not $cfg.runtime) {
        $cfg.runtime = @{}
    }
    elseif ($cfg.runtime -isnot [hashtable]) { $cfg.runtime = ConvertTo-HashtableDeep -InputObject $cfg.runtime }
    if (-not $cfg.runtime.ContainsKey("taskUpdateSoftFailLimit")) {
        $cfg.runtime["taskUpdateSoftFailLimit"] = 1
    }
    if (-not $cfg.runtime.ContainsKey("autoInjectTaskId")) {
        $cfg.runtime["autoInjectTaskId"] = $true
    }

    return $cfg
}

function Start-OrchestratorWatch {
    Invoke-OrchestratorTick
    Write-OrchestratorLog "Watch mode started"

    $todoDir = Split-Path $script:Config.todoFileResolved -Parent
    $todoName = Split-Path $script:Config.todoFileResolved -Leaf

    $leadInboxPath = Get-InboxPath -InboxName $script:Config.inboxes.teamLead
    $inboxDir = Split-Path $leadInboxPath -Parent
    $inboxName = Split-Path $leadInboxPath -Leaf

    $watchTodo = New-Object System.IO.FileSystemWatcher($todoDir, $todoName)
    $watchTodo.NotifyFilter = [System.IO.NotifyFilters]::LastWrite
    $watchTodo.EnableRaisingEvents = $true

    $watchInbox = New-Object System.IO.FileSystemWatcher($inboxDir, $inboxName)
    $watchInbox.NotifyFilter = [System.IO.NotifyFilters]::LastWrite
    $watchInbox.EnableRaisingEvents = $true

    Register-ObjectEvent -InputObject $watchTodo -EventName Changed -SourceIdentifier "orchestrator_todo_changed" | Out-Null
    Register-ObjectEvent -InputObject $watchInbox -EventName Changed -SourceIdentifier "orchestrator_inbox_changed" | Out-Null

    while ($true) {
        $evt = Wait-Event -Timeout 60
        if ($null -eq $evt) { continue }

        Remove-Event -EventIdentifier $evt.EventIdentifier | Out-Null
        Start-Sleep -Milliseconds 400

        Invoke-OrchestratorTick
    }
}

$script:Config = Initialize-Config

if ($Once) {
    Invoke-OrchestratorTick
}
else {
    Start-OrchestratorWatch
}
