param(
    [int]$Port = 8090
)

$ErrorActionPreference = 'SilentlyContinue'

Write-Output "[MCP CHECK] Unity process"
$unity = Get-Process Unity* | Select-Object Name, Id, StartTime
if ($unity) {
    $unity | Format-Table -AutoSize
} else {
    Write-Output "No Unity process found"
}

Write-Output "[MCP CHECK] netstat :$Port"
$lines = netstat -ano | findstr (":" + $Port)
if ($lines) {
    $lines
} else {
    Write-Output "No listener found for port $Port"
}

Write-Output "[MCP CHECK] TCP 127.0.0.1:$Port"
$tcp4 = Test-NetConnection -ComputerName 127.0.0.1 -Port $Port
$tcp4 | Select-Object ComputerName, RemotePort, TcpTestSucceeded | Format-Table -AutoSize

Write-Output "[MCP CHECK] TCP ::1:$Port"
$tcp6 = Test-NetConnection -ComputerName ::1 -Port $Port
$tcp6 | Select-Object ComputerName, RemotePort, TcpTestSucceeded | Format-Table -AutoSize

Write-Output "[MCP CHECK] HTTP probe 127.0.0.1"
try {
    $r4 = Invoke-WebRequest -UseBasicParsing -Uri ("http://127.0.0.1:" + $Port + "/") -TimeoutSec 3
    Write-Output ("HTTP4 status=" + $r4.StatusCode)
}
catch {
    Write-Output ("HTTP4 error=" + $_.Exception.Message)
}

Write-Output "[MCP CHECK] HTTP probe [::1]"
try {
    $r6 = Invoke-WebRequest -UseBasicParsing -Uri ("http://[::1]:" + $Port + "/") -TimeoutSec 3
    Write-Output ("HTTP6 status=" + $r6.StatusCode)
}
catch {
    Write-Output ("HTTP6 error=" + $_.Exception.Message)
}
