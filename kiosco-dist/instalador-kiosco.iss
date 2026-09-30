; =====================================================================
; Instalador del Kiosco - ConsultorioClinico (Inno Setup 6)
; ---------------------------------------------------------------------
; Genera Setup_KioscoConsultorio.exe: wizard siguiente/siguiente para
; personas NO técnicas. No pide admin (instala en AppData local).
;
; Compilar (persona técnica, una vez por release):
;   ISCC.exe instalador-kiosco.iss
; El Setup sale junto a este archivo. Requiere haber corrido antes:
;   flutter build windows --release --dart-define=RUTA_INICIAL=/kiosco ...
; =====================================================================

#define MyAppName "Kiosco ConsultorioClínico"
#define MyAppVersion "1.0.0"
#define MyAppExe "consultorio_clinico.exe"

[Setup]
AppId={{B4C210D9-8F2A-4E6B-A1C3-7D9E5F2A6B01}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
DefaultDirName={localappdata}\ConsultorioClinico\Kiosco
; Sin admin: instala en AppData del usuario (ideal para recepción).
PrivilegesRequired=lowest
OutputBaseFilename=Setup_KioscoConsultorio
Compression=lzma2/ultra
SolidCompression=yes
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
DisableProgramGroupPage=yes
UninstallDisplayName={#MyAppName}
WizardStyle=modern

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "Crear acceso directo en el escritorio"; GroupDescription: "Iconos:"; Flags: checkedonce
Name: "startup"; Description: "Abrir el kiosco solo al encender la PC (recomendado)"; GroupDescription: "Arranque:"

[Files]
; Todo el bundle compilado por Flutter. Se excluyen .lib/.exp (solo sirven
; para enlazar en compilación, no en ejecución).
Source: "..\frontend\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "*.exp,*.lib"

[Icons]
Name: "{autodesktop}\Kiosco Consultorio"; Filename: "{app}\{#MyAppExe}"; Tasks: desktopicon
Name: "{autostartup}\Kiosco Consultorio"; Filename: "{app}\{#MyAppExe}"; Tasks: startup

[Run]
Filename: "{app}\{#MyAppExe}"; Description: "Abrir el kiosco ahora"; Flags: nowait postinstall skipifsilent
