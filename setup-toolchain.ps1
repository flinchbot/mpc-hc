<#
.SYNOPSIS
    Installs everything build.bat needs on a fresh Windows PC (see docs\Compilation.md).

.DESCRIPTION
    - Visual Studio 2026 Community: C++ desktop workload, MSVC v143 + ATL/MFC for v143,
      latest MFC (vswhere detection needs it), Windows 11 SDK 26100, UCRT SDK, clang-cl
      (optional, makes LAV's ffmpeg ~10% faster)
    - NASM 2.16.03 -> C:\Windows\nasm.exe (the version docs\Compilation.md pins)
    - Python 3.13 (machine-wide) + polib, for the translation DLLs
    - git core.longpaths
    MSYS2 / mingw / yasm are NOT needed: upstream builds LAV Filters with MSBuild now.
    Re-running is safe; already-installed pieces are skipped.
#>
$ErrorActionPreference = 'Stop'

$principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -NoExit -File `"$PSCommandPath`""
    exit
}

function Step($msg) { Write-Host "`n== $msg" -ForegroundColor Cyan }

Step 'Visual Studio 2026 Community (C++ / v143 / MFC / Win11 SDK) - this takes a while'
$components = @(
    'Microsoft.VisualStudio.Workload.NativeDesktop'
    'Microsoft.VisualStudio.Component.VC.Tools.x86.x64'
    'Microsoft.VisualStudio.Component.VC.ATLMFC'
    'Microsoft.VisualStudio.Component.VC.14.44.17.14.x86.x64'
    'Microsoft.VisualStudio.Component.VC.14.44.17.14.ATL'
    'Microsoft.VisualStudio.Component.VC.14.44.17.14.MFC'
    'Microsoft.VisualStudio.Component.Windows11SDK.26100'
    'Microsoft.Component.VC.Runtime.UCRTSDK'
    'Microsoft.VisualStudio.Component.VC.Llvm.Clang'
    'Microsoft.VisualStudio.Component.VC.Llvm.ClangToolset'
)
$vsArgs = '--passive --wait --norestart ' + (($components | ForEach-Object { "--add $_" }) -join ' ')
$installer = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\setup.exe"
$vswhere   = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vsPath = if (Test-Path $vswhere) { & $vswhere -latest -products * -property installationPath } else { $null }
if ($vsPath) {
    # VS already there: just make sure the components are added.
    $p = Start-Process $installer -ArgumentList "modify --installPath `"$vsPath`" $vsArgs" -Wait -PassThru
} else {
    winget install --id Microsoft.VisualStudio.Community --source winget --exact `
        --accept-package-agreements --accept-source-agreements --override $vsArgs
}

Step 'NASM 2.16.03'
if (Get-Command nasm.exe -ErrorAction SilentlyContinue) {
    Write-Host "already on PATH: $((Get-Command nasm.exe).Source)"
} else {
    $zip = Join-Path $env:TEMP 'nasm-2.16.03-win64.zip'
    Invoke-WebRequest 'https://www.nasm.us/pub/nasm/releasebuilds/2.16.03/win64/nasm-2.16.03-win64.zip' -OutFile $zip
    $dir = Join-Path $env:TEMP 'nasm-2.16.03-extract'
    Expand-Archive $zip -DestinationPath $dir -Force
    Copy-Item (Get-ChildItem $dir -Recurse -Filter nasm.exe | Select-Object -First 1).FullName "$env:WINDIR\nasm.exe" -Force
    Write-Host "installed $env:WINDIR\nasm.exe"
}

Step 'Python 3.13 + polib'
$python = 'C:\Program Files\Python313\python.exe'
if (-not (Test-Path $python)) {
    winget install --id Python.Python.3.13 --source winget --exact --scope machine `
        --accept-package-agreements --accept-source-agreements
}
& $python -m pip install --upgrade --quiet polib
Write-Host "polib installed for $python"

Step 'git core.longpaths'
git config --global core.longpaths true

Step 'Check'
$vsPath = & $vswhere -latest -products * -requires Microsoft.Component.MSBuild Microsoft.VisualStudio.Component.VC.ATLMFC Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if ($vsPath) { Write-Host "Visual Studio : $vsPath" } else { Write-Host 'Visual Studio : NOT FOUND - open the Visual Studio Installer and check the C++ components' }
if (Test-Path "$env:WINDIR\nasm.exe") { Write-Host 'nasm          : ok' } else { Write-Host 'nasm          : missing' }
& $python -c 'import polib' 2>$null
if ($LASTEXITCODE -eq 0) { Write-Host 'python/polib  : ok' } else { Write-Host 'python/polib  : missing' }
Write-Host "`nDone. Open a NEW terminal, then: cd $PSScriptRoot; build.bat Release x64" -ForegroundColor Green
