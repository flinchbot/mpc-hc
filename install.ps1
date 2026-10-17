<#
.SYNOPSIS
    Installs a flinchbot-MPC-HC build into C:\Program Files\MPC-HC, overwriting the old build.

.DESCRIPTION
    Copies the build output over the existing install. Files that exist only in the
    install folder (MPCVR, Shaders, unins000.exe, ...) are left alone. Debug/link
    leftovers (*.pdb, *.exp, *.lib, *.ilk) are skipped. Elevates itself if needed and
    closes a running mpc-hc64.exe first.

.EXAMPLE
    .\install.ps1                         # installs bin\mpc-hc_x64
    .\install.ps1 -Lite                   # installs "bin\mpc-hc_x64 Lite"
    .\install.ps1 -Source D:\some\build   # installs any folder containing mpc-hc64.exe
#>
[CmdletBinding()]
param(
    [string]$Source,
    [string]$Destination = 'C:\Program Files\MPC-HC',
    [switch]$Lite
)

$ErrorActionPreference = 'Stop'

if (-not $Source) {
    $Source = if ($Lite) { Join-Path $PSScriptRoot 'bin\mpc-hc_x64 Lite' } else { Join-Path $PSScriptRoot 'bin\mpc-hc_x64' }
    # Script copied next to a build (e.g. a zip of the bin folder): install from its own folder.
    if (-not (Test-Path (Join-Path $Source 'mpc-hc64.exe')) -and (Test-Path (Join-Path $PSScriptRoot 'mpc-hc64.exe'))) {
        $Source = $PSScriptRoot
    }
}
if (-not (Test-Path (Join-Path $Source 'mpc-hc64.exe'))) {
    throw "No mpc-hc64.exe in '$Source'. Build first (build.bat Release x64) or pass -Source."
}
$Source = (Get-Item $Source).FullName  # long-form path, so it matches the FullName prefixes below

# Re-launch elevated: Program Files needs admin.
$principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host 'Requesting administrator rights...'
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"",
                 '-Source', "`"$Source`"", '-Destination', "`"$Destination`"")
    $p = Start-Process powershell.exe -Verb RunAs -ArgumentList $argList -Wait -PassThru
    exit $p.ExitCode
}

try {
    $running = Get-Process mpc-hc64, mpc-hc -ErrorAction SilentlyContinue
    if ($running) {
        Write-Host 'Closing MPC-HC...'
        $running | ForEach-Object { $_.CloseMainWindow() | Out-Null }
        $running | Wait-Process -Timeout 5 -ErrorAction SilentlyContinue
        Get-Process mpc-hc64, mpc-hc -ErrorAction SilentlyContinue | Stop-Process -Force
    }

    $version = (Get-Item (Join-Path $Source 'mpc-hc64.exe')).VersionInfo.FileVersion
    Write-Host "Installing $version"
    Write-Host "  from $Source"
    Write-Host "  to   $Destination"

    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    $skip = '.pdb', '.exp', '.lib', '.ilk'
    $count = 0
    Get-ChildItem -Path $Source -Recurse -File | Where-Object { $skip -notcontains $_.Extension } | ForEach-Object {
        $target = Join-Path $Destination $_.FullName.Substring($Source.Length).TrimStart('\')
        New-Item -ItemType Directory -Force -Path (Split-Path $target) | Out-Null
        Copy-Item -LiteralPath $_.FullName -Destination $target -Force
        $count++
    }

    Write-Host "Done: $count files copied." -ForegroundColor Green
}
catch {
    Write-Host "Install failed: $_" -ForegroundColor Red
    if ($Host.Name -eq 'ConsoleHost') { Read-Host 'Press Enter to close' | Out-Null }
    exit 1
}
