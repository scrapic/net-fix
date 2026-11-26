#Requires -RunAsAdministrator
# Fixes broken Roblox thumbnails/icons: tr.rbxcdn.com CNAME chain is dead,
# so we pin it to a working Akamai edge via the hosts file.
$ErrorActionPreference = 'Stop'
$hosts = "$env:SystemRoot\System32\drivers\etc\hosts"
$log = Join-Path $PSScriptRoot 'roblox.log'
"=== $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') roblox hosts ===" | Out-File $log -Encoding utf8 -Append
function Log($m) { Write-Host $m; $m | Out-File $log -Append -Encoding utf8 }

trap { Log ("FATAL: " + $_.Exception.Message + " @ line " + $_.InvocationInfo.ScriptLineNumber); exit 1 }

$begin = '# >>> roblox-cdn-fix >>>'
$end = '# <<< roblox-cdn-fix <<<'

try {
    $it = Get-Item $hosts -Force
    if ($it.Attributes -band [IO.FileAttributes]::ReadOnly) {
        $it.Attributes = $it.Attributes -bxor [IO.FileAttributes]::ReadOnly
        Log "removed read-only attribute from hosts"
    }
} catch { Log "attr: $($_.Exception.Message)" }

$lines = @(Get-Content $hosts -ErrorAction SilentlyContinue)
$out = New-Object System.Collections.Generic.List[string]
$skip = $false
foreach ($l in $lines) {
    if ($l.Trim() -eq $begin) { $skip = $true; continue }
    if ($l.Trim() -eq $end) { $skip = $false; continue }
    if (-not $skip) { $out.Add($l) }
}

$ip = '23.73.2.78'
$out.Add('')
$out.Add($begin)
$out.Add("$ip`ttr.rbxcdn.com")
$out.Add("$ip`tthumbnails.rbxcdn.com")
$out.Add($end)

Set-Content -Path $hosts -Value $out -Encoding ASCII
Log "hosts updated: tr.rbxcdn.com -> $ip"

Clear-DnsClientCache
Start-Sleep 1
foreach ($n in 'tr.rbxcdn.com', 'thumbnails.rbxcdn.com') {
    $r = Resolve-DnsName $n -Type A -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress } | Select-Object -First 1 -ExpandProperty IPAddress
    Log ("  {0,-26} -> {1}" -f $n, $(if ($r) { $r } else { 'FAIL' }))
}
Log "Done. Restart Roblox to reload images."
