$taskName = "Praetorian Daily"
$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if (-not $task) {
    Write-Output "Scheduled task '$taskName' was not found."
    exit 1
}

Write-Output "Scheduled task '$taskName' is registered with the following details:"
$task | Format-List TaskName, State, Author, Description
$triggerInfo = $task.Triggers | Select-Object -Property StartBoundary, Enabled, @{Name='Schedule';Expression={$_.GetType().Name}}
Write-Output "Triggers:"
$triggerInfo | Format-Table -AutoSize

$actionInfo = $task.Actions | Select-Object -Property Execute, Arguments, WorkingDirectory
Write-Output "Actions:"
$actionInfo | Format-Table -AutoSize
