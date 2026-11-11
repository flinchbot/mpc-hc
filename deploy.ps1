<#
.SYNOPSIS
    Copies a flinchbot-MPC-HC build plus install.ps1 to the deploy share (Z:\Apps\mpc-hc).

.DESCRIPTION
    Mirrors the build output (everything MPC-HC needs to run; *.pdb/*.exp/*.lib/*.ilk
    skipped) to the share and puts install.ps1 next to it, so any machine can install
    straight from the share: run install.ps1 there and it installs from its own folder.
    Run after every build.

.EXAMPLE
    .\deploy.ps1                          # deploys bin\mpc-hc_x64
    .\deploy.ps1 -Lite                    # deploys "bin\mpc-hc_x64 Lite"
    .\deploy.ps1 -Destination \\nas\apps  # deploys somewhere else
#>
[CmdletBinding()]
param(
    [string]$Source,
    [string]$Destination = 'Z:\Apps\mpc-hc',
    [switch]$Lite
)

$ErrorActionPreference = 'Stop'

if (-not $Source) {
    $Source = if ($Lite) { Join-Path $PSScriptRoot 'bin\mpc-hc_x64 Lite' } else { Join-Path $PSScriptRoot 'bin\mpc-hc_x64' }
}
if (-not (Test-Path (Join-Path $Source 'mpc-hc64.exe'))) {
    throw "No mpc-hc64.exe in '$Source'. Build first (build.bat Release x64) or pass -Source."
}

$version = (Get-Item (Join-Path $Source 'mpc-hc64.exe')).VersionInfo.FileVersion
Write-Host "Deploying $version"
Write-Host "  from $Source"
Write-Host "  to   $Destination"

New-Item -ItemType Directory -Force -Path $Destination | Out-Null

# Mirror the payload; debug/link leftovers skipped. install.ps1 is excluded from the
# mirror so robocopy never deletes it from the destination root.
robocopy $Source $Destination /MIR /XF *.pdb *.exp *.lib *.ilk install.ps1 /R:2 /W:5 /NJH /NP /NDL /NFL | Out-Null
if ($LASTEXITCODE -ge 8) {
    throw "robocopy failed with exit code $LASTEXITCODE"
}

# /XF also exempts matching files already at the destination from /MIR deletion —
# clear out any debug leftovers that got there some other way.
Get-ChildItem -Path $Destination -Recurse -File -Include *.pdb, *.exp, *.lib, *.ilk | Remove-Item -Force

Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'install.ps1') -Destination (Join-Path $Destination 'install.ps1') -Force

Write-Host "Done. Install from the share with:" -ForegroundColor Green
Write-Host "  powershell -ExecutionPolicy Bypass -File $Destination\install.ps1"
exit 0
