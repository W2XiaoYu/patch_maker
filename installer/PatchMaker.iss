; Inno Setup 6 script for Patch Maker
; 使用前：
;   1. 安装 Inno Setup 6: https://jrsoftware.org/isdl.php
;   2. 先在项目根跑: flutter build windows --release
;   3. 用 Inno Setup Compiler 打开本文件 → 点 Compile (Ctrl+F9)
;      或命令行: iscc installer\PatchMaker.iss
;   4. 输出: installer\Output\PatchMaker-Setup-1.0.0.exe

#define MyAppName "Patch Maker"
#define MyAppVersion "1.0.0"
#define MyAppExeName "patch_maker.exe"

[Setup]
AppId={{8F2B6D5E-7A4F-4E0A-9C1B-PATCHMAKER001}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
DefaultDirName={autopf}\PatchMaker
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}
OutputDir=Output
OutputBaseFilename=PatchMaker-Setup-{#MyAppVersion}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
ArchitecturesAllowed=x64compatible
PrivilegesRequired=admin
SetupIconFile=..\windows\runner\resources\app_icon.ico
; 移除下面这行的注释，并放一个 license.txt 在 installer/ 下，可以加许可协议
; LicenseFile=license.txt

[Languages]
Name: "chinesesimp"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"
Name: "english"; MessagesFile: "compiler:Languages\English.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; 把 flutter build windows 的 Release 目录整体复制进去
; 包括 patch_maker.exe / flutter_windows.dll / data/ / xdelta3.exe
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"
Name: "{group}\卸载 {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon; IconFilename: "{app}\{#MyAppExeName}"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; 卸载时清空安装目录（用户在 {app} 之外的文件不动）
Type: filesandordirs; Name: "{app}"
