; LabAssistant Inno Setup Script
; This script creates a Windows installer for the LabAssistant application
; including the Flutter app, Node.js backend, MinGW compiler, and screen capture agent

#define MyAppName "LabAssistant"
#define MyAppVersion "1.0.5"
#define MyAppPublisher "Sidaz Technology"
#define MyAppURL "https://sidaz.vercel.app/"
#define MyAppExeName "labassistant.exe"
#define ScreenCaptureExeName "ScreenCaptureAgent.exe"

[Setup]
; NOTE: The value of AppId uniquely identifies this application.
; Do not use the same AppId value in installers for other applications.
AppId=05f459ca-c18a-4ff5-b2e8-ade8e129ffe0
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
LicenseFile=C:\Users\user\LabAssistant\LICENSE.txt
; Uncomment the following line if you have a README
; InfoBeforeFile=C:\Users\user\LabAssistant\README.txt
OutputDir=C:\Users\user\LabAssistant\installer_output
OutputBaseFilename=LabAssistant_Setup_v{#MyAppVersion}
SetupIconFile=C:\Users\user\LabAssistant\assets\icon.ico
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesInstallIn64BitMode=x64
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\{#MyAppExeName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "quicklaunchicon"; Description: "{cm:CreateQuickLaunchIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked; OnlyBelowVersion: 6.1; Check: not IsAdminInstallMode

[Files]
; Main Flutter Application (build from flutter build windows)
Source: "C:\Users\user\LabAssistant\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; Note: Make sure to run 'flutter build windows --release' before creating the installer

; Backend Node.js Application
Source: "C:\Users\user\LabAssistant\backend\*"; DestDir: "{app}\backend"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "node_modules,*.log,*.tmp"

; MinGW Compiler (Required for C code compilation)
Source: "C:\Users\user\LabAssistant\MinGW\*"; DestDir: "{app}\MinGW"; Flags: ignoreversion recursesubdirs createallsubdirs

; Screen Capture Agent - Include the built executable
Source: "C:\Users\user\LabAssistant\screen_capture_agent\bin\Release\net6.0-windows\win-x64\publish\{#ScreenCaptureExeName}"; DestDir: "{app}\screen_capture_agent"; Flags: ignoreversion
Source: "C:\Users\user\LabAssistant\screen_capture_agent\*.md"; DestDir: "{app}\screen_capture_agent"; Flags: ignoreversion
Source: "C:\Users\user\LabAssistant\screen_capture_agent\INSTALL.bat"; DestDir: "{app}\screen_capture_agent"; Flags: ignoreversion

; Database initialization script (if you have one)
; Source: "C:\Users\user\LabAssistant\database\init.sql"; DestDir: "{app}\database"; Flags: ignoreversion

; Configuration files
Source: "C:\Users\user\LabAssistant\README.md"; DestDir: "{app}"; Flags: ignoreversion isreadme
Source: "C:\Users\user\LabAssistant\AUTO_LAUNCH_SETUP.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\Users\user\LabAssistant\ADMIN_LOGOUT_FEATURE.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\Users\user\LabAssistant\PORT_CONFIGURATION.md"; DestDir: "{app}"; Flags: ignoreversion
; Source: "C:\Users\user\LabAssistant\.env.example"; DestDir: "{app}\backend"; DestName: ".env"; Flags: ignoreversion onlyifdoesntexist

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
Name: "{userappdata}\Microsoft\Internet Explorer\Quick Launch\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: quicklaunchicon

[Run]
; Install Node.js dependencies for backend
Filename: "cmd.exe"; Parameters: "/c cd /d ""{app}\backend"" && npm install --production"; StatusMsg: "Installing backend dependencies..."; Flags: runhidden waituntilterminated
; Note: This requires Node.js to be installed on the target system

; Configure Windows Firewall for Screen Capture Agent
Filename: "netsh"; Parameters: "advfirewall firewall add rule name=""Lab Assistant Screen Capture"" dir=in action=allow protocol=TCP localport=8765 program=""{app}\screen_capture_agent\{#ScreenCaptureExeName}"" enable=yes"; StatusMsg: "Configuring Windows Firewall..."; Flags: runhidden waituntilterminated

; Optional: Run the application after installation
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
var
  NodeJSInstalled: Boolean;
  PostgreSQLInstalled: Boolean;

// Check if Node.js is installed
function IsNodeJSInstalled(): Boolean;
var
  ResultCode: Integer;
begin
  Result := Exec('cmd.exe', '/c node --version', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  if Result then
    Result := (ResultCode = 0);
end;

// Check if PostgreSQL is installed
function IsPostgreSQLInstalled(): Boolean;
var
  ResultCode: Integer;
begin
  Result := Exec('cmd.exe', '/c psql --version', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  if Result then
    Result := (ResultCode = 0);
end;

function InitializeSetup(): Boolean;
var
  ErrorMessage: String;
begin
  Result := True;
  ErrorMessage := '';
  
  // Check for Node.js
  NodeJSInstalled := IsNodeJSInstalled();
  if not NodeJSInstalled then
  begin
    ErrorMessage := ErrorMessage + '- Node.js (Required for backend server)' + #13#10;
  end;
  
  // Check for PostgreSQL
  PostgreSQLInstalled := IsPostgreSQLInstalled();
  if not PostgreSQLInstalled then
  begin
    ErrorMessage := ErrorMessage + '- PostgreSQL (Required for database)' + #13#10;
  end;
  
  // Show warning if prerequisites are missing
  if ErrorMessage <> '' then
  begin
    if MsgBox('The following prerequisites are not installed:' + #13#10 + #13#10 + 
              ErrorMessage + #13#10 + 
              'The application may not work correctly without these components.' + #13#10 + #13#10 +
              'Do you want to continue with the installation?', 
              mbConfirmation, MB_YESNO) = IDNO then
    begin
      Result := False;
    end;
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  ConfigContent: AnsiString;
  ConfigFile: String;
begin
  if CurStep = ssPostInstall then
  begin
    // Update paths in compiler.js
    // Note: Since we already updated compiler.js to use relative paths,
    // this section is no longer needed. The path.join() will work automatically.
    
    // Update paths in server_manager.dart (if needed - this is in compiled Flutter app)
    // Note: For Flutter app, you should use relative paths or environment variables
    
    // Create a batch file to set environment variables and run the app
    ConfigFile := ExpandConstant('{app}\run_labassistant.bat');
    ConfigContent := '@echo off' + #13#10 +
                     'set MINGW_PATH=' + ExpandConstant('{app}\MinGW\bin\gcc.exe') + #13#10 +
                     'set BACKEND_PATH=' + ExpandConstant('{app}\backend') + #13#10 +
                     'set SCREEN_CAPTURE_PATH=' + ExpandConstant('{app}\screen_capture_agent\{#ScreenCaptureExeName}') + #13#10 +
                     'start "" "' + ExpandConstant('{app}\{#MyAppExeName}') + '"' + #13#10;
    SaveStringToFile(ConfigFile, ConfigContent, False);
    
    // Create config.json for screen capture agent with default port
    ConfigFile := ExpandConstant('{app}\screen_capture_agent\config.json');
    ConfigContent := '{"port": 8765}';
    SaveStringToFile(ConfigFile, ConfigContent, False);
  end;
end;

[UninstallDelete]
Type: filesandordirs; Name: "{app}\backend\node_modules"
Type: filesandordirs; Name: "{app}\backend\*.log"
Type: files; Name: "{app}\run_labassistant.bat"

[Registry]
; Add MinGW to system PATH (optional)
Root: HKLM; Subkey: "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"; ValueType: expandsz; ValueName: "Path"; ValueData: "{olddata};{app}\MinGW\bin"; Check: NeedsAddPath(ExpandConstant('{app}\MinGW\bin'))

[Code]
// Check if path needs to be added
function NeedsAddPath(Param: string): boolean;
var
  OrigPath: string;
begin
  if not RegQueryStringValue(HKEY_LOCAL_MACHINE,
    'SYSTEM\CurrentControlSet\Control\Session Manager\Environment',
    'Path', OrigPath)
  then begin
    Result := True;
    exit;
  end;
  Result := Pos(';' + Param + ';', ';' + OrigPath + ';') = 0;
end;

[Messages]
WelcomeLabel2=This will install [name/ver] on your computer.%n%nThis application requires:%n- Node.js (v14 or higher)%n- PostgreSQL (v12 or higher)%n- MinGW (included)%n- .NET 6.0 Runtime (for Screen Capture Agent)%n%nFeatures:%n- Auto-launch Screen Capture Agent%n- Admin logout broadcasts to students%n- Real-time screen monitoring%n- Custom port configuration%n%nIt is recommended that you close all other applications before continuing.
