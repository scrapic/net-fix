#Requires -RunAsAdministrator
# Installs: DNS-over-HTTPS, hosts fixes (Roblox/Meta) and zapret service.
param(
    [string]$Preset = 'general (SIMPLE FAKE).bat'
)

$ErrorActionPreference = 'Continue'
$here = $PSScriptRoot
$log  = Join-Path $here 'install.log'
$AppDir   = Join-Path $env:ProgramData 'zapret'
$HostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
$Begin = '# >>> netfix >>>'
$End   = '# <<< netfix <<<'

if (Test-Path $log) { Remove-Item $log -Force -ErrorAction SilentlyContinue }
function Log($m) { Write-Host $m; Add-Content -Path $log -Value $m -Encoding UTF8 }
function Head($m) { Log ''; Log ('=== ' + (Get-Date -Format 'HH:mm:ss') + '  ' + $m + ' ===') }

# ---------------------------------------------------------------- helpers
function Test-Tcp([string]$ip, [int]$port = 443, [int]$timeout = 2500) {
    try {
        $c = New-Object Net.Sockets.TcpClient
        $t = $c.BeginConnect($ip, $port, $null, $null)
        $ok = $t.AsyncWaitHandle.WaitOne($timeout)
        if ($ok -and $c.Connected) { $c.EndConnect($t); $c.Close(); return $true }
        $c.Close(); return $false
    } catch { return $false }
}

function Pick-Ip([string[]]$candidates) {
    foreach ($ip in $candidates) {
        if (Test-Tcp $ip 443) { return $ip }
    }
    return $null
}

function Get-PresetArgs([string]$bat, [string]$bin, [string]$lists) {
    $c = Get-Content $bat -Raw
    $i = $c.IndexOf('winws.exe"')
    if ($i -lt 0) { throw "cannot parse $bat" }
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

function Set-HostsBlock([string[]]$lines) {
    $item = Get-Item $HostsPath -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReadOnly) {
        $item.Attributes = $item.Attributes -bxor [IO.FileAttributes]::ReadOnly
    }
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        $cur = @()
        try { $cur = @(Get-Content -LiteralPath $HostsPath -Force -ErrorAction Stop) } catch { $cur = @() }
        $out = New-Object System.Collections.Generic.List[string]
        $skip = $false
        foreach ($l in $cur) {
            $t = $l.Trim()
            if ($t -eq $Begin) { $skip = $true; continue }
            if ($t -eq $End)   { $skip = $false; continue }
            if (-not $skip) { $out.Add($l) }
        }
        $out.Add('')
        $out.Add($Begin)
        foreach ($l in $lines) { $out.Add($l) }
        $out.Add($End)

        $text = ($out -join "`r`n") + "`r`n"
        $tmp = "$HostsPath.netfix.tmp"
        try {
            [IO.File]::WriteAllText($tmp, $text, [Text.Encoding]::ASCII)
            if (Test-Path -LiteralPath $HostsPath) {
                try { [IO.File]::Replace($tmp, $HostsPath, $null) }
                catch { Copy-Item -LiteralPath $tmp -Destination $HostsPath -Force }
            } else {
                Move-Item -LiteralPath $tmp -Destination $HostsPath -Force
            }
            Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        } catch { Log "  hosts write attempt $attempt : $($_.Exception.Message)" }

        Start-Sleep -Milliseconds 300
        $check = @()
        try { $check = @(Get-Content -LiteralPath $HostsPath -Force -ErrorAction Stop) } catch { }
        if (($check -join "`n") -match [regex]::Escape($Begin)) {
            Log ("  hosts entries written: " + $lines.Count)
            return
        }
        Log "  hosts verify failed (attempt $attempt), retrying"
        Start-Sleep -Milliseconds 700
    }
    Log '  ERROR: could not write hosts file'
}

function Set-DoH {
    $servers = @(
        @{ ip = '1.1.1.1'; tpl = 'https://cloudflare-dns.com/dns-query' },
        @{ ip = '1.0.0.1'; tpl = 'https://cloudflare-dns.com/dns-query' }
    )
    foreach ($s in $servers) {
        try {
            Set-DnsClientDohServerAddress -ServerAddress $s.ip -DohTemplate $s.tpl -AllowFallbackToUdp $false -AutoUpgrade $true -ErrorAction Stop
            Log "  DoH template: $($s.ip)"
        } catch {
            try {
                Add-DnsClientDohServerAddress -ServerAddress $s.ip -DohTemplate $s.tpl -AllowFallbackToUdp $false -AutoUpgrade $true -ErrorAction Stop
                Log "  DoH template added: $($s.ip)"
            } catch { Log "  DoH ERR $($s.ip): $($_.Exception.Message)" }
        }
    }
    $adapters = Get-NetAdapter | Where-Object {
        $_.Status -eq 'Up' -and $_.Virtual -eq $false -and
        $_.InterfaceDescription -notmatch 'WARP|WireGuard|TAP|Tailscale|ZeroTier|Hyper-V'
    }
    foreach ($a in $adapters) {
        try {
            Set-DnsClientServerAddress -InterfaceIndex $a.ifIndex -ServerAddresses @('1.1.1.1', '1.0.0.1') -ErrorAction Stop
            Log "  adapter $($a.Name): DNS -> 1.1.1.1 / 1.0.0.1"
        } catch { Log "  adapter $($a.Name): ERR $($_.Exception.Message)" }
        & netsh dns set interface name="$($a.Name)" ddr=no ddrfallback=no 2>&1 | Out-Null
    }
}

