# ACNL-Recomp Bootstrap
# Baixa o Zakuro (runtime) e o w64devkit/GCC (compilador C portatil),
# configura a pasta do projeto e abre o launcher.
# Nao baixa nem inclui ROM ou assets do jogo.

param(
    [switch]$Auto,
    [switch]$NoLaunch,
    [switch]$ExitAfter,
    [switch]$ForceCompiler
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Pasta onde o bootstrap esta instalado (a mesma do launcher).
$ScriptDir = $PSScriptRoot
if (-not $ScriptDir -or -not (Test-Path $ScriptDir)) {
    try { $ScriptDir = Split-Path -Parent ([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName) } catch {}
}
if (-not $ScriptDir -or -not (Test-Path $ScriptDir)) { $ScriptDir = (Get-Location).Path }

$RootPath    = $ScriptDir
$ZakuroDir   = Join-Path $RootPath 'zakuro'
$ZakuroExe   = Join-Path $ZakuroDir 'zakuro.exe'
$ToolsDir    = Join-Path $RootPath 'tools'
$W64Dir      = Join-Path $ToolsDir 'w64devkit'
$GccExe      = Join-Path $W64Dir 'bin\gcc.exe'
$RecompExe   = Join-Path $RootPath '3dsrecomp.exe'
$LauncherExe = Join-Path $RootPath 'ACNL-Launcher.exe'
$ConfigFile  = Join-Path $RootPath 'launcher_config.json'
$VersionFile = Join-Path $RootPath 'dependencies.txt'
$TempDir     = Join-Path $env:TEMP ('acnl-bootstrap-' + [guid]::NewGuid().ToString('N'))

$ZakuroFallback       = 'https://github.com/fearkov/zakuro/releases/download/v0.2.32/zakuro-windows-x86_64.zip'
$ZakuroFallbackSha256 = '255F23D05EDA29F07DE0E7B5B67FE24BE9674C1BFC2F293B0C6D871B28CA1CCD'
$W64Fallback          = 'https://github.com/skeeto/w64devkit/releases/download/v2.11.0/w64devkit-x64-2.11.0.7z.exe'
$W64FallbackSha256    = '54C2BB9962E8A30C8270E34C5EFC3D5FEE579F53087FA7D435B95FBBA2AF7B2B'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Net.Http
Add-Type -AssemblyName System.IO.Compression.FileSystem

# ------------------------------------------------------------------------------
# Interface
# ------------------------------------------------------------------------------
$form = New-Object System.Windows.Forms.Form
$form.Text = 'ACNL-Recomp - Dependencias'
$form.ClientSize = New-Object System.Drawing.Size(680, 438)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox = $false
$form.BackColor = [System.Drawing.Color]::FromArgb(11, 15, 20)
$form.ForeColor = [System.Drawing.Color]::White
$form.Font = New-Object System.Drawing.Font -ArgumentList @('Segoe UI', 9)

$icoPath = Join-Path $RootPath 'leaf.ico'
if (Test-Path $icoPath) {
    try { $form.Icon = New-Object System.Drawing.Icon -ArgumentList $icoPath } catch {}
}

$title = New-Object System.Windows.Forms.Label
$title.Text = 'ACNL-Recomp'
$title.Font = New-Object System.Drawing.Font -ArgumentList @('Segoe UI', 18, [System.Drawing.FontStyle]::Bold)
$title.ForeColor = [System.Drawing.Color]::FromArgb(0, 184, 148)
$title.Location = New-Object System.Drawing.Point -ArgumentList 22, 16
$title.Size = New-Object System.Drawing.Size -ArgumentList 620, 34
$form.Controls.Add($title)

$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = 'Instalador de dependencias'
$subtitle.Font = New-Object System.Drawing.Font -ArgumentList @('Segoe UI', 10)
$subtitle.ForeColor = [System.Drawing.Color]::FromArgb(160, 168, 183)
$subtitle.Location = New-Object System.Drawing.Point -ArgumentList 24, 50
$subtitle.Size = New-Object System.Drawing.Size -ArgumentList 620, 20
$form.Controls.Add($subtitle)

$status = New-Object System.Windows.Forms.Label
$status.Text = 'Verificando...'
$status.Font = New-Object System.Drawing.Font -ArgumentList @('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
$status.ForeColor = [System.Drawing.Color]::White
$status.Location = New-Object System.Drawing.Point -ArgumentList 24, 82
$status.Size = New-Object System.Drawing.Size -ArgumentList 620, 22
$form.Controls.Add($status)

$progress = New-Object System.Windows.Forms.ProgressBar
$progress.Location = New-Object System.Drawing.Point -ArgumentList 24, 110
$progress.Size = New-Object System.Drawing.Size -ArgumentList 620, 18
$progress.Style = 'Continuous'
$form.Controls.Add($progress)

$log = New-Object System.Windows.Forms.TextBox
$log.Location = New-Object System.Drawing.Point -ArgumentList 24, 142
$log.Size = New-Object System.Drawing.Size -ArgumentList 620, 210
$log.Multiline = $true
$log.ReadOnly = $true
$log.ScrollBars = 'Vertical'
$log.BackColor = [System.Drawing.Color]::FromArgb(18, 23, 30)
$log.ForeColor = [System.Drawing.Color]::FromArgb(199, 206, 218)
$log.BorderStyle = 'FixedSingle'
$log.Font = New-Object System.Drawing.Font -ArgumentList @('Consolas', 8.5)
$form.Controls.Add($log)

$btnInstall = New-Object System.Windows.Forms.Button
$btnInstall.Text = 'Instalar dependencias'
$btnInstall.Location = New-Object System.Drawing.Point -ArgumentList 24, 372
$btnInstall.Size = New-Object System.Drawing.Size -ArgumentList 200, 40
$btnInstall.BackColor = [System.Drawing.Color]::FromArgb(0, 184, 148)
$btnInstall.ForeColor = [System.Drawing.Color]::FromArgb(11, 20, 16)
$btnInstall.FlatStyle = 'Flat'
$btnInstall.FlatAppearance.BorderSize = 0
$btnInstall.Font = New-Object System.Drawing.Font -ArgumentList @('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($btnInstall)

$btnOpen = New-Object System.Windows.Forms.Button
$btnOpen.Text = 'Abrir launcher'
$btnOpen.Location = New-Object System.Drawing.Point -ArgumentList 234, 372
$btnOpen.Size = New-Object System.Drawing.Size -ArgumentList 150, 40
$btnOpen.BackColor = [System.Drawing.Color]::FromArgb(44, 52, 64)
$btnOpen.ForeColor = [System.Drawing.Color]::White
$btnOpen.FlatStyle = 'Flat'
$btnOpen.FlatAppearance.BorderSize = 0
$btnOpen.Enabled = $false
$form.Controls.Add($btnOpen)

$btnClose = New-Object System.Windows.Forms.Button
$btnClose.Text = 'Fechar'
$btnClose.Location = New-Object System.Drawing.Point -ArgumentList 544, 372
$btnClose.Size = New-Object System.Drawing.Size -ArgumentList 100, 40
$btnClose.BackColor = [System.Drawing.Color]::FromArgb(44, 52, 64)
$btnClose.ForeColor = [System.Drawing.Color]::White
$btnClose.FlatStyle = 'Flat'
$btnClose.FlatAppearance.BorderSize = 0
$form.Controls.Add($btnClose)

function Write-Log {
    param([string]$Message)
    $line = '[' + (Get-Date -Format 'HH:mm:ss') + '] ' + $Message + [Environment]::NewLine
    $log.AppendText($line)
    $log.SelectionStart = $log.TextLength
    $log.ScrollToCaret()
    [System.Windows.Forms.Application]::DoEvents()
}

function Set-Status {
    param([string]$Message)
    $status.Text = $Message
    [System.Windows.Forms.Application]::DoEvents()
}

function Test-SystemCompiler {
    if ($env:CC) { return $true }
    foreach ($name in @('gcc', 'clang', 'cc')) {
        if (Get-Command $name -ErrorAction SilentlyContinue) { return $true }
    }
    foreach ($path in @(
        $GccExe,
        'C:\msys64\mingw64\bin\gcc.exe',
        'C:\mingw64\bin\gcc.exe',
        (Join-Path $RootPath 'mingw64\bin\gcc.exe')
    )) {
        if (Test-Path $path) { return $true }
    }
    return $false
}

function Get-ZakuroInfo {
    try {
        $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/fearkov/zakuro/releases/latest' `
            -Headers @{ 'User-Agent' = 'ACNL-Bootstrap/2.0' } -TimeoutSec 30
        $asset = $release.assets | Where-Object { $_.name -eq 'zakuro-windows-x86_64.zip' } | Select-Object -First 1
        if ($asset) {
            $sha = ''
            if ($asset.digest -and $asset.digest -match '^sha256:([0-9a-fA-F]{64})$') { $sha = $Matches[1] }
            return @{ Url = $asset.browser_download_url; Version = $release.tag_name; Sha256 = $sha }
        }
    } catch {
        Write-Log ('GitHub indisponivel: ' + $_.Exception.Message)
    }
    return @{ Url = $ZakuroFallback; Version = 'v0.2.32'; Sha256 = $ZakuroFallbackSha256 }
}

function Get-W64Info {
    try {
        $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/skeeto/w64devkit/releases/latest' `
            -Headers @{ 'User-Agent' = 'ACNL-Bootstrap/2.0' } -TimeoutSec 30
        $asset = $release.assets | Where-Object { $_.name -match '^w64devkit-x64-.*\.7z\.exe$' } | Select-Object -First 1
        if ($asset) {
            $sha = ''
            if ($asset.digest -and $asset.digest -match '^sha256:([0-9a-fA-F]{64})$') { $sha = $Matches[1] }
            return @{ Url = $asset.browser_download_url; Version = $release.tag_name; Sha256 = $sha }
        }
    } catch {
        Write-Log ('GitHub (w64devkit) indisponivel: ' + $_.Exception.Message)
    }
    return @{ Url = $W64Fallback; Version = 'v2.11.0'; Sha256 = $W64FallbackSha256 }
}

function Get-FileSha256 {
    param([string]$Path)
    return (Get-FileHash -Path $Path -Algorithm SHA256).Hash
}

function Download-File {
    param(
        [string]$Url,
        [string]$Destination,
        [string]$Label,
        [string]$Sha256 = '',
        [int]$Attempts = 3
    )

    for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
        try {
            if (Test-Path $Destination) { Remove-Item $Destination -Force -ErrorAction SilentlyContinue }

            $suffix = ''
            if ($attempt -gt 1) { $suffix = ' (tentativa ' + $attempt + ' de ' + $Attempts + ')' }
            Write-Log ('Baixando ' + $Label + $suffix + '...')
            Set-Status ('Baixando ' + $Label + '...')
            $progress.Value = 0
            $progress.Style = 'Continuous'

            $client = New-Object System.Net.Http.HttpClient
            $client.Timeout = [TimeSpan]::FromMinutes(30)
            $client.DefaultRequestHeaders.UserAgent.ParseAdd('ACNL-Bootstrap/2.0')

            $response = $null
            $stream = $null
            $file = $null
            try {
                $response = $client.GetAsync($Url, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).Result
                $response.EnsureSuccessStatusCode() | Out-Null

                $total = [int64]0
                if ($response.Content.Headers.ContentLength) { $total = [int64]$response.Content.Headers.ContentLength }
                if ($total -le 0) { $progress.Style = 'Marquee' }

                $stream = $response.Content.ReadAsStreamAsync().Result
                $file = [System.IO.File]::Create($Destination)
                $buffer = New-Object byte[] 131072
                $done = [int64]0
                $started = [DateTime]::UtcNow
                $lastUpdate = $started

                while (($read = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                    $file.Write($buffer, 0, $read)
                    $done += $read
                    if ($total -gt 0) {
                        $pct = [int][Math]::Min(100, (100.0 * $done / $total))
                        if ($pct -gt $progress.Value) { $progress.Value = $pct }
                    }

                    $now = [DateTime]::UtcNow
                    if (($now - $lastUpdate).TotalMilliseconds -ge 700) {
                        $lastUpdate = $now
                        $elapsed = ($now - $started).TotalSeconds
                        $speed = if ($elapsed -gt 0) { $done / $elapsed } else { 0 }
                        $speedMb = [math]::Round($speed / 1MB, 1)
                        if ($total -gt 0) {
                            $eta = if ($speed -gt 0) { [int](($total - $done) / $speed) } else { 0 }
                            Set-Status ('Baixando ' + $Label + ': ' + [math]::Round($done / 1MB, 1) + ' / ' + [math]::Round($total / 1MB, 1) + ' MB (' + $speedMb + ' MB/s, ~' + $eta + 's)')
                        } else {
                            Set-Status ('Baixando ' + $Label + ': ' + [math]::Round($done / 1MB, 1) + ' MB (' + $speedMb + ' MB/s)')
                        }
                    }
                    [System.Windows.Forms.Application]::DoEvents()
                }
            } finally {
                if ($file) { $file.Close() }
                if ($stream) { $stream.Close() }
                if ($response) { $response.Dispose() }
                $client.Dispose()
                $progress.Style = 'Continuous'
            }

            if ($Sha256) {
                Set-Status ('Verificando ' + $Label + '...')
                Write-Log ('Verificando SHA256 de ' + $Label + '...')
                $actual = Get-FileSha256 $Destination
                if ($actual -ne $Sha256) {
                    throw ('Hash SHA256 nao confere para ' + $Label + '. Esperado ' + $Sha256 + ', obtido ' + $actual + '.')
                }
                Write-Log 'SHA256 OK.'
            } else {
                Write-Log ('Aviso: ' + $Label + ' sem hash conhecido para verificar.')
            }

            $sizeMb = [math]::Round((Get-Item $Destination).Length / 1MB, 1)
            Write-Log ('OK: ' + $Label + ' (' + $sizeMb + ' MB)')
            Set-Status ('Baixado: ' + $Label)
            return
        } catch {
            if (Test-Path $Destination) { Remove-Item $Destination -Force -ErrorAction SilentlyContinue }
            $message = $_.Exception.Message
            if ($attempt -lt $Attempts) {
                Write-Log ('Falha ao baixar ' + $Label + ': ' + $message + ' Tentando de novo...')
                [System.Windows.Forms.Application]::DoEvents()
                Start-Sleep -Seconds (2 * $attempt)
            } else {
                throw ('Nao foi possivel baixar ' + $Label + ' depois de ' + $Attempts + ' tentativas: ' + $message)
            }
        }
    }
}

function Expand-Zip {
    param([string]$Zip, [string]$Destination)
    if (Test-Path $Destination) { Remove-Item $Destination -Recurse -Force }
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    [System.IO.Compression.ZipFile]::ExtractToDirectory($Zip, $Destination)
}

function Install-Zakuro {
    $info = Get-ZakuroInfo
    $zip = Join-Path $TempDir 'zakuro.zip'
    Download-File $info.Url $zip 'Zakuro' $info.Sha256

    Set-Status 'Extraindo Zakuro...'
    Expand-Zip $zip $ZakuroDir

    if (-not (Test-Path $ZakuroExe)) {
        $found = Get-ChildItem $ZakuroDir -Recurse -Filter 'zakuro.exe' -File | Select-Object -First 1
        if ($found) {
            $moveDir = Join-Path $TempDir 'zakuro-flat'
            Move-Item $found.DirectoryName $moveDir
            Remove-Item $ZakuroDir -Recurse -Force
            Move-Item $moveDir $ZakuroDir
        }
    }
    if (-not (Test-Path $ZakuroExe)) { throw 'zakuro.exe nao encontrado depois de extrair.' }

    Write-Log ('Zakuro instalado: ' + $info.Version)
    return $info.Version
}

function Install-Compiler {
    $info = Get-W64Info
    $sfx = Join-Path $TempDir 'w64devkit.7z.exe'
    Download-File $info.Url $sfx 'w64devkit (GCC)' $info.Sha256

    Set-Status 'Extraindo w64devkit...'
    if (-not (Test-Path $ToolsDir)) { New-Item -ItemType Directory -Path $ToolsDir -Force | Out-Null }
    if (Test-Path $W64Dir) { Remove-Item $W64Dir -Recurse -Force }

    $proc = Start-Process -FilePath $sfx -ArgumentList @('-y', ('-o"' + $ToolsDir + '"')) -Wait -PassThru -NoNewWindow
    if ($proc.ExitCode -ne 0) { throw ('w64devkit falhou ao extrair (codigo ' + $proc.ExitCode + ').') }

    if (-not (Test-Path $GccExe)) {
        $found = Get-ChildItem $ToolsDir -Recurse -Filter 'gcc.exe' -File | Select-Object -First 1
        if ($found) {
            $rootDir = Split-Path -Parent $found.DirectoryName
            if ($rootDir -ne $W64Dir) {
                if (Test-Path $W64Dir) { Remove-Item $W64Dir -Recurse -Force }
                Move-Item $rootDir $W64Dir
            }
        }
    }
    if (-not (Test-Path $GccExe)) { throw 'gcc.exe nao encontrado em tools\w64devkit\bin.' }

    Write-Log ('w64devkit instalado: ' + $info.Version)
    return $info.Version
}

$DefaultConfig = @'
{
    "RomPath": "",
    "ProjectRoot": "",
    "Resolution": 3,
    "Scale": 3,
    "Layout": "large_top",
    "Renderer": "vulkan",
    "Rasterizer": "hardware",
    "Filter": "smooth",
    "IntegerScale": false,
    "TopShape": "console",
    "Orientation": "north",
    "Stereo": "off",
    "Depth3D": 50,
    "SwapEyes": false,
    "TexturePacks": true,
    "FrameInterpolation": false,
    "ShowFps": false,
    "Language": "english",
    "Volume": 100,
    "Mute": false,
    "New3DS": false,
    "Keys": {
        "a": "KeyX", "b": "KeyZ", "x": "KeyS", "y": "KeyA",
        "l": "KeyQ", "r": "KeyW", "start": "Enter", "select": "Backspace",
        "up": "ArrowUp", "down": "ArrowDown", "left": "ArrowLeft", "right": "ArrowRight",
        "circle_up": "KeyI", "circle_down": "KeyK", "circle_left": "KeyJ", "circle_right": "KeyL",
        "zl": "Digit1", "zr": "Digit2",
        "c_up": "KeyT", "c_down": "KeyG", "c_left": "KeyF", "c_right": "KeyH"
    },
    "Pad": {
        "a": "East", "b": "South", "x": "North", "y": "West",
        "l": "LeftTrigger", "r": "RightTrigger", "start": "Start", "select": "Select",
        "up": "DPadUp", "down": "DPadDown", "left": "DPadLeft", "right": "DPadRight",
        "zl": "LeftTrigger2", "zr": "RightTrigger2"
    },
    "Stats": {
        "TotalSeconds": 0.0,
        "Sessions": 0,
        "LastPlayed": "",
        "LastSessionSeconds": 0.0,
        "History": []
    }
}
'@

function Save-LauncherConfig {
    if (-not (Test-Path $ConfigFile)) {
        [System.IO.File]::WriteAllText($ConfigFile, $DefaultConfig, [System.Text.UTF8Encoding]::new($false))
    }

    $cfg = $null
    try { $cfg = Get-Content -Raw -Encoding UTF8 $ConfigFile | ConvertFrom-Json } catch {}
    if (-not $cfg) {
        [System.IO.File]::WriteAllText($ConfigFile, $DefaultConfig, [System.Text.UTF8Encoding]::new($false))
        $cfg = Get-Content -Raw -Encoding UTF8 $ConfigFile | ConvertFrom-Json
    }

    if ($cfg.PSObject.Properties.Name -contains 'ProjectRoot') {
        $cfg.ProjectRoot = $RootPath
    } else {
        $cfg | Add-Member -NotePropertyName ProjectRoot -NotePropertyValue $RootPath
    }

    $json = $cfg | ConvertTo-Json -Depth 8
    [System.IO.File]::WriteAllText($ConfigFile, $json, [System.Text.UTF8Encoding]::new($false))
    Write-Log ('Configuracao salva em ' + $ConfigFile)
}

function Update-State {
    $missing = @()
    if (-not (Test-Path $ZakuroExe)) { $missing += 'Zakuro' }
    if (-not (Test-Path $GccExe) -and -not (Test-SystemCompiler)) { $missing += 'GCC (w64devkit)' }
    if (-not (Test-Path $RecompExe)) { $missing += '3dsrecomp' }

    if ($missing.Count -eq 0) {
        $status.Text = 'Tudo pronto!'
        $status.ForeColor = [System.Drawing.Color]::FromArgb(0, 184, 148)
        $btnInstall.Text = 'Verificar / atualizar'
        $btnOpen.Enabled = $true
    } else {
        $status.Text = 'Faltam: ' + ($missing -join ', ')
        $status.ForeColor = [System.Drawing.Color]::FromArgb(240, 160, 75)
        $btnInstall.Text = 'Instalar dependencias'
        $btnOpen.Enabled = $false
    }
    [System.Windows.Forms.Application]::DoEvents()
}

function Start-Launcher {
    if (-not (Test-Path $LauncherExe)) {
        [System.Windows.Forms.MessageBox]::Show('Launcher nao encontrado: ' + $LauncherExe, 'ACNL-Recomp', 'OK', 'Error') | Out-Null
        return
    }
    Start-Process -FilePath $LauncherExe -WorkingDirectory $RootPath
    $form.Close()
}

$script:Busy = $false
$script:InstallOk = $false

$btnInstall.Add_Click({
    if ($script:Busy) { return }

    $running = @(Get-Process -Name 'zakuro', 'ACNL-Launcher' -ErrorAction SilentlyContinue)
    if ($running.Count -gt 0) {
        [System.Windows.Forms.MessageBox]::Show(
            'Feche o launcher e o jogo antes de atualizar as dependencias.',
            'ACNL-Recomp', 'OK', 'Warning') | Out-Null
        return
    }

    $script:Busy = $true
    $script:InstallOk = $false
    $btnInstall.Enabled = $false
    $btnOpen.Enabled = $false
    $btnClose.Enabled = $false
    $progress.Value = 0

    try {
        if (-not (Test-Path $TempDir)) { New-Item -ItemType Directory -Path $TempDir -Force | Out-Null }
        Write-Log 'Iniciando instalacao das dependencias.'
        Write-Log ('Pasta: ' + $RootPath)

        $zakuroVersion = Install-Zakuro

        if (Test-Path $GccExe) {
            $compilerVersion = 'ja instalado'
            Write-Log 'w64devkit/GCC ja instalado, mantendo.'
        } elseif ((Test-SystemCompiler) -and -not $ForceCompiler) {
            $compilerVersion = 'compilador do sistema'
            Write-Log 'Compilador C do sistema encontrado, w64devkit nao sera baixado.'
        } else {
            $compilerVersion = Install-Compiler
        }

        Save-LauncherConfig

        $text = @(
            'ACNL-Recomp - dependencias'
            ('Instalado em: ' + $RootPath)
            ('Zakuro: ' + $zakuroVersion)
            ('GCC (w64devkit): ' + $compilerVersion)
            ('Atualizado em: ' + (Get-Date).ToString('s'))
        ) -join [Environment]::NewLine
        [System.IO.File]::WriteAllText($VersionFile, $text, [System.Text.UTF8Encoding]::new($false))

        Write-Log 'Dependencias instaladas com sucesso.'
        Set-Status 'Tudo pronto!'
        $progress.Value = 100
        $script:InstallOk = $true
    } catch {
        Write-Log ('ERRO: ' + $_.Exception.Message)
        Set-Status 'Falha na instalacao.'
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'ACNL-Recomp', 'OK', 'Error') | Out-Null
    } finally {
        $script:Busy = $false
        $btnInstall.Enabled = $true
        $btnClose.Enabled = $true
        Update-State
        if (Test-Path $TempDir) { Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue }

        if ($script:InstallOk) {
            if (-not $NoLaunch) {
                Start-Sleep -Milliseconds 700
                Start-Launcher
            } elseif ($ExitAfter) {
                $form.Close()
            }
        }
    }
})

$btnOpen.Add_Click({ Start-Launcher })
$btnClose.Add_Click({ $form.Close() })

$autoTimer = New-Object System.Windows.Forms.Timer
$autoTimer.Interval = 700
$autoTimer.Add_Tick({
    $autoTimer.Stop()
    if ($btnOpen.Enabled) {
        # Dependencias ja presentes: nao baixa de novo, apenas abre o launcher.
        if (-not $NoLaunch) { Start-Launcher }
        elseif ($ExitAfter) { $form.Close() }
    } elseif ($btnInstall.Enabled) {
        $btnInstall.PerformClick()
    }
})

$form.Add_Shown({
    Write-Log ('Pasta: ' + $RootPath)
    Update-State
    if ($Auto) { $autoTimer.Start() }
})

[void]$form.ShowDialog()
