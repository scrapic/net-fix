#Requires -RunAsAdministrator
# Enables system-wide DNS-over-HTTPS (Cloudflare) on all physical adapters.
# Fixes ISP DNS poisoning of blocked domains (youtube.com etc.) without any VPN.

$ErrorActionPreference = 'Continue'
$log = Join-Path $PSScriptRoot 'doh.log'
"=== $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') : DOH ON ===" | Out-File -FilePath $log -Encoding utf8 -Append

function Log([string]$m) {
    Write-Host $m
    $m | Out-File -FilePath $log -Encoding utf8 -Append
}

$servers = @(
    @{ ip = '1.1.1.1'; tpl = 'https://cloudflare-dns.com/dns-query' },
    @{ ip = '1.0.0.1'; tpl = 'https://cloudflare-dns.com/dns-query' }
)

Log "--- 1. Registering DoH templates (no UDP fallback = no poisoning) ---"
foreach ($s in $servers) {
    try {
        Set-DnsClientDohServerAddress -ServerAddress $s.ip -DohTemplate $s.tpl -AllowFallbackToUdp $false -AutoUpgrade $true -ErrorAction Stop
        Log "  OK (updated): $($s.ip) -> $($s.tpl)"
    } catch {
        try {
            Add-DnsClientDohServerAddress -ServerAddress $s.ip -DohTemplate $s.tpl -AllowFallbackToUdp $false -AutoUpgrade $true -ErrorAction Stop
            Log "  OK (added):   $($s.ip) -> $($s.tpl)"
        } catch {
            Log "  ERR: $($s.ip) : $($_.Exception.Message)"
        }
    }
}

Log "--- 2. Applying to active physical adapters ---"
$adapters = Get-NetAdapter | Where-Object {
    $_.Status -eq 'Up' -and $_.Virtual -eq $false -and
    $_.InterfaceDescription -notmatch 'WARP|WireGuard|TAP|Tailscale|ZeroTier|Hyper-V'
}

if (-not $adapters) { Log "  ERR: no active physical adapter found" }

foreach ($a in $adapters) {
    Log "  Adapter: $($a.Name) [#$($a.ifIndex)] $($a.InterfaceDescription)"
    try {
        Set-DnsClientServerAddress -InterfaceIndex $a.ifIndex -ServerAddresses @('1.1.1.1', '1.0.0.1') -ErrorAction Stop
        Log "    DNS set to 1.1.1.1, 1.0.0.1"
    } catch {
        Log "    ERR setting DNS: $($_.Exception.Message)"
    }

    # Disable DDR auto-downgrade so the resolver keeps using the DoH template.
    $r = & netsh dns set interface name="$($a.Name)" ddr=no ddrfallback=no 2>&1
    if ($LASTEXITCODE -ne 0) { $r = & netsh dns add interface name="$($a.Name)" ddr=no ddrfallback=no 2>&1 }
    Log ("    netsh dns interface: " + (($r | Out-String).Trim()))
}

Log "--- 3. Flushing DNS cache ---"
Clear-DnsClientCache
Log "  cache cleared"

Log "--- 4. Verification ---"
Start-Sleep -Seconds 2
$tests = @('www.youtube.com', 'youtube.com', 'm.youtube.com', 'i.ytimg.com', 'redirector.googlevideo.com', 'rr1---sn-gvbxgn-tt1e.googlevideo.com')
$fail = 0
foreach ($t in $tests) {
    $ips = @()
    try { $ips = Resolve-DnsName -Name $t -Type A -DnsOnly -ErrorAction Stop | Where-Object { $_.IPAddress } | Select-Object -ExpandProperty IPAddress } catch { }
    if ($ips) { Log ("  OK   {0,-38} -> {1}" -f $t, ($ips[0..([Math]::Min(2, $ips.Count - 1))] -join ', ')) }
    else { Log ("  FAIL {0}" -f $t); $fail++ }
}

Log ("--- RESULT: " + $(if ($fail -eq 0) { 'ALL GOOD' } else { "$fail test(s) failed" }) + " ---")
Log "If something breaks internet: run doh-off.ps1 as administrator."
