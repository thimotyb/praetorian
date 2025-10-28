$taskName = "Praetorian"
$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if (-not $task) {
    Write-Output "Scheduled task '$taskName' was not found."
    exit 1
}

$history = Get-ScheduledTaskInfo -TaskName $taskName
Write-Output "Last run time: $($history.LastRunTime)"
Write-Output "Last task result: $($history.LastTaskResult)"
Write-Output "Next run time: $($history.NextRunTime)"

Write-Output "Recent run history (last 10 events):"
Get-ScheduledTask -TaskName $taskName | Get-ScheduledTaskHistory | Select-Object -First 10 | Format-Table -AutoSize
