#Requires -RunAsAdministrator
# Measures googlevideo throughput with service off and with each zapret preset.
$ErrorActionPreference = 'Continue'
$root = 'C:\Users\scrapic\Documents\zapret-discord-youtube-1.10.1'
$bin = Join-Path $root 'bin\'
$lists = Join-Path $root 'lists\'
$log = Join-Path $PSScriptRoot 'speedtest.log'
"=== $(Get-Date -Format 'HH:mm:ss') SPEED TEST ===" | Out-File $log -Encoding utf8
function Log($m) { Write-Host $m; $m | Out-File $log -Append -Encoding utf8 }

$url = (Get-Content "$env:TEMP\yt_url.txt" -Raw).Trim() + '&range=0-6000000'

function Measure-Speed([string]$tag) {
    $out = & curl.exe -sS -o NUL -w "%{size_download} %{time_total}" --max-time 12 $url 2>&1
    $parts = ($out | Out-String).Trim() -split '\s+'
    if ($parts.Count -ge 2 -and $parts[0] -match '^\d+$') {
        $kbs = [math]::Round(([double]$parts[0] / 1024) / [double]$parts[1], 0)
        Log ("  {0,-34} {1,7} KB/s   ({2:N1} Mbps)" -f $tag, $kbs, ($kbs * 8 / 1024))
        return $kbs
    }
    Log ("  {0,-34} FAIL [{1}]" -f $tag, (($out | Out-String).Trim()))
    return 0
}

function Get-Args([string]$bat) {
    $c = Get-Content $bat -Raw
    $i = $c.IndexOf('winws.exe"')
    if ($i -lt 0) { return $null }
    $r = $c.Substring($i + 10)
    $r = $r -replace '(?m)\s*\^\s*$', ' '
    $r = $r -replace '\r?\n', ' '
    $blocks = $r -split ' --new '
    $keep = @()
    foreach ($b in $blocks) {
        if ($b -match '--filter-(tcp|udp)=\s*%GameFilter(TCP|UDP)%') { continue }
        $b = $b -replace ',%GameFilter(TCP|UDP)%', ''
        $b = $b -replace '%BIN%', $bin -replace '%LISTS%', $lists
        $keep += $b.Trim()
    }
    return ($keep -join ' --new ')
}

Log "--- stop zapret service (baseline) ---"
Stop-Service zapret -Force -ErrorAction SilentlyContinue
Start-Sleep 2
Get-Process winws -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep 1
Clear-DnsClientCache
Measure-Speed 'BASELINE (no zapret)'
Measure-Speed 'BASELINE (repeat)'

$presets = @(
    'general (SIMPLE FAKE).bat',
    'general (ALT).bat',
    'general (ALT2).bat',
    'general (ALT3).bat',
    'general (ALT11).bat',
    'general (FAKE TLS AUTO).bat',
    'general (FAKE TLS AUTO ALT).bat'
)

foreach ($p in $presets) {
    $bat = Join-Path $root $p
    if (-not (Test-Path $bat)) { Log "  missing: $p"; continue }
    $a = Get-Args $bat
    Log "--- $p ---"
    Get-Process winws -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep 1
    try {
        Start-Process -FilePath (Join-Path $bin 'winws.exe') -ArgumentList $a -WindowStyle Hidden
        Start-Sleep 3
        $alive = Get-Process winws -ErrorAction SilentlyContinue
        if (-not $alive) { Log "  winws did not start (bad args)"; continue }
        Measure-Speed $p
        Measure-Speed ($p + ' #2')
    } catch { Log "  ERR: $($_.Exception.Message)" }
}

Log "--- restore service ---"
Get-Process winws -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep 1
Start-Service zapret
Start-Sleep 2
Log ("service status: " + (Get-Service zapret).Status)
