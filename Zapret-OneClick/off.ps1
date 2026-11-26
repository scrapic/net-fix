#Requires -RunAsAdministrator
# Removes zapret service + hosts fixes.
# DNS-over-HTTPS is KEPT so the browser keeps working.
# Use  -ResetDns  to also restore automatic (ISP) DNS.

param([switch]$ResetDns)

$ErrorActionPreference = 'Continue'
$here = $PSScriptRoot
$log  = Join-Path $here 'off.log'
if (Test-Path $log) { Remove-Item $log -Force -ErrorAction SilentlyContinue }
$HostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
$Begin = '# >>> netfix >>>'
$End   = '# <<< netfix <<<'
$AppDir = Join-Path $env:ProgramData 'zapret'

function Log($m) { Write-Host $m; Add-Content -Path $log -Value $m -Encoding UTF8 }

Log "=== $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') uninstall ==="
Log ("zapret service now: " + (Get-Service zapret -ErrorAction SilentlyContinue).Status)
Log ("DNS now: " + ((Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.ServerAddresses } | ForEach-Object { $_.ServerAddresses }) -join ', '))

Log '--- removing zapret service ---'
Stop-Service zapret -Force -ErrorAction SilentlyContinue
Get-Process winws -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 1
& sc.exe delete zapret 2>&1 | Out-Null
if (Test-Path $AppDir) {
    Remove-Item $AppDir -Recurse -Force -ErrorAction SilentlyContinue
    Log '  service removed, folder C:\ProgramData\zapret deleted'
} else { Log '  service removed' }

Log '--- removing hosts entries ---'
$item = Get-Item $HostsPath -Force
if ($item.Attributes -band [IO.FileAttributes]::ReadOnly) {
    $item.Attributes = $item.Attributes -bxor [IO.FileAttributes]::ReadOnly
}
$out = New-Object System.Collections.Generic.List[string]
$skip = $false
foreach ($l in @(Get-Content $HostsPath -ErrorAction SilentlyContinue)) {
    $t = $l.Trim()
    if ($t -eq $Begin) { $skip = $true; continue }
    if ($t -eq $End)   { $skip = $false; continue }
    if (-not $skip) { $out.Add($l) }
}
if ($skip) { Log '  warms: hosts block was left incomplete, fixing' }
($out -join "`r`n") + "`r`n" | Set-Content -Path $HostsPath -Encoding ASCII
Log '  hosts entries removed'

if ($ResetDns) {
    Log '--- resetting DNS to automatic (DHCP) ---'
    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -and $_.Virtual -eq $false -and $_.InterfaceDescription -notmatch 'WARP|WireGuard|TAP|Tailscale|ZeroTier|Hyper-V' }
    foreach ($a in $adapters) {
        try {
            Set-DnsClientServerAddress -InterfaceIndex $a.ifIndex -ResetServerAddresses -ErrorAction Stop
            Log "  $($a.Name): DNS reset"
        } catch { Log "  $($a.Name): ERR $($_.Exception.Message)" }
        & netsh dns set interface name="$($a.Name)" ddr=yes ddrfallback=yes 2>&1 | Out-Null
    }
    foreach ($ip in '1.1.1.1', '1.0.0.1') {
        Set-DnsClientDohServerAddress -ServerAddress $ip -DohTemplate 'https://cloudflare-dns.com/dns-query' -AllowFallbackToUdp $true -AutoUpgrade $false -ErrorAction SilentlyContinue
    }
} else {
    Log '--- DNS-over-HTTPS KEPT (browser keeps working) ---'
    Log '  to also restore provider DNS run:  uninstall.ps1 -ResetDns'
}

Clear-DnsClientCache
Log ''
Log ("DNS after: " + ((Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.ServerAddresses } | ForEach-Object { $_.ServerAddresses }) -join ', '))
Log 'UNINSTALL done.'
Log 'NOTE: To make the browser work WITHOUT zapret, DNS-over-HTTPS must stay on (it is).'
Log '      YouTube / Facebook need zapret (DPI), they will not work without it.'
