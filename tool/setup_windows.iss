; LedgerSync Windows 安裝檔（Inno Setup 6；techstack §2.3）
; CI 以 /DAPP_VERSION=x.y.z 傳入版本；本機除錯用預設值。
; per-user 安裝（PrivilegesRequired=lowest）：免管理員、免憑證；
; 資料庫位於 <Documents>\ledger_sync\（與可攜版共用，升級資料自動延續）。

#ifndef APP_VERSION
#define APP_VERSION "0.0.0"
#endif

[Setup]
AppId={{8C7F4B62-2A1E-4D3F-9B5A-6E8C1D4F7A90}
AppName=LedgerSync
AppVersion={#APP_VERSION}
AppPublisher=hung214
DefaultDirName={localappdata}\Programs\LedgerSync
DisableProgramGroupPage=yes
OutputBaseFilename=LedgerSync-setup-{#APP_VERSION}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\ledger_sync.exe

[Files]
; 相對路徑以 .iss 所在目錄（tool\）為基準——故為 ..\build\...
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Icons]
Name: "{autoprograms}\LedgerSync"; Filename: "{app}\ledger_sync.exe"
Name: "{autodesktop}\LedgerSync"; Filename: "{app}\ledger_sync.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\ledger_sync.exe"; Description: "Launch LedgerSync"; Flags: nowait postinstall skipifsilent
