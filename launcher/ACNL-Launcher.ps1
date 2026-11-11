<#
================================================================================
  Animal Crossing: New Leaf - PC Recompiled Launcher  (v2.0)
  Launcher moderno para ACNL-Recomp: estatísticas, gráficos, controles e atalhos.
================================================================================
#>

Set-StrictMode -Off
$ErrorActionPreference = "Continue"

$LauncherVersion = "2.0"

# ------------------------------------------------------------------------------
# Win32: esconder o console do PowerShell quando a janela abrir
# ------------------------------------------------------------------------------
try {
    Add-Type -Name WinConsole -Namespace WinAPI -MemberDefinition '[DllImport("Kernel32.dll")] public static extern IntPtr GetConsoleWindow(); [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);' -ErrorAction SilentlyContinue
} catch {}

# ------------------------------------------------------------------------------
# Win32: titulo e icone da janela do Zakuro
# ------------------------------------------------------------------------------
try {
    Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class ACNLGameWindow {
    public delegate bool EnumProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr lParam);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr hWnd);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowTextLength(IntPtr hWnd);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern bool SetWindowText(IntPtr hWnd, string text);
    [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr LoadImage(IntPtr hinst, string name, uint type, int cx, int cy, uint load);
    [DllImport("user32.dll")] public static extern bool DestroyIcon(IntPtr hIcon);

    public static IntPtr FindByProcessId(uint pid) {
        IntPtr found = IntPtr.Zero;
        EnumWindows((h, l) => {
            uint p; GetWindowThreadProcessId(h, out p);
            if (p == pid && IsWindowVisible(h)) {
                int len = GetWindowTextLength(h);
                if (len > 0) { found = h; return false; }
            }
            return true;
        }, IntPtr.Zero);
        return found;
    }
}

// Reaplica o titulo no instante em que o Zakuro o reescreve (EVENT_OBJECT_NAMECHANGE)
public static class ACNLTitleGuard {
    private delegate void WinEventDelegate(IntPtr hook, uint evt, IntPtr hwnd, int idObject, int idChild, uint thread, uint time);
    [DllImport("user32.dll")] private static extern IntPtr SetWinEventHook(uint min, uint max, IntPtr hmod, WinEventDelegate cb, uint pid, uint tid, uint flags);
    [DllImport("user32.dll")] private static extern bool UnhookWinEvent(IntPtr hook);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern bool SetWindowText(IntPtr hwnd, string text);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern int GetWindowText(IntPtr hwnd, StringBuilder s, int n);

    private const uint EVENT_OBJECT_NAMECHANGE = 0x800C;
    private const uint WINEVENT_OUTOFCONTEXT = 0x0000;

    private static IntPtr _hook = IntPtr.Zero;
    private static WinEventDelegate _proc = null;
    private static IntPtr _target = IntPtr.Zero;
    private static string _title = null;
    private static bool _busy = false;

    public static bool Install(IntPtr hwnd, uint pid, string title) {
        Uninstall();
        if (hwnd == IntPtr.Zero || string.IsNullOrEmpty(title)) { return false; }
        _target = hwnd;
        _title = title;
        _proc = new WinEventDelegate(OnEvent);
        _hook = SetWinEventHook(EVENT_OBJECT_NAMECHANGE, EVENT_OBJECT_NAMECHANGE, IntPtr.Zero, _proc, pid, 0, WINEVENT_OUTOFCONTEXT);
        return _hook != IntPtr.Zero;
    }

    public static void Uninstall() {
        if (_hook != IntPtr.Zero) {
            try { UnhookWinEvent(_hook); } catch { }
            _hook = IntPtr.Zero;
        }
        _proc = null;
        _target = IntPtr.Zero;
        _title = null;
    }

    private static void OnEvent(IntPtr hook, uint evt, IntPtr hwnd, int idObject, int idChild, uint thread, uint time) {
        if (_busy || _title == null || hwnd != _target || idObject != 0) { return; }
        try {
            StringBuilder sb = new StringBuilder(256);
            GetWindowText(hwnd, sb, sb.Capacity);
            if (sb.ToString() == _title) { return; }
            _busy = true;
            SetWindowText(hwnd, _title);
        } catch {
        } finally {
            _busy = false;
        }
    }
}
'@ -ErrorAction SilentlyContinue
} catch {}

# ------------------------------------------------------------------------------
# Caminhos
# ------------------------------------------------------------------------------
$ScriptDir = $PSScriptRoot
if (-not $ScriptDir -or -not (Test-Path $ScriptDir)) {
    if ($MyInvocation.MyCommand.Path) {
        $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    } else {
        $ScriptDir = (Get-Location).Path
    }
}

$ConfigFile = Join-Path $ScriptDir "launcher_config.json"

function Find-ProjectRoot {
    param([string]$Start)
    $dir = $Start
    for ($i = 0; $i -lt 8 -and $dir; $i++) {
        if (Test-Path (Join-Path $dir "zakuro\zakuro.exe")) { return $dir }
        if (Test-Path (Join-Path $dir "zakuro.exe")) { return $dir }
        $parent = Split-Path -Parent $dir
        if (-not $parent -or $parent -eq $dir) { break }
        $dir = $parent
    }
    return $null
}

# A pasta do projeto fica salva no launcher_config.json (na pasta do .exe),
# assim o launcher pode ficar em qualquer lugar e apontar para o ACNL-Recomp.
$SavedProjectRoot = ""
if (Test-Path $ConfigFile) {
    try {
        $pre = Get-Content -Raw -Encoding UTF8 $ConfigFile | ConvertFrom-Json
        if ($pre.ProjectRoot) { $SavedProjectRoot = [string]$pre.ProjectRoot }
    } catch {}
}

$RootPath = $null
if ($SavedProjectRoot -and (Test-Path (Join-Path $SavedProjectRoot "zakuro\zakuro.exe"))) {
    $RootPath = $SavedProjectRoot
}
if (-not $RootPath) { $RootPath = Find-ProjectRoot $ScriptDir }
if (-not $RootPath) { $RootPath = Find-ProjectRoot (Get-Location).Path }
if (-not $RootPath) {
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
        $dlgRoot = New-Object System.Windows.Forms.FolderBrowserDialog
        $dlgRoot.Description = "Selecione a pasta do ACNL-Recomp (onde fica zakuro\zakuro.exe)"
        $dlgRoot.ShowNewFolderButton = $false
        if ($dlgRoot.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $candidate = $dlgRoot.SelectedPath
            if (Test-Path (Join-Path $candidate "zakuro\zakuro.exe")) { $RootPath = $candidate }
        }
    } catch {}
}
if (-not $RootPath) {
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
        [System.Windows.Forms.MessageBox]::Show(
            "Pasta do ACNL-Recomp nao encontrada.`n`nColoque o ACNL-Launcher.exe dentro da pasta do projeto (junto de zakuro\zakuro.exe) ou selecione a pasta ao abrir.",
            "ACNL-Recomp", "OK", "Warning") | Out-Null
    } catch {}
    exit 1
}

$ZakuroExe = Join-Path $RootPath "zakuro\zakuro.exe"

$RecompCandidates = @(
    (Join-Path $RootPath "3dsrecomp\target\release\3dsrecomp.exe"),
    (Join-Path $RootPath "3dsrecomp\target\debug\3dsrecomp.exe"),
    (Join-Path $RootPath "3dsrecomp.exe")
)
$RecompExe = $RecompCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $RecompExe) { $RecompExe = $RecompCandidates[0] }

$OutputDir    = Join-Path $RootPath "output"
$GameDataDir  = Join-Path $RootPath "game-data"
$AppDataZakuro = Join-Path $env:APPDATA "zakuro"
$SettingsToml  = Join-Path $AppDataZakuro "settings.toml"
$LeafPng       = Join-Path $ScriptDir "leaf.png"
$LeafIco       = Join-Path $ScriptDir "leaf.ico"
$TitleId       = "0004000000086300"
$DllPath       = Join-Path $OutputDir "$TitleId.dll"
$HintsPath     = Join-Path $OutputDir "$TitleId.hints"

# Compilador C portatil (w64devkit/GCC) instalado pelo setup. Fica na frente
# do PATH para que a recompilacao use sempre um GCC conhecido, sem depender de
# MSYS2/MinGW instalado na maquina.
$W64Bin = Join-Path $RootPath "tools\w64devkit\bin"
if (Test-Path (Join-Path $W64Bin "gcc.exe")) {
    if (-not (($env:PATH -split ';') -contains $W64Bin)) {
        $env:PATH = "$W64Bin;$env:PATH"
    }
} else {
    # MinGW no PATH, se existir
    foreach ($mingw in @("C:\msys64\mingw64\bin", "C:\mingw64\bin", (Join-Path $RootPath "mingw64\bin"))) {
        if (Test-Path $mingw) {
            $env:PATH = "$mingw;$env:PATH"
            break
        }
    }
}

# ------------------------------------------------------------------------------
# Assemblies
# ------------------------------------------------------------------------------
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ------------------------------------------------------------------------------
# Ícone de folhinha (PNG + ICO)
# ------------------------------------------------------------------------------
function New-LeafIcon {
    param([string]$PngPath, [string]$IcoPath)

    try {
        $size = 256
        $bmp = [System.Drawing.Bitmap]::new($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $g.Clear([System.Drawing.Color]::Transparent)

        $leaf = [System.Drawing.Drawing2D.GraphicsPath]::new()
        $leaf.StartFigure()
        $leaf.AddBezier(128, 224, 60, 170, 48, 80, 128, 24)
        $leaf.AddBezier(128, 24, 208, 80, 196, 170, 128, 224)
        $leaf.CloseFigure()

        $rect = [System.Drawing.Rectangle]::new(0, 0, 256, 256)
        $green1 = [System.Drawing.Color]::FromArgb(255, 123, 228, 149)
        $green2 = [System.Drawing.Color]::FromArgb(255, 0, 166, 132)
        $brush = [System.Drawing.Drawing2D.LinearGradientBrush]::new($rect, $green1, $green2, 55.0)
        $g.FillPath($brush, $leaf)
        $brush.Dispose()

        $outline = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(255, 7, 74, 58), 5)
        $g.DrawPath($outline, $leaf)
        $outline.Dispose()

        $vein = [System.Drawing.Drawing2D.GraphicsPath]::new()
        $vein.AddBezier(128, 220, 120, 170, 120, 90, 128, 36)
        $penVein = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(190, 7, 74, 58), 5)
        $penVein.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $penVein.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
        $g.DrawPath($penVein, $vein)
        $penVein.Dispose()
        $vein.Dispose()

        $penSide = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(150, 7, 74, 58), 3)
        $penSide.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $penSide.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
        $sideVeins = @(
            @(@(126, 190), @(82, 168)),  @(@(130, 190), @(174, 168)),
            @(@(124, 152), @(66, 124)),  @(@(132, 152), @(190, 124)),
            @(@(124, 112), @(74, 84)),   @(@(132, 112), @(182, 84))
        )
        foreach ($pair in $sideVeins) {
            $g.DrawLine($penSide, $pair[0][0], $pair[0][1], $pair[1][0], $pair[1][1])
        }
        $penSide.Dispose()

        $penStem = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(255, 93, 64, 55), 7)
        $penStem.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $penStem.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
        $g.DrawLine($penStem, 128, 222, 128, 246)
        $penStem.Dispose()

        $highlight = [System.Drawing.Drawing2D.GraphicsPath]::new()
        $highlight.AddBezier(108, 74, 78, 102, 72, 140, 84, 166)
        $penHi = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(110, 255, 255, 255), 8)
        $penHi.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $penHi.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
        $g.DrawPath($penHi, $highlight)
        $penHi.Dispose()
        $highlight.Dispose()

        $g.Dispose()
        $bmp.Save($PngPath, [System.Drawing.Imaging.ImageFormat]::Png)

        $hIcon = $bmp.GetHicon()
        $icon = [System.Drawing.Icon]::FromHandle($hIcon)
        $fs = [System.IO.File]::Create($IcoPath)
        $icon.Save($fs)
        $fs.Close()
        $icon.Dispose()
        $bmp.Dispose()
    } catch {
        # ícone é cosmético; não impede o launcher de abrir
    }
}

New-LeafIcon -PngPath $LeafPng -IcoPath $LeafIco

# ------------------------------------------------------------------------------
# Helpers gerais
# ------------------------------------------------------------------------------
function Write-TextNoBom {
    param([string]$Path, [string]$Text)
    $enc = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($Path, $Text, $enc)
}

function Brush {
    param([string]$Hex)
    return [System.Windows.Media.BrushConverter]::new().ConvertFromString($Hex)
}

function Format-Bytes {
    param($Bytes)
    if ($null -eq $Bytes -or $Bytes -le 0) { return "—" }
    $units = @('B', 'KB', 'MB', 'GB')
    $i = 0
    $v = [double]$Bytes
    while ($v -ge 1024 -and $i -lt 3) { $v = $v / 1024; $i++ }
    return ("{0:0.#} {1}" -f $v, $units[$i])
}

function Format-Duration {
    param($Seconds)
    $s = [int][math]::Round([double]$Seconds)
    if ($s -lt 60) { return "$s s" }
    $m = [int]($s / 60)
    if ($m -lt 60) { return "$m min" }
    $h = [int]($m / 60)
    $m = $m % 60
    if ($h -lt 24) { return "$h h $m min" }
    $d = [int]($h / 24)
    $h = $h % 24
    return "$d d $h h"
}

function Format-ShortDate {
    param($Text)
    try { return ([datetime]::Parse($Text)).ToString("dd/MM") } catch { return "—" }
}

function Get-Prop {
    param($Object, [string]$Name)
    if ($null -eq $Object) { return $null }
    if ($Object -is [System.Collections.IDictionary]) { return $Object[$Name] }
    return $Object.$Name
}

function To-Double {
    param($Value, $Default)
    $n = 0.0
    if ([double]::TryParse([string]$Value, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$n)) { return $n }
    return $Default
}

# ------------------------------------------------------------------------------
# TOML: leitura e escrita preservando o que o Zakuro guarda
# ------------------------------------------------------------------------------
function Get-TomlValue {
    param([string[]]$Lines, [string]$Key)
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match '^\s*\[') { break }
        if ($Lines[$i] -match ('^\s*' + [regex]::Escape($Key) + '\s*=\s*(.+?)\s*$')) {
            $v = $Matches[1].Trim()
            if ($v -match '^"(.*)"$') { return $Matches[1] }
            return $v
        }
    }
    return $null
}

function Get-TomlSection {
    param([string[]]$Lines, [string]$Section)
    $result = [ordered]@{}
    $inSection = $false
    foreach ($line in $Lines) {
        if ($line -match '^\s*\[([^\]]+)\]') {
            $inSection = ($Matches[1].Trim() -eq $Section)
            continue
        }
        if ($inSection -and $line -match '^\s*([A-Za-z0-9_]+)\s*=\s*"([^"]*)"') {
            $result[$Matches[1]] = $Matches[2]
        }
    }
    return $result
}

