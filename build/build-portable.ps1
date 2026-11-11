<#
    Monta a versao portatil (sem instalador) e gera o ZIP.

    Antes de rodar:
      1. build\build-launcher.ps1
      2. coloque 3dsrecomp.exe em installer\

    Saida:
      dist\ACNL-Portable-2.0\        (pasta pronta para usar)
      dist\ACNL-Portable-2.0.zip
#>
param(
    [string]$OutputDir
)

$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent $PSScriptRoot
if (-not $OutputDir) { $OutputDir = Join-Path $repo 'dist' }

$staging = Join-Path $OutputDir 'ACNL-Portable-2.0'
$zip     = Join-Path $OutputDir 'ACNL-Portable-2.0.zip'

$obrigatorios = @(
    (Join-Path $repo 'installer\ACNL-Launcher.exe'),
    (Join-Path $repo 'installer\ACNL-Bootstrap.exe'),
    (Join-Path $repo 'installer\3dsrecomp.exe'),
    (Join-Path $repo 'installer\leaf.ico')
)
foreach ($f in $obrigatorios) {
    if (-not (Test-Path $f)) {
        throw "Arquivo nao encontrado: $f`nRode build\build-launcher.ps1 e coloque 3dsrecomp.exe em installer\."
    }
}

if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
New-Item -ItemType Directory -Path $staging -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $staging 'game-data') | Out-Null
New-Item -ItemType Directory -Path (Join-Path $staging 'output') | Out-Null

Copy-Item (Join-Path $repo 'installer\ACNL-Launcher.exe')  $staging
Copy-Item (Join-Path $repo 'installer\ACNL-Bootstrap.exe') $staging
Copy-Item (Join-Path $repo 'installer\3dsrecomp.exe')      $staging
Copy-Item (Join-Path $repo 'installer\leaf.ico')           $staging
Copy-Item (Join-Path $repo 'launcher\launcher_config.json') $staging
Copy-Item (Join-Path $repo 'portable\INICIAR.cmd')              $staging
Copy-Item (Join-Path $repo 'portable\ATUALIZAR-DEPENDENCIAS.cmd') $staging
Copy-Item (Join-Path $repo 'docs\LEIA-ME.txt')              $staging
Copy-Item (Join-Path $repo 'README.md')                     $staging
Copy-Item (Join-Path $repo 'THIRD-PARTY-NOTICES.txt')       $staging

if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path $staging -DestinationPath $zip -CompressionLevel Optimal

Write-Output '--- gerados ---'
Get-Item $staging, $zip | Select-Object FullName, Length, LastWriteTime | Format-Table -AutoSize
