# DVS PTP MITM -- Windows control panel
#
# Double-click "DVS PTP MITM.cmd" (which launches this script). It opens a small
# menu to activate/deactivate the man-in-the-middle wrapper and toggle its
# options (PTPv2, leader mode). It elevates via UAC once, applies the change,
# and restarts the Dante Virtual Soundcard service so it takes effect.

$ErrorActionPreference = 'Stop'

# --- elevate to Administrator (needed to write into Program Files) -----------
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Host "Requesting administrator rights..."
    Start-Process powershell.exe -Verb RunAs -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`""
    )
    exit
}

$DvsDir = 'C:\Program Files\Audinate\Dante Virtual Soundcard'
$Ptp    = Join-Path $DvsDir 'ptp.exe'
$Orig   = Join-Path $DvsDir 'ptp-original.exe'
$Conf   = Join-Path $DvsDir 'ptp-mitm.conf'

# --- helpers ----------------------------------------------------------------

function Test-Installed { Test-Path $Orig }

function Get-ConfValue([string]$key) {
    if (-not (Test-Path $Conf)) { return $false }
    $line = Select-String -Path $Conf -Pattern "^\s*$key\s*=" -ErrorAction SilentlyContinue | Select-Object -Last 1
    if (-not $line) { return $false }
    $val = ($line.Line -split '=', 2)[1].Trim().ToLower()
    return @('1', 'y', 'yes', 'true', 'on') -contains $val
}

function Set-Conf([bool]$leader, [bool]$ptpv2) {
    $l = if ($leader) { 1 } else { 0 }
    $p = if ($ptpv2)  { 1 } else { 0 }
    @(
        '# DVS PTP MITM configuration (written by dvs-ptp-mitm.ps1)'
        "leader = $l"
        "ptpv2  = $p"
    ) | Set-Content -Path $Conf -Encoding ASCII
}

# Make sure a ptp-mitm.exe is available: prefer the prebuilt one shipped next to
# this script; only compile from source as a fallback.
function Get-Binary {
    $local = Join-Path $PSScriptRoot 'ptp-mitm.exe'
    if (Test-Path $local) { return $local }
    $src = Join-Path $PSScriptRoot 'ptp-mitm.c'
    if (-not (Test-Path $src)) { throw "No ptp-mitm.exe and no source to build it. Please download a release." }
    $cc = (Get-Command gcc, cc, clang -ErrorAction SilentlyContinue | Select-Object -First 1)
    if (-not $cc) { throw "No prebuilt ptp-mitm.exe and no C compiler found. Download a release, or install MinGW." }
    & $cc.Source '-DWIN32' '-O2' '-o' $local $src
    return $local
}

# Restart the DVS PTP service so the change takes effect. Best-effort: restart
# the Dante Virtual Soundcard service if present, otherwise stop ptp.exe and let
# DVS respawn it.
function Restart-Dvs {
    $svc = Get-Service -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like '*Dante Virtual Soundcard*' -or $_.Name -like '*Dante*' } |
        Select-Object -First 1
    if ($svc) {
        Restart-Service -InputObject $svc -Force -ErrorAction SilentlyContinue
    } else {
        Stop-Process -Name 'ptp' -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-Activate {
    $bin = Get-Binary
    if (-not (Test-Path $Orig)) {
        Copy-Item $Ptp $Orig                       # back up real original once
    }
    Copy-Item $bin $Ptp -Force
    if (-not (Test-Path $Conf)) {
        Copy-Item (Join-Path $PSScriptRoot 'ptp-mitm.conf') $Conf
    }
    Restart-Dvs
    Write-Host "`nActivated and DVS PTP service restarted." -ForegroundColor Green
}

function Invoke-Deactivate {
    if (-not (Test-Installed)) { Write-Host "`nNot installed -- nothing to do." -ForegroundColor Yellow; return }
    Move-Item $Orig $Ptp -Force
    Restart-Dvs
    Write-Host "`nOriginal ptp restored and DVS PTP service restarted." -ForegroundColor Green
}

function Edit-Options {
    $curLeader = Get-ConfValue 'leader'
    $curPtpv2  = Get-ConfValue 'ptpv2'
    Write-Host ""
    $a = Read-Host "Enable PTPv2 support? (y/n) [$(if($curPtpv2){'y'}else{'n'})]"
    $b = Read-Host "Allow DVS to become leader? (y/n) [$(if($curLeader){'y'}else{'n'})]"
    $ptpv2  = if ($a -eq '') { $curPtpv2 }  else { $a -match '^(y|yes|1|on|true)$' }
    $leader = if ($b -eq '') { $curLeader } else { $b -match '^(y|yes|1|on|true)$' }
    Set-Conf -leader $leader -ptpv2 $ptpv2
    if (Test-Installed) { Restart-Dvs; Write-Host "`nSaved and DVS PTP service restarted." -ForegroundColor Green }
    else { Write-Host "`nSaved. They apply once you activate the wrapper." -ForegroundColor Green }
}

# Inspect the running PTP process to report the EFFECTIVE state -- what DVS is
# actually running right now, independent of the config file. Works whether or
# not the wrapper is installed (matches both ptp.exe and ptp-original.exe).
function Get-LiveStatus {
    $proc = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq 'ptp.exe' -or $_.Name -eq 'ptp-original.exe' } |
        Select-Object -First 1
    if (-not $proc) { return 'PTP service not running' }
    $cmd = " $($proc.CommandLine) "
    $p = if ($cmd -match '\s-y2')  { 'enabled' } else { 'disabled' }   # wrapper appends -y2=-2 for PTPv2
    $l = if ($cmd -match '\s-s\s') { 'disabled' } else { 'enabled' }   # DVS passes -s for slave-only
    return "PTPv2 $p, leader mode $l"
}

function YesNo([bool]$b) { if ($b) { 'enabled' } else { 'disabled' } }

function Show-Status {
    $state = if (Test-Installed) { 'installed' } else { 'not installed' }
    Write-Host ""
    Write-Host "Wrapper : $state"
    Write-Host "Configured (desired):   PTPv2: $(YesNo (Get-ConfValue 'ptpv2')), Leader mode: $(YesNo (Get-ConfValue 'leader'))"
    Write-Host "Live (what DVS runs now):  $(Get-LiveStatus)"
    Write-Host "config file: $Conf"
}

# --- menu loop --------------------------------------------------------------
$quit = $false
while (-not $quit) {
    $state = if (Test-Installed) { 'active' } else { 'not installed' }
    Write-Host ""
    Write-Host "===== DVS PTP MITM  (currently: $state) =====" -ForegroundColor Cyan
    Write-Host "  1) Activate wrapper"
    Write-Host "  2) Deactivate wrapper"
    Write-Host "  3) Edit options (PTPv2 / leader)"
    Write-Host "  4) Show status"
    Write-Host "  5) Quit"
    try {
        switch (Read-Host "Choose") {
            '1' { Invoke-Activate }
            '2' { Invoke-Deactivate }
            '3' { Edit-Options }
            '4' { Show-Status }
            '5' { $quit = $true }
            default { }
        }
    } catch {
        Write-Host "`nError: $($_.Exception.Message)" -ForegroundColor Red
    }
}
