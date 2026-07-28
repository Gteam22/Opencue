; Inno Setup script for OpenCue.
;
; Produces a single OpenCue-Setup.exe that installs the complete Flutter Windows
; release bundle. Nothing here is imported by the application: the app has no
; knowledge that it was installed by an installer, so this file can change
; freely without touching lib/.
;
; Build it with:
;   iscc /DBuildDir="build\windows\x64\runner\Release" installer\opencue.iss
;
; BuildDir is passed in rather than hard-coded because Flutter's output path has
; changed across versions and is architecture-dependent. The default below only
; covers the common x64 case for a local build; CI always passes it explicitly
; after locating the directory that actually exists. See
; .github/workflows/build-windows-installer.yml.

#define MyAppName "OpenCue"
#define MyAppVersion "0.1.0"
; Replace with a real organisation name before publishing. This string also
; appears in lib/core/app_info.dart (AppInfo.publisher) and in LICENSE; all
; three must be changed together.
#define MyAppPublisher "PUBLISHER_PLACEHOLDER"
; Replace with the real project URL.
#define MyAppURL "https://github.com/OWNER/opencue"
#define MyAppExeName "opencue.exe"

#ifndef BuildDir
  #define BuildDir "..\build\windows\x64\runner\Release"
#endif

; Fail early and clearly rather than producing an installer with no program in
; it, which is a mistake that only shows up on the user's machine.
#if !FileExists(AddBackslash(BuildDir) + MyAppExeName)
  #error The Flutter release bundle was not found. Run "flutter build windows --release" first, or pass /DBuildDir=<path to the Release folder>.
#endif

[Setup]
; A stable GUID. Changing it would make an upgrade install alongside the old
; copy instead of replacing it, so it must never change for this application.
AppId={{8C4D3A9E-6B21-4F5E-9C7A-1D2E3F4A5B6C}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
VersionInfoVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
UninstallDisplayName={#MyAppName} {#MyAppVersion}
UninstallDisplayIcon={app}\{#MyAppExeName}

; Per-user install into the user's own AppData, so no administrator rights are
; needed and one machine can serve several accounts independently.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
; The licence is shown in the wizard; the readme is not, to keep the flow short.
LicenseFile=..\LICENSE

OutputDir=Output
OutputBaseFilename=OpenCue-Setup
SetupIconFile=..\assets\icons\opencue.ico
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
; The app itself is 64-bit; on a 64-bit OS install as a 64-bit application so
; {autopf} resolves to Program Files rather than Program Files (x86).
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

; Code signing: leave commented until a certificate is available. Configure the
; signing tool in the Inno Setup IDE (Tools > Configure Sign Tools) or pass
; /Ssigntool=... to iscc, then uncomment both lines.
; SignTool=signtool
; SignedUninstaller=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "japanese"; MessagesFile: "compiler:Languages\Japanese.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; \
  GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; The whole Flutter release bundle: the executable, flutter_windows.dll, the
; ICU data and the assets directory. recursesubdirs picks up data\ and any
; plugin DLLs, so no Flutter installation is needed on the target machine.
;
; ignoreversion is correct here because these files are versioned together as
; one bundle; comparing individual DLL versions would leave a mismatched set
; behind after an upgrade.
Source: "{#BuildDir}\*"; DestDir: "{app}"; \
  Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; \
  Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; \
  Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; \
  Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Only files this installer created are removed. The database lives in
; {userappdata}\OpenCue and is deliberately left in place: uninstalling should
; not silently destroy the user's own lines and notes. See the README for how
; to remove it by hand.
Type: filesandordirs; Name: "{app}"

[Code]
{ On upgrade Inno Setup replaces the files in {app}. The database is not in
  {app} at all - it is written to {userappdata}\OpenCue by AppPaths in
  lib/core/app_paths.dart - so an upgrade cannot reach it. This procedure exists
  only to make that guarantee explicit and to fail loudly if someone ever moves
  the data into the install directory. }
procedure CurStepChanged(CurStep: TSetupStep);
var
  StrayDatabase: String;
begin
  if CurStep = ssInstall then
  begin
    StrayDatabase := ExpandConstant('{app}\opencue.db');
    if FileExists(StrayDatabase) then
      MsgBox('A database was found inside the installation folder. OpenCue ' +
             'stores data in your user profile, so this file is not used and ' +
             'will be replaced. Copy it elsewhere first if you need it.',
             mbInformation, MB_OK);
  end;
end;
