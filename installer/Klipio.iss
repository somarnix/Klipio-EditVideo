; All release identifiers are supplied by the canonical pubspec-driven builder.
#ifndef AppVersion
  #error Run BUILD_FULL_WINDOWS_INSTALLER.bat, not ISCC directly.
#endif
#define RuntimeDir "versions\" + PackageId

[Setup]
AppId=Somarnix.Klipio
AppName=Klipio
AppVersion={#AppVersion}
AppVerName=Klipio V{#AppVersion}
AppPublisher=Somarnix
AppComments=Klipio Video Editor
VersionInfoVersion={#AppVersion}.{#BuildNumber}
VersionInfoDescription=Klipio Video Editor Setup
DefaultDirName={code:DefaultInstallRoot}
DefaultGroupName=Klipio
DisableProgramGroupPage=yes
DisableDirPage=no
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.17763
WizardStyle=modern
SetupIconFile=..\windows\runner\resources\app_icon.ico
#ifdef WizardLogo
WizardSmallImageFile={#WizardLogo}
#endif
UninstallDisplayIcon={app}\Klipio.exe
UninstallFilesDir={app}\uninstall
OutputDir={#Output}
OutputBaseFilename={#SetupName}
Compression=lzma2/normal
SolidCompression=yes
CloseApplications=no
RestartApplications=no
AppMutex=Local\Somarnix.Klipio.Runtime
SetupMutex=Local\Somarnix.Klipio.Setup
AllowCancelDuringInstall=yes
Uninstallable=yes
UsePreviousTasks=yes
#ifdef SignRelease
SignTool=KlipioSign
SignedUninstaller=yes
#endif

[Tasks]
Name: "desktopicon"; Description: "Create a Desktop shortcut"; Flags: unchecked
Name: "startmenuicon"; Description: "Create a Start Menu shortcut"

[Files]
Source: "{#Stage}\*"; DestDir: "{app}\{#RuntimeDir}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#Stage}\KlipioLauncher.exe"; DestDir: "{app}"; DestName: "Klipio.exe"; Flags: ignoreversion
Source: "{#PackagePointer}"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\Klipio"; Filename: "{app}\Klipio.exe"; WorkingDir: "{app}"; Comment: "Klipio V{#AppVersion}"; Tasks: startmenuicon; AppUserModelID: Somarnix.Klipio
Name: "{autodesktop}\Klipio"; Filename: "{app}\Klipio.exe"; WorkingDir: "{app}"; Comment: "Klipio V{#AppVersion}"; Tasks: desktopicon; AppUserModelID: Somarnix.Klipio

[Registry]
Root: HKCU; Subkey: "Software\Somarnix\Klipio"; ValueType: string; ValueName: "InstallRoot"; ValueData: "{app}"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Somarnix\Klipio"; ValueType: string; ValueName: "CurrentPackage"; ValueData: "{#PackageId}"
Root: HKCU; Subkey: "Software\Somarnix\Klipio"; ValueType: string; ValueName: "CurrentVersion"; ValueData: "{#AppVersion}.{#BuildNumber}"

[Run]
Filename: "{app}\Klipio.exe"; Description: "Launch Klipio V{#AppVersion}"; Flags: nowait postinstall skipifsilent

[Code]
function DefaultInstallRoot(Param: String): String;
begin
  if not RegQueryStringValue(HKCU, 'Software\Somarnix\Klipio', 'InstallRoot', Result) then
    if not RegQueryStringValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Uninstall\Klipio', 'InstallLocation', Result) then
      Result := ExpandConstant('{localappdata}\Programs\Klipio');
end;

function RunningKlipio: Boolean;
var Service, Processes, Locator: Variant;
begin
  Result := CheckForMutexes('Local\Somarnix.Klipio.Runtime');
  if Result then exit;
  // Legacy builds lack the mutex. Never kill them or overwrite loaded DLLs.
  try
    Service := GetActiveOleObject('winmgmts:');
  except
    Locator := CreateOleObject('WbemScripting.SWbemLocator');
    Service := Locator.ConnectServer('', 'root\CIMV2');
  end;
  Processes := Service.ExecQuery('SELECT ProcessId FROM Win32_Process WHERE Name = ''Klipio.exe''');
  Result := Processes.Count > 0;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var Root, InstalledVersion: String; Incoming, Previous: Int64;
begin
  Result := '';
  if RunningKlipio then begin
    Result := 'Save your project and close Klipio before installing. Setup will not force-close your editor.';
    exit;
  end;
  Root := RemoveBackslashUnlessRoot(ExpandConstant('{app}'));
  if (CompareText(Root, ExpandConstant('{localappdata}')) = 0) or
     (CompareText(Root, ExpandConstant('{userdocs}')) = 0) or
     (CompareText(Root, ExtractFileDrive(Root) + '\') = 0) then begin
    Result := 'Choose a dedicated Klipio installation folder, not a drive or user-data root.';
    exit;
  end;
  // Versions are content-addressed: upgrading never mixes an old DLL with a
  // new EXE, even when a developer rebuilds the same pubspec version.
  if RegQueryStringValue(HKCU, 'Software\Somarnix\Klipio', 'CurrentVersion', InstalledVersion) then
    if StrToVersion('{#AppVersion}.{#BuildNumber}', Incoming) and StrToVersion(InstalledVersion, Previous) then
      if ComparePackedVersion(Incoming, Previous) < 0 then
        Result := 'A newer Klipio version is installed. Uninstall it before deliberately downgrading. Projects are preserved.';
end;

procedure PreserveLegacyRuntime;
var Root, Backup, Source, Target, LegacyLocation: String; Names: TArrayOfString; I: Integer;
begin
  Root := ExpandConstant('{app}');
  if not FileExists(Root + '\Klipio.exe') then exit;
  if not RegQueryStringValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Uninstall\Klipio', 'InstallLocation', LegacyLocation) then exit;
  if CompareText(RemoveBackslashUnlessRoot(LegacyLocation), RemoveBackslashUnlessRoot(Root)) <> 0 then exit;
  Backup := ExpandConstant('{localappdata}\Klipio\LegacyInstallBackup\') + GetDateTimeString('yyyymmdd-hhnnss', '-', ':');
  ForceDirectories(Backup);
  // Move only known runtime entries. Unknown files and user projects stay put;
  // backups are user-owned and are deliberately not part of uninstall cleanup.
  // The old root EXE is replaced by Inno's rollback-aware file transaction.
  // Do not move the newly installed launcher into the legacy backup.
  Names := ['flutter_windows.dll', 'video_player_win_plugin.dll', 'audioplayers_windows_plugin.dll', 'desktop_drop_plugin.dll', 'ffmpeg.exe', 'ffprobe.exe', 'python', 'data', 'native_assets.yaml', 'Uninstall Klipio.cmd', 'klipio-language.txt'];
  for I := 0 to GetArrayLength(Names)-1 do begin
    Source := Root + '\' + Names[I];
    Target := Backup + '\' + Names[I];
    if FileExists(Source) or DirExists(Source) then
      if not RenameFile(Source, Target) then
        Log('Legacy entry retained because it could not be safely moved: ' + Names[I]);
  end;
  if FileExists(Backup + '\klipio-language.txt') then begin
    ForceDirectories(ExpandConstant('{userappdata}\Klipio'));
    if not FileExists(ExpandConstant('{userappdata}\Klipio\klipio-language.txt')) then
      CopyFile(Backup + '\klipio-language.txt', ExpandConstant('{userappdata}\Klipio\klipio-language.txt'), False);
  end;
  RegDeleteKeyIncludingSubkeys(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Uninstall\Klipio');
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then begin
    PreserveLegacyRuntime;
    if not WizardIsTaskSelected('desktopicon') then DeleteFile(ExpandConstant('{autodesktop}\Klipio.lnk'));
    if not WizardIsTaskSelected('startmenuicon') then DeleteFile(ExpandConstant('{autoprograms}\Klipio.lnk'));
  end;
end;

function InitializeUninstall: Boolean;
begin
  Result := not RunningKlipio;
  if not Result then MsgBox('Save your project and close Klipio before uninstalling. Your projects and user data will be preserved.', mbInformation, MB_OK);
end;
