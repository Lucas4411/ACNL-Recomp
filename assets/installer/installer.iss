; ACNL-Recomp - instalador (Inno Setup 6)
; Gera ACNL-Setup-2.0.exe com launcher + 3dsrecomp embutidos.
; Zakuro e w64devkit (GCC) sao baixados pelo ACNL-Bootstrap.exe no fim da instalacao.
;
; Antes de compilar, rode build\build-launcher.ps1 (gera ACNL-Launcher.exe e
; ACNL-Bootstrap.exe nesta pasta) e coloque 3dsrecomp.exe aqui tambem.

#define MyAppName "ACNL-Recomp"
#define MyAppVersion "2.0"
#define MyAppPublisher "ACNL-Recomp"
#define MyAppExeName "ACNL-Launcher.exe"

[Setup]
AppId={{0F8D39CC-7F9F-44E4-8BFD-E74487DF82EF}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={localappdata}\ACNL-Recomp
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=output
OutputBaseFilename=ACNL-Setup-2.0
SetupIconFile=leaf.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=yes
RestartApplications=no
InfoBeforeFile=..\docs\LEIA-ME.txt
VersionInfoVersion=2.0.0.0
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription=Instalador do ACNL-Recomp
VersionInfoProductName={#MyAppName}
VersionInfoProductVersion={#MyAppVersion}

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "ACNL-Launcher.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "ACNL-Bootstrap.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "3dsrecomp.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "leaf.ico"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\docs\LEIA-ME.txt"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\README.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\THIRD-PARTY-NOTICES.txt"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\launcher\launcher_config.json"; DestDir: "{app}"; Flags: onlyifdoesntexist uninsneveruninstall

[Dirs]
Name: "{app}\output"; Flags: uninsneveruninstall
Name: "{app}\game-data"; Flags: uninsneveruninstall

[Icons]
Name: "{group}\ACNL-Recomp"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; IconFilename: "{app}\{#MyAppExeName}"; Comment: "Abrir o launcher"
Name: "{group}\Atualizar dependências"; Filename: "{app}\ACNL-Bootstrap.exe"; WorkingDir: "{app}"; IconFilename: "{app}\ACNL-Bootstrap.exe"; Comment: "Baixar ou atualizar Zakuro e w64devkit (GCC)"
Name: "{group}\LEIA-ME"; Filename: "{app}\LEIA-ME.txt"; Comment: "Instruções do ACNL-Recomp"
Name: "{autodesktop}\ACNL-Recomp"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; IconFilename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\ACNL-Bootstrap.exe"; Parameters: "-Auto"; Description: "Baixar dependências e abrir o launcher"; Flags: nowait postinstall skipifsilent
Filename: "{app}\LEIA-ME.txt"; Description: "Abrir o LEIA-ME"; Flags: shellexec postinstall unchecked

[UninstallDelete]
Type: filesandordirs; Name: "{app}\zakuro"
Type: filesandordirs; Name: "{app}\tools"
Type: files; Name: "{app}\dependencies.txt"
Type: files; Name: "{app}\leaf.png"
