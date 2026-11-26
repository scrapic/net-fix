$lines = Get-Content "$env:TEMP\tg_proxies.txt" -ErrorAction Stop
$items = @()
foreach ($l in $lines) {
    if ($l -match 'server=([^&]+)&port=(\d+)&secret=([^&\s]+)') {
        $items += [pscustomobject]@{ Server = $matches[1]; Port = [int]$matches[2]; Secret = $matches[3] }
    }
}
"parsed: $($items.Count)"

$results = @()
$batchSize = 25
for ($i = 0; $i -lt $items.Count; $i += $batchSize) {
    $batch = @($items[$i..([Math]::Min($i + $batchSize - 1, $items.Count - 1))])
    $jobs = New-Object System.Collections.ArrayList
    foreach ($it in $batch) {
        $d = [System.Net.Dns]::GetHostEntry($it.Server)
        $ip = ($d.AddressList | Where-Object { $_.AddressFamily -eq 'InterNetwork' } | Select-Object -First 1).ToString()
        if (-not $ip) { $ip = $it.Server }
        [void]$jobs.Add([pscustomobject]@{ Item = $it; Ip = $ip })
    }
    foreach ($j in $jobs) {
        $c = New-Object Net.Sockets.TcpClient
        try { $ar = $c.BeginConnect($j.Ip, $j.Item.Port, $null, $null) } catch { continue }
        $j | Add-Member -NotePropertyName Client -NotePropertyValue $c -Force
        $j | Add-Member -NotePropertyName Ar -NotePropertyValue $ar -Force
    }
    Start-Sleep -Milliseconds 3000
    foreach ($j in $jobs) {
        $ok = $false
        try { $ok = $j.Ar.AsyncWaitHandle.WaitOne(0) -and $j.Client.Connected } catch { }
        if ($ok) {
            $results += "{0}:{1}  secret={2}  ip={3}" -f $j.Item.Server, $j.Item.Port, $j.Item.Secret, $j.Ip
        }
        try { $j.Client.Close() } catch { }
    }
    Write-Host "batch $i done, open so far: $($results.Count)"
}

"OPEN: $($results.Count)"
$results | Out-File "$env:TEMP\tg_open.txt" -Encoding utf8
$results | Select-Object -First 15 | Out-String -Width 200
