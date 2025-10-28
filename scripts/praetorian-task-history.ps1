$taskName = "Praetorian"
$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if (-not $task) {
    Write-Output "Scheduled task '$taskName' was not found."
    exit 1
}

$history = Get-ScheduledTaskInfo -TaskName $taskName
Write-Output "Last run time : $($history.LastRunTime)"
Write-Output "Last result   : $($history.LastTaskResult)"
Write-Output "Next run time : $($history.NextRunTime)"

$taskPath = "\$taskName"
$logName = 'Microsoft-Windows-TaskScheduler/Operational'

try {
    $events = Get-WinEvent -LogName $logName -ErrorAction Stop |
        Where-Object { $_.Properties.Count -gt 0 -and $_.Properties[0].Value -eq $taskPath } |
        Sort-Object TimeCreated -Descending |
        Select-Object -First 10

    if ($events) {
        Write-Output "Recent run history (last 10 events):"
        $events | Select-Object TimeCreated, Id, LevelDisplayName, Message | Format-Table -AutoSize
    } else {
        Write-Output "No recent history events found in $logName for task '$taskName'."
    }
} catch {
    Write-Output "Unable to read Task Scheduler event log: $($_.Exception.Message)"
}
