#Requires -RunAsAdministrator
# Reverts DNS-over-HTTPS changes: back to automatic (DHCP) DNS.

$ErrorActionPreference = 'Continue'
$log = Join-Path $PSScriptRoot 'doh.log'
"=== $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') : DOH OFF (revert) ===" | Out-File -FilePath $log -Encoding utf8 -Append

function Log([string]$m) {
    Write-Host $m
    $m | Out-File -FilePath $log -Encoding utf8 -Append
}

$adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -and $_.Virtual -eq $false -and $_.InterfaceDescription -notmatch 'WARP|WireGuard|TAP|Tailscale|ZeroTier|Hyper-V' }
foreach ($a in $adapters) {
    Log "Adapter: $($a.Name) [#$($a.ifIndex)]"
    try {
        Set-DnsClientServerAddress -InterfaceIndex $a.ifIndex -ResetServerAddresses -ErrorAction Stop
        Log "  DNS reset to automatic (DHCP)"
    } catch {
        Log "  ERR: $($_.Exception.Message)"
    }
    $r = & netsh dns set interface name="$($a.Name)" ddr=yes ddrfallback=yes 2>&1
    Log ("  netsh dns interface: " + (($r | Out-String).Trim()))
}

foreach ($ip in @('1.1.1.1', '1.0.0.1')) {
    try {
        Set-DnsClientDohServerAddress -ServerAddress $ip -DohTemplate 'https://cloudflare-dns.com/dns-query' -AllowFallbackToUdp $true -AutoUpgrade $false -ErrorAction Stop
        Log "  template ${ip} set to non-auto (harmless)"
    } catch { Log "  template ${ip}: $($_.Exception.Message)" }
}

Clear-DnsClientCache
Log "Done. DNS cache flushed."
