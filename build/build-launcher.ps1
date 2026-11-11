<#
    Compila o launcher e o bootstrap com ps2exe.

    Saida (por padrao em installer\, ao lado do installer.iss):
      - ACNL-Launcher.exe
      - ACNL-Bootstrap.exe

    Requer o modulo ps2exe:
      Install-Module ps2exe -Scope CurrentUser
#>
param(
    [string]$OutputDir
)

$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent $PSScriptRoot
if (-not $OutputDir) { $OutputDir = Join-Path $repo 'installer' }

$launcher  = Join-Path $repo 'launcher\ACNL-Launcher.ps1'
$bootstrap = Join-Path $repo 'installer\ACNL-Bootstrap.ps1'
$icon      = Join-Path $repo 'installer\leaf.ico'

foreach ($p in @($launcher, $bootstrap, $icon)) {
    if (-not (Test-Path $p)) { throw "Arquivo nao encontrado: $p" }
}

Import-Module ps2exe -Force

# O ps2exe usa o Windows PowerShell, que precisa de UTF-8 com BOM para acentos
foreach ($p in @($launcher, $bootstrap)) {
    $text = [System.IO.File]::ReadAllText($p, [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText($p, $text, [System.Text.UTF8Encoding]::new($true))
}

New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

$launcherExe  = Join-Path $OutputDir 'ACNL-Launcher.exe'
$bootstrapExe = Join-Path $OutputDir 'ACNL-Bootstrap.exe'

foreach ($exe in @($launcherExe, $bootstrapExe)) {
    if (Test-Path $exe) { Remove-Item $exe -Force }
}

Invoke-PS2EXE `
    -inputFile  $launcher `
    -outputFile $launcherExe `
    -iconFile   $icon `
    -title      'Animal Crossing: New Leaf - PC Recompiled' `
    -description 'Launcher do projeto ACNL-Recomp' `
    -company    'ACNL-Recomp' `
    -product    'ACNL-Recomp Launcher' `
    -copyright  'Projeto ACNL-Recomp' `
    -version    '2.0.0.0' `
    -x64 -STA -noConsole -DPIAware -supportOS -noConfigFile

Invoke-PS2EXE `
    -inputFile  $bootstrap `
    -outputFile $bootstrapExe `
    -iconFile   $icon `
    -title      'ACNL-Recomp - Dependencias' `
    -description 'Instalador de dependencias do ACNL-Recomp' `
    -company    'ACNL-Recomp' `
    -product    'ACNL-Recomp' `
    -copyright  'Projeto ACNL-Recomp' `
    -version    '2.0.0.0' `
    -x64 -STA -noConsole -DPIAware -supportOS -noConfigFile

Write-Output '--- gerados ---'
Get-Item $launcherExe, $bootstrapExe | Select-Object Name, Length, LastWriteTime | Format-Table -AutoSize
