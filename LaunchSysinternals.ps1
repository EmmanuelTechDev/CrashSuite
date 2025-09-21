$toolsToLaunch = @(
    "C:\Tools\Sysinternals\Autoruns.exe",
    "C:\Tools\Sysinternals\Procmon.exe",
    "C:\Tools\Sysinternals\RAMMap.exe"
)

foreach ($tool in $toolsToLaunch) {
    if (Test-Path $tool) {
        Write-Host "Launching: $tool"
        Start-Process $tool -Verb RunAs
    } else {
        Write-Host "Tool not found: $tool"
    }
}

