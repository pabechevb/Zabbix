Get-Process -IncludeUserName | ForEach-Object {
    $procId = $_.Id
    $user = $_.UserName
    if (-not $user) { $user = "NT AUTHORITY\SYSTEM" }
    if ($user -match "DWM-\d+") { $user = "Window_Manager_DWM_Pool" }
    elseif ($user -match "UMFD-\d+") { $user = "Window_Manager_UMFD_Pool" }
    [PSCustomObject]@{
        UserName    = $user
        WorkingSet  = $_.WorkingSet64
        VirtualMem  = $_.VirtualMemorySize64
        CPU         = $_.CPU
        Handles     = $_.Handles
        Threads     = $_.Threads.Count
        ThreadsWait = ($_.Threads | Where-Object { $_.ThreadState -eq 'Wait' -and $_.WaitReason -ne 'Suspended' -and $_.WaitReason -ne 'Executive' -and $_.WaitReason -ne 'UserRequest' }).Count
    }
} | Group-Object UserName | ForEach-Object {
    $mem = ($_.Group | Measure-Object WorkingSet -Sum).Sum
    $vmm = ($_.Group | Measure-Object VirtualMem -Sum).Sum
    $cpu = ($_.Group | Measure-Object CPU -Sum).Sum
    $hnd = ($_.Group | Measure-Object Handles -Sum).Sum
    $thr = ($_.Group | Measure-Object Threads -Sum).Sum
    $wtc = ($_.Group | Measure-Object ThreadsWait -Sum).Sum
    [PSCustomObject]@{
        PRG = $_.Name
        MEM = [Math]::Round($mem, 2)
        VMM = [Math]::Round($vmm, 2)
        CPU = [Math]::Round($cpu, 2)
        HND = [Math]::Round($hnd, 2)
        THR = [Math]::Round($thr, 2)
        WTC = [Math]::Round($wtc, 2)
    }
} | ConvertTo-Json -Compress