function Set-TomlTopLevel {
    param([string[]]$Lines, [System.Collections.Specialized.OrderedDictionary]$Values)

    $firstSection = $Lines.Count
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match '^\s*\[') { $firstSection = $i; break }
    }

    $managed = @($Values.Keys)
    $kept = [System.Collections.Generic.List[string]]::new()
    for ($i = 0; $i -lt $firstSection; $i++) {
        $line = $Lines[$i]
        $isManaged = $false
        foreach ($k in $managed) {
            if ($line -match ('^\s*' + [regex]::Escape($k) + '\s*=')) { $isManaged = $true; break }
        }
        if (-not $isManaged) { $kept.Add($line) }
    }

    while ($kept.Count -gt 0 -and $kept[$kept.Count - 1].Trim() -eq '') {
        $kept.RemoveAt($kept.Count - 1)
    }

    foreach ($k in $Values.Keys) {
        $kept.Add("$k = $($Values[$k])")
    }

    if ($firstSection -lt $Lines.Count) {
        $kept.Add('')
        for ($i = $firstSection; $i -lt $Lines.Count; $i++) { $kept.Add($Lines[$i]) }
    }

    return ,$kept.ToArray()
}

function Set-TomlSection {
    param([string[]]$Lines, [string]$Section, [System.Collections.Specialized.OrderedDictionary]$Values)

    $header = "[$Section]"
    $start = -1
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i].Trim() -eq $header) { $start = $i; break }
    }

    $extra = [System.Collections.Generic.List[string]]::new()
    if ($start -ge 0) {
        $end = $Lines.Count
        for ($i = $start + 1; $i -lt $Lines.Count; $i++) {
            if ($Lines[$i] -match '^\s*\[') { $end = $i; break }
        }
        for ($i = $start + 1; $i -lt $end; $i++) {
            if ($Lines[$i] -match '^\s*([A-Za-z0-9_]+)\s*=') {
                if (-not $Values.Contains($Matches[1])) { $extra.Add($Lines[$i]) }
            } elseif ($Lines[$i].Trim().StartsWith('#')) {
                $extra.Add($Lines[$i])
            }
        }
    }

    $block = [System.Collections.Generic.List[string]]::new()
    $block.Add($header)
    foreach ($k in $Values.Keys) {
        $block.Add("$k = `"$($Values[$k])`"")
    }
    foreach ($line in $extra) { $block.Add($line) }

    if ($start -ge 0) {
        $end = $Lines.Count
        for ($i = $start + 1; $i -lt $Lines.Count; $i++) {
            if ($Lines[$i] -match '^\s*\[') { $end = $i; break }
        }
        $list = [System.Collections.Generic.List[string]]::new()
        for ($i = 0; $i -lt $start; $i++) { $list.Add($Lines[$i]) }
        foreach ($b in $block) { $list.Add($b) }
        if ($end -lt $Lines.Count) {
            if ($list.Count -eq 0 -or $list[$list.Count - 1].Trim() -ne '') { $list.Add('') }
            for ($i = $end; $i -lt $Lines.Count; $i++) { $list.Add($Lines[$i]) }
        }
        return ,$list.ToArray()
    }

    $list = [System.Collections.Generic.List[string]]::new()
    foreach ($l in $Lines) { $list.Add($l) }
    if ($list.Count -gt 0 -and $list[$list.Count - 1].Trim() -ne '') { $list.Add('') }
    foreach ($b in $block) { $list.Add($b) }
    $list.Add('')
    return ,$list.ToArray()
}

# ------------------------------------------------------------------------------
# Configuração padrão
# ------------------------------------------------------------------------------
$DefaultKeys = [ordered]@{
    a = 'KeyX'; b = 'KeyZ'; x = 'KeyS'; y = 'KeyA'; l = 'KeyQ'; r = 'KeyW'
    start = 'Enter'; select = 'Backspace'
    up = 'ArrowUp'; down = 'ArrowDown'; left = 'ArrowLeft'; right = 'ArrowRight'
    circle_up = 'KeyI'; circle_down = 'KeyK'; circle_left = 'KeyJ'; circle_right = 'KeyL'
    zl = 'Digit1'; zr = 'Digit2'
    c_up = 'KeyT'; c_down = 'KeyG'; c_left = 'KeyF'; c_right = 'KeyH'
}

$DefaultPad = [ordered]@{
    a = 'East'; b = 'South'; x = 'North'; y = 'West'
    l = 'LeftTrigger'; r = 'RightTrigger'
    start = 'Start'; select = 'Select'
    up = 'DPadUp'; down = 'DPadDown'; left = 'DPadLeft'; right = 'DPadRight'
    zl = 'LeftTrigger2'; zr = 'RightTrigger2'
}

$Config = @{
    RomPath = ""
    ProjectRoot = ""
    Resolution = 3
    Scale = 3
    Layout = "large_top"
    Renderer = "vulkan"
    Rasterizer = "hardware"
    Filter = "smooth"
    IntegerScale = $false
    TopShape = "console"
    Orientation = "north"
    Stereo = "off"
    Depth3D = 50
    SwapEyes = $false
    TexturePacks = $true
    FrameInterpolation = $false
    ShowFps = $false
    Language = "english"
    Volume = 100
    Mute = $false
    New3DS = $false
    Keys = [ordered]@{}
    Pad = [ordered]@{}
    Stats = @{
        TotalSeconds = 0.0
        Sessions = 0
        LastPlayed = ""
        LastSessionSeconds = 0.0
        History = @()
    }
}

foreach ($k in $DefaultKeys.Keys) { $Config.Keys[$k] = $DefaultKeys[$k] }
foreach ($k in $DefaultPad.Keys)  { $Config.Pad[$k]  = $DefaultPad[$k] }

# Carrega launcher_config.json
if (Test-Path $ConfigFile) {
    try {
        $loaded = Get-Content -Raw -Encoding UTF8 $ConfigFile | ConvertFrom-Json
        $scalarMap = @(
            'RomPath', 'ProjectRoot', 'Resolution', 'Scale', 'Layout', 'Renderer', 'Rasterizer', 'Filter',
            'IntegerScale', 'TopShape', 'Orientation', 'Stereo', 'Depth3D', 'SwapEyes',
            'TexturePacks', 'FrameInterpolation', 'ShowFps', 'Language', 'Volume', 'Mute', 'New3DS'
        )
        foreach ($k in $scalarMap) {
            $prop = $loaded.PSObject.Properties[$k]
            if ($null -ne $prop -and $null -ne $prop.Value) { $Config[$k] = $prop.Value }
        }

        if ($loaded.Keys) {
            foreach ($p in $loaded.Keys.PSObject.Properties) {
                if ($Config.Keys.Contains($p.Name)) { $Config.Keys[$p.Name] = [string]$p.Value }
            }
        }
        if ($loaded.Pad) {
            foreach ($p in $loaded.Pad.PSObject.Properties) {
                if ($Config.Pad.Contains($p.Name)) { $Config.Pad[$p.Name] = [string]$p.Value }
            }
        }
        if ($loaded.Stats) {
            $s = $loaded.Stats
            if ($null -ne $s.TotalSeconds)       { $Config.Stats.TotalSeconds = [double]$s.TotalSeconds }
            if ($null -ne $s.Sessions)           { $Config.Stats.Sessions = [int]$s.Sessions }
            if ($null -ne $s.LastPlayed)         { $Config.Stats.LastPlayed = [string]$s.LastPlayed }
            if ($null -ne $s.LastSessionSeconds) { $Config.Stats.LastSessionSeconds = [double]$s.LastSessionSeconds }
            if ($s.History) {
                $hist = @()
                foreach ($h in $s.History) {
                    $hist += @{ Date = [string](Get-Prop $h 'Date'); Seconds = [double](Get-Prop $h 'Seconds') }
                }
                $Config.Stats.History = $hist
            }
        }
    } catch {
        Write-Output "Aviso: launcher_config.json inválido: $_"
    }
}

# Guarda a pasta do projeto escolhida/detectada, para os próximos usos
$Config.ProjectRoot = $RootPath

# Lê o settings.toml real do Zakuro (tem prioridade sobre o config do launcher)
$TomlLines = @()
if (Test-Path $SettingsToml) {
    try { $TomlLines = @(Get-Content -Path $SettingsToml -Encoding UTF8) } catch { $TomlLines = @() }
}

if ($TomlLines.Count -gt 0) {
    $v = Get-TomlValue $TomlLines 'layout';              if ($v) { $Config.Layout = $v }
    $v = Get-TomlValue $TomlLines 'renderer';            if ($v) { $Config.Renderer = $v }
    $v = Get-TomlValue $TomlLines 'filter';              if ($v) { $Config.Filter = $v }
    $v = Get-TomlValue $TomlLines 'top_shape';           if ($v) { $Config.TopShape = $v }
    $v = Get-TomlValue $TomlLines 'orientation';         if ($v) { $Config.Orientation = $v }
    $v = Get-TomlValue $TomlLines 'stereo';              if ($v) { $Config.Stereo = $v }
    $v = Get-TomlValue $TomlLines 'language';            if ($v) { $Config.Language = $v }

    $v = Get-TomlValue $TomlLines 'hardware_rasterizer'
    if ($null -ne $v) { if ($v -eq 'true') { $Config.Rasterizer = 'hardware' } else { $Config.Rasterizer = 'software' } }

    $v = Get-TomlValue $TomlLines 'integer_scale'
    if ($null -ne $v) { $Config.IntegerScale = ($v -eq 'true') }

    $v = Get-TomlValue $TomlLines 'swap_eyes'
    if ($null -ne $v) { $Config.SwapEyes = ($v -eq 'true') }

    $v = Get-TomlValue $TomlLines 'texture_packs'
    if ($null -ne $v) { $Config.TexturePacks = ($v -eq 'true') }

    $v = Get-TomlValue $TomlLines 'frame_interpolation'
    if ($null -ne $v) { $Config.FrameInterpolation = ($v -eq 'true') }

    $v = Get-TomlValue $TomlLines 'show_fps'
    if ($null -ne $v) { $Config.ShowFps = ($v -eq 'true') }

    $v = Get-TomlValue $TomlLines 'mute'
    if ($null -ne $v) { $Config.Mute = ($v -eq 'true') }

    $v = Get-TomlValue $TomlLines 'resolution'
    if ($null -ne $v) { $Config.Resolution = [int](To-Double $v $Config.Resolution) }

    $v = Get-TomlValue $TomlLines 'scale'
    if ($null -ne $v) { $Config.Scale = [int](To-Double $v $Config.Scale) }

    $v = Get-TomlValue $TomlLines 'depth_3d'
    if ($null -ne $v) { $Config.Depth3D = [int](To-Double $v $Config.Depth3D) }

    $v = Get-TomlValue $TomlLines 'volume'
    if ($null -ne $v) { $Config.Volume = [int][math]::Round((To-Double $v 1.0) * 100) }

    $tomlKeys = Get-TomlSection $TomlLines 'keys'
    foreach ($k in $tomlKeys.Keys) {
        if ($Config.Keys.Contains($k)) { $Config.Keys[$k] = [string]$tomlKeys[$k] }
    }

    $tomlPad = Get-TomlSection $TomlLines 'pad'
    foreach ($k in $tomlPad.Keys) {
        if ($Config.Pad.Contains($k)) { $Config.Pad[$k] = [string]$tomlPad[$k] }
    }
}

# Procura uma ROM na pasta do projeto (o usuário pode escolher outra em Procurar...)
if (-not $Config.RomPath -or -not (Test-Path $Config.RomPath)) {
    $candidates = @()
    $candidates += @(Get-ChildItem -Path $RootPath -Filter *.3ds -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
    $candidates += @(Get-ChildItem -Path $RootPath -Filter *.cxi -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
    if ($ScriptDir -ne $RootPath) {
        $candidates += @(Get-ChildItem -Path $ScriptDir -Filter *.3ds -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
        $candidates += @(Get-ChildItem -Path $ScriptDir -Filter *.cxi -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
    }
    if ($candidates.Count -gt 0) { $Config.RomPath = $candidates[0] }
}

# ------------------------------------------------------------------------------
# Salvar configurações
# ------------------------------------------------------------------------------
function Save-Config {
    $json = $Config | ConvertTo-Json -Depth 8
    Write-TextNoBom -Path $ConfigFile -Text $json
}

function Test-RecompDll {
    return (Test-Path $DllPath)
}

function Set-Footer {
    param([string]$Text)
    if ($TxtFooterStatus) { $TxtFooterStatus.Text = $Text }
}

# ------------------------------------------------------------------------------
# Aplicar configurações no settings.toml do Zakuro
# ------------------------------------------------------------------------------
function Apply-Settings {
    # Gráficos
    $v = Get-ComboTag $CmbLayout;      if ($v) { $Config.Layout = $v }
    $v = Get-ComboTag $CmbOrientation; if ($v) { $Config.Orientation = $v }
    $v = Get-ComboTag $CmbTopShape;    if ($v) { $Config.TopShape = $v }
    $v = Get-ComboTag $CmbScale;       if ($v) { $Config.Scale = [int]$v }
    $v = Get-ComboTag $CmbFilter;      if ($v) { $Config.Filter = $v }
    $v = Get-ComboTag $CmbResolution;  if ($v) { $Config.Resolution = [int]$v }
    $v = Get-ComboTag $CmbRenderer;    if ($v) { $Config.Renderer = $v }
    $v = Get-ComboTag $CmbRasterizer;  if ($v) { $Config.Rasterizer = $v }
    $v = Get-ComboTag $CmbStereo;      if ($v) { $Config.Stereo = $v }
    $v = Get-ComboTag $CmbLanguage;    if ($v) { $Config.Language = $v }

    $Config.IntegerScale       = [bool]$ChkIntegerScale.IsChecked
    $Config.TexturePacks       = [bool]$ChkTexturePacks.IsChecked
    $Config.FrameInterpolation = [bool]$ChkFrameInterpolation.IsChecked
    $Config.ShowFps            = [bool]$ChkShowFps.IsChecked
    $Config.SwapEyes           = [bool]$ChkSwapEyes.IsChecked
    $Config.Mute               = [bool]$ChkMute.IsChecked
    $Config.New3DS             = [bool]$ChkNew3DS.IsChecked
    $Config.Depth3D            = [int]$DepthSlider.Value
    $Config.Volume             = [int]$VolumeSlider.Value

    # Controles
    foreach ($key in $KbCombos.Keys) {
        $sel = $KbCombos[$key].SelectedItem
        if ($null -ne $sel) { $Config.Keys[$key] = [string]$sel }
    }
    foreach ($key in $PadCombos.Keys) {
        $sel = $PadCombos[$key].SelectedItem
        if ($null -ne $sel) { $Config.Pad[$key] = [string]$sel }
    }

    # settings.toml
    if (-not (Test-Path $AppDataZakuro)) {
        New-Item -ItemType Directory -Path $AppDataZakuro -Force | Out-Null
    }

    $lines = @()
    if (Test-Path $SettingsToml) {
        try { $lines = @(Get-Content -Path $SettingsToml -Encoding UTF8) } catch { $lines = @() }
    }

    $top = [ordered]@{}
    $top['language']            = '"' + $Config.Language + '"'
    $top['renderer']            = '"' + $Config.Renderer + '"'
    $top['hardware_rasterizer'] = Bool-Str ($Config.Rasterizer -eq 'hardware')
    $top['resolution']          = [string]$Config.Resolution
    $top['texture_packs']       = Bool-Str $Config.TexturePacks
    $top['frame_interpolation'] = Bool-Str $Config.FrameInterpolation
    $top['recompiled']          = 'true'
    $top['scale']               = [string]$Config.Scale
    $top['layout']              = '"' + $Config.Layout + '"'
    $top['orientation']         = '"' + $Config.Orientation + '"'
    $top['filter']              = '"' + $Config.Filter + '"'
    $top['integer_scale']       = Bool-Str $Config.IntegerScale
    $top['top_shape']           = '"' + $Config.TopShape + '"'
    $top['stereo']              = '"' + $Config.Stereo + '"'
    $top['depth_3d']            = [string]$Config.Depth3D
    $top['swap_eyes']           = Bool-Str $Config.SwapEyes
    $top['volume']              = (([double]$Config.Volume / 100.0).ToString('0.00', [System.Globalization.CultureInfo]::InvariantCulture))
    $top['mute']                = Bool-Str $Config.Mute
    $top['show_fps']            = Bool-Str $Config.ShowFps

    $lines = Set-TomlTopLevel -Lines $lines -Values $top
    $lines = Set-TomlSection -Lines $lines -Section 'keys' -Values $Config.Keys
    $lines = Set-TomlSection -Lines $lines -Section 'pad' -Values $Config.Pad

    Write-TextNoBom -Path $SettingsToml -Text ($lines -join "`r`n")
    Save-Config

    Set-Footer "Configurações salvas às $(Get-Date -Format 'HH:mm:ss')."
    Write-GuiLog "Configurações aplicadas em $SettingsToml"
}

function Bool-Str {
    param($Value)
    if ($Value) { return 'true' }
    return 'false'
}

# ------------------------------------------------------------------------------
# Helpers de UI
# ------------------------------------------------------------------------------
function Set-ComboTag {
    param($Combo, $TagValue)
    if ($null -eq $TagValue -or "$TagValue" -eq '') {
        if ($Combo.Items.Count -gt 0) { $Combo.SelectedIndex = 0 }
        return
    }
    foreach ($item in $Combo.Items) {
        if ("$($item.Tag)" -eq "$TagValue") { $Combo.SelectedItem = $item; return }
    }
    # valor vindo do settings.toml que não está na lista: preserva em vez de resetar
    $ci = [System.Windows.Controls.ComboBoxItem]::new()
    $ci.Content = [string]$TagValue
    $ci.Tag = [string]$TagValue
    $Combo.Items.Add($ci) | Out-Null
    $Combo.SelectedItem = $ci
}

function Get-ComboTag {
    param($Combo)
    if ($Combo.SelectedItem) { return "$($Combo.SelectedItem.Tag)" }
    return $null
}

function Set-ComboText {
    param($Combo, $Text)
    foreach ($item in $Combo.Items) {
        if ("$item" -eq "$Text") { $Combo.SelectedItem = $item; return }
    }
    if ($Text) {
        $Combo.Items.Add($Text) | Out-Null
        $Combo.SelectedItem = $Text
    } elseif ($Combo.Items.Count -gt 0) {
        $Combo.SelectedIndex = 0
    }
}

function New-Section {
    param($Parent, [string]$Title)
    $border = [System.Windows.Controls.Border]::new()
    $border.Background = Brush "#20242D"
    $border.BorderBrush = Brush "#2F3643"
    $border.BorderThickness = "1"
    $border.CornerRadius = "12"
    $border.Padding = "14"
    $border.Margin = "0,0,0,12"

    $panel = [System.Windows.Controls.StackPanel]::new()
    $header = [System.Windows.Controls.TextBlock]::new()
    $header.Text = $Title
    $header.Foreground = Brush "#00B894"
    $header.FontWeight = "Bold"
    $header.FontSize = 11
    $header.Margin = "0,0,0,10"
    $panel.Children.Add($header) | Out-Null
    $border.Child = $panel
    $Parent.Children.Add($border) | Out-Null
    return $panel
}

function Add-ComboField {
    param($Parent, [string]$Label, $Items, $SelectedTag, [string]$Tooltip)
    $sp = [System.Windows.Controls.StackPanel]::new()
    $sp.Margin = "0,0,0,9"

    $lbl = [System.Windows.Controls.TextBlock]::new()
    $lbl.Text = $Label
    $lbl.Foreground = Brush "#A0A8B7"
    $lbl.FontSize = 10
    $lbl.Margin = "0,0,0,4"

    $cmb = [System.Windows.Controls.ComboBox]::new()
    $cmb.FontSize = 11
    $cmb.MinHeight = 30
    foreach ($it in $Items) {
        $ci = [System.Windows.Controls.ComboBoxItem]::new()
        $ci.Content = [string]$it['Content']
        $ci.Tag = [string]$it['Tag']
        $cmb.Items.Add($ci) | Out-Null
    }
    if ($null -ne $SelectedTag) { Set-ComboTag $cmb $SelectedTag }
    if ($Tooltip) { $cmb.ToolTip = $Tooltip }

    $sp.Children.Add($lbl) | Out-Null
    $sp.Children.Add($cmb) | Out-Null
    $Parent.Children.Add($sp) | Out-Null
    return $cmb
}

function Add-CheckField {
    param($Parent, [string]$Label, $Checked, [string]$Tooltip)
    $cb = [System.Windows.Controls.CheckBox]::new()
    $cb.Content = $Label
    $cb.IsChecked = [bool]$Checked
    $cb.FontSize = 11
    $cb.Margin = "0,0,0,8"
    if ($Tooltip) { $cb.ToolTip = $Tooltip }
    $Parent.Children.Add($cb) | Out-Null
    return $cb
}

function Add-SliderField {
    param($Parent, [string]$Label, $Min, $Max, $Value, [string]$Suffix, [string]$Tooltip)
    $sp = [System.Windows.Controls.StackPanel]::new()
    $sp.Margin = "0,0,0,9"

    $grid = [System.Windows.Controls.Grid]::new()
    $lbl = [System.Windows.Controls.TextBlock]::new()
    $lbl.Text = $Label
    $lbl.Foreground = Brush "#A0A8B7"
    $lbl.FontSize = 10
    $val = [System.Windows.Controls.TextBlock]::new()
    $val.Text = "$([int]$Value)$Suffix"
    $val.Foreground = Brush "#00B894"
    $val.FontSize = 10
    $val.HorizontalAlignment = "Right"
    $grid.Children.Add($lbl) | Out-Null
    $grid.Children.Add($val) | Out-Null

    $sl = [System.Windows.Controls.Slider]::new()
    $sl.Minimum = $Min
    $sl.Maximum = $Max
    $sl.Value = $Value
    $sl.TickFrequency = 1
    $sl.IsSnapToTickEnabled = $true
    $sl.Margin = "0,6,0,0"
    if ($Tooltip) { $sl.ToolTip = $Tooltip }

    $sp.Children.Add($grid) | Out-Null
    $sp.Children.Add($sl) | Out-Null
    $Parent.Children.Add($sp) | Out-Null
    return @{ Slider = $sl; Value = $val }
}

function Add-BindingRow {
    param($Parent, [string]$Label, $Combo)
    $grid = [System.Windows.Controls.Grid]::new()
    $grid.Margin = "0,0,0,5"

    $c1 = [System.Windows.Controls.ColumnDefinition]::new()
    $c1.Width = [System.Windows.GridLength]::new(118)
    $c2 = [System.Windows.Controls.ColumnDefinition]::new()
    $c2.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
    $grid.ColumnDefinitions.Add($c1)
    $grid.ColumnDefinitions.Add($c2)

    $lbl = [System.Windows.Controls.TextBlock]::new()
    $lbl.Text = $Label
    $lbl.Foreground = Brush "#A0A8B7"
    $lbl.FontSize = 10
    $lbl.VerticalAlignment = "Center"
    $lbl.TextTrimming = "CharacterEllipsis"

    $Combo.Height = 28
    $Combo.FontSize = 10

    [System.Windows.Controls.Grid]::SetColumn($lbl, 0)
    [System.Windows.Controls.Grid]::SetColumn($Combo, 1)
    $grid.Children.Add($lbl) | Out-Null
    $grid.Children.Add($Combo) | Out-Null
    $Parent.Children.Add($grid) | Out-Null
}

function New-BindingCombo {
    param($Items, $Selected)
    $cmb = [System.Windows.Controls.ComboBox]::new()
    foreach ($item in $Items) { $cmb.Items.Add($item) | Out-Null }
    Set-ComboText $cmb $Selected
    return $cmb
}

# ------------------------------------------------------------------------------
# XAML
# ------------------------------------------------------------------------------
[xml]$Xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Animal Crossing: New Leaf - PC Recompiled"
        Height="720" Width="1020"
        MinHeight="640" MinWidth="900"
        WindowStartupLocation="CenterScreen"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        ResizeMode="CanMinimize"
        FontFamily="Segoe UI" UseLayoutRounding="True" SnapsToDevicePixels="True">

    <Window.Resources>
        <SolidColorBrush x:Key="Bg" Color="#14171C"/>

        <Style TargetType="TextBlock">
            <Setter Property="Foreground" Value="#ECEFF4"/>
            <Setter Property="FontSize" Value="12"/>
        </Style>

        <Style TargetType="Button">
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Padding" Value="14,8"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Background" Value="#2C3440"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" CornerRadius="7"
                                Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Opacity" Value="0.86"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="Opacity" Value="0.70"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="border" Property="Opacity" Value="0.40"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="NavButton" TargetType="RadioButton">
            <Setter Property="Foreground" Value="#A0A8B7"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="RadioButton">
                        <Border x:Name="navBorder" Background="Transparent" CornerRadius="8" Padding="12,9" Margin="0,2">
                            <Grid>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="4"/>
                                    <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>
                                <Border x:Name="accent" Grid.Column="0" Width="4" CornerRadius="2" Background="Transparent" Margin="0,0,10,0"/>
                                <ContentPresenter Grid.Column="1" VerticalAlignment="Center"/>
                            </Grid>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="navBorder" Property="Background" Value="#232833"/>
                            </Trigger>
                            <Trigger Property="IsChecked" Value="True">
                                <Setter TargetName="navBorder" Property="Background" Value="#202A26"/>
                                <Setter TargetName="accent" Property="Background" Value="#00B894"/>
                                <Setter Property="Foreground" Value="#FFFFFF"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="TextBox">
            <Setter Property="Background" Value="#181B21"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="BorderBrush" Value="#343B4A"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="8,6"/>
            <Setter Property="CaretBrush" Value="#00B894"/>
            <Setter Property="SelectionBrush" Value="#00B894"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="TextBox">
                        <Border Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="6">
                            <ScrollViewer x:Name="PART_ContentHost" Margin="{TemplateBinding Padding}"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="ComboBoxItem">
            <Setter Property="Foreground" Value="#ECEFF4"/>
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Padding" Value="8,6"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ComboBoxItem">
                        <Border x:Name="itemBorder" Background="{TemplateBinding Background}"
                                Padding="{TemplateBinding Padding}" CornerRadius="4" Margin="3,1">
                            <ContentPresenter/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsHighlighted" Value="True">
                                <Setter TargetName="itemBorder" Property="Background" Value="#2F3643"/>
                            </Trigger>
                            <Trigger Property="IsSelected" Value="True">
                                <Setter TargetName="itemBorder" Property="Background" Value="#00B894"/>
                                <Setter Property="Foreground" Value="#0B1410"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="ComboBox">
            <Setter Property="Foreground" Value="#ECEFF4"/>
            <Setter Property="Background" Value="#252A34"/>
            <Setter Property="BorderBrush" Value="#3B4252"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="8,5"/>
            <Setter Property="FontSize" Value="11"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ComboBox">
                        <Grid>
                            <ToggleButton x:Name="ToggleButton" Focusable="False" ClickMode="Press"
                                          Background="{TemplateBinding Background}"
                                          BorderBrush="{TemplateBinding BorderBrush}"
                                          BorderThickness="{TemplateBinding BorderThickness}"
                                          IsChecked="{Binding IsDropDownOpen, Mode=TwoWay, RelativeSource={RelativeSource TemplatedParent}}">
                                <ToggleButton.Template>
                                    <ControlTemplate TargetType="ToggleButton">
                                        <Border Background="{TemplateBinding Background}"
                                                BorderBrush="{TemplateBinding BorderBrush}"
                                                BorderThickness="{TemplateBinding BorderThickness}"
                                                CornerRadius="6">
                                            <Path HorizontalAlignment="Right" VerticalAlignment="Center"
                                                  Margin="0,0,10,0" Data="M 0,0 L 4,4 L 8,0"
                                                  Stroke="#A0A8B7" StrokeThickness="1.6"/>
                                        </Border>
                                    </ControlTemplate>
                                </ToggleButton.Template>
                            </ToggleButton>
                            <ContentPresenter Name="ContentSite" IsHitTestVisible="False"
                                              Content="{TemplateBinding SelectionBoxItem}"
                                              ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}"
                                              ContentStringFormat="{TemplateBinding SelectionBoxItemStringFormat}"
                                              Margin="10,0,30,0" VerticalAlignment="Center" HorizontalAlignment="Left"/>
                            <Popup Name="Popup" Placement="Bottom" IsOpen="{TemplateBinding IsDropDownOpen}"
                                   AllowsTransparency="True" Focusable="False" PopupAnimation="None">
                                <Border Name="DropDownBorder" Background="#252A34" BorderBrush="#3B4252"
                                        BorderThickness="1" CornerRadius="6"
                                        MinWidth="{Binding ActualWidth, RelativeSource={RelativeSource TemplatedParent}}"
                                        MaxHeight="{TemplateBinding MaxDropDownHeight}">
                                    <ScrollViewer SnapsToDevicePixels="True">
                                        <StackPanel IsItemsHost="True" KeyboardNavigation.DirectionalNavigation="Contained"/>
                                    </ScrollViewer>
                                </Border>
                            </Popup>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="CheckBox">
            <Setter Property="Foreground" Value="#ECEFF4"/>
            <Setter Property="FontSize" Value="11"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="CheckBox">
                        <StackPanel Orientation="Horizontal">
                            <Border x:Name="box" Width="18" Height="18" CornerRadius="4"
                                    Background="#181B21" BorderBrush="#3B4252" BorderThickness="1"
                                    VerticalAlignment="Center">
                                <Path x:Name="check" Data="M 3,9 L 7,13 L 15,4" Stroke="#0B1410"
                                      StrokeThickness="2.2" StrokeStartLineCap="Round"
                                      StrokeEndLineCap="Round" StrokeLineJoin="Round"
                                      Visibility="Collapsed" Margin="3"/>
                            </Border>
                            <ContentPresenter Margin="8,0,0,0" VerticalAlignment="Center"/>
                        </StackPanel>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsChecked" Value="True">
                                <Setter TargetName="box" Property="Background" Value="#00B894"/>
                                <Setter TargetName="box" Property="BorderBrush" Value="#00B894"/>
                                <Setter TargetName="check" Property="Visibility" Value="Visible"/>
                            </Trigger>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="box" Property="BorderBrush" Value="#00B894"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="Slider">
            <Setter Property="Foreground" Value="#00B894"/>
            <Setter Property="Height" Value="24"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Slider">
                        <Grid VerticalAlignment="Center">
                            <Border Height="4" CornerRadius="2" Background="#2F3643"/>
                            <Track x:Name="PART_Track">
                                <Track.DecreaseRepeatButton>
                                    <RepeatButton Command="{x:Static Slider.DecreaseLarge}" Focusable="False"
                                                  Background="#00B894" BorderThickness="0">
                                        <RepeatButton.Template>
                                            <ControlTemplate TargetType="RepeatButton">
                                                <Border Background="{TemplateBinding Background}" Height="4" CornerRadius="2"/>
                                            </ControlTemplate>
                                        </RepeatButton.Template>
                                    </RepeatButton>
                                </Track.DecreaseRepeatButton>
                                <Track.IncreaseRepeatButton>
                                    <RepeatButton Command="{x:Static Slider.IncreaseLarge}" Focusable="False"
                                                  Background="Transparent" BorderThickness="0">
                                        <RepeatButton.Template>
                                            <ControlTemplate TargetType="RepeatButton">
                                                <Border Background="Transparent" Height="4"/>
                                            </ControlTemplate>
                                        </RepeatButton.Template>
                                    </RepeatButton>
                                </Track.IncreaseRepeatButton>
                                <Track.Thumb>
                                    <Thumb Width="16" Height="16">
                                        <Thumb.Template>
                                            <ControlTemplate TargetType="Thumb">
                                                <Ellipse Fill="#00B894" Stroke="#0B1410" StrokeThickness="2" Width="16" Height="16"/>
                                            </ControlTemplate>
                                        </Thumb.Template>
                                    </Thumb>
                                </Track.Thumb>
                            </Track>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="ScrollBar">
            <Setter Property="Width" Value="8"/>
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ScrollBar">
                        <Grid Background="Transparent">
                            <Track x:Name="PART_Track" IsDirectionReversed="True">
                                <Track.DecreaseRepeatButton>
                                    <RepeatButton Command="{x:Static ScrollBar.PageUpCommand}" Opacity="0" Focusable="False"/>
                                </Track.DecreaseRepeatButton>
                                <Track.Thumb>
                                    <Thumb>
                                        <Thumb.Template>
                                            <ControlTemplate TargetType="Thumb">
                                                <Border Background="#3B4252" CornerRadius="4" Margin="1"/>
                                            </ControlTemplate>
                                        </Thumb.Template>
                                    </Thumb>
                                </Track.Thumb>
                                <Track.IncreaseRepeatButton>
                                    <RepeatButton Command="{x:Static ScrollBar.PageDownCommand}" Opacity="0" Focusable="False"/>
                                </Track.IncreaseRepeatButton>
                            </Track>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="ToolTip">
            <Setter Property="Background" Value="#252A34"/>
            <Setter Property="Foreground" Value="#ECEFF4"/>
            <Setter Property="BorderBrush" Value="#3B4252"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="8,5"/>
            <Setter Property="FontSize" Value="10"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ToolTip">
                        <Border Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="6" Padding="{TemplateBinding Padding}">
                            <ContentPresenter/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Border CornerRadius="16" Background="{StaticResource Bg}" BorderBrush="#2D333F" BorderThickness="1" Margin="12">
        <Border.Effect>
            <DropShadowEffect BlurRadius="24" ShadowDepth="4" Opacity="0.55" Color="#000000"/>
        </Border.Effect>

        <Grid>
            <Grid.RowDefinitions>
                <RowDefinition Height="54"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="34"/>
            </Grid.RowDefinitions>

            <!-- Barra de título -->
            <Grid Grid.Row="0" Name="TitleBar" Background="#191D24">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center" Margin="18,0,0,0">
                    <Image Name="ImgLogo" Width="26" Height="26" Stretch="Uniform" Margin="0,0,10,0"/>
                    <TextBlock Text="Animal Crossing: New Leaf" Foreground="#FFFFFF" FontWeight="Bold" FontSize="14" VerticalAlignment="Center"/>
                    <TextBlock Text="  •  PC Recompiled" Foreground="#00B894" FontWeight="SemiBold" FontSize="12" VerticalAlignment="Center"/>
                </StackPanel>
                <StackPanel Grid.Column="2" Orientation="Horizontal" Margin="0,0,12,0" VerticalAlignment="Center">
                    <Button Name="BtnMin" Content="—" Width="36" Height="28" Background="Transparent" Foreground="#A0A5B5" FontSize="14" Padding="0"/>
                    <Button Name="BtnClose" Content="✕" Width="36" Height="28" Background="Transparent" Foreground="#A0A5B5" FontSize="13" Margin="4,0,0,0" Padding="0"/>
                </StackPanel>
            </Grid>

            <!-- Corpo -->
            <Grid Grid.Row="1">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="220"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>

                <!-- Menu lateral -->
                <Border Grid.Column="0" Background="#171B21" BorderBrush="#252B35" BorderThickness="0,1,1,0">
                    <Grid Margin="14,18,14,14">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>

                        <Border Grid.Row="0" Background="#1C2622" BorderBrush="#2A4A3E" BorderThickness="1" CornerRadius="12" Padding="14">
                            <StackPanel>
                                <Image Name="ImgSidebarLeaf" Width="42" Height="42" HorizontalAlignment="Left" Stretch="Uniform"/>
                                <TextBlock Text="Animal Crossing" Foreground="#FFFFFF" FontWeight="Bold" FontSize="14" Margin="0,8,0,0"/>
                                <TextBlock Text="New Leaf" Foreground="#00B894" FontWeight="SemiBold" FontSize="13"/>
                                <TextBlock Text="PC Recompiled" Foreground="#7C8797" FontSize="10" Margin="0,2,0,0"/>
                            </StackPanel>
                        </Border>

                        <StackPanel Grid.Row="1" Margin="0,16,0,0">
                            <RadioButton Name="NavPlay" Style="{StaticResource NavButton}" Content="Jogar" GroupName="Nav" IsChecked="True"/>
                            <RadioButton Name="NavGraphics" Style="{StaticResource NavButton}" Content="Gráficos" GroupName="Nav"/>
                            <RadioButton Name="NavControls" Style="{StaticResource NavButton}" Content="Controles" GroupName="Nav"/>
                            <RadioButton Name="NavStats" Style="{StaticResource NavButton}" Content="Estatísticas" GroupName="Nav"/>
                            <RadioButton Name="NavAbout" Style="{StaticResource NavButton}" Content="Sobre" GroupName="Nav"/>
                        </StackPanel>

                        <Button Grid.Row="3" Name="BtnSidebarPlay" Content="▶  JOGAR" Height="46" Background="#00B894" Foreground="#0B1410" FontSize="14" FontWeight="Bold" Margin="0,0,0,8"/>
                        <TextBlock Grid.Row="4" Name="TxtSidebarStatus" Text="Pronto" Foreground="#6B7686" FontSize="10" HorizontalAlignment="Center"/>
                    </Grid>
                </Border>

                <!-- Páginas -->
                <Grid Grid.Column="1" Margin="22,18,22,14">

                    <!-- JOGAR -->
                    <Grid Name="PagePlay">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                        </Grid.RowDefinitions>

                        <Border Grid.Row="0" CornerRadius="14" Padding="20" Margin="0,0,0,12" BorderThickness="1" BorderBrush="#2F5E4E">
                            <Border.Background>
                                <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
                                    <GradientStop Color="#1D2A26" Offset="0"/>
                                    <GradientStop Color="#20242D" Offset="1"/>
                                </LinearGradientBrush>
                            </Border.Background>
                            <Grid>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>
                                <StackPanel Grid.Column="0" VerticalAlignment="Center">
                                    <TextBlock Name="TxtHeroStatus" Text="Pronto para jogar" Foreground="#FFFFFF" FontSize="21" FontWeight="Bold"/>
                                    <TextBlock Name="TxtHeroSub" Text="Carregando informações..." Foreground="#A0A8B7" FontSize="11" Margin="0,4,0,0" TextWrapping="Wrap"/>
                                    <StackPanel Orientation="Horizontal" Margin="0,12,0,0">
                                        <Border Name="PillStatus" Background="#173B31" CornerRadius="10" Padding="9,4">
                                            <TextBlock Name="TxtPill" Text="PRONTO" Foreground="#00B894" FontSize="9" FontWeight="Bold"/>
                                        </Border>
                                        <TextBlock Name="TxtSessionLive" Text="" Foreground="#7C8797" FontSize="10" VerticalAlignment="Center" Margin="10,0,0,0"/>
                                    </StackPanel>
                                </StackPanel>
                                <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                                    <Button Name="BtnRecompile" Content="Recompilar" Height="42" Background="#2C3440" Margin="0,0,8,0"/>
                                    <Button Name="BtnPlay" Content="▶  JOGAR" Height="42" Width="170" Background="#00B894" Foreground="#0B1410" FontSize="14" FontWeight="Bold"/>
                                </StackPanel>
                            </Grid>
                        </Border>

                        <Border Grid.Row="1" Background="#20242D" CornerRadius="12" Padding="14" BorderBrush="#2F3643" BorderThickness="1" Margin="0,0,0,12">
                            <StackPanel>
                                <TextBlock Text="Arquivo da ROM (.3DS / .CXI)" Foreground="#A0A8B7" FontWeight="SemiBold" FontSize="11" Margin="0,0,0,6"/>
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="Auto"/>
                                    </Grid.ColumnDefinitions>
                                    <TextBox Name="TxtRomPath" Grid.Column="0" IsReadOnly="True" Height="32" FontSize="11"/>
                                    <Button Name="BtnBrowse" Grid.Column="1" Content="Procurar..." Width="92" Height="32" Background="#2C3440" Margin="8,0,0,0" FontSize="11"/>
                                </Grid>
                            </StackPanel>
                        </Border>

                        <WrapPanel Grid.Row="2" Margin="0,0,0,12">
                            <Button Name="BtnOpenSaves" Content="Abrir saves" Height="30" Background="#252C37" Margin="0,0,6,6" FontSize="10"/>
                            <Button Name="BtnOpenOutput" Content="Abrir DLL" Height="30" Background="#252C37" Margin="0,0,6,6" FontSize="10"/>
                            <Button Name="BtnBackup" Content="Backup do save" Height="30" Background="#252C37" Margin="0,0,6,6" FontSize="10"/>
                            <Button Name="BtnOpenLog" Content="Abrir log" Height="30" Background="#252C37" Margin="0,0,6,6" FontSize="10"/>
                            <Button Name="BtnOpenSettings" Content="settings.toml" Height="30" Background="#252C37" Margin="0,0,6,6" FontSize="10"/>
                        </WrapPanel>

                        <Border Grid.Row="3" Background="#181B21" CornerRadius="12" Padding="12" BorderBrush="#292F3B" BorderThickness="1">
                            <Grid>
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="Auto"/>
                                    <RowDefinition Height="*"/>
                                </Grid.RowDefinitions>
                                <Grid Grid.Row="0" Margin="0,0,0,8">
                                    <TextBlock Text="Registro de atividade" Foreground="#747D8C" FontSize="10" FontWeight="SemiBold"/>
                                    <ProgressBar Name="CompileProgress" Height="4" Maximum="100" Value="100" Foreground="#00B894" Background="#242933" BorderThickness="0" VerticalAlignment="Bottom" Visibility="Collapsed"/>
                                </Grid>
                                <TextBox Name="TxtLog" Grid.Row="1" Background="Transparent" Foreground="#00CE9D" BorderThickness="0" IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" FontFamily="Consolas" FontSize="10"/>
                            </Grid>
                        </Border>
                    </Grid>

                    <!-- GRÁFICOS -->
                    <Grid Name="PageGraphics" Visibility="Collapsed">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                        </Grid.RowDefinitions>
                        <Grid Grid.Row="0" Margin="0,0,0,12">
                            <TextBlock Text="Gráficos" Foreground="#FFFFFF" FontSize="20" FontWeight="Bold"/>
                            <TextBlock Text="Ajustes aplicados ao iniciar o jogo" Foreground="#6B7686" FontSize="10" HorizontalAlignment="Right" VerticalAlignment="Bottom"/>
                        </Grid>
                        <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
                            <Grid Margin="0,0,10,0">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>
                                <StackPanel Name="GfxCol1" Grid.Column="0" Margin="0,0,10,0"/>
                                <StackPanel Name="GfxCol2" Grid.Column="1" Margin="10,0,0,0"/>
                            </Grid>
                        </ScrollViewer>
                    </Grid>

                    <!-- CONTROLES -->
                    <Grid Name="PageControls" Visibility="Collapsed">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                        </Grid.RowDefinitions>
                        <Grid Grid.Row="0" Margin="0,0,0,12">
                            <TextBlock Text="Controles" Foreground="#FFFFFF" FontSize="20" FontWeight="Bold"/>
                            <TextBlock Text="Teclado e controle" Foreground="#6B7686" FontSize="10" HorizontalAlignment="Right" VerticalAlignment="Bottom"/>
                        </Grid>
                        <Grid Grid.Row="1">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>

                            <Border Grid.Column="0" Background="#20242D" CornerRadius="12" Padding="14" BorderBrush="#2F3643" BorderThickness="1" Margin="0,0,8,0">
                                <Grid>
                                    <Grid.RowDefinitions>
                                        <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="*"/>
                                    </Grid.RowDefinitions>
                                    <Grid Grid.Row="0" Margin="0,0,0,10">
                                        <TextBlock Text="TECLADO" Foreground="#00B894" FontWeight="Bold" FontSize="11"/>
                                        <Button Name="BtnResetKb" Content="Restaurar padrão" Height="24" Background="#2C3440" FontSize="9" HorizontalAlignment="Right" Padding="8,2"/>
                                    </Grid>
                                    <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
                                        <StackPanel Name="KbPanel"/>
                                    </ScrollViewer>
                                </Grid>
                            </Border>

                            <Border Grid.Column="1" Background="#20242D" CornerRadius="12" Padding="14" BorderBrush="#2F3643" BorderThickness="1" Margin="8,0,0,0">
                                <Grid>
                                    <Grid.RowDefinitions>
                                        <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="*"/>
                                        <RowDefinition Height="Auto"/>
                                    </Grid.RowDefinitions>
                                    <Grid Grid.Row="0" Margin="0,0,0,10">
                                        <TextBlock Text="CONTROLE" Foreground="#00B894" FontWeight="Bold" FontSize="11"/>
                                        <Button Name="BtnResetPad" Content="Restaurar padrão" Height="24" Background="#2C3440" FontSize="9" HorizontalAlignment="Right" Padding="8,2"/>
                                    </Grid>
                                    <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
                                        <StackPanel Name="PadPanel"/>
                                    </ScrollViewer>
                                    <TextBlock Grid.Row="2" Text="O Circle Pad e o C-Stick usam os analógicos esquerdo e direito automaticamente." Foreground="#6B7686" FontSize="9" TextWrapping="Wrap" Margin="0,8,0,0"/>
                                </Grid>
                            </Border>
                        </Grid>
                    </Grid>

                    <!-- ESTATÍSTICAS -->
                    <Grid Name="PageStats" Visibility="Collapsed">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                        </Grid.RowDefinitions>

                        <Grid Grid.Row="0" Margin="0,0,0,12">
                            <TextBlock Text="Estatísticas" Foreground="#FFFFFF" FontSize="20" FontWeight="Bold"/>
                            <Button Name="BtnClearStats" Content="Zerar estatísticas" Height="26" Background="#2C3440" FontSize="9" HorizontalAlignment="Right" VerticalAlignment="Bottom" Padding="8,2"/>
                        </Grid>

                        <UniformGrid Grid.Row="1" Columns="4" Margin="0,0,0,12">
                            <Border Background="#20242D" CornerRadius="12" Padding="14" BorderBrush="#2F3643" BorderThickness="1" Margin="0,0,4,0">
                                <StackPanel>
                                    <TextBlock Name="StatTotal" Text="0 min" Foreground="#FFFFFF" FontSize="19" FontWeight="Bold"/>
                                    <TextBlock Text="Tempo total" Foreground="#7C8797" FontSize="10" Margin="0,3,0,0"/>
                                </StackPanel>
                            </Border>
                            <Border Background="#20242D" CornerRadius="12" Padding="14" BorderBrush="#2F3643" BorderThickness="1" Margin="4,0,4,0">
                                <StackPanel>
                                    <TextBlock Name="StatSessions" Text="0" Foreground="#FFFFFF" FontSize="19" FontWeight="Bold"/>
                                    <TextBlock Text="Sessões" Foreground="#7C8797" FontSize="10" Margin="0,3,0,0"/>
                                </StackPanel>
                            </Border>
                            <Border Background="#20242D" CornerRadius="12" Padding="14" BorderBrush="#2F3643" BorderThickness="1" Margin="4,0,4,0">
                                <StackPanel>
                                    <TextBlock Name="StatLastSession" Text="—" Foreground="#FFFFFF" FontSize="19" FontWeight="Bold"/>
                                    <TextBlock Text="Última sessão" Foreground="#7C8797" FontSize="10" Margin="0,3,0,0"/>
                                </StackPanel>
                            </Border>
                            <Border Background="#20242D" CornerRadius="12" Padding="14" BorderBrush="#2F3643" BorderThickness="1" Margin="4,0,0,0">
                                <StackPanel>
                                    <TextBlock Name="StatLastPlayed" Text="—" Foreground="#FFFFFF" FontSize="14" FontWeight="Bold" Margin="0,5,0,0"/>
                                    <TextBlock Text="Último jogo" Foreground="#7C8797" FontSize="10" Margin="0,3,0,0"/>
                                </StackPanel>
                            </Border>
                        </UniformGrid>

                        <Border Grid.Row="2" Background="#20242D" CornerRadius="12" Padding="14" BorderBrush="#2F3643" BorderThickness="1" Margin="0,0,0,12">
                            <Grid>
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="Auto"/>
                                    <RowDefinition Height="Auto"/>
                                </Grid.RowDefinitions>
                                <TextBlock Grid.Row="0" Text="ATIVIDADE RECENTE" Foreground="#00B894" FontWeight="Bold" FontSize="11" Margin="0,0,0,8"/>
                                <Grid Grid.Row="1" Height="120">
                                    <TextBlock Name="StatsEmpty" Text="Nenhuma sessão registrada ainda. Jogue pelo launcher para começar a acompanhar." Foreground="#6B7686" FontSize="10" VerticalAlignment="Center" HorizontalAlignment="Center"/>
                                    <StackPanel Name="StatsChart" Orientation="Horizontal" Height="120" VerticalAlignment="Bottom"/>
                                </Grid>
                            </Grid>
                        </Border>

                        <Border Grid.Row="3" Background="#20242D" CornerRadius="12" Padding="14" BorderBrush="#2F3643" BorderThickness="1">
                            <Grid>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>
                                <StackPanel Grid.Column="0" Margin="0,0,12,0">
                                    <TextBlock Text="INFORMAÇÕES DO JOGO" Foreground="#00B894" FontWeight="Bold" FontSize="11" Margin="0,0,0,8"/>
                                    <Grid>
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="110"/>
                                            <ColumnDefinition Width="*"/>
                                        </Grid.ColumnDefinitions>
                                        <Grid.RowDefinitions>
                                            <RowDefinition Height="22"/>
                                            <RowDefinition Height="22"/>
                                            <RowDefinition Height="22"/>
                                            <RowDefinition Height="22"/>
                                            <RowDefinition Height="22"/>
                                            <RowDefinition Height="22"/>
                                        </Grid.RowDefinitions>
                                        <TextBlock Grid.Row="0" Grid.Column="0" Text="ROM" Foreground="#7C8797" FontSize="10"/>
                                        <TextBlock Grid.Row="0" Grid.Column="1" Name="InfoRom" Text="—" Foreground="#ECEFF4" FontSize="10" TextTrimming="CharacterEllipsis"/>
                                        <TextBlock Grid.Row="1" Grid.Column="0" Text="Title ID" Foreground="#7C8797" FontSize="10"/>
                                        <TextBlock Grid.Row="1" Grid.Column="1" Name="InfoTitle" Text="—" Foreground="#ECEFF4" FontSize="10"/>
                                        <TextBlock Grid.Row="2" Grid.Column="0" Text="DLL" Foreground="#7C8797" FontSize="10"/>
                                        <TextBlock Grid.Row="2" Grid.Column="1" Name="InfoDll" Text="—" Foreground="#ECEFF4" FontSize="10" TextTrimming="CharacterEllipsis"/>
                                        <TextBlock Grid.Row="3" Grid.Column="0" Text="Entry points" Foreground="#7C8797" FontSize="10"/>
                                        <TextBlock Grid.Row="3" Grid.Column="1" Name="InfoEntries" Text="—" Foreground="#ECEFF4" FontSize="10"/>
                                        <TextBlock Grid.Row="4" Grid.Column="0" Text="Código C" Foreground="#7C8797" FontSize="10"/>
                                        <TextBlock Grid.Row="4" Grid.Column="1" Name="InfoCode" Text="—" Foreground="#ECEFF4" FontSize="10"/>
                                        <TextBlock Grid.Row="5" Grid.Column="0" Text="Compilado em" Foreground="#7C8797" FontSize="10"/>
                                        <TextBlock Grid.Row="5" Grid.Column="1" Name="InfoBuilt" Text="—" Foreground="#ECEFF4" FontSize="10"/>
                                    </Grid>
                                </StackPanel>
                                <StackPanel Grid.Column="1">
                                    <TextBlock Text="AÇÕES" Foreground="#00B894" FontWeight="Bold" FontSize="11" Margin="0,0,0,8"/>
                                    <Button Name="BtnStatsSaves" Content="Abrir pasta de saves" Height="30" Background="#252C37" FontSize="10" Margin="0,0,0,6" HorizontalAlignment="Stretch"/>
                                    <Button Name="BtnStatsBackup" Content="Criar backup do save" Height="30" Background="#252C37" FontSize="10" Margin="0,0,0,6" HorizontalAlignment="Stretch"/>
                                    <Button Name="BtnStatsLog" Content="Abrir log do Zakuro" Height="30" Background="#252C37" FontSize="10" HorizontalAlignment="Stretch"/>
                                </StackPanel>
                            </Grid>
                        </Border>
                    </Grid>

                    <!-- SOBRE -->
                    <Grid Name="PageAbout" Visibility="Collapsed">
                        <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
                            <StackPanel Margin="0,0,10,0">
                                <StackPanel Orientation="Horizontal" Margin="0,0,0,14">
                                    <Image Name="ImgAboutLeaf" Width="72" Height="72" Stretch="Uniform" Margin="0,0,16,0"/>
                                    <StackPanel VerticalAlignment="Center">
                                        <TextBlock Text="Animal Crossing: New Leaf" Foreground="#FFFFFF" FontSize="24" FontWeight="Bold"/>
                                        <TextBlock Text="PC Recompiled Launcher" Foreground="#00B894" FontSize="13" FontWeight="SemiBold"/>
                                        <TextBlock Name="TxtAboutVersion" Text="Versão 2.0" Foreground="#7C8797" FontSize="10" Margin="0,3,0,0"/>
                                    </StackPanel>
                                </StackPanel>

                                <Border Background="#20242D" CornerRadius="12" Padding="16" BorderBrush="#2F3643" BorderThickness="1" Margin="0,0,0,12">
                                    <StackPanel>
                                        <TextBlock Text="SOBRE O PROJETO" Foreground="#00B894" FontWeight="Bold" FontSize="11" Margin="0,0,0,8"/>
                                        <TextBlock Text="Launcher para o projeto ACNL-Recomp: recompilação estática de Animal Crossing: New Leaf (Nintendo 3DS) para x86_64. O jogo roda no Zakuro, um emulador HLE que executa o código recompilado como código nativo." TextWrapping="Wrap" Foreground="#C7CEDA" FontSize="11" LineHeight="18"/>
                                    </StackPanel>
                                </Border>

                                <Border Background="#20242D" CornerRadius="12" Padding="16" BorderBrush="#2F3643" BorderThickness="1" Margin="0,0,0,12">
                                    <StackPanel>
                                        <TextBlock Text="CRÉDITOS" Foreground="#00B894" FontWeight="Bold" FontSize="11" Margin="0,0,0,8"/>
                                        <TextBlock Text="Projeto e launcher — Lucas4411 (github.com/Lucas4411)&#x0a;Desenvolvimento assistido por — OpenCode, agente de IA (opencode.ai)&#x0a;Recompilador — 3dsrecomp, de fearkov&#x0a;Runtime do jogo — Zakuro, de fearkov&#x0a;Compilador C — w64devkit (GCC), de skeeto&#x0a;Instalador — Inno Setup  •  Launcher compilado com ps2exe&#x0a;Interface — PowerShell + WPF" TextWrapping="Wrap" Foreground="#C7CEDA" FontSize="10" LineHeight="18"/>
                                    </StackPanel>
                                </Border>

                                <Border Background="#2A221D" CornerRadius="12" Padding="16" BorderBrush="#5E4A2F" BorderThickness="1" Margin="0,0,0,12">
                                    <StackPanel>
                                        <TextBlock Text="AVISO LEGAL" Foreground="#F0A04B" FontWeight="Bold" FontSize="11" Margin="0,0,0,8"/>
                                        <TextBlock Text="Este projeto não contém ROM, assets ou código proprietário da Nintendo. Para jogar, use uma cópia legítima de Animal Crossing: New Leaf e forneça o seu próprio dump (.3ds ou .cxi). A recompilação é feita localmente, na sua máquina, para uso pessoal." TextWrapping="Wrap" Foreground="#D8C7B5" FontSize="10" LineHeight="16"/>
                                    </StackPanel>
                                </Border>

                                <Border Background="#20242D" CornerRadius="12" Padding="16" BorderBrush="#2F3643" BorderThickness="1" Margin="0,0,0,12">
                                    <StackPanel>
                                        <TextBlock Text="ATALHOS NO JOGO" Foreground="#00B894" FontWeight="Bold" FontSize="11" Margin="0,0,0,8"/>
                                        <TextBlock Text="Esc — menu do Zakuro&#x0a;F1 — pausar / despausar&#x0a;F9 — trocar o layout das telas&#x0a;F10 — inverter tela grande e pequena&#x0a;F11 — tela cheia&#x0a;Tab — fast-forward (segurar)&#x0a;F5 / F8 — salvar / carregar estado" TextWrapping="Wrap" Foreground="#C7CEDA" FontSize="10" LineHeight="18"/>
                                    </StackPanel>
                                </Border>

                                <StackPanel Orientation="Horizontal">
                                    <Button Name="BtnOpenReadme" Content="Abrir README" Height="30" Background="#252C37" FontSize="10" Margin="0,0,8,0" Padding="10,4"/>
                                    <Button Name="BtnOpenProject" Content="Abrir pasta do projeto" Height="30" Background="#252C37" FontSize="10" Margin="0,0,8,0" Padding="10,4"/>
                                    <Button Name="BtnOpenZakuroSettings" Content="settings.toml" Height="30" Background="#252C37" FontSize="10" Margin="0,0,8,0" Padding="10,4"/>
                                    <Button Name="BtnOpenAuthor" Content="GitHub do autor" Height="30" Background="#252C37" FontSize="10" Margin="0,0,8,0" Padding="10,4"/>
                                    <Button Name="BtnOpenOpenCode" Content="OpenCode" Height="30" Background="#252C37" FontSize="10" Padding="10,4"/>
                                </StackPanel>
                            </StackPanel>
                        </ScrollViewer>
                    </Grid>
                </Grid>
            </Grid>

            <!-- Rodapé -->
            <Grid Grid.Row="2" Background="#101317">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <TextBlock Grid.Column="0" Text="Esc menu  •  F1 pausa  •  F9 layout  •  F10 inverter telas  •  F11 tela cheia  •  Tab fast-forward" Foreground="#57606F" FontSize="9" VerticalAlignment="Center" Margin="20,0,0,0"/>
                <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center" Margin="0,0,16,0">
                    <TextBlock Name="TxtFooterStatus" Text="Pronto" Foreground="#57606F" FontSize="9" VerticalAlignment="Center" Margin="0,0,10,0"/>
                    <Button Name="BtnApply" Content="Salvar configurações" Height="24" Background="#00B894" Foreground="#0B1410" FontSize="9" Padding="10,2"/>
                </StackPanel>
            </Grid>
        </Grid>
    </Border>
</Window>
'@

$Reader = [System.Xml.XmlNodeReader]::new($Xaml)
$Window = [System.Windows.Markup.XamlReader]::Load($Reader)

# ------------------------------------------------------------------------------
# Controles nomeados
# ------------------------------------------------------------------------------
$ControlNames = @(
    'TitleBar', 'BtnMin', 'BtnClose', 'ImgLogo', 'ImgSidebarLeaf', 'ImgAboutLeaf',
    'NavPlay', 'NavGraphics', 'NavControls', 'NavStats', 'NavAbout',
    'PagePlay', 'PageGraphics', 'PageControls', 'PageStats', 'PageAbout',
    'TxtHeroStatus', 'TxtHeroSub', 'PillStatus', 'TxtPill', 'TxtSessionLive',
    'BtnPlay', 'BtnRecompile', 'BtnSidebarPlay', 'TxtSidebarStatus',
    'TxtRomPath', 'BtnBrowse', 'BtnOpenSaves', 'BtnOpenOutput', 'BtnBackup',
    'BtnOpenLog', 'BtnOpenSettings', 'TxtLog', 'CompileProgress',
    'GfxCol1', 'GfxCol2', 'KbPanel', 'PadPanel', 'BtnResetKb', 'BtnResetPad',
    'StatTotal', 'StatSessions', 'StatLastSession', 'StatLastPlayed',
    'StatsChart', 'StatsEmpty', 'InfoRom', 'InfoTitle', 'InfoDll', 'InfoEntries',
    'InfoCode', 'InfoBuilt', 'BtnClearStats', 'BtnStatsSaves', 'BtnStatsBackup',
    'BtnStatsLog', 'TxtAboutVersion', 'BtnOpenReadme', 'BtnOpenProject',
    'BtnOpenZakuroSettings', 'BtnOpenAuthor', 'BtnOpenOpenCode', 'TxtFooterStatus', 'BtnApply'
)
foreach ($name in $ControlNames) {
    Set-Variable -Name $name -Value ($Window.FindName($name)) -Scope Script
}

# Ícone / imagens
if (Test-Path $LeafPng) {
    try {
        $bitmap = [System.Windows.Media.Imaging.BitmapImage]::new()
        $bitmap.BeginInit()
        $bitmap.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $bitmap.UriSource = [System.Uri]::new($LeafPng)
        $bitmap.EndInit()
        $bitmap.Freeze()
        $Window.Icon = $bitmap
        $ImgLogo.Source = $bitmap
        $ImgSidebarLeaf.Source = $bitmap
        $ImgAboutLeaf.Source = $bitmap
    } catch {}
}

$TxtAboutVersion.Text = "Versão $LauncherVersion  •  por Lucas4411  •  Zakuro HLE + 3dsrecomp"

# ------------------------------------------------------------------------------
# Estado do jogo / recompilação
# ------------------------------------------------------------------------------
$script:GameProcess = $null
$script:SessionStart = $null
$script:RecompProc = $null
$script:RecompOutLog = ""
$script:RecompErrLog = ""
$script:RecompOutPos = 0
$script:RecompErrPos = 0
$script:RecompCancelled = $false
$script:RecompTotal = 0
$script:RecompLastCount = [DateTime]::MinValue

# Janela do Zakuro (titulo/icone personalizados)
$script:GameWindowTitle = "Animal Crossing: New Leaf"
$script:GameHwnd = [IntPtr]::Zero
$script:GameHicon = [IntPtr]::Zero
$script:TitleGuardInstalled = $false

# ------------------------------------------------------------------------------
# Log
# ------------------------------------------------------------------------------
function Write-GuiLog {
    param([string]$Message)
    if (-not $TxtLog) { return }
    $timestamp = (Get-Date).ToString("HH:mm:ss")
    foreach ($line in ($Message -split "`r?`n")) {
        if ($line.Trim() -eq '') { continue }
        $TxtLog.AppendText("[$timestamp] $line`r`n")
    }
    $TxtLog.ScrollToEnd()
}

# ------------------------------------------------------------------------------
# Status
# ------------------------------------------------------------------------------
function Update-StatusUI {
    $hasRom = ($TxtRomPath.Text -and (Test-Path $TxtRomPath.Text))
    $hasDll = Test-RecompDll
    $running = ($script:GameProcess -and -not $script:GameProcess.HasExited)

    if ($running) {
        $TxtHeroStatus.Text = "Jogando Animal Crossing"
        $TxtHeroSub.Text = "Zakuro em execução. Use Esc para abrir o menu do jogo."
        $TxtPill.Text = "EM EXECUÇÃO"
        $PillStatus.Background = Brush "#173B31"
        $TxtPill.Foreground = Brush "#00B894"
        $TxtSidebarStatus.Text = "Jogando..."
        $BtnPlay.IsEnabled = $false
        $BtnSidebarPlay.IsEnabled = $false
        $BtnRecompile.IsEnabled = $false
        return
    }

    if (-not $hasRom) {
        $TxtHeroStatus.Text = "ROM necessária"
        $TxtHeroSub.Text = "Selecione o arquivo .3ds ou .cxi para começar."
        $TxtPill.Text = "AGUARDANDO ROM"
        $PillStatus.Background = Brush "#3A2A1D"
        $TxtPill.Foreground = Brush "#F0A04B"
        $TxtSidebarStatus.Text = "Sem ROM"
        $BtnPlay.IsEnabled = $false
        $BtnSidebarPlay.IsEnabled = $false
        $BtnRecompile.IsEnabled = $false
        return
    }

    if (-not $hasDll) {
        $TxtHeroStatus.Text = "Recompilação necessária"
        $TxtHeroSub.Text = "A DLL do jogo ainda não foi gerada. Clique em Recompilar para começar."
        $TxtPill.Text = "RECOMPILAR"
        $PillStatus.Background = Brush "#3A321D"
        $TxtPill.Foreground = Brush "#F1C40F"
        $TxtSidebarStatus.Text = "Recompilar"
        $BtnPlay.Content = "▶  RECOMPILAR"
        $BtnSidebarPlay.Content = "▶  RECOMPILAR"
        $BtnPlay.IsEnabled = $true
        $BtnSidebarPlay.IsEnabled = $true
        $BtnRecompile.IsEnabled = $true
        return
    }

    $TxtHeroStatus.Text = "Pronto para jogar"
    $TxtHeroSub.Text = "Código nativo x86_64  •  Zakuro HLE  •  $($Config.Renderer)"
    $TxtPill.Text = "PRONTO"
    $PillStatus.Background = Brush "#173B31"
    $TxtPill.Foreground = Brush "#00B894"
    $TxtSidebarStatus.Text = "Pronto"
    $BtnPlay.Content = "▶  JOGAR"
    $BtnSidebarPlay.Content = "▶  JOGAR"
    $BtnPlay.IsEnabled = $true
    $BtnSidebarPlay.IsEnabled = $true
    $BtnRecompile.IsEnabled = $true
}

# ------------------------------------------------------------------------------
# Estatísticas
# ------------------------------------------------------------------------------
function Update-StatsUI {
    $st = $Config.Stats
    $StatTotal.Text = Format-Duration $st.TotalSeconds
    $StatSessions.Text = [string]$st.Sessions

    if ([double]$st.LastSessionSeconds -gt 0) {
        $StatLastSession.Text = Format-Duration $st.LastSessionSeconds
    } else {
        $StatLastSession.Text = "—"
    }

    if ($st.LastPlayed) {
        try { $StatLastPlayed.Text = ([datetime]::Parse($st.LastPlayed)).ToString("dd/MM/yyyy HH:mm") }
        catch { $StatLastPlayed.Text = [string]$st.LastPlayed }
    } else {
        $StatLastPlayed.Text = "—"
    }

    # Informações do jogo
    if ($Config.RomPath -and (Test-Path $Config.RomPath)) {
        $romItem = Get-Item $Config.RomPath
        $InfoRom.Text = "$($romItem.Name)  •  $(Format-Bytes $romItem.Length)"
        $InfoRom.ToolTip = $Config.RomPath
    } else {
        $InfoRom.Text = "—"
        $InfoRom.ToolTip = ""
    }

    $InfoTitle.Text = $TitleId

    if (Test-Path $DllPath) {
        $dllItem = Get-Item $DllPath
        $InfoDll.Text = "$($dllItem.Name)  •  $(Format-Bytes $dllItem.Length)"
        $InfoDll.ToolTip = $DllPath
        $InfoBuilt.Text = $dllItem.LastWriteTime.ToString("dd/MM/yyyy HH:mm")
    } else {
        $InfoDll.Text = "—"
        $InfoDll.ToolTip = ""
        $InfoBuilt.Text = "—"
    }

    $entries = "—"
    $logPath = Join-Path $GameDataDir "zakuro.log"
    if (Test-Path $logPath) {
        try {
            $match = Select-String -Path $logPath -Pattern '(\d+)\s+entry points' | Select-Object -Last 1
            if ($match -and $match.Matches.Count -gt 0) { $entries = $match.Matches[0].Groups[1].Value }
        } catch {}
    }
    if ($entries -eq "—" -and (Test-Path $HintsPath)) {
        try {
            $count = @(Get-Content $HintsPath -Encoding UTF8 | Where-Object { $_ -match '^[0-9A-Fa-f]{8}$' }).Count
            if ($count -gt 0) { $entries = [string]$count }
        } catch {}
    }
    $InfoEntries.Text = $entries

    $cFiles = @(Get-ChildItem $OutputDir -Filter *.c -File -ErrorAction SilentlyContinue)
    if ($cFiles.Count -gt 0) {
        $cSize = ($cFiles | Measure-Object Length -Sum).Sum
        $InfoCode.Text = "$($cFiles.Count) arquivos .c  •  $(Format-Bytes $cSize)"
    } else {
        $InfoCode.Text = "—"
    }

    # Gráfico das últimas sessões
    $StatsChart.Children.Clear()
    $hist = @($Config.Stats.History)
    if ($hist.Count -eq 0) {
        $StatsEmpty.Visibility = "Visible"
        return
    }

    $StatsEmpty.Visibility = "Collapsed"
    $recent = @($hist | Select-Object -Last 7)
    $maxSec = 1.0
    foreach ($h in $recent) {
        $s = [double](Get-Prop $h 'Seconds')
        if ($s -gt $maxSec) { $maxSec = $s }
    }

    for ($i = 0; $i -lt $recent.Count; $i++) {
        $h = $recent[$i]
        $sec = [double](Get-Prop $h 'Seconds')
        $dateStr = [string](Get-Prop $h 'Date')
        $height = 8 + [int](($sec / $maxSec) * 88)

        $col = [System.Windows.Controls.Grid]::new()
        $col.Width = 46
        $col.Margin = "0,0,4,0"
        $r0 = [System.Windows.Controls.RowDefinition]::new()
        $r0.Height = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
        $r1 = [System.Windows.Controls.RowDefinition]::new()
        $r1.Height = [System.Windows.GridLength]::new(18)
        $col.RowDefinitions.Add($r0)
        $col.RowDefinitions.Add($r1)

        $bar = [System.Windows.Controls.Border]::new()
        $bar.Width = 26
        $bar.Height = $height
        $bar.CornerRadius = "4"
        if ($i -eq $recent.Count - 1) {
            $bar.Background = Brush "#00B894"
        } else {
            $bar.Background = Brush "#1F6F5C"
        }
        $bar.HorizontalAlignment = "Center"
        $bar.VerticalAlignment = "Bottom"
        $bar.ToolTip = "$(Format-Duration $sec) — $dateStr"
        [System.Windows.Controls.Grid]::SetRow($bar, 0)

        $lbl = [System.Windows.Controls.TextBlock]::new()
        $lbl.Text = Format-ShortDate $dateStr
        $lbl.Foreground = Brush "#7C8797"
        $lbl.FontSize = 9
        $lbl.HorizontalAlignment = "Center"
        $lbl.VerticalAlignment = "Bottom"
        [System.Windows.Controls.Grid]::SetRow($lbl, 1)

        $col.Children.Add($bar) | Out-Null
        $col.Children.Add($lbl) | Out-Null
        $StatsChart.Children.Add($col) | Out-Null
    }
}

# ------------------------------------------------------------------------------
# Sessão de jogo
# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
# Janela do jogo: titulo limpo + icone da folha
# ------------------------------------------------------------------------------
function Update-GameWindow {
    if (-not $script:GameProcess) { return }
    try {
        if ($script:GameProcess.HasExited) { return }
    } catch { return }

    if ($script:GameHwnd -eq [IntPtr]::Zero) {
        try {
            $script:GameHwnd = [ACNLGameWindow]::FindByProcessId([uint32]$script:GameProcess.Id)
        } catch { return }
        if ($script:GameHwnd -eq [IntPtr]::Zero) { return }
    }
    if (-not [ACNLGameWindow]::IsWindow($script:GameHwnd)) {
        $script:GameHwnd = [IntPtr]::Zero
        return
    }

    # Gancho instantaneo: o Zakuro reescreve o titulo e nos devolvemos na hora
    if (-not $script:TitleGuardInstalled) {
        try {
            $script:TitleGuardInstalled = [ACNLTitleGuard]::Install($script:GameHwnd, [uint32]$script:GameProcess.Id, $script:GameWindowTitle)
        } catch { $script:TitleGuardInstalled = $false }
    }

    # O icone e aplicado uma unica vez por janela
    if ($script:GameHicon -eq [IntPtr]::Zero -and (Test-Path $LeafIco)) {
        try {
            $script:GameHicon = [ACNLGameWindow]::LoadImage([IntPtr]::Zero, $LeafIco, 1, 0, 0, 0x50)
            if ($script:GameHicon -ne [IntPtr]::Zero) {
                [ACNLGameWindow]::SendMessage($script:GameHwnd, 0x0080, [IntPtr]::Zero, $script:GameHicon) | Out-Null
                [ACNLGameWindow]::SendMessage($script:GameHwnd, 0x0080, [IntPtr]1, $script:GameHicon) | Out-Null
            }
        } catch { $script:GameHicon = [IntPtr]::Zero }
    }

    # O Zakuro reescreve o titulo a cada ~500 ms; reaplicamos o nosso.
    try {
        $sb = [System.Text.StringBuilder]::new(256)
        [ACNLGameWindow]::GetWindowText($script:GameHwnd, $sb, $sb.Capacity) | Out-Null
        if ($sb.ToString() -ne $script:GameWindowTitle) {
            [ACNLGameWindow]::SetWindowText($script:GameHwnd, $script:GameWindowTitle) | Out-Null
        }
    } catch {}
}

function Clear-GameWindow {
    if ($script:GameWindowTimer) { $script:GameWindowTimer.Stop() }
    if ($script:TitleGuardInstalled) {
        try { [ACNLTitleGuard]::Uninstall() } catch {}
        $script:TitleGuardInstalled = $false
    }
    $stillRunning = $false
    if ($script:GameProcess) {
        try { $stillRunning = -not $script:GameProcess.HasExited } catch { $stillRunning = $false }
    }
    if (-not $stillRunning -and $script:GameHicon -ne [IntPtr]::Zero) {
        try { [ACNLGameWindow]::DestroyIcon($script:GameHicon) | Out-Null } catch {}
        $script:GameHicon = [IntPtr]::Zero
    }
    $script:GameHwnd = [IntPtr]::Zero
}

function Finish-GameSession {
    if (-not $script:SessionStart) { return }

    $seconds = ((Get-Date) - $script:SessionStart).TotalSeconds
    if ($seconds -lt 1) { $seconds = 1 }

    $Config.Stats.TotalSeconds = [double]$Config.Stats.TotalSeconds + $seconds
    $Config.Stats.LastSessionSeconds = [double]$seconds

    $hist = @($Config.Stats.History)
    $hist += @{ Date = (Get-Date).ToString("o"); Seconds = [double]$seconds }
    if ($hist.Count -gt 30) {
        $hist = $hist[($hist.Count - 30)..($hist.Count - 1)]
    }
    $Config.Stats.History = $hist

    Save-Config
    $script:GameProcess = $null
    $script:SessionStart = $null
    if ($script:GameTimer) { $script:GameTimer.Stop() }
    Clear-GameWindow
    $TxtSessionLive.Text = ""
    Write-GuiLog "Sessão encerrada: $(Format-Duration $seconds)."
    Update-StatsUI
    Update-StatusUI
}

$script:GameTimer = [System.Windows.Threading.DispatcherTimer]::new()
$script:GameTimer.Interval = [TimeSpan]::FromSeconds(1)
$script:GameTimer.Add_Tick({
    if (-not $script:GameProcess -or -not $script:SessionStart) {
        $script:GameTimer.Stop()
        return
    }
    $exited = $false
    try { $exited = $script:GameProcess.HasExited } catch { $exited = $true }
    if ($exited) {
        Finish-GameSession
    } else {
        $elapsed = (Get-Date) - $script:SessionStart
        $TxtSessionLive.Text = "Jogando há $(Format-Duration $elapsed.TotalSeconds)"
        $TxtSidebarStatus.Text = "Jogando..."
    }
})

$script:GameWindowTimer = [System.Windows.Threading.DispatcherTimer]::new()
$script:GameWindowTimer.Interval = [TimeSpan]::FromMilliseconds(500)
$script:GameWindowTimer.Add_Tick({
    if (-not $script:GameProcess) {
        $script:GameWindowTimer.Stop()
        return
    }
    Update-GameWindow
})

# ------------------------------------------------------------------------------
# Abrir pastas / arquivos
# ------------------------------------------------------------------------------
function Open-Path {
    param([string]$Path)
    if (Test-Path $Path) {
        Start-Process -FilePath "explorer.exe" -ArgumentList "`"$Path`"" | Out-Null
    } else {
        [System.Windows.MessageBox]::Show("Pasta não encontrada:`n$Path", "Aviso", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
    }
}

function Open-File {
    param([string]$Path)
    if (Test-Path $Path) {
        Start-Process -FilePath "notepad.exe" -ArgumentList "`"$Path`"" | Out-Null
    } else {
        [System.Windows.MessageBox]::Show("Arquivo não encontrado:`n$Path", "Aviso", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
    }
}

function Backup-Save {
    if ($script:GameProcess -and -not $script:GameProcess.HasExited) {
        [System.Windows.MessageBox]::Show("Feche o jogo antes de criar um backup do save.", "Jogo em execução", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
        return
    }
    if (-not (Test-Path $GameDataDir)) {
        [System.Windows.MessageBox]::Show("A pasta de dados do jogo não foi encontrada.", "Aviso", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
        return
    }

    $backupDir = Join-Path $RootPath "backups"
    if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir -Force | Out-Null }
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $zip = Join-Path $backupDir "save-$stamp.zip"

    try {
        Compress-Archive -Path (Join-Path $GameDataDir '*') -DestinationPath $zip -Force
        Write-GuiLog "Backup criado: $zip"
        Set-Footer "Backup criado."
        [System.Windows.MessageBox]::Show("Backup criado com sucesso:`n$zip", "Backup", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
    } catch {
        Write-GuiLog "ERRO ao criar backup: $_"
        [System.Windows.MessageBox]::Show("Não foi possível criar o backup:`n$_", "Erro", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) | Out-Null
    }
}

# ------------------------------------------------------------------------------
# Recompilação
# ------------------------------------------------------------------------------
function Read-NewLog {
    param([string]$Path, [long]$Pos)
    $result = @{ Text = ""; Pos = $Pos }
    if (-not (Test-Path $Path)) { return $result }
    try {
        $fs = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        try {
            if ($Pos -gt $fs.Length) { $Pos = 0 }
            $fs.Seek($Pos, [System.IO.SeekOrigin]::Begin) | Out-Null
            $len = [int]($fs.Length - $fs.Position)
            if ($len -gt 0) {
                $buffer = New-Object byte[] $len
                $read = $fs.Read($buffer, 0, $len)
                $result.Text = [System.Text.Encoding]::UTF8.GetString($buffer, 0, $read)
            }
            $result.Pos = $fs.Position
        } finally {
            $fs.Dispose()
        }
    } catch {}
    return $result
}

$script:RecompTimer = [System.Windows.Threading.DispatcherTimer]::new()
$script:RecompTimer.Interval = [TimeSpan]::FromMilliseconds(400)
$script:RecompTimer.Add_Tick({
    if (-not $script:RecompProc) {
        $script:RecompTimer.Stop()
        return
    }

    $r1 = Read-NewLog $script:RecompOutLog $script:RecompOutPos
    $script:RecompOutPos = $r1.Pos
    if ($r1.Text) {
        Write-GuiLog $r1.Text.TrimEnd()

        # O 3dsrecomp imprime "compiled X of Y" a cada arquivo compilado.
        # Guardamos o total para transformar a contagem de objetos em uma
        # barra de progresso.
        $progMatches = [regex]::Matches($r1.Text, 'compiled\s+(\d+)\s+of\s+(\d+)')
        if ($progMatches.Count -gt 0) {
            $lastProg = $progMatches[$progMatches.Count - 1]
            $done = [int]$lastProg.Groups[1].Value
            $total = [int]$lastProg.Groups[2].Value
            if ($total -gt 0) {
                $script:RecompTotal = $total
                $pct = [int][Math]::Min(100, [Math]::Round(100.0 * $done / $total))
                $CompileProgress.IsIndeterminate = $false
                $CompileProgress.Value = $pct
                Set-Footer ("Recompilando... $done de $total ($pct%)")
            }
        }
        if ($r1.Text -match 'built\s+.*\s+in\s+|installed\s+') {
            $CompileProgress.Value = 100
            Set-Footer "Finalizando recompilação..."
        }
    }

    $r2 = Read-NewLog $script:RecompErrLog $script:RecompErrPos
    $script:RecompErrPos = $r2.Pos
    if ($r2.Text) { Write-GuiLog ("AVISO: " + $r2.Text.TrimEnd()) }

    # Contagem de objetos para a barra andar de forma mais suave do que as
    # atualizacoes do log (no maximo uma vez por segundo). Inclui a subpasta
    # hand e nunca deixa a barra andar para tras.
    if ($script:RecompTotal -gt 0) {
        $nowCount = [DateTime]::UtcNow
        if (($nowCount - $script:RecompLastCount).TotalMilliseconds -ge 1000) {
            $script:RecompLastCount = $nowCount
            $objCount = @(Get-ChildItem -LiteralPath $OutputDir -Filter *.o -File -ErrorAction SilentlyContinue).Count
            $handDir = Join-Path $OutputDir "hand"
            if (Test-Path $handDir) {
                $objCount += @(Get-ChildItem -LiteralPath $handDir -Filter *.o -File -ErrorAction SilentlyContinue).Count
            }
            if ($objCount -gt 0) {
                $pct = [int][Math]::Min(100, [Math]::Round(100.0 * $objCount / $script:RecompTotal))
                if ($pct -gt $CompileProgress.Value) {
                    $CompileProgress.IsIndeterminate = $false
                    $CompileProgress.Value = $pct
                    Set-Footer ("Recompilando... $objCount de $($script:RecompTotal) ($pct%)")
                }
            }
        }
    }

    $exited = $false
    try { $exited = $script:RecompProc.HasExited } catch { $exited = $true }
    if (-not $exited) { return }

    $r1 = Read-NewLog $script:RecompOutLog $script:RecompOutPos
    $script:RecompOutPos = $r1.Pos
    if ($r1.Text) { Write-GuiLog $r1.Text.TrimEnd() }

    $r2 = Read-NewLog $script:RecompErrLog $script:RecompErrPos
    $script:RecompErrPos = $r2.Pos
    if ($r2.Text) { Write-GuiLog ("AVISO: " + $r2.Text.TrimEnd()) }

    $code = -1
    try { $code = $script:RecompProc.ExitCode } catch {}
    $script:RecompProc = $null
    $script:RecompTimer.Stop()

    $CompileProgress.Visibility = "Collapsed"
    $CompileProgress.IsIndeterminate = $false
    $CompileProgress.Value = 0
    $BtnRecompile.Content = "Recompilar"
    $BtnRecompile.IsEnabled = $true
    $BtnPlay.IsEnabled = $true
    $BtnSidebarPlay.IsEnabled = $true

    if ($script:RecompCancelled) {
        $script:RecompCancelled = $false
        Write-GuiLog "Recompilação cancelada pelo usuário."
        Set-Footer "Recompilação cancelada."
        Update-StatusUI
        Update-StatsUI
        return
    }

    if (Test-RecompDll) {
        Write-GuiLog "SUCESSO! DLL recompilada (código $code)."
        Set-Footer "Recompilação concluída."
    } else {
        Write-GuiLog "A recompilação terminou com código $code, mas a DLL não foi encontrada."
        Set-Footer "Falha na recompilação."
    }
    Update-StatusUI
    Update-StatsUI
})

function Stop-RecompileProcess {
    if (-not $script:RecompProc) { return }
    try {
        if (-not $script:RecompProc.HasExited) {
            $script:RecompCancelled = $true
            Write-GuiLog "Cancelando recompilação..."
            Set-Footer "Cancelando..."
            $targetPid = $script:RecompProc.Id
            try {
                & taskkill.exe /PID $targetPid /T /F 2>$null | Out-Null
            } catch {
                Stop-Process -Id $targetPid -Force -ErrorAction SilentlyContinue
            }
        }
    } catch {
        Write-GuiLog ("ERRO ao cancelar a recompilação: " + $_.Exception.Message)
    }
}

function Start-RecompileProcess {
    $rom = $TxtRomPath.Text
    if (-not $rom -or -not (Test-Path $rom)) {
        [System.Windows.MessageBox]::Show("Selecione uma ROM válida primeiro.", "Aviso", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
        return
    }
    if (-not (Test-Path $RecompExe)) {
        Write-GuiLog "ERRO: 3dsrecomp.exe não encontrado em: $RecompExe"
        [System.Windows.MessageBox]::Show("O recompilador não foi encontrado:`n$RecompExe", "Erro", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) | Out-Null
        return
    }
    if ($script:RecompProc -and -not $script:RecompProc.HasExited) {
        Write-GuiLog "Já existe uma recompilação em andamento."
        return
    }
    if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null }

    # Remove objetos de builds anteriores para o progresso comecar do zero.
    Get-ChildItem -LiteralPath $OutputDir -Filter *.o -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    $handDir = Join-Path $OutputDir "hand"
    if (Test-Path $handDir) {
        Get-ChildItem -LiteralPath $handDir -Filter *.o -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    }

    $script:RecompCancelled = $false
    $script:RecompTotal = 0
    $script:RecompLastCount = [DateTime]::MinValue
    $BtnPlay.IsEnabled = $false
    $BtnSidebarPlay.IsEnabled = $false
    $BtnRecompile.Content = "Cancelar"
    $BtnRecompile.IsEnabled = $true
    $CompileProgress.Visibility = "Visible"
    $CompileProgress.IsIndeterminate = $true
    $CompileProgress.Value = 0
    Set-Footer "Analisando a ROM..."

    Write-GuiLog "Iniciando análise e recompilação..."
    Write-GuiLog "ROM: $rom"
    Write-GuiLog "Destino: $OutputDir"
    Write-GuiLog "Aguarde, isso pode levar alguns minutos..."

    $script:RecompOutLog = Join-Path $env:TEMP "acnl-recomp-out.log"
    $script:RecompErrLog = Join-Path $env:TEMP "acnl-recomp-err.log"
    Remove-Item $script:RecompOutLog, $script:RecompErrLog -Force -ErrorAction SilentlyContinue
    $script:RecompOutPos = 0
    $script:RecompErrPos = 0

    try {
        $proc = Start-Process -FilePath $RecompExe `
            -ArgumentList "build `"$rom`" `"$OutputDir`"" `
            -WorkingDirectory $RootPath `
            -RedirectStandardOutput $script:RecompOutLog `
            -RedirectStandardError $script:RecompErrLog `
            -NoNewWindow -PassThru
        $script:RecompProc = $proc
        $script:RecompTimer.Start()
    } catch {
        $CompileProgress.Visibility = "Collapsed"
        $CompileProgress.IsIndeterminate = $false
        $CompileProgress.Value = 0
        $BtnRecompile.Content = "Recompilar"
        $BtnRecompile.IsEnabled = $true
        $BtnPlay.IsEnabled = $true
        $BtnSidebarPlay.IsEnabled = $true
        Write-GuiLog "ERRO ao iniciar a recompilação: $_"
    }
}

# ------------------------------------------------------------------------------
# Iniciar jogo
# ------------------------------------------------------------------------------
function Launch-Game {
    if (-not $TxtRomPath.Text -or -not (Test-Path $TxtRomPath.Text)) {
        [System.Windows.MessageBox]::Show("Selecione uma ROM válida primeiro.", "Aviso", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
        return
    }
    if (-not (Test-RecompDll)) {
        Start-RecompileProcess
        return
    }
    if ($script:GameProcess -and -not $script:GameProcess.HasExited) {
        [System.Windows.MessageBox]::Show("O jogo já está em execução.", "Aviso", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
        return
    }

    Apply-Settings
    Write-GuiLog "Iniciando Animal Crossing: New Leaf no Zakuro..."

    $renderer = Get-ComboTag $CmbRenderer
    if (-not $renderer) { $renderer = $Config.Renderer }
    $scale = Get-ComboTag $CmbScale
    if (-not $scale) { $scale = [string]$Config.Scale }
    $rasterizer = Get-ComboTag $CmbRasterizer
    if (-not $rasterizer) { $rasterizer = $Config.Rasterizer }

    $argsList = @(
        "`"$($TxtRomPath.Text)`"",
        "--recompiled", "`"$OutputDir`"",
        "--renderer", "$renderer",
        "--rasterizer", "$rasterizer",
        "--scale", "$scale",
        "--data", "`"$GameDataDir`""
    )
    if ($Config.New3DS) { $argsList += "--new3ds" }
    if ($Config.Mute) { $argsList += "--mute" }

    $env:ZAKURO_SHADER_JIT = "0"

    Write-GuiLog "Executando: zakuro.exe $($argsList -join ' ')"

    try {
        $psi = [System.Diagnostics.ProcessStartInfo]::new()
        $psi.FileName = $ZakuroExe
        $psi.Arguments = ($argsList -join " ")
        $psi.WorkingDirectory = $RootPath
        $psi.UseShellExecute = $true

        $proc = [System.Diagnostics.Process]::Start($psi)
        if ($null -eq $proc) { throw "O processo não foi iniciado." }

        $script:GameProcess = $proc
        $script:SessionStart = Get-Date
        $script:GameHwnd = [IntPtr]::Zero
        $script:TitleGuardInstalled = $false
        $Config.Stats.Sessions = [int]$Config.Stats.Sessions + 1
        $Config.Stats.LastPlayed = (Get-Date).ToString("o")
        Save-Config
        $script:GameTimer.Start()
        $script:GameWindowTimer.Start()
        Update-StatusUI
        Write-GuiLog "Jogo iniciado (PID $($proc.Id)). Bom jogo!"
    } catch {
        Write-GuiLog "ERRO ao iniciar o Zakuro: $_"
        [System.Windows.MessageBox]::Show("Não foi possível iniciar o Zakuro:`n$_", "Erro", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) | Out-Null
    }
}

# ------------------------------------------------------------------------------
# Montagem da página de gráficos
# ------------------------------------------------------------------------------
$LayoutItems = @(
    @{ Content = 'Uma sobre a outra (3DS real)'; Tag = 'stacked' },
    @{ Content = 'Lado a lado'; Tag = 'side_by_side' },
    @{ Content = 'Tela grande + pequena ao lado'; Tag = 'large_top' },
    @{ Content = 'Apenas tela superior'; Tag = 'top_only' },
    @{ Content = 'Apenas tela inferior'; Tag = 'bottom_only' }
)

$ResolutionItems = @()
foreach ($n in 1..6) {
    $w = 400 * $n
    $h = 240 * $n
    $ResolutionItems += @{ Content = "$($n)x  ($w x $h)"; Tag = "$n" }
}

$ScaleItems = @()
foreach ($n in 1..6) {
    $w = 400 * $n
    $h = 480 * $n
    $ScaleItems += @{ Content = "$($n)x  ($w x $h)"; Tag = "$n" }
}

$RendererItems = @(
    @{ Content = 'Vulkan (recomendado)'; Tag = 'vulkan' },
    @{ Content = 'OpenGL (compatibilidade)'; Tag = 'opengl' }
)

$RasterizerItems = @(
    @{ Content = 'Hardware (GPU)'; Tag = 'hardware' },
    @{ Content = 'Software (CPU)'; Tag = 'software' }
)

$FilterItems = @(
    @{ Content = 'Suave (smooth)'; Tag = 'smooth' },
    @{ Content = 'Nítido (sharp)'; Tag = 'sharp' },
    @{ Content = 'Pixels (retro)'; Tag = 'pixels' }
)

$TopShapeItems = @(
    @{ Content = 'Console (5:3)'; Tag = 'console' },
    @{ Content = 'Widescreen 16:9'; Tag = 'wide16x9' },
    @{ Content = 'Ultrawide 21:9'; Tag = 'wide21x9' }
)

$OrientationItems = @(
    @{ Content = '0° (normal)'; Tag = 'north' },
    @{ Content = '90°'; Tag = 'east' },
    @{ Content = '180°'; Tag = 'south' },
    @{ Content = '270°'; Tag = 'west' }
)

$StereoItems = @(
    @{ Content = 'Desligado'; Tag = 'off' },
    @{ Content = 'Anaglifo (óculos vermelho/ciano)'; Tag = 'anaglyph' },
    @{ Content = 'Lado a lado'; Tag = 'side_by_side' },
    @{ Content = 'Lado a lado (meia largura)'; Tag = 'half_side_by_side' },
    @{ Content = 'Linhas alternadas'; Tag = 'interlaced' }
)

$LanguageItems = @(
    @{ Content = 'Japonês'; Tag = 'japanese' },
    @{ Content = 'Inglês'; Tag = 'english' },
    @{ Content = 'Francês'; Tag = 'french' },
    @{ Content = 'Alemão'; Tag = 'german' },
    @{ Content = 'Italiano'; Tag = 'italian' },
    @{ Content = 'Espanhol'; Tag = 'spanish' },
    @{ Content = 'Chinês (simplificado)'; Tag = 'chinese_simplified' },
    @{ Content = 'Coreano'; Tag = 'korean' },
    @{ Content = 'Holandês'; Tag = 'dutch' },
    @{ Content = 'Português'; Tag = 'portuguese' },
    @{ Content = 'Russo'; Tag = 'russian' },
    @{ Content = 'Chinês (tradicional)'; Tag = 'chinese_traditional' }
)

$secDisplay = New-Section $GfxCol1 "TELA"
$CmbLayout      = Add-ComboField $secDisplay "Disposição das telas" $LayoutItems $Config.Layout "Como as duas telas aparecem na janela."
$CmbOrientation = Add-ComboField $secDisplay "Orientação" $OrientationItems $Config.Orientation "Rotação das telas."
$CmbTopShape    = Add-ComboField $secDisplay "Formato da tela superior" $TopShapeItems $Config.TopShape "16:9 e 21:9 só ficam corretos com códigos widescreen."
$CmbScale       = Add-ComboField $secDisplay "Tamanho da janela" $ScaleItems $Config.Scale "Escala da janela em relação às telas do console."
$CmbFilter      = Add-ComboField $secDisplay "Filtro de escala" $FilterItems $Config.Filter "Como os pixels são ampliados."
$ChkIntegerScale = Add-CheckField $secDisplay "Escala inteira (bordas em vez de esticar)" $Config.IntegerScale "Evita pixels cortados usando apenas múltiplos inteiros."

$BtnFillScreen = [System.Windows.Controls.Button]::new()
$BtnFillScreen.Content = 'Preencher tela (16:9)'
$BtnFillScreen.Height = 30
$BtnFillScreen.FontSize = 10
$BtnFillScreen.Padding = '10,4'
$BtnFillScreen.HorizontalAlignment = 'Left'
$BtnFillScreen.Background = Brush "#00B894"
$BtnFillScreen.Foreground = Brush "#0B1410"
$BtnFillScreen.ToolTip = 'Usa apenas a tela superior no formato 16:9, que preenche a tela inteira no fullscreen sem bordas. No jogo, F10 alterna para a tela inferior.'
$BtnFillScreen.Add_Click({
    Set-ComboTag $CmbLayout 'top_only'
    Set-ComboTag $CmbTopShape 'wide16x9'
    Apply-Settings
    Set-Footer 'Preset 16:9 aplicado: a tela superior preenche a janela (F10 alterna para a inferior).'
    Write-GuiLog 'Preset 16:9 aplicado: apenas tela superior, widescreen.'
})
$secDisplay.Children.Add($BtnFillScreen) | Out-Null

$secQuality = New-Section $GfxCol1 "QUALIDADE"
$CmbResolution      = Add-ComboField $secQuality "Resolução interna 3D" $ResolutionItems $Config.Resolution "Quanto maior, mais nítido e mais pesado."
$CmbRenderer        = Add-ComboField $secQuality "API gráfica" $RendererItems $Config.Renderer
$CmbRasterizer      = Add-ComboField $secQuality "Rasterizador" $RasterizerItems $Config.Rasterizer
$ChkTexturePacks    = Add-CheckField $secQuality "Pacotes de textura (mods)" $Config.TexturePacks
$ChkFrameInterpolation = Add-CheckField $secQuality "Interpolação de quadros (30 → 60 FPS)" $Config.FrameInterpolation
$ChkShowFps         = Add-CheckField $secQuality "Mostrar contador de FPS" $Config.ShowFps

$sec3d = New-Section $GfxCol2 "3D ESTEREOSCÓPICO"
$CmbStereo = Add-ComboField $sec3d "Modo 3D" $StereoItems $Config.Stereo
$depthField = Add-SliderField $sec3d "Profundidade 3D" 0 100 $Config.Depth3D "%" "Posição do slider de 3D do console."
$DepthSlider = $depthField.Slider
$DepthValueLabel = $depthField.Value
$DepthSlider.Add_ValueChanged({ $DepthValueLabel.Text = "$([int]$DepthSlider.Value)%" })
$ChkSwapEyes = Add-CheckField $sec3d "Inverter olhos (trocar esquerda/direita)" $Config.SwapEyes

$secAudio = New-Section $GfxCol2 "ÁUDIO"
$volField = Add-SliderField $secAudio "Volume" 0 100 $Config.Volume "%"
$VolumeSlider = $volField.Slider
$VolumeValueLabel = $volField.Value
$VolumeSlider.Add_ValueChanged({ $VolumeValueLabel.Text = "$([int]$VolumeSlider.Value)%" })
$ChkMute = Add-CheckField $secAudio "Mudo" $Config.Mute

$secSystem = New-Section $GfxCol2 "SISTEMA"
$CmbLanguage = Add-ComboField $secSystem "Idioma do console" $LanguageItems $Config.Language "Idioma que o jogo usa para textos e arquivos."
$ChkNew3DS = Add-CheckField $secSystem "Emular New 3DS (--new3ds)" $Config.New3DS "Ativa o modo New 3DS do Zakuro."

$note = [System.Windows.Controls.TextBlock]::new()
$note.Text = "As configurações são gravadas no settings.toml do Zakuro ao clicar em Salvar ou Jogar."
$note.Foreground = Brush "#6B7686"
$note.FontSize = 9
$note.TextWrapping = "Wrap"
$note.Margin = "0,4,0,0"
$secSystem.Children.Add($note) | Out-Null

# ------------------------------------------------------------------------------
# Montagem da página de controles
# ------------------------------------------------------------------------------
$KeyCodeNames = @(
    'KeyA','KeyB','KeyC','KeyD','KeyE','KeyF','KeyG','KeyH','KeyI','KeyJ','KeyK','KeyL','KeyM',
    'KeyN','KeyO','KeyP','KeyQ','KeyR','KeyS','KeyT','KeyU','KeyV','KeyW','KeyX','KeyY','KeyZ',
    'Digit0','Digit1','Digit2','Digit3','Digit4','Digit5','Digit6','Digit7','Digit8','Digit9',
    'F1','F2','F3','F4','F5','F6','F7','F8','F9','F10','F11','F12',
    'ArrowUp','ArrowDown','ArrowLeft','ArrowRight',
    'Enter','Escape','Backspace','Tab','Space',
    'ShiftLeft','ShiftRight','ControlLeft','ControlRight','AltLeft','AltRight',
    'Minus','Equal','BracketLeft','BracketRight','Backslash','Semicolon','Quote',
    'Comma','Period','Slash','Backquote',
    'Insert','Delete','Home','End','PageUp','PageDown','CapsLock','PrintScreen','ScrollLock','Pause',
    'Numpad0','Numpad1','Numpad2','Numpad3','Numpad4','Numpad5','Numpad6','Numpad7','Numpad8','Numpad9',
    'NumpadAdd','NumpadSubtract','NumpadMultiply','NumpadDivide','NumpadEnter','NumpadDecimal'
)

$PadButtonNames = @(
    'South','East','North','West','C','Z',
    'LeftTrigger','LeftTrigger2','RightTrigger','RightTrigger2',
    'Select','Start','Mode','LeftThumb','RightThumb',
    'DPadUp','DPadDown','DPadLeft','DPadRight'
)

$KeyOrder = [ordered]@{
    a = 'A'; b = 'B'; x = 'X'; y = 'Y'; l = 'L'; r = 'R'
    start = 'Start'; select = 'Select'
    up = 'D-pad ↑'; down = 'D-pad ↓'; left = 'D-pad ←'; right = 'D-pad →'
    circle_up = 'Circle Pad ↑'; circle_down = 'Circle Pad ↓'; circle_left = 'Circle Pad ←'; circle_right = 'Circle Pad →'
    zl = 'ZL'; zr = 'ZR'
    c_up = 'C-Stick ↑'; c_down = 'C-Stick ↓'; c_left = 'C-Stick ←'; c_right = 'C-Stick →'
}

$PadOrder = [ordered]@{
    a = 'A'; b = 'B'; x = 'X'; y = 'Y'; l = 'L'; r = 'R'
    start = 'Start'; select = 'Select'
    up = 'D-pad ↑'; down = 'D-pad ↓'; left = 'D-pad ←'; right = 'D-pad →'
    zl = 'ZL'; zr = 'ZR'
}

$KbCombos = [ordered]@{}
foreach ($key in $KeyOrder.Keys) {
    $cmb = New-BindingCombo $KeyCodeNames $Config.Keys[$key]
    $KbCombos[$key] = $cmb
    Add-BindingRow $KbPanel $KeyOrder[$key] $cmb
}

$PadCombos = [ordered]@{}
foreach ($key in $PadOrder.Keys) {
    $cmb = New-BindingCombo $PadButtonNames $Config.Pad[$key]
    $PadCombos[$key] = $cmb
    Add-BindingRow $PadPanel $PadOrder[$key] $cmb
}

# ------------------------------------------------------------------------------
# Navegação
# ------------------------------------------------------------------------------
$Pages = @{
    play = $PagePlay
    graphics = $PageGraphics
    controls = $PageControls
    stats = $PageStats
    about = $PageAbout
}

function Show-Page {
    param([string]$Name)
    foreach ($p in $Pages.Values) {
        $p.Visibility = [System.Windows.Visibility]::Collapsed
    }
    if ($Pages.ContainsKey($Name)) {
        $Pages[$Name].Visibility = [System.Windows.Visibility]::Visible
    }
    if ($Name -eq 'stats') { Update-StatsUI }
}

$NavPlay.Add_Checked({ Show-Page 'play' })
$NavGraphics.Add_Checked({ Show-Page 'graphics' })
$NavControls.Add_Checked({ Show-Page 'controls' })
$NavStats.Add_Checked({ Show-Page 'stats' })
$NavAbout.Add_Checked({ Show-Page 'about' })

# ------------------------------------------------------------------------------
# Eventos
# ------------------------------------------------------------------------------
$TitleBar.Add_MouseDown({
    if ($_.ChangedButton -eq [System.Windows.Input.MouseButton]::Left) {
        $Window.DragMove()
    }
})
$BtnMin.Add_Click({ $Window.WindowState = [System.Windows.WindowState]::Minimized })
$BtnClose.Add_Click({ $Window.Close() })

$BtnApply.Add_Click({ Apply-Settings })

$BtnBrowse.Add_Click({
    $dialog = [System.Windows.Forms.OpenFileDialog]::new()
    $dialog.Filter = "Nintendo 3DS ROMs (*.3ds;*.cxi)|*.3ds;*.cxi|Todos os arquivos (*.*)|*.*"
    $dialog.Title = "Selecione a ROM de Animal Crossing: New Leaf"
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $TxtRomPath.Text = $dialog.FileName
        $Config.RomPath = $dialog.FileName
        Save-Config
        Write-GuiLog "ROM selecionada: $($dialog.FileName)"
        Update-StatusUI
        Update-StatsUI
    }
})

$BtnPlay.Add_Click({ Launch-Game })
$BtnSidebarPlay.Add_Click({ Launch-Game })
$BtnRecompile.Add_Click({
    if ($script:RecompProc -and -not $script:RecompProc.HasExited) {
        Stop-RecompileProcess
    } else {
        Start-RecompileProcess
    }
})

$BtnOpenSaves.Add_Click({ Open-Path $GameDataDir })
$BtnOpenOutput.Add_Click({ Open-Path $OutputDir })
$BtnBackup.Add_Click({ Backup-Save })
$BtnOpenLog.Add_Click({ Open-File (Join-Path $GameDataDir "zakuro.log") })
$BtnOpenSettings.Add_Click({ Open-File $SettingsToml })

$BtnResetKb.Add_Click({
    foreach ($key in $DefaultKeys.Keys) {
        Set-ComboText $KbCombos[$key] $DefaultKeys[$key]
    }
    Set-Footer "Teclado restaurado ao padrão."
    Write-GuiLog "Bindings de teclado restaurados ao padrão."
})

$BtnResetPad.Add_Click({
    foreach ($key in $DefaultPad.Keys) {
        Set-ComboText $PadCombos[$key] $DefaultPad[$key]
    }
    Set-Footer "Controle restaurado ao padrão."
    Write-GuiLog "Bindings de controle restaurados ao padrão."
})

$BtnClearStats.Add_Click({
    $res = [System.Windows.MessageBox]::Show("Zerar todo o histórico de tempo jogado e sessões?", "Zerar estatísticas", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
    if ($res -eq [System.Windows.MessageBoxResult]::Yes) {
        $Config.Stats.TotalSeconds = 0.0
        $Config.Stats.Sessions = 0
        $Config.Stats.LastSessionSeconds = 0.0
        $Config.Stats.LastPlayed = ""
        $Config.Stats.History = @()
        Save-Config
        Update-StatsUI
        Write-GuiLog "Estatísticas zeradas."
        Set-Footer "Estatísticas zeradas."
    }
})

$BtnStatsSaves.Add_Click({ Open-Path $GameDataDir })
$BtnStatsBackup.Add_Click({ Backup-Save })
$BtnStatsLog.Add_Click({ Open-File (Join-Path $GameDataDir "zakuro.log") })

$BtnOpenReadme.Add_Click({ Open-File (Join-Path $RootPath "README.md") })
$BtnOpenProject.Add_Click({ Open-Path $RootPath })
$BtnOpenZakuroSettings.Add_Click({ Open-File $SettingsToml })
$BtnOpenAuthor.Add_Click({ Start-Process "https://github.com/Lucas4411" })
$BtnOpenOpenCode.Add_Click({ Start-Process "https://opencode.ai" })

$Window.Add_Closing({
    if ($script:RecompProc -and -not $script:RecompProc.HasExited) {
        $res = [System.Windows.MessageBox]::Show("A recompilação ainda está em andamento. Fechar mesmo assim?", "Recompilação", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
        if ($res -eq [System.Windows.MessageBoxResult]::No) { $_.Cancel = $true; return }
        try { $script:RecompProc.Kill() } catch {}
    }

    if ($script:GameProcess -and -not $script:GameProcess.HasExited) {
        $res = [System.Windows.MessageBox]::Show("O jogo continuará aberto. Fechar o launcher e registrar o tempo jogado até agora?", "Jogo em execução", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
        if ($res -eq [System.Windows.MessageBoxResult]::No) { $_.Cancel = $true; return }
        Finish-GameSession
    }

    try { Apply-Settings } catch {}
})

$Window.Add_Loaded({
    try {
        $consoleWnd = [WinAPI.WinConsole]::GetConsoleWindow()
        if ($consoleWnd -ne [IntPtr]::Zero) {
            [WinAPI.WinConsole]::ShowWindow($consoleWnd, 0) | Out-Null
        }
    } catch {}
    $Window.Activate()
})

# ------------------------------------------------------------------------------
# Inicialização da UI
# ------------------------------------------------------------------------------
$TxtRomPath.Text = $Config.RomPath
Update-StatusUI
Update-StatsUI

Write-GuiLog "Launcher v$LauncherVersion carregado."
Write-GuiLog "Zakuro: $ZakuroExe"
Write-GuiLog "Recompilador: $RecompExe"
if ($Config.RomPath) { Write-GuiLog "ROM: $($Config.RomPath)" }
Write-GuiLog "Dica: F11 tela cheia, F9 layout, F10 inverter telas, Tab fast-forward."
Set-Footer "Pronto."

$Window.ShowDialog() | Out-Null
