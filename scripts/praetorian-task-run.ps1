$taskName = "Praetorian"
try {
    $task = Get-ScheduledTask -TaskName $taskName -ErrorAction Stop
} catch {
    Write-Output "Scheduled task '$taskName' was not found."
    exit 1
}

try {
    Start-ScheduledTask -TaskName $taskName
    Write-Output "Task '$taskName' has been triggered."
} catch {
    Write-Output "Failed to trigger task '$taskName': $($_.Exception.Message)"
    exit 1
}
