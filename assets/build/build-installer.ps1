<#
    Gera ACNL-Setup-2.0.exe com o Inno Setup 6.

    Antes de rodar:
      1. build\build-launcher.ps1  (gera ACNL-Launcher.exe e ACNL-Bootstrap.exe)
      2. coloque 3dsrecomp.exe em installer\

    Saida: installer\output\ACNL-Setup-2.0.exe
#>
param(
    [string]$Iscc
)

$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent $PSScriptRoot
$iss  = Join-Path $repo 'installer\installer.iss'

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

if (-not $Iscc) {
    $candidatos = @(
        (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe'),
        (Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe')
    )
    $Iscc = $candidatos | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
}
if (-not $Iscc -or -not (Test-Path $Iscc)) {
    throw 'ISCC.exe nao encontrado. Instale o Inno Setup 6 ou passe -Iscc "C:\caminho\ISCC.exe".'
}

& $Iscc $iss
if ($LASTEXITCODE -ne 0) { throw "Inno Setup falhou (codigo $LASTEXITCODE)." }

Write-Output '--- gerado ---'
Get-Item (Join-Path $repo 'installer\output\ACNL-Setup-2.0.exe') | Select-Object FullName, Length, LastWriteTime | Format-Table -AutoSize