function Install-Zapret {
    $svc = 'zapret'
    $srcExe = Join-Path $here 'zapret\bin\winws.exe'
    if (-not (Test-Path $srcExe)) { Log '  zapret folder not found next to installer - skipped'; return }

    Stop-Service $svc -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
    Get-Process winws -ErrorAction SilentlyContinue | Stop-Process -Force
    & sc.exe delete $svc 2>&1 | Out-Null
    Start-Sleep -Seconds 1

    if (Test-Path $AppDir) { Remove-Item $AppDir -Recurse -Force -ErrorAction SilentlyContinue }
    New-Item -ItemType Directory -Force -Path $AppDir | Out-Null
    Copy-Item (Join-Path $here 'zapret\*') $AppDir -Recurse -Force
    Log "  files copied to $AppDir"

    $bin   = Join-Path $AppDir 'bin\'
    $lists = Join-Path $AppDir 'lists\'
    $presetPath = Join-Path $AppDir $Preset
    if (-not (Test-Path $presetPath)) { Log "  preset not found: $Preset"; return }

    $svcArgs = Get-PresetArgs $presetPath $bin $lists
    try {
        New-Service -Name $svc -BinaryPathName "`"$($bin)winws.exe`" $svcArgs" `
            -DisplayName 'zapret' -StartupType Automatic `
            -Description 'Zapret DPI bypass software' -ErrorAction Stop | Out-Null
        Start-Service $svc -ErrorAction Stop
        Log "  service 'zapret' installed and started (preset: $Preset)"
    } catch {
        Log "  service ERR: $($_.Exception.Message)"
    }
}

function Test-Url([string]$u) {
    $o = & curl.exe -sS -o NUL -w '%{http_code}' --max-time 15 $u 2>&1
    return (($o | Out-String).Trim())
}

# ---------------------------------------------------------------- main
Head 'DNS over HTTPS'
Set-DoH

Head 'hosts fixes'
$meta = Pick-Ip @('157.240.0.35', '157.240.0.174', '157.240.0.63', '157.240.0.60')
$rbx  = Pick-Ip @('23.73.2.78', '23.73.2.80', '23.73.2.95', '23.73.2.76')
$lines = @()
if ($rbx) {
    $lines += "$rbx`ttr.rbxcdn.com"
    $lines += "$rbx`tthumbnails.rbxcdn.com"
    Log "  roblox edge: $rbx"
} else { Log '  roblox: no reachable edge, skipped' }
if ($meta) {
    foreach ($h in 'instagram.com', 'www.instagram.com', 'i.instagram.com', 'graph.instagram.com', 'scontent.cdninstagram.com') {
        $lines += "$meta`t$h"
    }
    foreach ($h in 'facebook.com', 'www.facebook.com', 'whatsapp.com', 'www.whatsapp.com', 'web.whatsapp.com', 'static.whatsapp.net', 'mmg.whatsapp.net') {
        $lines += "$meta`t$h"
    }
    Log "  meta edge: $meta"
} else { Log '  meta: no reachable edge, skipped' }
if ($lines.Count -gt 0) { Set-HostsBlock $lines }

Clear-DnsClientCache

Head 'zapret service'
Install-Zapret

Head 'verification'
Start-Sleep -Seconds 2
Clear-DnsClientCache
foreach ($u in 'https://www.youtube.com/', 'https://www.facebook.com/', 'https://www.instagram.com/', 'https://cdn.discordapp.com/', 'https://tr.rbxcdn.com/') {
    Log ("  {0,-34} {1}" -f $u, (Test-Url $u))
}
Log ''
Log 'Done. Reboot is not required. If something breaks - run UNINSTALL.bat'
Log 'NOTE: DNS-over-HTTPS works independently of zapret. UNINSTALL keeps DoH on,'
Log '      so the browser keeps working even with zapret removed.'
Log '      YouTube/Facebook specifically need zapret (DPI) and will not open without it.'
